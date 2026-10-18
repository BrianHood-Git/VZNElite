begin;
insert into auth.users(id,email,email_confirmed_at) values('11111111-1111-4111-8111-111111111111','calendar-coach@example.invalid',now()),('22222222-2222-4222-8222-222222222222','calendar-parent@example.invalid',now());
insert into public.team_memberships values('11111111-1111-4111-8111-111111111111','coach'),('22222222-2222-4222-8222-222222222222','parent');
insert into public.team_events(id,title,type,date,time,series_id) values('aaaaaaaa-0000-4000-8000-000000000001','Test practice','Practice','2026-10-01','18:00','aaaaaaaa-0000-4000-8000-000000000010'),('aaaaaaaa-0000-4000-8000-000000000002','Test practice','Practice','2026-10-08','18:00','aaaaaaaa-0000-4000-8000-000000000010'),('aaaaaaaa-0000-4000-8000-000000000003','Test practice','Practice','2026-10-15','18:00','aaaaaaaa-0000-4000-8000-000000000010');
set local role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$begin begin perform public.update_event_occurrences('aaaaaaaa-0000-4000-8000-000000000002',true,'Forbidden','Practice','19:00','Gym',true);raise exception 'Parent edited series';exception when insufficient_privilege then null;end;end$$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$declare n integer;begin
n:=public.update_event_occurrences('aaaaaaaa-0000-4000-8000-000000000002',true,'Changed','Practice','19:00','Gym',true);
if n<>2 then raise exception 'Incorrect series update count';end if;
if (select cancelled from public.team_events where id='aaaaaaaa-0000-4000-8000-000000000001') then raise exception 'Past occurrence changed';end if;
if not (select cancelled from public.team_events where id='aaaaaaaa-0000-4000-8000-000000000003') then raise exception 'Future occurrence unchanged';end if;
end$$;
rollback;
