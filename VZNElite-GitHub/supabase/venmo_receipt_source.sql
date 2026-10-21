create or replace function team_private.import_venmo(receipts jsonb) returns integer
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
