begin;
create temporary table desk_context as select
 (select user_id from public.team_memberships where role='administrator' limit 1) admin_id,
 l.user_id parent_id,l.player_id,gen_random_uuid() payment_id,gen_random_uuid() optional_id
 from public.family_links l join public.team_memberships m on m.user_id=l.user_id and m.role='parent'
 join public.team_players p on p.id=l.player_id and p.roster_status='active' and p.billing_parent_id=l.user_id
 where not exists(select 1 from public.team_memberships a where a.user_id=l.user_id and a.role='administrator') limit 1;
do $$begin if not exists(select 1 from desk_context where admin_id is not null) then raise exception 'No testable admin/parent';end if;end$$;
grant select on desk_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from desk_context),true);
do $$begin
 begin perform public.save_player_support((select player_id from desk_context),'2097-01-01','full','',1);raise exception 'Parent changed support';exception when insufficient_privilege then null;end;
 begin perform public.record_player_contribution(gen_random_uuid(),(select player_id from desk_context),'2097-01-01','voluntary',1000,current_date,'cash','Test','','',1,null,false);raise exception 'Parent recorded money';exception when insufficient_privilege then null;end;
 if has_function_privilege('anon','public.save_player_support(uuid,date,text,text,integer)','EXECUTE') then raise exception 'Anonymous support RPC';end if;
 if has_table_privilege('authenticated','public.player_contributions','INSERT') then raise exception 'Direct writes exposed';end if;
 if exists(select 1 from public.player_contributions) then raise exception 'Parent saw admin receipts';end if;
end$$;
select set_config('request.jwt.claim.sub',(select admin_id::text from desk_context),true);
do $$declare p uuid; pay uuid; optional uuid; v integer; d public.manual_dues; result uuid; amount integer; paid_date date:=(now() at time zone 'America/Chicago')::date; support_before jsonb; begin
 select player_id,payment_id,optional_id into p,pay,optional from desk_context;
 select version into v from public.team_documents where key='dues';
 perform public.save_player_support(p,'2097-01-01','half','Rollback fixture',v);
 select version,(data->>'monthly')::integer into v,amount from public.team_documents where key='dues';
 amount:=amount-amount/2;
 begin perform public.record_player_contribution(pay,p,'2097-01-01','dues',amount,paid_date,'cash','Rollback fixture','','',v,null,false);raise exception 'Unverified payment accepted';exception when raise_exception then if sqlerrm not like 'Confirm the full monthly%' then raise;end if;end;
 result:=public.record_player_contribution(pay,p,'2097-01-01','dues',amount,paid_date,'cash','Rollback fixture','','',v,null,true);
 if result<>pay then raise exception 'Wrong idempotency ID';end if;
 select * into d from public.manual_dues where player_id=p and period='2097-01-01';
 if not d.paid or d.amount_cents<>amount then raise exception 'Half support payment incorrect';end if;
 result:=public.record_player_contribution(pay,p,'2097-01-01','dues',amount,paid_date,'cash','Rollback fixture','','',v,null,true);
 if (select count(*) from public.player_contributions where id=pay)<>1 then raise exception 'Duplicate money';end if;
 begin perform public.set_manual_dues_payment(d.id,d.version,false,null,null,'Legacy reopen');raise exception 'Reopened without void';exception when raise_exception then if sqlerrm not like 'Void the linked player receipt%' then raise;end if;end;
 select data->'support' into support_before from public.team_documents where key='dues';
 perform public.record_player_contribution(optional,p,'2097-01-01','voluntary',1000,paid_date,'venmo','Rollback fixture','TEST-DESK-VOLUNTARY','',v,d.version,false);
 if (select data->'support' from public.team_documents where key='dues') is distinct from support_before then raise exception 'Optional altered support';end if;
 begin perform public.import_venmo(jsonb_build_array(jsonb_build_object('transaction_id','TEST-DESK-VOLUNTARY','payment_date',paid_date,'gross_cents',1000,'fee_cents',0,'sender','Rollback fixture','note','')));raise exception 'Duplicate Venmo import accepted';exception when raise_exception then if sqlerrm not like 'Venmo reference already recorded%' then raise;end if;end;
 perform public.void_player_contribution(pay,'Test correction');
 if (select paid from public.manual_dues where id=d.id) then raise exception 'Void did not reopen dues';end if;
 if (select sum(net_cents) from public.player_contributions where player_id=p and period='2097-01-01' and voided_at is null)<>1000 then raise exception 'Voided cash still counted';end if;
 select version into v from public.team_documents where key='dues';
 perform public.save_player_support(p,'2097-01-01','full','Rollback full support',v);
 select * into d from public.manual_dues where id=d.id;
 select version into v from public.team_documents where key='dues';
 begin perform public.record_player_contribution(gen_random_uuid(),p,'2097-01-01','dues',100,paid_date,'cash','Rollback fixture','','',v,d.version,true);raise exception 'Sponsored dues paid again';exception when raise_exception then if sqlerrm not like 'This month is already paid or fully sponsored%' then raise;end if;end;
 perform public.record_player_contribution(gen_random_uuid(),p,'2097-01-01','voluntary',4699,paid_date,'venmo','Rollback fixture','','Net-only voluntary gift',v,d.version,false);
 if not (select (data->'support'->p::text->>'full')::boolean from public.team_documents where key='dues') then raise exception 'Full support removed by gift';end if;
end$$;
reset role;
rollback;
select 'Player desk authorization, half/full support, payments, gifts, replay, duplicate prevention and corrections passed; fixtures rolled back' result;
