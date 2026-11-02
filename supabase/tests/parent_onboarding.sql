begin;
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','onboarding-parent@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','onboarding-coach@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','onboarding-child@example.invalid',now()),
('44444444-4444-4444-8444-444444444444','onboarding-other@example.invalid',now());
insert into public.team_memberships values('22222222-2222-4222-8222-222222222222','coach');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.submit_player_request('Onboarding test','7','Guard','Test bio','new');
do $$begin
begin perform public.review_player_request((select id from public.player_requests where requested_by=auth.uid()),true,null);raise exception 'Parent approved own request';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select public.review_player_request((select id from public.player_requests where child_name='Onboarding test'),true,null);
do $$declare p uuid;begin
select id into p from public.team_players where display_name='Onboarding test';
if not exists(select 1 from public.family_links where player_id=p and user_id='11111111-1111-4111-8111-111111111111' and relationship='parent') then raise exception 'Parent not linked';end if;
if (select billing_parent_id from public.team_players where id=p)<>'11111111-1111-4111-8111-111111111111'::uuid then raise exception 'Billing parent not assigned';end if;
end$$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.create_player_invitation((select id from public.team_players where display_name='Onboarding test'),'onboarding-child@example.invalid');
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
do $$begin if exists(select 1 from public.player_requests) then raise exception 'Other pending user saw requests';end if;end$$;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select set_config('request.jwt.claims','{"email":"onboarding-child@example.invalid"}',true);
select public.accept_player_invitation((select id from public.player_invitations where email='onboarding-child@example.invalid'));
do $$declare p uuid;begin
select id into p from public.team_players where display_name='Onboarding test';
if not team_private.linked(p) then raise exception 'Player link failed';end if;
if team_private.linked(p,true) then raise exception 'Player received guardian rights';end if;
begin insert into public.parent_consents(player_id,version,payload) values(p,'test','{}');raise exception 'Player signed guardian consent';exception when insufficient_privilege then null;end;
begin update public.team_players set billing_parent_id=auth.uid() where id=p;raise exception 'Player changed billing owner';exception when insufficient_privilege then null;end;
end$$;
rollback;
