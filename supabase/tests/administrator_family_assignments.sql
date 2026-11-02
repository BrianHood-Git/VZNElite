begin;
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','directory-admin@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','directory-parent@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','directory-guardian@example.invalid',now());
insert into public.team_memberships values('11111111-1111-4111-8111-111111111111','administrator');
insert into public.team_players(id,display_name) values('aaaaaaaa-0000-4000-8000-000000000001','Directory test');
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$begin begin perform public.admin_assign_guardian(auth.uid(),'aaaaaaaa-0000-4000-8000-000000000001',true);raise exception 'Parent assigned guardian';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.admin_assign_guardian('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001',true);
select public.admin_assign_guardian('33333333-3333-4333-8333-333333333333','aaaaaaaa-0000-4000-8000-000000000001',false);
do $$begin
if (select billing_parent_id from public.team_players where id='aaaaaaaa-0000-4000-8000-000000000001')<>'22222222-2222-4222-8222-222222222222'::uuid then raise exception 'Additional guardian changed billing';end if;
begin perform public.admin_unlink_guardian('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001');raise exception 'Billing owner was unlinked';exception when raise_exception then if sqlerrm<>'Assign another responsible billing parent before removing this link' then raise;end if;end;
end$$;
select public.admin_assign_guardian('33333333-3333-4333-8333-333333333333','aaaaaaaa-0000-4000-8000-000000000001',true);
select public.admin_unlink_guardian('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001');
rollback;
