create schema if not exists team_private;
revoke all on schema team_private from public;
grant usage on schema team_private to authenticated;
create table public.account_profiles(id uuid primary key references auth.users(id) on delete cascade,display_name text not null check(length(trim(display_name)) between 1 and 100));
create table public.team_memberships(user_id uuid not null references auth.users(id) on delete cascade,role text not null check(role in ('parent','player','coach','administrator')),primary key(user_id,role));
alter table public.account_profiles enable row level security;
alter table public.team_memberships enable row level security;
create function team_private.has_role(wanted text) returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.team_memberships where user_id=auth.uid() and role=wanted)
$$;
revoke all on function team_private.has_role(text) from public;
grant execute on function team_private.has_role(text) to authenticated;
revoke all on public.account_profiles,public.team_memberships from anon,authenticated;
grant select,insert,update,delete on public.account_profiles to authenticated;
grant select on public.team_memberships to authenticated;
create policy profile_read on public.account_profiles for select to authenticated using(id=(select auth.uid()) or (select team_private.has_role('administrator')));
create policy profile_insert on public.account_profiles for insert to authenticated with check(id=(select auth.uid()) or (select team_private.has_role('administrator')));
create policy profile_update on public.account_profiles for update to authenticated using(id=(select auth.uid()) or (select team_private.has_role('administrator'))) with check(id=(select auth.uid()) or (select team_private.has_role('administrator')));
create policy profile_delete on public.account_profiles for delete to authenticated using((select team_private.has_role('administrator')));
create policy membership_read on public.team_memberships for select to authenticated using(user_id=(select auth.uid()) or (select team_private.has_role('administrator')));
create table public.team_players(id uuid primary key default gen_random_uuid(),display_name text not null check(length(trim(display_name)) between 1 and 100),jersey_number text not null default '' check(length(jersey_number)<=3),position text not null default '' check(length(position)<=60),bio text not null default '' check(length(bio)<=1000));
alter table public.team_players enable row level security;
revoke all on public.team_players from anon,authenticated;
grant select,insert,update,delete on public.team_players to authenticated;
create policy roster_read on public.team_players for select to authenticated using(exists(select 1 from public.team_memberships where user_id=(select auth.uid())));
create policy roster_write on public.team_players for all to authenticated using((select team_private.has_role('administrator')) or (select team_private.has_role('coach'))) with check((select team_private.has_role('administrator')) or (select team_private.has_role('coach')));
create table public.role_audit(id bigint generated always as identity primary key,actor uuid not null,target uuid not null,role text not null,granted boolean not null,at timestamptz not null default now());
alter table public.role_audit enable row level security;
revoke all on public.role_audit from anon,authenticated;
grant select on public.role_audit to authenticated;
create policy audit_admin_read on public.role_audit for select to authenticated using((select team_private.has_role('administrator')));
create function public.manage_team_role(target_user uuid,wanted_role text,grant_role boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501'; end if;
 if wanted_role not in ('parent','player','coach','administrator') or grant_role is null then raise exception 'Invalid role'; end if;
 perform pg_advisory_xact_lock(72819311);
 if not exists(select 1 from auth.users where id=target_user and email_confirmed_at is not null) then raise exception 'A verified user is required'; end if;
 if not grant_role and wanted_role='administrator' and exists(select 1 from public.team_memberships where user_id=target_user and role='administrator') and (select count(*) from public.team_memberships where role='administrator')<=1 then raise exception 'Cannot remove the last administrator'; end if;
 if grant_role then insert into public.team_memberships values(target_user,wanted_role) on conflict do nothing;
 else delete from public.team_memberships where user_id=target_user and role=wanted_role; end if;
 insert into public.role_audit(actor,target,role,granted) values(auth.uid(),target_user,wanted_role,grant_role);
end $$;
revoke all on function public.manage_team_role(uuid,text,boolean) from public,anon;
grant execute on function public.manage_team_role(uuid,text,boolean) to authenticated;
