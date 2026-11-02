-- Run in Supabase SQL Editor. No user receives a role automatically.
begin;
create table public.account_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check (length(trim(display_name)) between 1 and 100)
);
create table public.team_memberships (
 user_id uuid not null references auth.users(id) on delete cascade,
 role text not null check (role in ('parent','player','coach','administrator')),
 primary key (user_id,role)
);
alter table public.account_profiles enable row level security;
alter table public.team_memberships enable row level security;
revoke all on public.account_profiles, public.team_memberships from anon, authenticated;
grant select,insert,update on public.account_profiles to authenticated;
grant select on public.team_memberships to authenticated;
create policy "Read own account profile" on public.account_profiles for select to authenticated using ((select auth.uid())=id);
create policy "Create own account profile" on public.account_profiles for insert to authenticated with check ((select auth.uid())=id);
create policy "Update own account profile" on public.account_profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);
create policy "Read own assigned roles" on public.team_memberships for select to authenticated using ((select auth.uid())=user_id);
-- No client role writes. Bootstrap verified organizer from SQL Editor only:
-- insert into public.team_memberships(user_id,role)
-- values ('VERIFIED-AUTH-USER-UUID-HERE','administrator');
commit;
