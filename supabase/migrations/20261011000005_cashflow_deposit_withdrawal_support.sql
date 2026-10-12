-- ==============================================================================
-- Migration: 20261011000005_cashflow_deposit_withdrawal_support.sql
-- Description: Ensures transactions table supports multiple daily deposits and
--              withdrawals without restriction, allowing seamless multi-device sync.
-- ==============================================================================

-- 1. Safely update check constraint on transactions table if present
ALTER TABLE public.transactions DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE public.transactions ADD CONSTRAINT transactions_type_check 
    CHECK (type IN ('BUY', 'SELL', 'SALARY_DEPOSIT', 'DEPOSIT', 'WITHDRAWAL'));

-- 2. Indexes for fast cashflow filtering
CREATE INDEX IF NOT EXISTS idx_transactions_type_user 
    ON public.transactions(user_id, type, transaction_date DESC);
