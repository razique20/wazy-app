-- ============================================================
-- Wazy — App Version & Force Update Migration Schema
-- Run this query in Supabase Dashboard → SQL Editor → New query
-- ============================================================

-- 1. Create app_versions table
create table if not exists public.app_versions (
  id uuid primary key default gen_random_uuid(),
  platform text not null default 'all' check (platform in ('all', 'ios', 'android', 'web')),
  min_required_version text not null default '1.0.0',
  latest_version text not null default '1.0.0',
  is_force_update boolean not null default false,
  download_url text default 'https://github.com/razique20/wazy-app/releases',
  release_notes text default 'Performance enhancements and bug fixes.',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for platform lookup
create index if not exists idx_app_versions_platform on public.app_versions(platform);

-- 2. Enable Row Level Security (RLS)
alter table public.app_versions enable row level security;

-- 3. RLS Policy: Allow public read access to all users (authenticated and anon)
drop policy if exists "Allow public read access to app_versions" on public.app_versions;
create policy "Allow public read access to app_versions"
  on public.app_versions for select
  using (true);

-- 4. Seed initial default record if empty
insert into public.app_versions (
  platform,
  min_required_version,
  latest_version,
  is_force_update,
  download_url,
  release_notes
)
select
  'all',
  '1.0.0',
  '1.0.0',
  false,
  'https://github.com/razique20/wazy-app/releases',
  'Wazy version 1.0.0 — Track company document renewals & financial intelligence.'
where not exists (select 1 from public.app_versions limit 1);

-- 5. Helpful SQL helper functions to update version parameters
-- Example SQL to set minimum required version (triggering force update for older clients):
-- UPDATE public.app_versions SET min_required_version = '1.1.0', latest_version = '1.2.0', is_force_update = true WHERE platform = 'all';
