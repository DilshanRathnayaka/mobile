-- ================================================================
-- Migration: 20261011000010_trade_isolation_fix.sql
-- Description: Fix trade isolation, chronological BUY/SELL ordering,
--              zero-quantity reset (average_buy_price & total_invested_cost = 0),
--              and repair existing contaminated holdings.
-- ================================================================

-- 1. Helper function: Recalculate holding for a user & coin with deterministic BUY-before-SELL ordering
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

    -- Iterate chronologically through all trades for this coin.
    -- Crucial: When transaction_date is identical, BUY/LONG is processed BEFORE SELL/SHORT
    -- so that closed cycles resolve cleanly without negative temporary inventory.
    FOR tx IN 
        SELECT id, type, amount, price_per_unit, total_amount, fee, transaction_date, created_at
        FROM public.transactions 
        WHERE user_id = p_user_id 
          AND (coin_id = p_coin_id OR UPPER(symbol) = UPPER(p_symbol))
          AND type IN ('BUY', 'SELL', 'LONG', 'SHORT')
        ORDER BY transaction_date ASC, 
                 CASE WHEN type IN ('BUY', 'LONG') THEN 1 ELSE 2 END ASC, 
                 created_at ASC, 
                 id ASC
    LOOP
        IF tx.type = 'BUY' OR tx.type = 'LONG' THEN
            v_total_qty := v_total_qty + tx.amount;
            v_total_cost := v_total_cost + tx.total_amount + COALESCE(tx.fee, 0);
            IF v_total_qty > 0 THEN
                v_avg_price := v_total_cost / v_total_qty;
            END IF;
        ELSIF tx.type = 'SELL' OR tx.type = 'SHORT' THEN
            -- Inventory check: Prevent oversells beyond available qty
            IF tx.amount > (v_total_qty + 0.001) THEN
                RAISE EXCEPTION 'Inventory violation: Attempted to sell % % with only % available at date %',
                    tx.amount, p_symbol, v_total_qty, tx.transaction_date;
            END IF;

            v_sell_rev := tx.total_amount - COALESCE(tx.fee, 0);
            v_cost_basis := tx.amount * v_avg_price;
            v_realized_pnl := v_realized_pnl + (v_sell_rev - v_cost_basis);
            v_total_qty := GREATEST(0, v_total_qty - tx.amount);
            
            -- If position is closed or reduced to negligible dust (< 0.001 qty or < $0.20 value), reset active cost basis and average entry price to 0
            IF v_total_qty <= 0.001 OR (v_total_qty * v_avg_price) < 0.20 THEN
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

-- 2. Trigger function for direct transactions table inserts/updates/deletes
CREATE OR REPLACE FUNCTION public.recalculate_user_holding()
RETURNS TRIGGER AS $$
DECLARE
    target_user_id UUID;
    target_coin_id TEXT;
    target_symbol TEXT;
    target_name TEXT;
BEGIN
    target_user_id := COALESCE(NEW.user_id, OLD.user_id);
    target_coin_id := COALESCE(NEW.coin_id, OLD.coin_id);
    target_symbol := COALESCE(NEW.symbol, OLD.symbol);
    target_name := COALESCE(NEW.name, OLD.name);

    IF target_coin_id IS NOT NULL AND target_user_id IS NOT NULL THEN
        PERFORM public.internal_recalculate_holding(target_user_id, target_coin_id, target_symbol, target_name);
    END IF;

    -- If coin_id was modified on update, also recalculate the old coin
    IF TG_OP = 'UPDATE' AND OLD.coin_id IS NOT NULL AND OLD.coin_id <> NEW.coin_id THEN
        PERFORM public.internal_recalculate_holding(target_user_id, OLD.coin_id, OLD.symbol, OLD.name);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_recalculate_dca ON public.transactions;

CREATE TRIGGER trigger_recalculate_dca
AFTER INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.recalculate_user_holding();

-- 3. Immediate repair: Recalculate all existing holdings in the database
DO $$
DECLARE
    h RECORD;
BEGIN
    FOR h IN SELECT user_id, coin_id, symbol, name FROM public.holdings LOOP
        PERFORM public.internal_recalculate_holding(h.user_id, h.coin_id, h.symbol, h.name);
    END LOOP;
END;
$$;
