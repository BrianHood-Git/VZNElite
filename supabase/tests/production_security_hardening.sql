begin;
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','security-admin@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','security-parent@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','security-player@example.invalid',now()),
('44444444-4444-4444-8444-444444444444','security-coach@example.invalid',now()),
('55555555-5555-4555-8555-555555555555','security-pending@example.invalid',now());
insert into public.team_memberships values('11111111-1111-4111-8111-111111111111','administrator'),('22222222-2222-4222-8222-222222222222','parent'),('33333333-3333-4333-8333-333333333333','player'),('44444444-4444-4444-8444-444444444444','coach');
insert into public.team_players(id,display_name,billing_parent_id) values('aaaaaaaa-0000-4000-8000-000000000001','Security test player','22222222-2222-4222-8222-222222222222'),('aaaaaaaa-0000-4000-8000-000000000002','Other family test',null);
insert into public.family_links values('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001','parent'),('33333333-3333-4333-8333-333333333333','aaaaaaaa-0000-4000-8000-000000000001','player');
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$declare n integer;begin
update public.team_players set bio='Allowed family edit' where id='aaaaaaaa-0000-4000-8000-000000000001';get diagnostics n=row_count;if n<>1 then raise exception 'Own profile edit blocked';end if;
begin update public.team_players set billing_parent_id=null where id='aaaaaaaa-0000-4000-8000-000000000001';raise exception 'Billing owner bypass';exception when insufficient_privilege then null;end;
begin update public.team_players set roster_status='former' where id='aaaaaaaa-0000-4000-8000-000000000001';raise exception 'Roster status bypass';exception when insufficient_privilege then null;end;
update public.team_players set bio='Wrong family' where id='aaaaaaaa-0000-4000-8000-000000000002';get diagnostics n=row_count;if n<>0 then raise exception 'Cross-family edit bypass';end if;
begin perform public.manage_team_role(auth.uid(),'administrator',true);raise exception 'Self promotion bypass';exception when insufficient_privilege then null;end;
if exists(select 1 from public.team_documents where key='finances') or exists(select 1 from public.player_private_details) then raise exception 'Private information exposed';end if;
end$$;
insert into public.parent_consents(player_id,parent_id,version,payload,recorded_at) values('aaaaaaaa-0000-4000-8000-000000000001',auth.uid(),'security-test','{}','2099-01-01');
do $$begin if exists(select 1 from public.parent_consents where version='security-test' and recorded_at>now()+interval '1 minute') then raise exception 'Consent timestamp spoofed';end if;end$$;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
do $$begin
update public.team_players set bio='Allowed player edit' where id='aaaaaaaa-0000-4000-8000-000000000001';
begin update public.team_players set billing_parent_id=null where id='aaaaaaaa-0000-4000-8000-000000000001';raise exception 'Player billing bypass';exception when insufficient_privilege then null;end;
begin insert into public.parent_consents(player_id,parent_id,version,payload) values('aaaaaaaa-0000-4000-8000-000000000001',auth.uid(),'security-test','{}');raise exception 'Player submitted parent consent';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
do $$begin
update public.team_players set position='Point Guard' where id='aaaaaaaa-0000-4000-8000-000000000001';
begin update public.team_players set billing_parent_id=null where id='aaaaaaaa-0000-4000-8000-000000000001';raise exception 'Coach billing bypass';exception when insufficient_privilege then null;end;
if exists(select 1 from public.team_documents where key='finances') then raise exception 'Coach finance access bypass';end if;
end$$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.admin_assign_guardian('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
do $$begin if exists(select 1 from public.team_players) or exists(select 1 from public.team_events) then raise exception 'Unapproved account accessed team data';end if;end$$;
reset role;
set local role anon;
do $$begin
if has_table_privilege('anon','public.team_players','select') or has_table_privilege('anon','public.player_private_details','select') then raise exception 'Anonymous table privileges';end if;
end$$;
rollback;
