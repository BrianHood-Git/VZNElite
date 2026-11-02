-- REVIEWED SETUP SCRIPT, NOT APPLIED. Apply only to the confirmed VZN Elite project.
-- Existing team schema is required. Run in a transaction. Never run obsolete bootstrap drafts.
create table public.billing_invoices (
 id uuid primary key default gen_random_uuid(),
 player_id uuid not null references public.team_players(id),
 payer_id uuid not null references auth.users(id),
 period date not null check(extract(day from period)=1),
 amount_cents integer not null check(amount_cents between 0 and 1000000),
 status text not null check(status in ('open','paid','covered')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id),
 paid_at timestamptz, checkout_session_id text unique, payment_intent_id text unique,
 unique(player_id,period)
);
create index billing_invoices_payer on public.billing_invoices(payer_id);
alter table public.billing_invoices enable row level security;
revoke all on public.billing_invoices from public,anon,authenticated;
grant select on public.billing_invoices to authenticated;
grant all on public.billing_invoices to service_role;
create policy invoice_read on public.billing_invoices for select to authenticated
 using(payer_id=(select auth.uid()) or (select team_private.has_role('administrator')));

create function team_private.issue_monthly_invoice(player_key uuid,billing_month date) returns uuid
language plpgsql security definer set search_path='' as $$
declare p public.team_players; d jsonb; s jsonb; cents integer; result uuid;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
 if billing_month is null or extract(day from billing_month)<>1 then raise exception 'Choose the first day of the billing month'; end if;
 select * into p from public.team_players where id=player_key for update;
 if not found or p.roster_status<>'active' or p.billing_parent_id is null then raise exception 'Assign a billing parent to an active player first'; end if;
 if not exists(select 1 from public.family_links l join public.team_memberships m on m.user_id=l.user_id and m.role='parent' where l.user_id=p.billing_parent_id and l.player_id=p.id and l.relationship='parent') then raise exception 'Billing parent must have approved parent access'; end if;
 select data into d from public.team_documents where key='dues';
 if d is null then raise exception 'Configure dues first'; end if;
 s=d->'support'->player_key::text;
 cents=greatest(0,(d->>'monthly')::integer-case when coalesce((s->>'full')::boolean,false) then (d->>'monthly')::integer else least((d->>'monthly')::integer,coalesce((s->>'amount')::integer,0)) end);
 if cents between 1 and 49 then raise exception 'Card invoices must be zero or at least 50 cents'; end if;
 insert into public.billing_invoices(player_id,payer_id,period,amount_cents,status,created_by)
 values(p.id,p.billing_parent_id,billing_month,cents,case when cents=0 then 'covered' else 'open' end,auth.uid()) returning id into result;
 return result;
end $$;
revoke all on function team_private.issue_monthly_invoice(uuid,date) from public,anon;
grant execute on function team_private.issue_monthly_invoice(uuid,date) to authenticated;
create function public.issue_monthly_invoice(player_key uuid,billing_month date) returns uuid language sql security invoker set search_path='' as $$select team_private.issue_monthly_invoice(player_key,billing_month)$$;
revoke all on function public.issue_monthly_invoice(uuid,date) from public,anon;
grant execute on function public.issue_monthly_invoice(uuid,date) to authenticated;

create table public.billing_webhook_events(event_id text primary key,invoice_id uuid not null references public.billing_invoices(id),received_at timestamptz not null default now());
alter table public.billing_webhook_events enable row level security;
revoke all on public.billing_webhook_events from public,anon,authenticated;
grant all on public.billing_webhook_events to service_role;
create function public.record_invoice_payment(event_key text,invoice_key uuid,session_key text,paid_amount integer,intent_key text) returns void
language plpgsql security invoker set search_path='' as $$
declare i public.billing_invoices;
begin
 select * into i from public.billing_invoices where id=invoice_key for update;
 if not found or i.amount_cents<>paid_amount or i.checkout_session_id is distinct from session_key or i.status='covered' then raise exception 'Payment does not match invoice'; end if;
 if exists(select 1 from public.billing_webhook_events where event_id=event_key) then return; end if;
 insert into public.billing_webhook_events(event_id,invoice_id) values(event_key,invoice_key);
 update public.billing_invoices set status='paid',paid_at=coalesce(paid_at,now()),payment_intent_id=intent_key where id=invoice_key;
end $$;
revoke all on function public.record_invoice_payment(text,uuid,text,integer,text) from public,anon,authenticated;
grant execute on function public.record_invoice_payment(text,uuid,text,integer,text) to service_role;

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
