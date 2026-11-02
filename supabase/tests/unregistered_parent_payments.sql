begin;
create temporary table offline_context as select gen_random_uuid() player_id,null::uuid dues_id,
 (select user_id from public.team_memberships where role='administrator' limit 1) admin_id,
 (select user_id from public.team_memberships m where role='parent' and not exists(select 1 from public.team_memberships a where a.user_id=m.user_id and a.role='administrator') limit 1) parent_id;
insert into public.team_players(id,display_name,roster_status) select player_id,'Rollback unregistered payer test','active' from offline_context;
grant select on offline_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select admin_id::text from offline_context),true);
do $$declare p uuid; receipt uuid:=gen_random_uuid(); version integer; amount integer; d public.manual_dues; begin
 select player_id into p from offline_context;
 select t.version,(t.data->>'monthly')::integer into version,amount from public.team_documents t where key='dues';
 perform public.record_player_contribution(receipt,p,'2096-01-01','dues',amount,(now() at time zone 'America/Chicago')::date,'cash','Unregistered fixture parent','','Rollback only',version,null,true);
 select * into d from public.manual_dues where player_id=p and period='2096-01-01';
 if not d.paid or d.payer_id is not null then raise exception 'Offline payment needs fake parent account';end if;
 if not exists(select 1 from public.player_contributions where id=receipt and payer_name='Unregistered fixture parent' and net_cents=amount and dues_id=d.id) then raise exception 'Missing finance receipt';end if;
 perform public.void_player_contribution(receipt,'Rollback correction');
 if (select paid from public.manual_dues where id=d.id) then raise exception 'Offline correction failed';end if;
end$$;
select set_config('request.jwt.claim.sub',(select parent_id::text from offline_context),true);
do $$begin
 if exists(select 1 from public.manual_dues where player_id=(select player_id from offline_context)) then raise exception 'Unrelated parent saw offline dues';end if;
 begin perform public.create_manual_dues((select player_id from offline_context),'2096-02-01');raise exception 'Parent created offline dues';exception when insufficient_privilege then null;end;
end$$;
reset role;
update offline_context c set dues_id=(select id from public.manual_dues where player_id=c.player_id);
-- Even a linked parent cannot claim unassigned historical dues by guessing an ID.
insert into public.family_links(user_id,player_id,relationship) select parent_id,player_id,'parent' from offline_context;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select parent_id::text from offline_context),true);
do $$begin
 begin perform public.report_venmo((select dues_id from offline_context),current_date,'fixture');raise exception 'Claimed unassigned dues';exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;
select 'Unregistered parent payment, finance receipt, correction and access isolation checks passed; all fixtures rolled back' result;
