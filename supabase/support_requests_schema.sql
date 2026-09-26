-- ============================================================
-- Finavig — Support & Tracking Requests Schema
-- Run this script in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Create support_requests table
CREATE TABLE IF NOT EXISTS public.support_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  user_email TEXT,
  request_type TEXT NOT NULL DEFAULT 'tracking_option_request' 
    CHECK (request_type IN ('tracking_option_request', 'support_request', 'feature_request', 'bug_report')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' 
    CHECK (status IN ('open', 'in_progress', 'resolved')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast lookup by user_id
CREATE INDEX IF NOT EXISTS idx_support_requests_user_id ON public.support_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_support_requests_created_at ON public.support_requests(created_at DESC);

-- 2. Enable Row Level Security
ALTER TABLE public.support_requests ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies: Users can read and insert ONLY their own support requests
DROP POLICY IF EXISTS "users can read own support requests" ON public.support_requests;
CREATE POLICY "users can read own support requests"
  ON public.support_requests FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "users can insert own support requests" ON public.support_requests;
CREATE POLICY "users can insert own support requests"
  ON public.support_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "users can update own support requests" ON public.support_requests;
CREATE POLICY "users can update own support requests"
  ON public.support_requests FOR UPDATE
  USING (auth.uid() = user_id);

-- 4. Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_support_request_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_support_requests_updated_at ON public.support_requests;
CREATE TRIGGER tr_support_requests_updated_at
  BEFORE UPDATE ON public.support_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_support_request_updated_at();
