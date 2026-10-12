-- ==============================================================================
-- Migration: 20261011000002_security_rls_mfa.sql
-- Description: Enforces Row-Level Security (RLS) with TOTP MFA (AAL2) validation,
--              protects derived holdings from client tampering, and ensures
--              secure search_paths.
-- ==============================================================================

-- 1. Helper function to check MFA assurance
CREATE OR REPLACE FUNCTION public.is_mfa_compliant()
RETURNS BOOLEAN AS $$
BEGIN
    -- If user has enrolled and verified MFA factor(s), require AAL2 session
    IF EXISTS (
        SELECT 1 FROM auth.mfa_factors 
        WHERE user_id = auth.uid() AND status = 'verified'
    ) THEN
        RETURN (auth.jwt() ->> 'aal') = 'aal2';
    END IF;

    -- Allows bootstrap for newly registered accounts prior to initial MFA setup
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = '';

-- 2. Enable RLS on all domain tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salary_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.idempotent_operations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 3. Profiles Policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;

CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE USING (auth.uid() = id AND public.is_mfa_compliant());

CREATE POLICY "profiles_insert_own" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

-- 4. Transactions Policies
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can update own transactions" ON public.transactions;
DROP POLICY IF EXISTS "Users can delete own transactions" ON public.transactions;

CREATE POLICY "transactions_select_own" ON public.transactions
    FOR SELECT USING (auth.uid() = user_id AND public.is_mfa_compliant());

-- Direct client modifications revoked in favor of atomic RPCs,
-- but owner policies kept for authorized authenticated roles during RPC execution:
DROP POLICY IF EXISTS "transactions_modify_own" ON public.transactions;
CREATE POLICY "transactions_modify_own" ON public.transactions
    FOR ALL USING (auth.uid() = user_id AND public.is_mfa_compliant())
    WITH CHECK (auth.uid() = user_id AND public.is_mfa_compliant());

-- 5. Holdings Policies (ReadOnly for clients to prevent manual tampering)
DROP POLICY IF EXISTS "Users can view own holdings" ON public.holdings;
DROP POLICY IF EXISTS "Users can manage own holdings" ON public.holdings;
DROP POLICY IF EXISTS "holdings_select_own" ON public.holdings;

CREATE POLICY "holdings_select_own" ON public.holdings
    FOR SELECT USING (auth.uid() = user_id AND public.is_mfa_compliant());

-- Revoke direct DML from public / anon / authenticated on holdings
REVOKE INSERT, UPDATE, DELETE ON public.holdings FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.holdings FROM authenticated;

-- 6. Salary Allocations Policies
DROP POLICY IF EXISTS "Users can manage own salary allocations" ON public.salary_allocations;
DROP POLICY IF EXISTS "salary_allocations_select_own" ON public.salary_allocations;
DROP POLICY IF EXISTS "salary_allocations_modify_own" ON public.salary_allocations;

CREATE POLICY "salary_allocations_select_own" ON public.salary_allocations
    FOR SELECT USING (auth.uid() = user_id AND public.is_mfa_compliant());

CREATE POLICY "salary_allocations_modify_own" ON public.salary_allocations
    FOR ALL USING (auth.uid() = user_id AND public.is_mfa_compliant())
    WITH CHECK (auth.uid() = user_id AND public.is_mfa_compliant());

-- 7. Idempotent Operations & Audit Logs Policies
DROP POLICY IF EXISTS "idempotent_select_own" ON public.idempotent_operations;
CREATE POLICY "idempotent_select_own" ON public.idempotent_operations
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "idempotent_insert_own" ON public.idempotent_operations;
CREATE POLICY "idempotent_insert_own" ON public.idempotent_operations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "audit_select_own" ON public.audit_logs;
CREATE POLICY "audit_select_own" ON public.audit_logs
    FOR SELECT USING (auth.uid() = user_id AND public.is_mfa_compliant());

REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM anon, authenticated;
