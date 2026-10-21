-- Integration assertions use real member IDs but roll back ALL fixtures.
begin;
create temporary table venmo_test_context as
 select (select user_id from public.team_memberships where role='administrator' limit 1) as admin_id,
 l.user_id as parent_id,l.player_id,gen_random_uuid() as dues_id
 from public.family_links l join public.team_memberships m on m.user_id=l.user_id and m.role='parent'
 where not exists(select 1 from public.team_memberships a where a.user_id=l.user_id and a.role='administrator')
 limit 1;
do $$begin if not exists(select 1 from venmo_test_context where admin_id is not null) then raise exception 'No testable family/admin relationship'; end if; end$$;
grant select on venmo_test_context to authenticated;
insert into public.manual_dues(id,player_id,payer_id,period,amount_cents,created_by,updated_by)
 select dues_id,player_id,parent_id,'2099-01-01',5000,admin_id,admin_id from venmo_test_context;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from venmo_test_context),true);
do $$declare d uuid; r uuid;begin
 select dues_id into d from venmo_test_context;
 r:=public.report_venmo(d,'2026-10-20','TEST-VENMO-ROLLBACK');
 if (select paid from public.manual_dues where id=d) then raise exception 'Reporting marked dues paid'; end if;
 if (select status from public.venmo_reports where id=r)<>'pending' then raise exception 'Report not pending'; end if;
 begin perform public.import_venmo('[]');raise exception 'Parent imported receipts';exception when insufficient_privilege then null;end;
 begin perform public.review_venmo(r,'TEST-VENMO-ROLLBACK','confirm','');raise exception 'Parent confirmed';exception when insufficient_privilege then null;end;
 begin update public.manual_dues set paid=true where id=d;raise exception 'Parent changed paid status';exception when insufficient_privilege then null;end;
 if has_table_privilege('authenticated','public.venmo_reports','INSERT') or has_table_privilege('authenticated','public.venmo_receipts','INSERT') then raise exception 'Direct writes exposed';end if;
 if has_function_privilege('anon','public.import_venmo(jsonb)','EXECUTE') or has_function_privilege('anon','public.report_venmo(uuid,date,text)','EXECUTE') then raise exception 'Anonymous RPC exposed';end if;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000000',true);
do $$begin
 if exists(select 1 from public.venmo_reports) then raise exception 'Unrelated account saw reports';end if;
 if exists(select 1 from public.venmo_receipts) then raise exception 'Unrelated account saw receipts';end if;
 begin perform public.report_venmo((select dues_id from venmo_test_context),'2026-10-20','bad');raise exception 'Unrelated account reported';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub',(select admin_id::text from venmo_test_context),true);
do $$declare r uuid; n integer; payload jsonb:='[{"transaction_id":"TEST-VENMO-ROLLBACK","payment_date":"2026-10-20","gross_cents":5000,"fee_cents":105,"sender":"Rollback test","note":"Fixture only"}]';begin
 n:=public.import_venmo(payload);if n<>1 then raise exception 'Receipt not imported';end if;
 n:=public.import_venmo(payload);if n<>0 then raise exception 'Duplicate counted';end if;
 select id into r from public.venmo_reports where dues_id=(select dues_id from venmo_test_context);
 perform public.review_venmo(r,'TEST-VENMO-ROLLBACK','confirm','Verified fixture');
 if not (select paid from public.manual_dues where id=(select dues_id from venmo_test_context)) then raise exception 'Confirmation did not pay dues';end if;
 if (select status from public.venmo_reports where id=r)<>'confirmed' then raise exception 'Report not confirmed';end if;
 if (select sum(gross_cents-fee_cents) from public.venmo_receipts where transaction_id='TEST-VENMO-ROLLBACK')<>4895 then raise exception 'Wrong net';end if;
 n:=public.import_venmo(payload);if n<>0 then raise exception 'Matching created duplicate income';end if;
 begin perform public.import_venmo(jsonb_set(payload,'{0,gross_cents}','5100'));raise exception 'Conflicting duplicate accepted';exception when raise_exception then if sqlerrm not like 'Conflicting data%' then raise;end if;end;
 begin perform public.review_venmo(r,'TEST-VENMO-ROLLBACK','confirm','');raise exception 'Double confirmation accepted';exception when raise_exception then if sqlerrm<>'Report already reviewed' then raise;end if;end;
end$$;
reset role;
rollback;
select 'Venmo authorization, isolation, confirmation, replay, conflict, and net-ledger assertions passed; fixtures rolled back' as result;
