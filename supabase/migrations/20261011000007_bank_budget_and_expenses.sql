-- ==============================================================================
-- Migration: 20261011000007_bank_budget_and_expenses.sql
-- Description: Supports initial bank account balance, recurring salary inflows,
--              daily cashflow (income/expenses), monthly investment allocation,
--              and historical category analytics.
-- ==============================================================================

-- 1. Bank Accounts Table (Tracks user bank baseline, initial balance, and auto-credit preference)
CREATE TABLE IF NOT EXISTS public.bank_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    bank_name TEXT NOT NULL DEFAULT 'Commercial Bank',
    account_number TEXT DEFAULT '',
    initial_balance NUMERIC(28, 4) NOT NULL DEFAULT 0.0,
    initial_balance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    currency TEXT NOT NULL DEFAULT 'LKR',
    auto_credit_salary BOOLEAN NOT NULL DEFAULT true,
    salary_start_month TEXT NOT NULL DEFAULT '', -- e.g. '2026-11' (start crediting from next month)
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_bank UNIQUE (user_id)
);

-- Upgrade columns if table already existed
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS bank_name TEXT DEFAULT 'Commercial Bank';
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS account_number TEXT DEFAULT '';
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS initial_balance NUMERIC(28, 4) DEFAULT 0.0;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS initial_balance_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'LKR';
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS auto_credit_salary BOOLEAN DEFAULT true;
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS salary_start_month TEXT DEFAULT '';
ALTER TABLE public.bank_accounts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 2. Cash Records Table (Income, Expenses, and Investment Transfers)
CREATE TABLE IF NOT EXISTS public.cash_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'INVESTMENT_TRANSFER')),
    category TEXT NOT NULL, 
    -- Income: 'Salary', 'Freelance', 'Bonus', 'Dividend', 'Business', 'Other'
    -- Expense: 'Housing & Rent', 'Food & Dining', 'Utilities & Bills', 'Transport', 'Healthcare', 'Leisure & Shopping', 'EMI & Debt', 'Miscellaneous'
    -- Investment: 'Crypto DCA', 'Stock Market', 'Fixed Deposit', 'Emergency Fund'
    amount NUMERIC(28, 4) NOT NULL CHECK (amount > 0),
    record_date DATE NOT NULL DEFAULT CURRENT_DATE,
    year_month TEXT NOT NULL, -- e.g. '2026-10'
    notes TEXT DEFAULT '',
    source_employment_id UUID REFERENCES public.employments(id) ON DELETE SET NULL,
    is_auto_generated BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for speedy cashflow and analytics filtering
CREATE INDEX IF NOT EXISTS idx_cash_records_user_date ON public.cash_records(user_id, record_date DESC);
CREATE INDEX IF NOT EXISTS idx_cash_records_user_ym ON public.cash_records(user_id, year_month);
CREATE INDEX IF NOT EXISTS idx_cash_records_user_type ON public.cash_records(user_id, type);

-- 3. Monthly Budget & Investment Allocation Targets Table
CREATE TABLE IF NOT EXISTS public.monthly_budget_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    savings_percentage NUMERIC(5, 2) NOT NULL DEFAULT 20.0,
    crypto_percentage NUMERIC(5, 2) NOT NULL DEFAULT 15.0,
    other_invest_percentage NUMERIC(5, 2) NOT NULL DEFAULT 15.0,
    expenses_percentage NUMERIC(5, 2) NOT NULL DEFAULT 50.0,
    emergency_fund_target NUMERIC(28, 4) DEFAULT 500000.0,
    notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_user_budget_plan UNIQUE (user_id)
);

-- Enable RLS for all newly added tables
ALTER TABLE public.bank_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cash_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monthly_budget_plans ENABLE ROW LEVEL SECURITY;

-- bank_accounts policies
DROP POLICY IF EXISTS "bank_accounts_select_own" ON public.bank_accounts;
DROP POLICY IF EXISTS "bank_accounts_insert_own" ON public.bank_accounts;
DROP POLICY IF EXISTS "bank_accounts_update_own" ON public.bank_accounts;
DROP POLICY IF EXISTS "bank_accounts_delete_own" ON public.bank_accounts;

CREATE POLICY "bank_accounts_select_own" ON public.bank_accounts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "bank_accounts_insert_own" ON public.bank_accounts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "bank_accounts_update_own" ON public.bank_accounts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "bank_accounts_delete_own" ON public.bank_accounts FOR DELETE USING (auth.uid() = user_id);

-- cash_records policies
DROP POLICY IF EXISTS "cash_records_select_own" ON public.cash_records;
DROP POLICY IF EXISTS "cash_records_insert_own" ON public.cash_records;
DROP POLICY IF EXISTS "cash_records_update_own" ON public.cash_records;
DROP POLICY IF EXISTS "cash_records_delete_own" ON public.cash_records;

CREATE POLICY "cash_records_select_own" ON public.cash_records FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "cash_records_insert_own" ON public.cash_records FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "cash_records_update_own" ON public.cash_records FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "cash_records_delete_own" ON public.cash_records FOR DELETE USING (auth.uid() = user_id);

-- monthly_budget_plans policies
DROP POLICY IF EXISTS "monthly_budget_plans_select_own" ON public.monthly_budget_plans;
DROP POLICY IF EXISTS "monthly_budget_plans_insert_own" ON public.monthly_budget_plans;
DROP POLICY IF EXISTS "monthly_budget_plans_update_own" ON public.monthly_budget_plans;
DROP POLICY IF EXISTS "monthly_budget_plans_delete_own" ON public.monthly_budget_plans;

CREATE POLICY "monthly_budget_plans_select_own" ON public.monthly_budget_plans FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "monthly_budget_plans_insert_own" ON public.monthly_budget_plans FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "monthly_budget_plans_update_own" ON public.monthly_budget_plans FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "monthly_budget_plans_delete_own" ON public.monthly_budget_plans FOR DELETE USING (auth.uid() = user_id);
