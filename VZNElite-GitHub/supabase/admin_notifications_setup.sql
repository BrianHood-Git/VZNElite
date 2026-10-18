-- Email-only setup for the existing VZN Elite project; no billing tables. Not yet applied.
create table public.admin_notifications (
 id uuid primary key default gen_random_uuid(),user_id uuid not null unique references auth.users(id),
 created_at timestamptz not null default now(),sent_at timestamptz,
 attempts integer not null default 0,next_attempt_at timestamptz not null default now(),last_error text
);
alter table public.admin_notifications enable row level security;
revoke all on public.admin_notifications from public,anon,authenticated;
grant select(id,user_id,created_at,sent_at,attempts) on public.admin_notifications to authenticated;
grant all on public.admin_notifications to service_role;
create policy notification_admin_read on public.admin_notifications for select to authenticated using((select team_private.has_role('administrator')));
create function team_private.queue_verified_account() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.email_confirmed_at is not null then
  insert into public.admin_notifications(user_id) values(new.id) on conflict(user_id) do nothing;
 end if;
 return new;
end $$;
revoke all on function team_private.queue_verified_account() from public,anon,authenticated;
create trigger new_verified_account after insert or update of email_confirmed_at on auth.users for each row execute function team_private.queue_verified_account();
create function public.claim_admin_notifications() returns setof public.admin_notifications language sql security invoker set search_path='' as $$
 with pending as (select id from public.admin_notifications where sent_at is null and attempts<10 and next_attempt_at<=now() order by created_at for update skip locked limit 10)
 update public.admin_notifications n set attempts=n.attempts+1,next_attempt_at=now()+interval '10 minutes' from pending where n.id=pending.id returning n.*
$$;
revoke all on function public.claim_admin_notifications() from public,anon,authenticated;
grant execute on function public.claim_admin_notifications() to service_role;
-- Notifications begin with future verified users. No historical emails are sent by setup.
