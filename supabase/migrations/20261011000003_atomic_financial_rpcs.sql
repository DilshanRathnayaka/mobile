-- ==============================================================================
-- Migration: 20261011000003_atomic_financial_rpcs.sql
-- Description: Provides atomic, idempotent financial ledger RPCs:
--              create_trade, update_trade, delete_trade,
--              save_salary_allocation, delete_salary_allocation.
--              Enforces advisory locking, inventory checks (no oversells),
--              retains realized PnL on liquidations, handles asset changes,
--              and links salary allocations to deposit transactions atomically.
-- ==============================================================================

-- Clean up any existing function overloads to prevent ambiguity
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT oid::regprocedure AS func_signature
        FROM pg_proc 
        WHERE pronamespace = 'public'::regnamespace 
          AND proname IN ('create_trade', 'update_trade', 'delete_trade', 'save_salary_allocation', 'delete_salary_allocation', 'internal_recalculate_holding')
    ) LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_signature || ' CASCADE';
    END LOOP;
END $$;

-- 1. Helper function: Recalculate holding for a user & coin
CREATE OR REPLACE FUNCTION public.internal_recalculate_holding(
    p_user_id UUID,
    p_coin_id TEXT,
    p_symbol TEXT,
    p_name TEXT
)
RETURNS VOID AS $$
DECLARE
    tx RECORD;
    v_total_qty NUMERIC(28, 8) := 0;
    v_total_cost NUMERIC(28, 4) := 0;
    v_avg_price NUMERIC(28, 8) := 0;
    v_realized_pnl NUMERIC(28, 4) := 0;
    v_sell_rev NUMERIC(28, 4);
    v_cost_basis NUMERIC(28, 4);
BEGIN
    IF p_coin_id IS NULL OR p_user_id IS NULL THEN
        RETURN;
    END IF;

    -- Iterate chronologically through all trades for this coin
    FOR tx IN 
        SELECT id, type, amount, price_per_unit, total_amount, fee, transaction_date, created_at
        FROM public.transactions 
        WHERE user_id = p_user_id AND coin_id = p_coin_id AND type IN ('BUY', 'SELL')
        ORDER BY transaction_date ASC, 
                 CASE WHEN type IN ('BUY', 'LONG') THEN 1 ELSE 2 END ASC, 
                 created_at ASC, 
                 id ASC
    LOOP
        IF tx.type = 'BUY' THEN
            v_total_qty := v_total_qty + tx.amount;
            v_total_cost := v_total_cost + tx.total_amount + COALESCE(tx.fee, 0);
            IF v_total_qty > 0 THEN
                v_avg_price := v_total_cost / v_total_qty;
            END IF;
        ELSIF tx.type = 'SELL' THEN
            -- Inventory check: Prevent oversells
            IF tx.amount > (v_total_qty + 0.00000001) THEN
                RAISE EXCEPTION 'Inventory violation: Attempted to sell % % with only % available at date %',
                    tx.amount, p_symbol, v_total_qty, tx.transaction_date;
            END IF;

            v_sell_rev := tx.total_amount - COALESCE(tx.fee, 0);
            v_cost_basis := tx.amount * v_avg_price;
            v_realized_pnl := v_realized_pnl + (v_sell_rev - v_cost_basis);
            v_total_qty := GREATEST(0, v_total_qty - tx.amount);
            IF v_total_qty <= 0.00000001 THEN
                v_total_qty := 0;
                v_avg_price := 0;
                v_total_cost := 0;
            ELSE
                v_total_cost := v_total_qty * v_avg_price;
            END IF;
        END IF;
    END LOOP;

    -- Upsert holding: RETAIN realized PnL even if total_quantity is 0!
    INSERT INTO public.holdings (
        user_id, coin_id, symbol, name, total_quantity, average_buy_price, total_invested_cost, realized_pnl, updated_at
    )
    VALUES (
        p_user_id, p_coin_id, p_symbol, p_name, v_total_qty, v_avg_price, v_total_cost, v_realized_pnl, NOW()
    )
    ON CONFLICT (user_id, coin_id)
    DO UPDATE SET
        total_quantity = EXCLUDED.total_quantity,
        average_buy_price = EXCLUDED.average_buy_price,
        total_invested_cost = EXCLUDED.total_invested_cost,
        realized_pnl = EXCLUDED.realized_pnl,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 2. RPC: create_trade
CREATE OR REPLACE FUNCTION public.create_trade(
    p_operation_id UUID,
    p_type TEXT,
    p_symbol TEXT,
    p_name TEXT,
    p_coin_id TEXT,
    p_amount NUMERIC,
    p_price NUMERIC,
    p_fee NUMERIC,
    p_date TIMESTAMPTZ,
    p_notes TEXT,
    p_original_currency TEXT DEFAULT 'USD',
    p_original_amount NUMERIC DEFAULT NULL,
    p_fx_to_base NUMERIC DEFAULT 1.0,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_op RECORD;
    v_tx_id UUID;
    v_total NUMERIC(28, 4);
    v_result JSONB;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: User not authenticated';
    END IF;

    -- Acquire per-user advisory transaction lock for strict serialization
    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    -- Idempotency check
    SELECT * INTO v_existing_op FROM public.idempotent_operations
    WHERE id = p_operation_id AND user_id = v_user_id;
    IF FOUND THEN
        RETURN v_existing_op.result;
    END IF;

    -- Input validations
    IF p_type NOT IN ('BUY', 'SELL') THEN
        RAISE EXCEPTION 'Invalid transaction type: %', p_type;
    END IF;
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Transaction amount must be positive';
    END IF;
    IF p_price < 0 THEN
        RAISE EXCEPTION 'Transaction price cannot be negative';
    END IF;
    IF p_fee < 0 THEN
        RAISE EXCEPTION 'Transaction fee cannot be negative';
    END IF;

    v_total := ROUND(p_amount * p_price, 4);

    -- Insert trade
    INSERT INTO public.transactions (
        user_id, type, coin_id, symbol, name, amount, price_per_unit, total_amount, fee,
        transaction_date, notes, original_currency, original_amount, fx_to_base, operation_id
    )
    VALUES (
        v_user_id, p_type, p_coin_id, p_symbol, p_name, p_amount, p_price, v_total, COALESCE(p_fee, 0),
        COALESCE(p_date, NOW()), COALESCE(p_notes, ''), COALESCE(p_original_currency, 'USD'),
        COALESCE(p_original_amount, p_amount), COALESCE(p_fx_to_base, 1.0), p_operation_id
    )
    RETURNING id INTO v_tx_id;

    -- Atomically recalculate DCA holding and validate inventory
    PERFORM public.internal_recalculate_holding(v_user_id, p_coin_id, p_symbol, p_name);

    -- Log audit trail
    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, payload)
    VALUES (v_user_id, 'CREATE_TRADE', 'transaction', v_tx_id, jsonb_build_object(
        'type', p_type, 'symbol', p_symbol, 'amount', p_amount, 'price', p_price, 'fee', p_fee
    ));

    v_result := jsonb_build_object(
        'success', true,
        'transaction_id', v_tx_id,
        'operation_id', p_operation_id
    );

    -- Save operation record
    INSERT INTO public.idempotent_operations (id, user_id, operation_type, result)
    VALUES (p_operation_id, v_user_id, 'create_trade', v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 3. RPC: update_trade
CREATE OR REPLACE FUNCTION public.update_trade(
    p_operation_id UUID,
    p_tx_id UUID,
    p_type TEXT,
    p_symbol TEXT,
    p_name TEXT,
    p_coin_id TEXT,
    p_amount NUMERIC,
    p_price NUMERIC,
    p_fee NUMERIC,
    p_date TIMESTAMPTZ,
    p_notes TEXT,
    p_original_currency TEXT DEFAULT 'USD',
    p_original_amount NUMERIC DEFAULT NULL,
    p_fx_to_base NUMERIC DEFAULT 1.0,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_op RECORD;
    v_old_tx RECORD;
    v_total NUMERIC(28, 4);
    v_result JSONB;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    SELECT * INTO v_existing_op FROM public.idempotent_operations
    WHERE id = p_operation_id AND user_id = v_user_id;
    IF FOUND THEN
        RETURN v_existing_op.result;
    END IF;

    -- Fetch old transaction
    SELECT * INTO v_old_tx FROM public.transactions
    WHERE id = p_tx_id AND user_id = v_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;

    IF p_type NOT IN ('BUY', 'SELL') THEN
        RAISE EXCEPTION 'Invalid transaction type: %', p_type;
    END IF;
    IF p_amount <= 0 OR p_price < 0 OR p_fee < 0 THEN
        RAISE EXCEPTION 'Invalid trade numeric inputs';
    END IF;

    v_total := ROUND(p_amount * p_price, 4);

    -- Update transaction
    UPDATE public.transactions SET
        type = p_type,
        coin_id = p_coin_id,
        symbol = p_symbol,
        name = p_name,
        amount = p_amount,
        price_per_unit = p_price,
        total_amount = v_total,
        fee = COALESCE(p_fee, 0),
        transaction_date = COALESCE(p_date, NOW()),
        notes = COALESCE(p_notes, ''),
        original_currency = COALESCE(p_original_currency, 'USD'),
        original_amount = COALESCE(p_original_amount, p_amount),
        fx_to_base = COALESCE(p_fx_to_base, 1.0),
        updated_at = NOW()
    WHERE id = p_tx_id AND user_id = v_user_id;

    -- Recalculate new coin
    PERFORM public.internal_recalculate_holding(v_user_id, p_coin_id, p_symbol, p_name);

    -- If coin was changed, ALSO recalculate old coin!
    IF v_old_tx.coin_id IS DISTINCT FROM p_coin_id THEN
        PERFORM public.internal_recalculate_holding(v_user_id, v_old_tx.coin_id, v_old_tx.symbol, v_old_tx.name);
    END IF;

    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, payload)
    VALUES (v_user_id, 'UPDATE_TRADE', 'transaction', p_tx_id, jsonb_build_object(
        'old_coin', v_old_tx.coin_id, 'new_coin', p_coin_id, 'amount', p_amount
    ));

    v_result := jsonb_build_object('success', true, 'transaction_id', p_tx_id);
    INSERT INTO public.idempotent_operations (id, user_id, operation_type, result)
    VALUES (p_operation_id, v_user_id, 'update_trade', v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 4. RPC: delete_trade
CREATE OR REPLACE FUNCTION public.delete_trade(
    p_operation_id UUID,
    p_tx_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_op RECORD;
    v_old_tx RECORD;
    v_result JSONB;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    SELECT * INTO v_existing_op FROM public.idempotent_operations
    WHERE id = p_operation_id AND user_id = v_user_id;
    IF FOUND THEN
        RETURN v_existing_op.result;
    END IF;

    SELECT * INTO v_old_tx FROM public.transactions
    WHERE id = p_tx_id AND user_id = v_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Transaction % not found', p_tx_id;
    END IF;

    DELETE FROM public.transactions WHERE id = p_tx_id AND user_id = v_user_id;

    -- Recalculate holding after deletion
    IF v_old_tx.coin_id IS NOT NULL THEN
        PERFORM public.internal_recalculate_holding(v_user_id, v_old_tx.coin_id, v_old_tx.symbol, v_old_tx.name);
    END IF;

    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, payload)
    VALUES (v_user_id, 'DELETE_TRADE', 'transaction', p_tx_id, jsonb_build_object(
        'deleted_coin', v_old_tx.coin_id, 'amount', v_old_tx.amount
    ));

    v_result := jsonb_build_object('success', true, 'deleted_id', p_tx_id);
    INSERT INTO public.idempotent_operations (id, user_id, operation_type, result)
    VALUES (p_operation_id, v_user_id, 'delete_trade', v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 5. RPC: save_salary_allocation (Atomic allocation + linked deposit)
CREATE OR REPLACE FUNCTION public.save_salary_allocation(
    p_operation_id UUID,
    p_year_month TEXT,
    p_salary NUMERIC,
    p_allocated NUMERIC,
    p_percentage NUMERIC,
    p_notes TEXT,
    p_original_currency TEXT DEFAULT 'USD',
    p_fx_to_base NUMERIC DEFAULT 1.0,
    p_effective_date TIMESTAMPTZ DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_op RECORD;
    v_alloc_id UUID;
    v_deposit_id UUID;
    v_eff_date TIMESTAMPTZ;
    v_result JSONB;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    SELECT * INTO v_existing_op FROM public.idempotent_operations
    WHERE id = p_operation_id AND user_id = v_user_id;
    IF FOUND THEN
        RETURN v_existing_op.result;
    END IF;

    IF p_salary < 0 OR p_allocated < 0 OR p_percentage < 0 OR p_percentage > 100 THEN
        RAISE EXCEPTION 'Invalid salary allocation amounts';
    END IF;

    v_eff_date := COALESCE(p_effective_date, NOW());

    -- Upsert salary allocation
    INSERT INTO public.salary_allocations (
        user_id, year_month, salary_amount, allocated_amount, allocation_percentage,
        notes, original_currency, fx_to_base, effective_date, operation_id, updated_at
    )
    VALUES (
        v_user_id, p_year_month, p_salary, p_allocated, p_percentage,
        COALESCE(p_notes, ''), COALESCE(p_original_currency, 'USD'), COALESCE(p_fx_to_base, 1.0),
        v_eff_date, p_operation_id, NOW()
    )
    ON CONFLICT (user_id, year_month)
    DO UPDATE SET
        salary_amount = EXCLUDED.salary_amount,
        allocated_amount = EXCLUDED.allocated_amount,
        allocation_percentage = EXCLUDED.allocation_percentage,
        notes = EXCLUDED.notes,
        original_currency = EXCLUDED.original_currency,
        fx_to_base = EXCLUDED.fx_to_base,
        effective_date = EXCLUDED.effective_date,
        updated_at = NOW()
    RETURNING id INTO v_alloc_id;

    -- Atomically update or insert the linked SALARY_DEPOSIT transaction
    SELECT id INTO v_deposit_id FROM public.transactions
    WHERE user_id = v_user_id AND salary_allocation_id = v_alloc_id;

    IF FOUND THEN
        UPDATE public.transactions SET
            amount = 1.0,
            price_per_unit = p_allocated,
            total_amount = p_allocated,
            fee = 0,
            transaction_date = v_eff_date,
            notes = 'Salary Deposit for ' || p_year_month || ': ' || COALESCE(p_notes, ''),
            original_currency = COALESCE(p_original_currency, 'USD'),
            original_amount = p_allocated,
            fx_to_base = COALESCE(p_fx_to_base, 1.0),
            updated_at = NOW()
        WHERE id = v_deposit_id;
    ELSE
        INSERT INTO public.transactions (
            user_id, type, amount, price_per_unit, total_amount, fee,
            transaction_date, notes, original_currency, original_amount, fx_to_base, salary_allocation_id
        )
        VALUES (
            v_user_id, 'SALARY_DEPOSIT', 1.0, p_allocated, p_allocated, 0,
            v_eff_date, 'Salary Deposit for ' || p_year_month || ': ' || COALESCE(p_notes, ''),
            COALESCE(p_original_currency, 'USD'), p_allocated, COALESCE(p_fx_to_base, 1.0), v_alloc_id
        )
        RETURNING id INTO v_deposit_id;
    END IF;

    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, payload)
    VALUES (v_user_id, 'SAVE_SALARY_ALLOCATION', 'salary_allocation', v_alloc_id, jsonb_build_object(
        'year_month', p_year_month, 'allocated', p_allocated, 'deposit_id', v_deposit_id
    ));

    v_result := jsonb_build_object(
        'success', true,
        'allocation_id', v_alloc_id,
        'deposit_transaction_id', v_deposit_id
    );

    INSERT INTO public.idempotent_operations (id, user_id, operation_type, result)
    VALUES (p_operation_id, v_user_id, 'save_salary_allocation', v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 6. RPC: delete_salary_allocation (Atomic allocation + linked deposit removal)
CREATE OR REPLACE FUNCTION public.delete_salary_allocation(
    p_operation_id UUID,
    p_year_month TEXT,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_existing_op RECORD;
    v_alloc RECORD;
    v_result JSONB;
BEGIN
    v_user_id := COALESCE(auth.uid(), p_user_id);
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized';
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_user_id::text));

    SELECT * INTO v_existing_op FROM public.idempotent_operations
    WHERE id = p_operation_id AND user_id = v_user_id;
    IF FOUND THEN
        RETURN v_existing_op.result;
    END IF;

    SELECT * INTO v_alloc FROM public.salary_allocations
    WHERE user_id = v_user_id AND year_month = p_year_month;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Salary allocation for % not found', p_year_month;
    END IF;

    -- Delete linked transaction & allocation (ON DELETE CASCADE removes transaction too)
    DELETE FROM public.salary_allocations WHERE id = v_alloc.id;

    INSERT INTO public.audit_logs (user_id, action, entity_type, entity_id, payload)
    VALUES (v_user_id, 'DELETE_SALARY_ALLOCATION', 'salary_allocation', v_alloc.id, jsonb_build_object(
        'year_month', p_year_month
    ));

    v_result := jsonb_build_object('success', true, 'deleted_year_month', p_year_month);
    INSERT INTO public.idempotent_operations (id, user_id, operation_type, result)
    VALUES (p_operation_id, v_user_id, 'delete_salary_allocation', v_result);

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Set permissions safely across all signatures
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT oid::regprocedure AS func_signature
        FROM pg_proc 
        WHERE pronamespace = 'public'::regnamespace 
          AND proname IN ('create_trade', 'update_trade', 'delete_trade', 'save_salary_allocation', 'delete_salary_allocation')
    ) LOOP
        EXECUTE 'REVOKE EXECUTE ON FUNCTION ' || r.func_signature || ' FROM PUBLIC, anon';
        EXECUTE 'GRANT EXECUTE ON FUNCTION ' || r.func_signature || ' TO authenticated';
    END LOOP;
END $$;
