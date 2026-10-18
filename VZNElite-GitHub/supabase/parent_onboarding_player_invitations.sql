alter table public.team_players add column roster_status text not null default 'active' check(roster_status in ('active','former'));
alter table public.team_players add column billing_parent_id uuid references auth.users(id);
create index on public.team_players(billing_parent_id);
revoke update on public.team_players from authenticated;
grant update(display_name,jersey_number,position,bio) on public.team_players to authenticated;
create table public.player_requests(id uuid primary key default gen_random_uuid(),requested_by uuid not null default auth.uid() references auth.users(id),child_name text not null check(length(trim(child_name)) between 1 and 100),jersey_number text not null default '' check(length(jersey_number)<=3),position text not null default '' check(length(position)<=60),bio text not null default '' check(length(bio)<=1000),request_kind text not null check(request_kind in ('new','existing')),status text not null default 'pending' check(status in ('pending','approved','declined')),resolved_player_id uuid references public.team_players(id),created_at timestamptz not null default now(),reviewed_by uuid references auth.users(id));
create index on public.player_requests(requested_by);create index on public.player_requests(resolved_player_id);create index on public.player_requests(reviewed_by);
alter table public.player_requests enable row level security;
revoke all on public.player_requests from anon,authenticated;grant select,insert on public.player_requests to authenticated;
create policy request_read on public.player_requests for select to authenticated using(requested_by=(select auth.uid()) or (select team_private.has_role('administrator')) or (select team_private.has_role('coach')));
create policy request_insert on public.player_requests for insert to authenticated with check(requested_by=(select auth.uid()) and status='pending' and resolved_player_id is null and reviewed_by is null and (select auth.jwt()->>'email') is not null and exists(select 1 from auth.users where false));
drop policy request_insert on public.player_requests;
create function team_private.submit_player_request(child_name text,jersey_number text,p_position text,bio text,request_kind text) returns uuid language plpgsql security definer set search_path='' as $$declare result uuid;begin
if auth.uid() is null or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then raise exception 'Verify your email first' using errcode='42501';end if;
if (select count(*) from public.player_requests where requested_by=auth.uid() and status='pending')>=10 then raise exception 'Please wait for staff to review your pending requests';end if;
insert into public.player_requests(requested_by,child_name,jersey_number,position,bio,request_kind) values(auth.uid(),trim(child_name),trim(jersey_number),trim(p_position),trim(bio),request_kind) returning id into result;return result;end$$;
create function team_private.review_player_request(request_id uuid,approve boolean,existing_player uuid default null) returns uuid language plpgsql security definer set search_path='' as $$declare r public.player_requests;p uuid;begin
if auth.uid() is null or not (team_private.has_role('administrator') or team_private.has_role('coach')) then raise exception 'Staff access required' using errcode='42501';end if;
select * into r from public.player_requests where id=request_id for update;if not found or r.status<>'pending' then raise exception 'Request is no longer pending';end if;
if approve then
 if existing_player is not null then select id into p from public.team_players where id=existing_player and roster_status='active' for update;if p is null then raise exception 'Select an active player';end if;
 elsif r.request_kind='existing' then raise exception 'Match this request to an existing player';
 else insert into public.team_players(display_name,jersey_number,position,bio,billing_parent_id) values(r.child_name,r.jersey_number,r.position,r.bio,r.requested_by) returning id into p;end if;
 insert into public.team_memberships values(r.requested_by,'parent') on conflict do nothing;
 insert into public.family_links values(r.requested_by,p,'parent') on conflict(user_id,player_id) do update set relationship='parent';
 update public.team_players set billing_parent_id=coalesce(billing_parent_id,r.requested_by) where id=p;
end if;
update public.player_requests set status=case when approve then 'approved' else 'declined' end,resolved_player_id=p,reviewed_by=auth.uid() where id=request_id;
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'player_requests',case when approve then 'APPROVE' else 'DECLINE' end);
return p;end$$;
create function team_private.set_roster_status(p uuid,new_status text) returns void language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null or not (team_private.has_role('administrator') or team_private.has_role('coach')) then raise exception 'Staff access required' using errcode='42501';end if;
if new_status not in ('active','former') then raise exception 'Invalid status';end if;
update public.team_players set roster_status=new_status where id=p;
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'team_players',new_status);end$$;
create table public.player_invitations(id uuid primary key default gen_random_uuid(),player_id uuid not null references public.team_players(id),invited_by uuid not null references auth.users(id),email text not null check(length(email)<=254),created_at timestamptz not null default now(),expires_at timestamptz not null default now()+interval '7 days',accepted_by uuid references auth.users(id),revoked boolean not null default false);
create index on public.player_invitations(player_id);create index on public.player_invitations(invited_by);create index on public.player_invitations(accepted_by);
alter table public.player_invitations enable row level security;
revoke all on public.player_invitations from anon,authenticated;grant select on public.player_invitations to authenticated;
create policy invitation_read on public.player_invitations for select to authenticated using(invited_by=(select auth.uid()) or email=lower((select auth.jwt()->>'email')) or (select team_private.has_role('administrator')));
create function team_private.create_player_invitation(p uuid,target_email text) returns uuid language plpgsql security definer set search_path='' as $$declare result uuid;begin
if auth.uid() is null or not (team_private.has_role('administrator') or team_private.linked(p,true)) then raise exception 'Only a linked guardian or administrator can invite a player' using errcode='42501';end if;
if not exists(select 1 from public.team_players where id=p and roster_status='active') then raise exception 'Player must be active';end if;
target_email:=lower(trim(target_email));if target_email !~ '^[^ @]+@[^ @]+\.[^ @]+$' or length(target_email)>254 then raise exception 'Enter a valid email';end if;
if target_email=(select lower(email) from auth.users where id=auth.uid()) then raise exception 'Use the player email, not your own';end if;
if (select count(*) from public.player_invitations where invited_by=auth.uid() and created_at>now()-interval '1 hour')>=10 then raise exception 'Invitation limit reached; try again later';end if;
insert into public.player_invitations(player_id,invited_by,email) values(p,auth.uid(),target_email) returning id into result;return result;end$$;
create function team_private.accept_player_invitation(invitation_id uuid) returns void language plpgsql security definer set search_path='' as $$declare i public.player_invitations;verified_email text;begin
select lower(email) into verified_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
if verified_email is null then raise exception 'Verify the invited email first' using errcode='42501';end if;
select * into i from public.player_invitations where id=invitation_id for update;
if not found or i.revoked or i.accepted_by is not null or i.expires_at<now() or i.email<>verified_email then raise exception 'Invitation is unavailable for this account' using errcode='42501';end if;
if not exists(select 1 from public.team_players where id=i.player_id and roster_status='active') then raise exception 'Player is no longer active';end if;
if exists(select 1 from public.family_links where user_id=auth.uid() and player_id=i.player_id and relationship='parent') then raise exception 'This account already manages this player as a parent';end if;
insert into public.team_memberships values(auth.uid(),'player') on conflict do nothing;
insert into public.family_links values(auth.uid(),i.player_id,'player') on conflict(user_id,player_id) do update set relationship='player';
update public.player_invitations set accepted_by=auth.uid() where id=invitation_id;
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'player_invitations','ACCEPT');end$$;
create function team_private.revoke_player_invitation(invitation_id uuid) returns void language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null then raise exception 'Sign in first';end if;
update public.player_invitations set revoked=true where id=invitation_id and accepted_by is null and (invited_by=auth.uid() or team_private.has_role('administrator'));end$$;

revoke all on function team_private.submit_player_request(text,text,text,text,text) from public;
grant execute on function team_private.submit_player_request(text,text,text,text,text) to authenticated;
create function public.submit_player_request(child_name text,jersey_number text,p_position text,bio text,request_kind text) returns uuid language sql security invoker set search_path='' as $$ select team_private.submit_player_request(child_name,jersey_number,p_position,bio,request_kind) $$;
revoke all on function public.submit_player_request(text,text,text,text,text) from public,anon;
grant execute on function public.submit_player_request(text,text,text,text,text) to authenticated;
revoke all on function team_private.review_player_request(uuid,boolean,uuid) from public;
grant execute on function team_private.review_player_request(uuid,boolean,uuid) to authenticated;
create function public.review_player_request(request_id uuid,approve boolean,existing_player uuid default null) returns uuid language sql security invoker set search_path='' as $$ select team_private.review_player_request(request_id,approve,existing_player) $$;
revoke all on function public.review_player_request(uuid,boolean,uuid) from public,anon;
grant execute on function public.review_player_request(uuid,boolean,uuid) to authenticated;
revoke all on function team_private.set_roster_status(uuid,text) from public;
grant execute on function team_private.set_roster_status(uuid,text) to authenticated;
create function public.set_roster_status(p uuid,new_status text) returns void language sql security invoker set search_path='' as $$ select team_private.set_roster_status(p,new_status) $$;
revoke all on function public.set_roster_status(uuid,text) from public,anon;
grant execute on function public.set_roster_status(uuid,text) to authenticated;
revoke all on function team_private.create_player_invitation(uuid,text) from public;
grant execute on function team_private.create_player_invitation(uuid,text) to authenticated;
create function public.create_player_invitation(p uuid,target_email text) returns uuid language sql security invoker set search_path='' as $$ select team_private.create_player_invitation(p,target_email) $$;
revoke all on function public.create_player_invitation(uuid,text) from public,anon;
grant execute on function public.create_player_invitation(uuid,text) to authenticated;
revoke all on function team_private.accept_player_invitation(uuid) from public;
grant execute on function team_private.accept_player_invitation(uuid) to authenticated;
create function public.accept_player_invitation(invitation_id uuid) returns void language sql security invoker set search_path='' as $$ select team_private.accept_player_invitation(invitation_id) $$;
revoke all on function public.accept_player_invitation(uuid) from public,anon;
grant execute on function public.accept_player_invitation(uuid) to authenticated;
revoke all on function team_private.revoke_player_invitation(uuid) from public;
grant execute on function team_private.revoke_player_invitation(uuid) to authenticated;
create function public.revoke_player_invitation(invitation_id uuid) returns void language sql security invoker set search_path='' as $$ select team_private.revoke_player_invitation(invitation_id) $$;
revoke all on function public.revoke_player_invitation(uuid) from public,anon;
grant execute on function public.revoke_player_invitation(uuid) to authenticated;

