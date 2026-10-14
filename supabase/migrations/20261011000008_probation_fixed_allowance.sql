-- Migration: 20261011000008_probation_fixed_allowance.sql
-- Description: Adds option to configure whether fixed allowances are paid during probation or only after permanent confirmation.

ALTER TABLE public.employments 
    ADD COLUMN IF NOT EXISTS has_fixed_allowance_during_probation BOOLEAN NOT NULL DEFAULT true;
