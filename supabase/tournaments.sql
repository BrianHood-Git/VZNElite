create table public.team_tournaments (
 id uuid primary key default gen_random_uuid(),
 name text not null check(length(trim(name)) between 1 and 150),
 event_date date, location text not null default '' check(length(location)<=300),
 contact_name text not null default '' check(length(contact_name)<=100),
 contact_phone text not null default '' check(length(contact_phone)<=40),
 cost_cents integer check(cost_cents between 0 and 100000000),
 paid_cents integer not null default 0 check(paid_cents between 0 and 100000000),
 notes text not null default '' check(length(notes)<=3000),
 archived boolean not null default false,
 version integer not null default 1,
 updated_at timestamptz not null default now(),
 check(cost_cents is null or paid_cents<=cost_cents)
);
alter table public.team_tournaments enable row level security;
revoke all on public.team_tournaments from public,anon,authenticated;
grant select,insert,update on public.team_tournaments to authenticated;
create policy tournaments_read on public.team_tournaments for select to authenticated using((select team_private.has_role('administrator')));
create policy tournaments_insert on public.team_tournaments for insert to authenticated with check((select team_private.has_role('administrator')));
create policy tournaments_update on public.team_tournaments for update to authenticated using((select team_private.has_role('administrator'))) with check((select team_private.has_role('administrator')));
insert into public.team_tournaments(name,event_date,contact_name,contact_phone,notes) values('Tournament - details pending','2026-10-18','Gino','(210) 473-9047','Tournament played yesterday. Confirm the tournament name and team cost.');
