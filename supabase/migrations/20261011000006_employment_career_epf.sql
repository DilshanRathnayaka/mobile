-- ==============================================================================
-- Migration: 20261011000006_employment_career_epf.sql
-- Description: Manages career timeline, multiple jobs, join dates, resignation dates,
--              monthly salary payout day, and Sri Lankan legal EPF (8%+12%) & ETF (3%).
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.employments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    designation TEXT NOT NULL,
    basic_salary NUMERIC(28, 4) NOT NULL DEFAULT 0,    -- Base salary for EPF/ETF calculations
    fixed_allowance NUMERIC(28, 4) NOT NULL DEFAULT 0, -- Non-EPF fixed allowances
    monthly_salary NUMERIC(28, 4) NOT NULL DEFAULT 0,  -- Total gross salary (basic + allowance)
    salary_day INT NOT NULL DEFAULT 25, -- Monthly payout day (1 - 31)
    start_date DATE NOT NULL,          -- Job join date
    end_date DATE,                    -- Resignation / exit date (null if active)
    is_current BOOLEAN NOT NULL DEFAULT true,
    notes TEXT DEFAULT '',
    currency TEXT NOT NULL DEFAULT 'LKR',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Upgrade employments if table already existed
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS basic_salary NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS fixed_allowance NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS monthly_salary NUMERIC(28, 4) DEFAULT 0;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS salary_day INT DEFAULT 25;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS start_date DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS end_date DATE;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS is_current BOOLEAN DEFAULT true;
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'LKR';
ALTER TABLE public.employments ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_employments_user_dates 
    ON public.employments(user_id, start_date DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE public.employments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "employments_select_own" ON public.employments;
DROP POLICY IF EXISTS "employments_insert_own" ON public.employments;
DROP POLICY IF EXISTS "employments_update_own" ON public.employments;
DROP POLICY IF EXISTS "employments_delete_own" ON public.employments;

CREATE POLICY "employments_select_own" ON public.employments
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "employments_insert_own" ON public.employments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "employments_update_own" ON public.employments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "employments_delete_own" ON public.employments
    FOR DELETE USING (auth.uid() = user_id);
