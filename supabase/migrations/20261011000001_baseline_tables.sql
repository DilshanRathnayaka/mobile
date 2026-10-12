-- ==============================================================================
-- Migration: 20261011000001_baseline_tables.sql
-- Description: Establishes base tables and upgrades existing tables safely with
--              multi-currency provenance, precise limits, idempotency & audit trail.
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Profiles Table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT DEFAULT '',
    preferred_currency TEXT DEFAULT 'USD',
    monthly_salary NUMERIC(28, 4) DEFAULT 0,
    crypto_allocation_percentage NUMERIC(5, 2) DEFAULT 10,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Upgrade profiles if already existed
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferred_currency TEXT DEFAULT 'USD';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS monthly_salary NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS crypto_allocation_percentage NUMERIC(5, 2) DEFAULT 10;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Salary Allocations Table (Monthly DCA Budgeting)
CREATE TABLE IF NOT EXISTS public.salary_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    year_month TEXT NOT NULL, -- e.g. '2026-10'
    salary_amount NUMERIC(28, 4) NOT NULL DEFAULT 0,
    allocated_amount NUMERIC(28, 4) NOT NULL DEFAULT 0,
    allocation_percentage NUMERIC(5, 2) DEFAULT 0,
    notes TEXT DEFAULT '',
    original_currency TEXT DEFAULT 'USD',
    fx_to_base NUMERIC(20, 8) DEFAULT 1.0,
    effective_date TIMESTAMPTZ DEFAULT NOW(),
    operation_id UUID UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_year_month UNIQUE (user_id, year_month)
);

-- Upgrade salary_allocations if table existed
ALTER TABLE public.salary_allocations ADD COLUMN IF NOT EXISTS original_currency TEXT DEFAULT 'USD';
ALTER TABLE public.salary_allocations ADD COLUMN IF NOT EXISTS fx_to_base NUMERIC(20, 8) DEFAULT 1.0;
ALTER TABLE public.salary_allocations ADD COLUMN IF NOT EXISTS effective_date TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.salary_allocations ADD COLUMN IF NOT EXISTS operation_id UUID UNIQUE;
ALTER TABLE public.salary_allocations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. Transactions Table (Buy, Sell, Salary Deposits)
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    coin_id TEXT, -- canonical ID e.g. 'bitcoin'
    symbol TEXT,  -- ticker e.g. 'BTC'
    name TEXT,    -- asset name e.g. 'Bitcoin'
    amount NUMERIC(28, 8) NOT NULL DEFAULT 0,
    price_per_unit NUMERIC(28, 8) DEFAULT 1,
    total_amount NUMERIC(28, 4) NOT NULL DEFAULT 0,
    fee NUMERIC(28, 4) DEFAULT 0,
    transaction_date TIMESTAMPTZ DEFAULT NOW(),
    notes TEXT DEFAULT '',
    original_currency TEXT DEFAULT 'USD',
    original_amount NUMERIC(28, 8),
    fx_to_base NUMERIC(20, 8) DEFAULT 1.0,
    operation_id UUID UNIQUE,
    salary_allocation_id UUID REFERENCES public.salary_allocations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Safely add all required columns if table already existed previously
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS original_currency TEXT DEFAULT 'USD';
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS original_amount NUMERIC(28, 8);
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS fx_to_base NUMERIC(20, 8) DEFAULT 1.0;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS operation_id UUID UNIQUE;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS salary_allocation_id UUID REFERENCES public.salary_allocations(id) ON DELETE CASCADE;
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Indexes for transactions
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_coin ON public.transactions(user_id, coin_id);
CREATE INDEX IF NOT EXISTS idx_transactions_salary_alloc ON public.transactions(salary_allocation_id);

-- 4. Holdings Table (Aggregated DCA positions per user & coin)
CREATE TABLE IF NOT EXISTS public.holdings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    coin_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    name TEXT NOT NULL,
    total_quantity NUMERIC(28, 8) DEFAULT 0,
    average_buy_price NUMERIC(28, 8) DEFAULT 0,
    total_invested_cost NUMERIC(28, 4) DEFAULT 0,
    realized_pnl NUMERIC(28, 4) DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_coin UNIQUE (user_id, coin_id)
);

-- Upgrade holdings if already existed
ALTER TABLE public.holdings ADD COLUMN IF NOT EXISTS total_invested_cost NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.holdings ADD COLUMN IF NOT EXISTS realized_pnl NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.holdings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 5. Idempotent Operations Table
CREATE TABLE IF NOT EXISTS public.idempotent_operations (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    operation_type TEXT NOT NULL,
    result JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_idempotent_user ON public.idempotent_operations(user_id, id);

-- 6. Audit Trail Table
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID,
    payload JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON public.audit_logs(user_id, created_at DESC);
