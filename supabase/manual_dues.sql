-- Offline dues tracking. No processor, bank transfer, or financial-ledger mutation.
create table public.manual_dues (
 id uuid primary key default gen_random_uuid(),
 player_id uuid not null references public.team_players(id),
 payer_id uuid not null references auth.users(id),
 period date not null check(extract(day from period)=1),
 amount_cents integer not null check(amount_cents between 0 and 1000000),
 paid boolean not null default false,
 payment_date date, method text, note text not null default '',
 version integer not null default 1,
 created_by uuid not null references auth.users(id),
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 unique(player_id,period),
 check(not paid or (amount_cents>0 and payment_date is not null and method in ('cash','check','cash_app','bank_transfer','other')))
);
create index manual_dues_payer_idx on public.manual_dues(payer_id);
create table public.manual_dues_history (
 id bigint generated always as identity primary key,
 dues_id uuid not null references public.manual_dues(id),
 actor uuid not null references auth.users(id),
 recorded_at timestamptz not null default now(),
 action text not null, snapshot jsonb not null
);
create index manual_dues_history_dues_idx on public.manual_dues_history(dues_id);
alter table public.manual_dues enable row level security;
alter table public.manual_dues_history enable row level security;
revoke all on public.manual_dues,public.manual_dues_history from public,anon,authenticated;
grant select on public.manual_dues,public.manual_dues_history to authenticated;
create policy manual_dues_read on public.manual_dues for select to authenticated using(payer_id=(select auth.uid()) or (select team_private.has_role('administrator')));
create policy manual_dues_history_read on public.manual_dues_history for select to authenticated using((select team_private.has_role('administrator')));
create function team_private.create_manual_dues(p uuid,billing_month date) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_players; d jsonb; s jsonb; cents integer; result uuid;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 if billing_month is null or extract(day from billing_month)<>1 then raise exception 'Choose a billing month';end if;
 select * into r from public.team_players where id=p for update;
 if not found or r.roster_status<>'active' or r.billing_parent_id is null then raise exception 'Assign a responsible parent to an active player first';end if;
 if not exists(select 1 from public.family_links where user_id=r.billing_parent_id and player_id=p and relationship='parent') then raise exception 'Responsible parent must be linked to the player';end if;
 select data into d from public.team_documents where key='dues';if d is null then raise exception 'Configure team dues first';end if;
 s:=d->'support'->p::text;
 cents:=greatest(0,(d->>'monthly')::integer-case when coalesce((s->>'full')::boolean,false) then (d->>'monthly')::integer else least((d->>'monthly')::integer,coalesce((s->>'amount')::integer,0)) end);
 if exists(select 1 from public.manual_dues where player_id=p and period=billing_month) then raise exception 'Dues already recorded for this player and month';end if;
 insert into public.manual_dues(player_id,payer_id,period,amount_cents,created_by,updated_by) values(p,r.billing_parent_id,billing_month,cents,auth.uid(),auth.uid()) returning id into result;
 insert into public.manual_dues_history(dues_id,actor,action,snapshot) select result,auth.uid(),'created',to_jsonb(m) from public.manual_dues m where id=result;
 return result;
end$$;
create function team_private.set_manual_dues_payment(dues_key uuid,expected_version integer,is_paid boolean,paid_on date,payment_method text,payment_note text) returns void language plpgsql security definer set search_path='' as $$
declare r public.manual_dues;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 select * into r from public.manual_dues where id=dues_key for update;
 if not found then raise exception 'Dues record not found';end if;
 if expected_version is distinct from r.version then raise exception 'This record changed. Refresh before saving.';end if;
 if is_paid is null or is_paid=r.paid then raise exception 'Payment status is already set. Refresh before saving.';end if;
 if length(coalesce(payment_note,''))>500 then raise exception 'Use a note under 500 characters';end if;
 if is_paid then
  if r.amount_cents=0 then raise exception 'This month is covered by support';end if;
  if paid_on is null or paid_on>(now() at time zone 'America/Chicago')::date or payment_method is null or payment_method not in ('cash','check','cash_app','bank_transfer','other') then raise exception 'Choose a valid payment date and method';end if;
 elsif length(trim(coalesce(payment_note,'')))=0 then raise exception 'Enter a reason for reopening dues';end if;
 update public.manual_dues set paid=is_paid,payment_date=case when is_paid then paid_on end,method=case when is_paid then payment_method end,note=coalesce(trim(payment_note),''),version=version+1,updated_by=auth.uid(),updated_at=now() where id=dues_key;
 insert into public.manual_dues_history(dues_id,actor,action,snapshot) select r.id,auth.uid(),case when is_paid then 'marked_paid' else 'reopened' end,to_jsonb(m) from public.manual_dues m where id=r.id;
end$$;
revoke all on function team_private.create_manual_dues(uuid,date),team_private.set_manual_dues_payment(uuid,integer,boolean,date,text,text) from public,anon;
grant execute on function team_private.create_manual_dues(uuid,date),team_private.set_manual_dues_payment(uuid,integer,boolean,date,text,text) to authenticated;
create function public.create_manual_dues(p uuid,billing_month date) returns uuid language sql security invoker set search_path='' as $$select team_private.create_manual_dues(p,billing_month)$$;
create function public.set_manual_dues_payment(dues_key uuid,expected_version integer,is_paid boolean,paid_on date,payment_method text,payment_note text) returns void language sql security invoker set search_path='' as $$select team_private.set_manual_dues_payment(dues_key,expected_version,is_paid,paid_on,payment_method,payment_note)$$;
revoke all on function public.create_manual_dues(uuid,date),public.set_manual_dues_payment(uuid,integer,boolean,date,text,text) from public,anon;
grant execute on function public.create_manual_dues(uuid,date),public.set_manual_dues_payment(uuid,integer,boolean,date,text,text) to authenticated;
