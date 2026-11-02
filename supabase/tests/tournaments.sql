begin;
do $test$ declare admin_id uuid:=gen_random_uuid();parent_id uuid:=gen_random_uuid();coach_id uuid:=gen_random_uuid();begin
insert into auth.users(id,email,email_confirmed_at) values(admin_id,admin_id||'@example.invalid',now()),(parent_id,parent_id||'@example.invalid',now()),(coach_id,coach_id||'@example.invalid',now());
insert into public.team_memberships values(admin_id,'administrator'),(parent_id,'parent'),(coach_id,'coach');
perform set_config('request.jwt.claim.sub',admin_id::text,true);set local role authenticated;
insert into public.team_tournaments(name,cost_cents,paid_cents) values('Tournament QA',10000,5000);
update public.team_tournaments set paid_cents=10000 where name='Tournament QA';
if not exists(select 1 from public.team_tournaments where name='Tournament QA' and paid_cents=10000) then raise exception 'Admin save failed';end if;
begin insert into public.team_tournaments(name,cost_cents,paid_cents) values('Invalid QA',100,200);raise exception 'Overpayment allowed';exception when check_violation then null;end;
perform set_config('request.jwt.claim.sub',parent_id::text,true);
if exists(select 1 from public.team_tournaments) then raise exception 'Parent can read tournament records';end if;
begin insert into public.team_tournaments(name) values('Unauthorized QA');raise exception 'Parent can write';exception when insufficient_privilege then null;end;
update public.team_tournaments set name='Unauthorized change';
if found then raise exception 'Parent can update';end if;
perform set_config('request.jwt.claim.sub',coach_id::text,true);
if exists(select 1 from public.team_tournaments) then raise exception 'Coach can read admin contacts';end if;
reset role;
end $test$;
rollback;
