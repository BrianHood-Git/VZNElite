-- Private operational email outbox. No direct client writes or recipient email exposure.
create table public.team_email_outbox (
 id uuid primary key default gen_random_uuid(),
 message_key text not null,
 user_id uuid not null references auth.users(id),
 kind text not null check(kind in ('announcement','practice')),
 event_id uuid references public.team_events(id) on delete set null,
 event_date date, announcement_id text, announcement_title text,
 subject text not null, message text not null,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null,
 available_at timestamptz not null default now(),
 sent_at timestamptz, attempts integer not null default 0,
 last_error text,
 unique(message_key,user_id)
);
alter table public.team_email_outbox enable row level security;
revoke all on public.team_email_outbox from public,anon,authenticated;
grant select on public.team_email_outbox to authenticated;
create policy team_email_status_read on public.team_email_outbox for select to authenticated using((select team_private.has_role('administrator')));
grant all on public.team_email_outbox to service_role;
create index team_email_pending_idx on public.team_email_outbox(available_at) where sent_at is null;

create function team_private.team_email_recipients() returns table(user_id uuid)
language sql stable security definer set search_path='' as $$
 select distinct u.id from auth.users u join public.team_memberships m on m.user_id=u.id
 where u.email_confirmed_at is not null and u.email is not null and u.deleted_at is null
 and not coalesce(u.is_anonymous,false) and (u.banned_until is null or u.banned_until<now())
 and (m.role in ('administrator','coach') or (m.role in ('parent','player') and exists(
 select 1 from public.family_links l join public.team_players p on p.id=l.player_id
 where l.user_id=u.id and p.roster_status='active')))
$$;
revoke all on function team_private.team_email_recipients() from public,anon,authenticated;

create function team_private.queue_announcement_emails() returns trigger
language plpgsql security definer set search_path='' as $$declare item jsonb;prior jsonb;begin
 if new.key<>'announcements' then return new;end if;
 if jsonb_typeof(new.data->'items') is distinct from 'array' or jsonb_array_length(new.data->'items')>200 then raise exception 'Invalid announcement list';end if;
 for item in select value from jsonb_array_elements(new.data->'items') loop
  if length(coalesce(item->>'id','')) not between 1 and 100 or length(trim(coalesce(item->>'title',''))) not between 1 and 100 or length(trim(coalesce(item->>'body',''))) not between 1 and 2000 then raise exception 'Announcement title or message is invalid';end if;
  select value into prior from jsonb_array_elements(coalesce(old.data->'items','[]'::jsonb)) where value->>'id'=item->>'id' limit 1;
  if prior is null or prior->>'title' is distinct from item->>'title' or prior->>'body' is distinct from item->>'body' then
   insert into public.team_email_outbox(message_key,user_id,kind,announcement_id,announcement_title,subject,message,expires_at)
   select 'announcement:'||new.version||':'||(item->>'id'),r.user_id,'announcement',item->>'id',item->>'title',
    'VZN Elite: '||case when prior is null then '' else 'Updated - ' end||(item->>'title'),item->>'body',now()+interval '23 hours'
   from team_private.team_email_recipients() r on conflict(message_key,user_id) do nothing;
  end if;
 end loop;
 return new;
end$$;
revoke all on function team_private.queue_announcement_emails() from public,anon,authenticated;
create trigger announcement_email_queue after update on public.team_documents for each row when(new.key='announcements') execute function team_private.queue_announcement_emails();

create function team_private.queue_practice_reminders(as_of timestamptz default now()) returns void
language sql security definer set search_path='' as $$
 insert into public.team_email_outbox(message_key,user_id,kind,event_id,event_date,subject,message,expires_at)
 select 'practice:'||e.id||':'||e.date,r.user_id,'practice',e.id,e.date,
 'VZN Elite: practice reminder - '||e.title,
 e.title||E'\nDate: '||to_char(e.date,'FMDay, FMMonth DD, YYYY')||E'\nTime: '||to_char(e.time,'FMHH12:MI AM')||E' Central\nLocation: '||coalesce(e.location,'Location pending'),
 least((e.date+e.time) at time zone 'America/Chicago',now()+interval '23 hours')
 from public.team_events e cross join team_private.team_email_recipients() r
 where e.type='Practice' and not e.cancelled
 and ((e.date-1)+time '18:00') at time zone 'America/Chicago'<=as_of
 and (e.date+e.time) at time zone 'America/Chicago'>as_of
 on conflict(message_key,user_id) do nothing;
$$;
revoke all on function team_private.queue_practice_reminders(timestamptz) from public,anon,authenticated;
grant execute on function team_private.queue_practice_reminders(timestamptz) to service_role;

create function public.claim_team_emails() returns table(id uuid,email text,subject text,message text,kind text)
language plpgsql security definer set search_path='' as $$begin
 perform team_private.queue_practice_reminders();
 -- Refresh unsent reminders after an event edit. Cancelled/deleted/rescheduled events are excluded below.
 update public.team_email_outbox q set subject='VZN Elite: practice reminder - '||e.title,
 message=e.title||E'\nDate: '||to_char(e.date,'FMDay, FMMonth DD, YYYY')||E'\nTime: '||to_char(e.time,'FMHH12:MI AM')||E' Central\nLocation: '||coalesce(e.location,'Location pending')
 from public.team_events e where q.event_id=e.id and q.kind='practice' and q.sent_at is null and q.attempts=0;
 return query with ready as (
 select q.id from public.team_email_outbox q join team_private.team_email_recipients() r on r.user_id=q.user_id
 where q.sent_at is null and q.available_at<=now() and q.attempts<10 and q.expires_at>now()
 and ((q.kind='announcement' and exists(select 1 from public.team_documents d cross join lateral jsonb_array_elements(d.data->'items') item where d.key='announcements' and item->>'id'=q.announcement_id and item->>'title'=q.announcement_title and item->>'body'=q.message)) or exists(select 1 from public.team_events e where e.id=q.event_id and e.type='Practice' and not e.cancelled and e.date=q.event_date
 and ((e.date-1)+time '18:00') at time zone 'America/Chicago'<=now() and (e.date+e.time) at time zone 'America/Chicago'>now()))
 order by q.created_at,q.id for update of q skip locked limit 20
 ), claimed as (
 update public.team_email_outbox q set attempts=q.attempts+1,available_at=now()+interval '5 minutes' from ready where q.id=ready.id returning q.*
 ) select q.id,u.email::text,q.subject,q.message,q.kind from claimed q join auth.users u on u.id=q.user_id;
end$$;
revoke all on function public.claim_team_emails() from public,anon,authenticated;
grant execute on function public.claim_team_emails() to service_role;
