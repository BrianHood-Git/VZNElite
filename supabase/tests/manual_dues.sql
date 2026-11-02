begin;
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','dues-admin@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','dues-parent@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','dues-other@example.invalid',now());
insert into public.team_memberships values('11111111-1111-4111-8111-111111111111','administrator'),('22222222-2222-4222-8222-222222222222','parent'),('33333333-3333-4333-8333-333333333333','coach');
insert into public.team_players(id,display_name,billing_parent_id) values('aaaaaaaa-0000-4000-8000-000000000001','Manual dues test','22222222-2222-4222-8222-222222222222');
insert into public.family_links values('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001','parent');
update public.team_documents set data=jsonb_build_object('monthly',12500,'support',jsonb_build_object('aaaaaaaa-0000-4000-8000-000000000001',jsonb_build_object('amount',2500,'full',false))) where key='dues';
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.create_manual_dues('aaaaaaaa-0000-4000-8000-000000000001','2026-10-01');
do $$declare r public.manual_dues;begin
select * into r from public.manual_dues where player_id='aaaaaaaa-0000-4000-8000-000000000001';
if r.amount_cents<>10000 then raise exception 'Support calculation failed';end if;
begin perform public.create_manual_dues(r.player_id,r.period);raise exception 'Duplicate accepted';exception when raise_exception then if sqlerrm<>'Dues already recorded for this player and month' then raise;end if;end;
perform public.set_manual_dues_payment(r.id,1,true,(now() at time zone 'America/Chicago')::date,'cash','Test receipt');
begin perform public.set_manual_dues_payment(r.id,1,false,null,null,'Mistake');raise exception 'Stale update accepted';exception when raise_exception then if sqlerrm<>'This record changed. Refresh before saving.' then raise;end if;end;
begin perform public.set_manual_dues_payment(r.id,2,false,null,null,'');raise exception 'Missing correction reason accepted';exception when raise_exception then if sqlerrm<>'Enter a reason for reopening dues' then raise;end if;end;
perform public.set_manual_dues_payment(r.id,2,false,null,null,'Incorrect receipt');
if (select count(*) from public.manual_dues_history where dues_id=r.id)<>3 then raise exception 'History lost';end if;
end$$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$declare r public.manual_dues;begin
select * into r from public.manual_dues where player_id='aaaaaaaa-0000-4000-8000-000000000001';if r.id is null then raise exception 'Parent cannot see dues';end if;
begin perform public.set_manual_dues_payment(r.id,3,true,current_date,'cash','');raise exception 'Parent changed payment';exception when insufficient_privilege then null;end;
if exists(select 1 from public.manual_dues_history) then raise exception 'Parent accessed administrator history';end if;
end$$;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
do $$begin
if exists(select 1 from public.manual_dues) then raise exception 'Coach accessed family dues';end if;
begin perform public.create_manual_dues('aaaaaaaa-0000-4000-8000-000000000001','2026-11-01');raise exception 'Coach created dues';exception when insufficient_privilege then null;end;
end$$;
rollback;
