-- ============================================================
-- Wazy — Subscription Tier (Track 1 monetization) Migration
-- Run this query in Supabase Dashboard → SQL Editor → New query
--
-- Pairs with lib/services/entitlement_service.dart, which reads:
--   client.from('user_tiers').select('tier, plan_duration, plan_started_at, plan_ends_at')
--     .eq('user_id', userId).maybeSingle()
-- Admin Console grants tiers with the service-role key (see
-- TIER_MANAGEMENT_PROMPT.md).
-- ============================================================

-- 1. Create user_tiers table (one row per user; missing row = Free)
create table if not exists public.user_tiers (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  tier       text not null default 'free'
             check (tier in ('free', 'plus', 'business')),
  -- Paid-plan window. Null on Free. The app computes the countdown from
  -- plan_ends_at and treats a past date as Free until the admin renews.
  plan_duration text check (plan_duration in ('1_month', '3_months', '1_year')),
  plan_started_at timestamptz,
  plan_ends_at   timestamptz,
  updated_at timestamptz not null default now(),
  updated_by text,
  note       text
);

-- Columns added to an existing deployment (idempotent).
alter table public.user_tiers add column if not exists plan_duration text;
alter table public.user_tiers add column if not exists plan_started_at timestamptz;
alter table public.user_tiers add column if not exists plan_ends_at timestamptz;
alter table public.user_tiers drop constraint if exists user_tiers_plan_duration_check;
alter table public.user_tiers add constraint user_tiers_plan_duration_check
  check (plan_duration is null or plan_duration in ('1_month', '3_months', '1_year'));

-- 2. Enable Row Level Security
alter table public.user_tiers enable row level security;

-- 3. RLS Policy: users may read ONLY their own tier row. The Admin Console
--    reads/writes with the service-role key, which bypasses RLS entirely.
--    Without this policy the app's authenticated read returns null and every
--    user silently stays on Free even after the admin grants a tier.
drop policy if exists "users can read own tier" on public.user_tiers;
create policy "users can read own tier"
  on public.user_tiers for select
  using (auth.uid() = user_id);

-- 4. Optional but recommended: immutable tier-change history
create table if not exists public.user_tier_audit (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  old_tier   text,
  new_tier   text not null,
  changed_by text,
  note       text,
  created_at timestamptz not null default now()
);

alter table public.user_tier_audit enable row level security;
-- Deliberately NO policies: service-role key only (admin console writes it).

-- 5. Auto-expire: a paid tier past plan_ends_at snaps back to Free on the
--    next write to the row (admin renewal, or any admin-console save).
create or replace function public.expire_finished_plans()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tier <> 'free' and new.plan_ends_at is not null
     and new.plan_ends_at <= now() then
    insert into public.user_tier_audit (user_id, old_tier, new_tier, changed_by, note)
    values (new.user_id, new.tier, 'free', 'system',
            'auto-expired: plan ended ' || new.plan_ends_at::text);
    new.tier := 'free';
    new.plan_duration := null;
    new.plan_started_at := null;
    new.plan_ends_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists user_tiers_auto_expire on public.user_tiers;
create trigger user_tiers_auto_expire
  before insert or update on public.user_tiers
  for each row execute function public.expire_finished_plans();
