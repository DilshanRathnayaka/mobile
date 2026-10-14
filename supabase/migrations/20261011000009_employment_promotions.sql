-- Migration: 20261011000009_employment_promotions.sql
-- Description: Adds promotions JSONB column to employments table to track past and future promotions/salary increments.

ALTER TABLE public.employments 
    ADD COLUMN IF NOT EXISTS promotions JSONB NOT NULL DEFAULT '[]'::jsonb;
