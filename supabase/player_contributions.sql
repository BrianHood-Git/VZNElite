-- One recorded receipt drives the player tracker and finance ledger.
create table public.player_contributions (
 id uuid primary key,
 player_id uuid not null references public.team_players(id),
 period date not null check(extract(day from period)=1),
 kind text not null check(kind in ('dues','voluntary')),
 dues_id uuid references public.manual_dues(id),
 credit_cents integer not null check(credit_cents between 0 and 1000000),
 net_cents integer not null check(net_cents between 1 and 100000000),
 payment_date date not null,
 method text not null check(method in ('venmo','cash','check','cash_app','bank_transfer','other')),
 payer_name text not null check(length(payer_name) between 1 and 200),
 reference text not null default '' check(length(reference)<=120),
 note text not null default '' check(length(note)<=500),
 recorded_by uuid not null references auth.users(id),
 recorded_at timestamptz not null default now(),
 voided_at timestamptz, voided_by uuid references auth.users(id), void_reason text,
 check((kind='dues' and dues_id is not null and credit_cents>0) or (kind='voluntary' and dues_id is null and credit_cents=0))
);
create unique index contribution_dues_active on public.player_contributions(dues_id) where voided_at is null;
create unique index contribution_reference on public.player_contributions(method,reference) where reference<>'';
create index contribution_player on public.player_contributions(player_id,period);
alter table public.player_contributions enable row level security;
revoke all on public.player_contributions from public,anon,authenticated;
grant select on public.player_contributions to authenticated;
create policy contribution_admin_read on public.player_contributions for select to authenticated using ((select team_private.has_role('administrator')));

create function team_private.save_player_support(player_key uuid,billing_month date,support_kind text,sponsor_note text,expected_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare doc public.team_documents; support jsonb; amount integer; d public.manual_dues;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 if support_kind is null or support_kind not in ('none','half','full') or billing_month is null or extract(day from billing_month)<>1 or length(coalesce(sponsor_note,''))>120 then raise exception 'Invalid support settings';end if;
 if not exists(select 1 from public.team_players where id=player_key) then raise exception 'Player not found';end if;
 select * into doc from public.team_documents where key='dues' for update;
 if not found or doc.version is distinct from expected_version then raise exception 'Settings changed. Refresh before saving.';end if;
 amount:=case support_kind when 'full' then (doc.data->>'monthly')::integer when 'half' then (doc.data->>'monthly')::integer/2 else 0 end;
 support:=coalesce(doc.data->'support','{}'::jsonb);
 if support_kind='none' then support:=support-player_key::text;
 else support:=jsonb_set(support,array[player_key::text],jsonb_build_object('full',support_kind='full','half',support_kind='half','amount',case when support_kind='full' then 0 else amount end,'note',trim(coalesce(sponsor_note,''))));end if;
 select * into d from public.manual_dues where player_id=player_key and period=billing_month for update;
 if found and not d.paid then
  if exists(select 1 from public.venmo_reports where dues_id=d.id and status in ('pending','confirmed')) then raise exception 'Review this month''s Venmo report before changing its support';end if;
  update public.manual_dues set amount_cents=greatest(0,(doc.data->>'monthly')::integer-amount),version=version+1,updated_by=auth.uid(),updated_at=now() where id=d.id;
  insert into public.manual_dues_history(dues_id,actor,action,snapshot) select d.id,auth.uid(),'support_updated',to_jsonb(m) from public.manual_dues m where id=d.id;
 end if;
 update public.team_documents set data=jsonb_set(jsonb_set(doc.data,'{support}',support),'{history}',coalesce(doc.data->'history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('at',now(),'actor',auth.uid(),'message','Player '||player_key::text||': '||support_kind||' support; unpaid month '||billing_month::text))),version=version+1,updated_at=now() where key='dues';
end $$;

create function team_private.record_player_contribution(request_key uuid,player_key uuid,billing_month date,contribution_kind text,received_cents integer,paid_on date,payment_method text,payer text,payment_reference text,payment_note text,expected_settings_version integer,expected_dues_version integer,verified_full_payment boolean) returns uuid
language plpgsql security definer set search_path='' as $$
declare prior public.player_contributions; d public.manual_dues; doc public.team_documents; dues_key uuid;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 if request_key is null or player_key is null or billing_month is null or extract(day from billing_month)<>1 or contribution_kind is null or contribution_kind not in ('dues','voluntary') or received_cents is null or received_cents not between 1 and 100000000 or paid_on is null or paid_on>(now() at time zone 'America/Chicago')::date or payment_method is null or payment_method not in ('venmo','cash','check','cash_app','bank_transfer','other') or length(trim(coalesce(payer,''))) not between 1 and 200 or length(coalesce(payment_reference,''))>120 or length(coalesce(payment_note,''))>500 then raise exception 'Enter valid payment details';end if;
 perform pg_advisory_xact_lock(hashtextextended(request_key::text,1));
 select * into prior from public.player_contributions where id=request_key;
 if found then
  if prior.player_id=player_key and prior.period=billing_month and prior.kind=contribution_kind and prior.net_cents=received_cents and prior.payment_date=paid_on and prior.method=payment_method and prior.payer_name=trim(payer) and prior.reference=trim(coalesce(payment_reference,'')) and prior.note=trim(coalesce(payment_note,'')) and prior.voided_at is null then return prior.id;end if;
  raise exception 'This payment attempt already has different details. Refresh.';
 end if;
 if payment_method='venmo' and trim(coalesce(payment_reference,''))<>'' and exists(select 1 from public.venmo_receipts where transaction_id=trim(payment_reference)) then raise exception 'This receipt is already in Venmo reconciliation. Match it there instead.';end if;
 if contribution_kind='dues' then
  select * into doc from public.team_documents where key='dues' for update;
  if not found or doc.version is distinct from expected_settings_version then raise exception 'Support settings changed. Refresh before recording payment.';end if;
  select * into d from public.manual_dues where player_id=player_key and period=billing_month for update;
  if not found then
   if expected_dues_version is not null then raise exception 'Monthly record changed. Refresh.';end if;
   dues_key:=team_private.create_manual_dues(player_key,billing_month);
   select * into d from public.manual_dues where id=dues_key for update;
  elsif d.version is distinct from expected_dues_version then raise exception 'Monthly record changed. Refresh.';end if;
  if d.paid or d.amount_cents=0 then raise exception 'This month is already paid or fully sponsored. Record an optional contribution instead.';end if;
  if exists(select 1 from public.venmo_reports where dues_id=d.id and status in ('pending','confirmed')) then raise exception 'Review the existing Venmo report in Finances first';end if;
  if verified_full_payment is distinct from true or received_cents>d.amount_cents or (payment_method<>'venmo' and received_cents<>d.amount_cents) then raise exception 'Confirm the full monthly amount was paid; record extra funds separately as optional contributions';end if;
  update public.manual_dues set paid=true,payment_date=paid_on,method=payment_method,note=trim(coalesce(payment_note,'')),version=version+1,updated_by=auth.uid(),updated_at=now() where id=d.id;
  insert into public.manual_dues_history(dues_id,actor,action,snapshot) select d.id,auth.uid(),'contribution_recorded',to_jsonb(m) from public.manual_dues m where id=d.id;
 end if;
 insert into public.player_contributions(id,player_id,period,kind,dues_id,credit_cents,net_cents,payment_date,method,payer_name,reference,note,recorded_by)
 values(request_key,player_key,billing_month,contribution_kind,case when contribution_kind='dues' then d.id end,case when contribution_kind='dues' then d.amount_cents else 0 end,received_cents,paid_on,payment_method,trim(payer),trim(coalesce(payment_reference,'')),trim(coalesce(payment_note,'')),auth.uid());
 return request_key;
end $$;

create function team_private.void_player_contribution(receipt_key uuid,reason text) returns void language plpgsql security definer set search_path='' as $$
declare r public.player_contributions; d public.manual_dues;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 if length(trim(coalesce(reason,''))) not between 1 and 500 then raise exception 'Enter a correction reason';end if;
 select * into r from public.player_contributions where id=receipt_key;
 if not found then raise exception 'Receipt not found';end if;
 if r.dues_id is not null then select * into d from public.manual_dues where id=r.dues_id for update;end if;
 select * into r from public.player_contributions where id=receipt_key for update;
 if r.voided_at is not null then raise exception 'Receipt already voided';end if;
 update public.player_contributions set voided_at=now(),voided_by=auth.uid(),void_reason=trim(reason) where id=receipt_key;
 if r.dues_id is not null then
  perform team_private.set_manual_dues_payment(d.id,d.version,false,null,null,'Voided receipt: '||left(trim(reason),480));
 end if;
end $$;

create function public.save_player_support(player_key uuid,billing_month date,support_kind text,sponsor_note text,expected_version integer) returns void language sql security invoker set search_path='' as $$select team_private.save_player_support(player_key,billing_month,support_kind,sponsor_note,expected_version)$$;
create function public.record_player_contribution(request_key uuid,player_key uuid,billing_month date,contribution_kind text,received_cents integer,paid_on date,payment_method text,payer text,payment_reference text,payment_note text,expected_settings_version integer,expected_dues_version integer,verified_full_payment boolean) returns uuid language sql security invoker set search_path='' as $$select team_private.record_player_contribution(request_key,player_key,billing_month,contribution_kind,received_cents,paid_on,payment_method,payer,payment_reference,payment_note,expected_settings_version,expected_dues_version,verified_full_payment)$$;
create function public.void_player_contribution(receipt_key uuid,reason text) returns void language sql security invoker set search_path='' as $$select team_private.void_player_contribution(receipt_key,reason)$$;
revoke all on function team_private.save_player_support(uuid,date,text,text,integer),public.save_player_support(uuid,date,text,text,integer),team_private.record_player_contribution(uuid,uuid,date,text,integer,date,text,text,text,text,integer,integer,boolean),public.record_player_contribution(uuid,uuid,date,text,integer,date,text,text,text,text,integer,integer,boolean),team_private.void_player_contribution(uuid,text),public.void_player_contribution(uuid,text) from public,anon;
grant execute on function team_private.save_player_support(uuid,date,text,text,integer),public.save_player_support(uuid,date,text,text,integer),team_private.record_player_contribution(uuid,uuid,date,text,integer,date,text,text,text,text,integer,integer,boolean),public.record_player_contribution(uuid,uuid,date,text,integer,date,text,text,text,text,integer,integer,boolean),team_private.void_player_contribution(uuid,text),public.void_player_contribution(uuid,text) to authenticated;

-- Both receipt entry paths serialize on the real Venmo reference, when known.
create function team_private.guard_contribution_reference() returns trigger language plpgsql security definer set search_path='' as $$
declare ref text;
begin
 if tg_table_name='venmo_receipts' then ref:=new.transaction_id;
 elsif new.method='venmo' then ref:=new.reference;
 else return new;end if;
 if coalesce(ref,'')='' then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended(ref,0));
 if tg_table_name='venmo_receipts' then
  if exists(select 1 from public.player_contributions where method='venmo' and reference=ref) then raise exception 'Venmo reference already recorded in player contributions';end if;
 else
  if exists(select 1 from public.venmo_receipts where transaction_id=ref) then raise exception 'Venmo reference already imported; use reconciliation';end if;
 end if;
 return new;
end $$;
revoke all on function team_private.guard_contribution_reference() from public,anon,authenticated;
create trigger contribution_reference_guard before insert on public.player_contributions for each row execute function team_private.guard_contribution_reference();
create trigger venmo_contribution_reference_guard before insert on public.venmo_receipts for each row execute function team_private.guard_contribution_reference();
create function team_private.guard_recorded_contribution() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.paid and not new.paid and exists(select 1 from public.player_contributions where dues_id=old.id and voided_at is null) then raise exception 'Void the linked player receipt before reopening this month';end if;
 return new;
end $$;
revoke all on function team_private.guard_recorded_contribution() from public,anon,authenticated;
create trigger contribution_dues_guard before update on public.manual_dues for each row execute function team_private.guard_recorded_contribution();
notify pgrst,'reload schema';
