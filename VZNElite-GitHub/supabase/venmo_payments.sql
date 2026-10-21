-- Additive upgrade for the existing VZN project; never run bootstrap scripts.
create table public.venmo_reports (
 id uuid primary key default gen_random_uuid(),
 dues_id uuid not null references public.manual_dues(id),
 parent_id uuid not null references auth.users(id),
 payment_date date not null,
 reference text not null check(length(reference) between 1 and 120),
 status text not null default 'pending' check(status in ('pending','confirmed','rejected')),
 created_at timestamptz not null default now(),
 reviewed_by uuid references auth.users(id), reviewed_at timestamptz, review_note text
);
create unique index venmo_reports_active on public.venmo_reports(dues_id) where status in ('pending','confirmed');
create index venmo_reports_parent on public.venmo_reports(parent_id);
create table public.venmo_receipts (
 transaction_id text primary key check(length(transaction_id) between 1 and 120),
 payment_date date not null, gross_cents integer not null check(gross_cents between 1 and 100000000),
 fee_cents integer not null check(fee_cents>=0 and fee_cents<=gross_cents),
 sender text not null check(length(sender)<=200), note text not null check(length(note)<=1000),
 report_id uuid unique references public.venmo_reports(id),
 recorded_by uuid not null references auth.users(id), recorded_at timestamptz not null default now(),
 source text not null check(source in ('manual','csv'))
);
alter table public.venmo_reports enable row level security;
alter table public.venmo_receipts enable row level security;
revoke all on public.venmo_reports,public.venmo_receipts from public,anon,authenticated;
grant select on public.venmo_reports,public.venmo_receipts to authenticated;
create policy venmo_reports_read on public.venmo_reports for select to authenticated
 using(parent_id=(select auth.uid()) or (select team_private.has_role('administrator')));
create policy venmo_receipts_read on public.venmo_receipts for select to authenticated
 using((select team_private.has_role('administrator')));

-- Private privileged functions are necessary to keep direct writes disabled.
create function team_private.report_venmo(dues_key uuid,paid_on date,venmo_reference text) returns uuid
language plpgsql security definer set search_path='' as $$
declare d public.manual_dues; result uuid;
begin
 if auth.uid() is null or not team_private.has_role('parent') then raise exception 'Parent access required' using errcode='42501'; end if;
 select * into d from public.manual_dues where id=dues_key for update;
 if not found or d.payer_id<>auth.uid() or not exists(select 1 from public.family_links where player_id=d.player_id and user_id=auth.uid() and relationship='parent') then raise exception 'Not your dues record' using errcode='42501'; end if;
 if d.paid or d.amount_cents=0 then raise exception 'Dues are already paid or covered'; end if;
 if paid_on is null or paid_on>(now() at time zone 'America/Chicago')::date or length(trim(coalesce(venmo_reference,''))) not between 1 and 120 then raise exception 'Enter a valid date and Venmo reference'; end if;
 insert into public.venmo_reports(dues_id,parent_id,payment_date,reference) values(dues_key,auth.uid(),paid_on,trim(venmo_reference)) returning id into result;
 return result;
end $$;
create function public.report_venmo(dues_key uuid,paid_on date,venmo_reference text) returns uuid
language sql security invoker set search_path='' as $$select team_private.report_venmo(dues_key,paid_on,venmo_reference)$$;

create function team_private.import_venmo(receipts jsonb) returns integer
language plpgsql security definer set search_path='' as $$
declare item jsonb; old public.venmo_receipts; added integer:=0; tx text; paid date; gross integer; fee integer;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
 if jsonb_typeof(receipts)<>'array' or jsonb_array_length(receipts)>2000 then raise exception 'Import up to 2000 receipts'; end if;
 for item in select value from jsonb_array_elements(receipts) loop
  tx:=trim(item->>'transaction_id'); paid:=(item->>'payment_date')::date; gross:=(item->>'gross_cents')::integer; fee:=(item->>'fee_cents')::integer;
  if tx is null or paid is null or paid>(now() at time zone 'America/Chicago')::date or gross is null or fee is null then raise exception 'Invalid receipt'; end if;
  -- Serialize manual confirmations and imports for the same external ID.
  perform pg_advisory_xact_lock(hashtextextended(tx,0));
  select * into old from public.venmo_receipts where transaction_id=tx;
  if found then
   if old.payment_date<>paid or old.gross_cents<>gross or old.fee_cents<>fee then raise exception 'Conflicting data for transaction %; review existing receipt',tx; end if;
  else
   if exists(select 1 from public.team_documents doc cross join lateral jsonb_array_elements(coalesce(doc.data->'transactions','[]'::jsonb)) t where doc.key='finances' and t->>'reference' in (tx,'Venmo '||tx)) then raise exception 'Transaction already referenced in legacy ledger: %',tx; end if;
   insert into public.venmo_receipts(transaction_id,payment_date,gross_cents,fee_cents,sender,note,recorded_by,source)
    values(tx,paid,gross,fee,coalesce(item->>'sender',''),coalesce(item->>'note',''),auth.uid(),coalesce(item->>'source','csv'));
   added:=added+1;
  end if;
 end loop;
 return added;
end $$;
create function public.import_venmo(receipts jsonb) returns integer language sql security invoker set search_path='' as $$select team_private.import_venmo(receipts)$$;

create function team_private.review_venmo(report_key uuid,tx_key text,decision text,reason text) returns void
language plpgsql security definer set search_path='' as $$
declare r public.venmo_reports; d public.manual_dues; receipt public.venmo_receipts;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
 select * into r from public.venmo_reports where id=report_key for update;
 if not found then raise exception 'Report not found'; end if;
 if r.status<>'pending' then raise exception 'Report already reviewed'; end if;
 if decision not in ('confirm','reject') or decision is null or length(coalesce(reason,''))>500 then raise exception 'Invalid review'; end if;
 if decision='reject' then
  if length(trim(coalesce(reason,'')))=0 then raise exception 'Explain why the report was rejected'; end if;
  update public.venmo_reports set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),review_note=reason where id=report_key;
  return;
 end if;
 select * into d from public.manual_dues where id=r.dues_id for update;
 select * into receipt from public.venmo_receipts where transaction_id=trim(tx_key) for update;
 if not found or receipt.report_id is not null or receipt.gross_cents<>d.amount_cents or receipt.payment_date<>r.payment_date then raise exception 'Choose an unassigned receipt with matching amount and date'; end if;
 if d.paid then raise exception 'Dues already paid; reconcile before confirming'; end if;
 update public.manual_dues set paid=true,payment_date=receipt.payment_date,method='venmo',note='Venmo '||receipt.transaction_id,version=version+1,updated_by=auth.uid(),updated_at=now() where id=d.id;
 insert into public.manual_dues_history(dues_id,actor,action,snapshot) select d.id,auth.uid(),'venmo_confirmed',to_jsonb(m) from public.manual_dues m where id=d.id;
 update public.venmo_receipts set report_id=report_key where transaction_id=receipt.transaction_id;
 update public.venmo_reports set status='confirmed',reviewed_by=auth.uid(),reviewed_at=now(),review_note=coalesce(reason,'') where id=report_key;
end $$;
create function public.review_venmo(report_key uuid,tx_key text,decision text,reason text) returns void
language sql security invoker set search_path='' as $$select team_private.review_venmo(report_key,tx_key,decision,reason)$$;

revoke all on function team_private.report_venmo(uuid,date,text),public.report_venmo(uuid,date,text),team_private.import_venmo(jsonb),public.import_venmo(jsonb),team_private.review_venmo(uuid,text,text,text),public.review_venmo(uuid,text,text,text) from public,anon;
grant execute on function team_private.report_venmo(uuid,date,text),public.report_venmo(uuid,date,text),team_private.import_venmo(jsonb),public.import_venmo(jsonb),team_private.review_venmo(uuid,text,text,text),public.review_venmo(uuid,text,text,text) to authenticated;
-- Future dues use $50. Existing issued dues and support are preserved.
update public.team_documents set data=jsonb_set(data,'{monthly}','5000'::jsonb),version=version+1,updated_at=now() where key='dues' and data->>'monthly' is distinct from '5000';
notify pgrst,'reload schema';
