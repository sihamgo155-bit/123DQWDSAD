-- CIA COMMAND PORTAL — Supabase starter schema
-- Run in Supabase SQL Editor. All content is fictional roleplay data.
-- Security principle: authenticated users only; admin actions use trusted server-side functions.
create extension if not exists pgcrypto;

create type public.application_status as enum ('PENDING','APPROVED','REJECTED');
create type public.membership_status as enum ('ACTIVE','INACTIVE');
create type public.mission_status as enum ('NEW','ACTIVE','COMPLETED','CANCELLED');
create type public.mission_priority as enum ('LOW','NORMAL','HIGH','CRITICAL');
create type public.announcement_audience as enum ('PUBLIC','MEMBERS');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 80),
  discord_username text not null check (char_length(discord_username) between 2 and 80),
  role text not null default 'Recruit',
  membership_status public.membership_status not null default 'INACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.applications (
  id uuid primary key default gen_random_uuid(),
  applicant_user_id uuid references auth.users(id) on delete set null,
  reference_code text not null unique default ('CCP-' || upper(substr(encode(gen_random_bytes(8),'hex'),1,8))),
  roleplay_name text not null check (char_length(roleplay_name) between 2 and 60),
  discord_username text not null check (char_length(discord_username) between 2 and 80),
  discord_id text,
  age_range text not null,
  reason text not null check (char_length(reason) between 20 and 1200),
  experience text not null check (char_length(experience) between 5 and 1200),
  availability text not null,
  preferred_role text not null default 'General recruit',
  exam_score integer not null check (exam_score between 0 and 100),
  exam_passed boolean not null,
  exam_answers jsonb not null default '[]'::jsonb,
  status public.application_status not null default 'PENDING',
  admin_note text not null default '',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.exam_questions (
  id uuid primary key default gen_random_uuid(),
  question_text text not null,
  options jsonb not null check (jsonb_typeof(options)='array'),
  -- Never return correct_index to unauthenticated clients; preferably keep answer keys in a private table/function.
  active boolean not null default true,
  order_index integer not null default 0,
  created_at timestamptz not null default now()
);
create table public.exam_answer_keys (
  question_id uuid primary key references public.exam_questions(id) on delete cascade,
  correct_index integer not null check (correct_index >= 0)
);
create table public.missions (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 120),
  description text not null,
  priority public.mission_priority not null default 'NORMAL',
  status public.mission_status not null default 'NEW',
  target_role text,
  deadline timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.mission_assignments (
  mission_id uuid not null references public.missions(id) on delete cascade,
  member_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (mission_id, member_user_id)
);
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 2 and 140),
  content text not null,
  audience public.announcement_audience not null default 'MEMBERS',
  published_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('ADMIN','STAFF')),
  created_at timestamptz not null default now()
);
create table public.portal_settings (
  id integer primary key default 1 check (id=1),
  site_name text not null default 'CIA COMMAND PORTAL',
  description text not null default 'A fictional intelligence roleplay community.',
  min_exam_score integer not null default 70 check (min_exam_score between 0 and 100),
  allow_retake boolean not null default true,
  allow_reapply boolean not null default true,
  applications_open boolean not null default true,
  show_public_stats boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.portal_settings(id) values (1) on conflict do nothing;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admin_roles ar where ar.user_id = (select auth.uid()) and ar.role in ('ADMIN','STAFF'));
$$;
create or replace function public.is_active_member()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.membership_status = 'ACTIVE');
$$;
revoke all on function public.is_admin() from public;
revoke all on function public.is_active_member() from public;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_active_member() to authenticated;

alter table public.profiles enable row level security;
alter table public.applications enable row level security;
alter table public.exam_questions enable row level security;
alter table public.exam_answer_keys enable row level security;
alter table public.missions enable row level security;
alter table public.mission_assignments enable row level security;
alter table public.announcements enable row level security;
alter table public.admin_roles enable row level security;
alter table public.portal_settings enable row level security;

-- Profiles: users can read/update only their own profile. Admins can manage all.
create policy "profiles read own or admin" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.is_admin());
create policy "profiles update own basic profile" on public.profiles for update to authenticated using (id = (select auth.uid()) and not public.is_admin()) with check (id = (select auth.uid()) and role = (select p.role from public.profiles p where p.id = (select auth.uid())) and membership_status = (select p.membership_status from public.profiles p where p.id = (select auth.uid())));
create policy "profiles admin manage" on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Application insertion/review should go through server/Edge Functions, not direct browser table writes.
create policy "applicant reads own application" on public.applications for select to authenticated using (applicant_user_id = (select auth.uid()) or public.is_admin());
create policy "staff read applications" on public.applications for select to authenticated using (public.is_admin());
-- Exam question options are public; answer keys are never directly readable by clients.
create policy "read active exam questions" on public.exam_questions for select to anon, authenticated using (active = true);
create policy "admin manage questions" on public.exam_questions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin manage answer keys" on public.exam_answer_keys for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Missions: only active members see internal missions; public has no access. Assignment filtering enforced when assignments exist.
create policy "active members read missions" on public.missions for select to authenticated using (public.is_admin() or (public.is_active_member() and (target_role is null or target_role = (select p.role from public.profiles p where p.id = (select auth.uid()))) and (not exists (select 1 from public.mission_assignments ma where ma.mission_id = missions.id) or exists (select 1 from public.mission_assignments ma where ma.mission_id = missions.id and ma.member_user_id = (select auth.uid())))));
create policy "admin manage missions" on public.missions for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "members read own mission assignments" on public.mission_assignments for select to authenticated using (member_user_id = (select auth.uid()) and public.is_active_member() or public.is_admin());
create policy "admin manage mission assignments" on public.mission_assignments for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "read published public announcements" on public.announcements for select to anon, authenticated using (audience = 'PUBLIC' and published_at is not null or public.is_admin() or (audience = 'MEMBERS' and public.is_active_member()));
create policy "admin manage announcements" on public.announcements for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "user can read own admin role" on public.admin_roles for select to authenticated using (user_id = (select auth.uid()));
create policy "admin roles admin managed" on public.admin_roles for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "read safe portal settings" on public.portal_settings for select to anon, authenticated using (true);
create policy "admin manage portal settings" on public.portal_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Explicitly remove broad default table grants; adjust through trusted functions as needed.
revoke all on public.applications from anon, authenticated;
grant select on public.applications to authenticated;
revoke all on public.exam_answer_keys from anon, authenticated;
revoke all on public.admin_roles from anon, authenticated;
grant select on public.admin_roles to authenticated;
revoke all on public.mission_assignments from anon, authenticated;
grant select on public.mission_assignments to authenticated;
revoke all on public.profiles from anon, authenticated;
grant select, update on public.profiles to authenticated;
revoke all on public.missions from anon, authenticated;
grant select on public.missions to authenticated;
revoke all on public.announcements from anon, authenticated;
grant select on public.announcements to anon, authenticated;
revoke all on public.portal_settings from anon, authenticated;
grant select on public.portal_settings to anon, authenticated;
revoke all on public.exam_questions from anon, authenticated;
grant select on public.exam_questions to anon, authenticated;

-- IMPORTANT BOOTSTRAP: create your first user through Supabase Auth, then run a one-time
-- SQL statement replacing the UUID below with that user's auth.users.id:
-- insert into public.admin_roles(user_id, role) values ('YOUR-AUTH-USER-UUID', 'ADMIN');
-- Delete/disable this bootstrap instruction after setup. Never expose service_role credentials.
