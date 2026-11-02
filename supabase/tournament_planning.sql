create table public.tournament_vendors (
 id uuid primary key default gen_random_uuid(),
 organization text not null check(length(trim(organization)) between 1 and 150),
 kind text not null default 'vendor' check(kind in ('vendor','resource')),
 contact_name text not null default '' check(length(contact_name)<=100),
 phone text not null default '' check(length(phone)<=40),
 email text not null default '' check(email='' or (length(email)<=254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')),
 website text not null default '' check(website='' or (length(website)<=1000 and website ~* '^https?://[^[:space:]]+$')),
 location text not null default '' check(length(location)<=300),
 notes text not null default '' check(length(notes)<=3000),
 archived boolean not null default false,
 version integer not null default 1,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create unique index tournament_vendor_name_idx on public.tournament_vendors(lower(regexp_replace(trim(organization),'[[:space:]]+',' ','g')));
create table public.tournament_vendor_history (
 id bigint generated always as identity primary key,
 vendor_id uuid not null references public.tournament_vendors(id),
 actor uuid references auth.users(id),recorded_at timestamptz not null default now(),
 action text not null,snapshot jsonb not null
);
create index tournament_vendor_history_vendor_idx on public.tournament_vendor_history(vendor_id);
alter table public.tournament_vendors enable row level security;
alter table public.tournament_vendor_history enable row level security;
revoke all on public.tournament_vendors,public.tournament_vendor_history from public,anon,authenticated;
grant select,insert,update on public.tournament_vendors to authenticated;
grant select on public.tournament_vendor_history to authenticated;
create policy vendors_read on public.tournament_vendors for select to authenticated using((select team_private.has_role('administrator')));
create policy vendors_insert on public.tournament_vendors for insert to authenticated with check((select team_private.has_role('administrator')));
create policy vendors_update on public.tournament_vendors for update to authenticated using((select team_private.has_role('administrator'))) with check((select team_private.has_role('administrator')));
create policy vendor_history_read on public.tournament_vendor_history for select to authenticated using((select team_private.has_role('administrator')));
create function team_private.audit_tournament_vendor() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.tournament_vendor_history(vendor_id,actor,action,snapshot) values(new.id,auth.uid(),tg_op,to_jsonb(new));return new;
end$$;
revoke all on function team_private.audit_tournament_vendor() from public,anon,authenticated;
-- AFTER insert is required for the history foreign key; version stamps happen separately.
create function team_private.stamp_vendor_version() returns trigger language plpgsql set search_path='' as $$begin new.version:=old.version+1;new.updated_at:=now();return new;end$$;
revoke all on function team_private.stamp_vendor_version() from public,anon,authenticated;
create trigger vendor_version before update on public.tournament_vendors for each row execute function team_private.stamp_vendor_version();
create trigger vendor_audit after insert or update on public.tournament_vendors for each row execute function team_private.audit_tournament_vendor();

insert into public.tournament_vendors(organization,kind,contact_name,phone,website,notes) values
 ('Road to Nationals','vendor','','','','Name supplied by the team. Other details pending.'),
 ('Alamo City All-Stars','vendor','','','https://alamocityallstars.com/','Website supplied by the team. Texas youth basketball.'),
 ('George Gervin Academy','vendor','Gino','(210) 473-9047','','Private tournament contact supplied by the team.'),
 ('Exposure Events','resource','','','https://basketball.exposureevents.com/','Tournament discovery resource. Filter to Texas youth basketball; individual events require review.'),
 ('San Antonio Youth Basketball','resource','','','https://www.facebook.com/groups/1142225714433361/','Local Facebook discovery group supplied by the team; not a confirmed tournament organizer.'),
 ('Full Court Athletics','vendor','','','https://fullcourtathleticstx.com/','Website supplied by the team. Texas youth basketball.');

alter table public.team_tournaments
 add column vendor_id uuid references public.tournament_vendors(id),
 add column end_date date,
 add column start_time time,
 add column planning_status text not null default 'considering' check(planning_status in ('considering','registered','confirmed','completed','cancelled')),
 add column registration_deadline date,
 add column registration_url text not null default '' check(registration_url='' or (length(registration_url)<=1000 and registration_url ~* '^https?://[^[:space:]]+$')),
 add column calendar_published boolean not null default false,
 add constraint tournament_date_range check(end_date is null or (event_date is not null and end_date>=event_date and end_date<=event_date+6));
create index tournament_vendor_link_idx on public.team_tournaments(vendor_id);
alter table public.team_events add column tournament_id uuid references public.team_tournaments(id),add column tournament_day integer;
alter table public.team_events add constraint tournament_event_day unique(tournament_id,tournament_day),add constraint tournament_event_link check((tournament_id is null and tournament_day is null) or (tournament_id is not null and tournament_day between 0 and 6));

create function team_private.guard_tournament_calendar() returns trigger language plpgsql set search_path='' as $$begin
 if current_user not in ('postgres','service_role','supabase_admin') and
 ((tg_op<>'INSERT' and old.tournament_id is not null) or (tg_op<>'DELETE' and new.tournament_id is not null)) then
 raise exception 'Manage linked tournament dates and cancellations in Administration > Tournaments' using errcode='42501';end if;
 if tg_op='DELETE' then return old;end if;return new;
end$$;
revoke all on function team_private.guard_tournament_calendar() from public,anon,authenticated;
create trigger tournament_event_guard before insert or update or delete on public.team_events for each row execute function team_private.guard_tournament_calendar();

create function team_private.sync_tournament_calendar() returns trigger language plpgsql security definer set search_path='' as $$declare d integer;begin
 if not new.calendar_published then return new;end if;
 if new.archived or new.planning_status='cancelled' then
 update public.team_events set cancelled=true where tournament_id=new.id;return new;end if;
 if new.planning_status not in ('registered','confirmed','completed') or new.event_date is null or new.start_time is null or length(trim(new.location))=0 then
 raise exception 'Published tournaments need a committed status, date, start time, and location. Cancel the tournament to withdraw it.';end if;
 for d in 0..(coalesce(new.end_date,new.event_date)-new.event_date) loop
 insert into public.team_events(title,type,date,time,location,cancelled,tournament_id,tournament_day)
 values(left(new.name,120),'Tournament',new.event_date+d,new.start_time,new.location,false,new.id,d)
 on conflict(tournament_id,tournament_day) do update set title=excluded.title,type='Tournament',date=excluded.date,time=excluded.time,location=excluded.location,cancelled=false;
 end loop;
 update public.team_events set cancelled=true where tournament_id=new.id and tournament_day>(coalesce(new.end_date,new.event_date)-new.event_date);
 return new;
end$$;
revoke all on function team_private.sync_tournament_calendar() from public,anon,authenticated;
-- AFTER UPDATE observes the new row and keeps all calendar changes in the same transaction.
create trigger tournament_calendar_sync after update on public.team_tournaments for each row execute function team_private.sync_tournament_calendar();
create function team_private.publish_tournament(tournament_key uuid,expected_version integer) returns void language plpgsql security definer set search_path='' as $$declare t public.team_tournaments;begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
 select * into t from public.team_tournaments where id=tournament_key for update;
 if not found or expected_version is null or t.version<>expected_version then raise exception 'Tournament changed. Refresh before publishing.';end if;
 if t.archived or t.planning_status not in ('registered','confirmed') or t.event_date is null or t.start_time is null or length(trim(t.location))=0 then raise exception 'Choose Registered or Confirmed, then enter date, start time, and location before publishing.';end if;
 update public.team_tournaments set calendar_published=true,version=version+1,updated_at=now() where id=t.id;
end$$;
revoke all on function team_private.publish_tournament(uuid,integer) from public,anon;
grant execute on function team_private.publish_tournament(uuid,integer) to authenticated;
create function public.publish_tournament(tournament_key uuid,expected_version integer) returns void language sql security invoker set search_path='' as $$select team_private.publish_tournament(tournament_key,expected_version)$$;
revoke all on function public.publish_tournament(uuid,integer) from public,anon;
grant execute on function public.publish_tournament(uuid,integer) to authenticated;
