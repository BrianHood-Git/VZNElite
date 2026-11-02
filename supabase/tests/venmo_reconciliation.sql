begin;
create temporary table reconcile_context as select
 (select user_id from public.team_memberships where role='administrator' limit 1) admin_id,
 l.user_id parent_id,l.player_id,gen_random_uuid() dues_id,
 (select data from public.team_documents where key='dues') sponsorship_before
 from public.family_links l join public.team_memberships m on m.user_id=l.user_id and m.role='parent'
 where not exists(select 1 from public.team_memberships a where a.user_id=l.user_id and a.role='administrator') limit 1;
do $$begin if not exists(select 1 from reconcile_context where admin_id is not null) then raise exception 'Missing fixture members'; end if; end$$;
grant select on reconcile_context to authenticated;
insert into public.manual_dues(id,player_id,payer_id,period,amount_cents,created_by,updated_by)
 select dues_id,player_id,parent_id,'2098-01-01',5000,admin_id,admin_id from reconcile_context;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from reconcile_context),true);
do $$begin
 begin perform public.reconcile_venmo('TEST-RECONCILE','voluntary',(select player_id from reconcile_context),null,'test');raise exception 'Parent reconciled';exception when insufficient_privilege then null;end;
 if has_function_privilege('anon','public.reconcile_venmo(text,text,uuid,uuid,text)','EXECUTE') then raise exception 'Anonymous access';end if;
end$$;
select set_config('request.jwt.claim.sub',(select admin_id::text from reconcile_context),true);
select public.import_venmo('[{"transaction_id":"TEST-RECONCILE","payment_date":"2026-10-20","gross_cents":5000,"fee_cents":105,"sender":"Rollback fixture","note":"Test only"},{"transaction_id":"TEST-VOLUNTARY","payment_date":"2026-10-20","gross_cents":4999,"fee_cents":100,"sender":"Rollback fixture","note":"Test only"}]');
do $$declare p uuid; d uuid;begin
 select player_id,dues_id into p,d from reconcile_context;
 begin perform public.reconcile_venmo('TEST-VOLUNTARY','dues',p,d,'Mismatch');raise exception 'Mismatch accepted';exception when raise_exception then if sqlerrm not like 'Gross payment%' then raise;end if;end;
 perform public.reconcile_venmo('TEST-RECONCILE','dues',p,d,'Verified test');
 if not (select paid from public.manual_dues where id=d) then raise exception 'Dues not paid';end if;
 begin perform public.reconcile_venmo('TEST-RECONCILE','voluntary',p,null,'Repeat');raise exception 'Replay accepted';exception when raise_exception then if sqlerrm not like 'Receipt already assigned%' then raise;end if;end;
 perform public.reconcile_venmo('TEST-VOLUNTARY','voluntary',p,null,'Voluntary test');
 if (select dues_id from public.venmo_receipts where transaction_id='TEST-VOLUNTARY') is not null then raise exception 'Voluntary paid dues';end if;
 if (select data from public.team_documents where key='dues') is distinct from (select sponsorship_before from reconcile_context) then raise exception 'Sponsorship altered';end if;
 if (select count(*) from public.venmo_reconciliation_history where transaction_id in ('TEST-RECONCILE','TEST-VOLUNTARY'))<>2 then raise exception 'Missing audit';end if;
end$$;
reset role;
rollback;
select 'Reconciliation assertions passed; all fixtures rolled back' result;
