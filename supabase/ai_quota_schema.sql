-- ============================================================
-- Wazy — AI Quota Usage Schema (Supabase Database Tracking)
-- Run this script in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Create ai_quota_usage table
CREATE TABLE IF NOT EXISTS public.ai_quota_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_name TEXT NOT NULL CHECK (feature_name IN ('groq_ai_summary', 'groq_ai_budget_plan')),
  usage_month TEXT NOT NULL, -- Format: 'YYYY-MM', e.g. '2026-09'
  used_count INT NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, feature_name, usage_month)
);

-- 2. Enable Row Level Security
ALTER TABLE public.ai_quota_usage ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies: users can read & write ONLY their own quota rows
DROP POLICY IF EXISTS "users can read own quota" ON public.ai_quota_usage;
CREATE POLICY "users can read own quota"
  ON public.ai_quota_usage FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "users can insert own quota" ON public.ai_quota_usage;
CREATE POLICY "users can insert own quota"
  ON public.ai_quota_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "users can update own quota" ON public.ai_quota_usage;
CREATE POLICY "users can update own quota"
  ON public.ai_quota_usage FOR UPDATE
  USING (auth.uid() = user_id);

-- 4. Atomic Increment RPC Helper Function
CREATE OR REPLACE FUNCTION public.increment_ai_quota(
  p_feature_name TEXT,
  p_usage_month TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_new_count INT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.ai_quota_usage (user_id, feature_name, usage_month, used_count, updated_at)
  VALUES (v_user_id, p_feature_name, p_usage_month, 1, NOW())
  ON CONFLICT (user_id, feature_name, usage_month)
  DO UPDATE SET 
    used_count = ai_quota_usage.used_count + 1,
    updated_at = NOW()
  RETURNING used_count INTO v_new_count;

  RETURN v_new_count;
END;
$$;

-- 5. SQL Query to RESET AI Quota for ALL Users (Run in SQL Editor anytime):
-- UPDATE public.ai_quota_usage SET used_count = 0, updated_at = NOW();
