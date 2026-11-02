create or replace function team_private.admin_link_player_signup(player_user uuid,parent_user uuid,existing_player uuid default null,player_name text default null) returns uuid
language plpgsql security definer set search_path='' as $$declare p uuid; n text;begin
if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
perform 1 from auth.users where id=player_user and deleted_at is null and not coalesce(is_anonymous,false) for update;
if not found then raise exception 'Choose an existing player signup';end if;
if player_user=parent_user then raise exception 'Choose a separate parent account';end if;
if exists(select 1 from public.family_links where user_id=player_user) or exists(select 1 from public.team_memberships where user_id=player_user) then raise exception 'This account is already assigned. Refresh and review its existing access.';end if;
if not exists(select 1 from auth.users u join public.team_memberships m on m.user_id=u.id where u.id=parent_user and u.email_confirmed_at is not null and m.role='parent') then raise exception 'Choose a verified parent';end if;
if existing_player is null then
 n:=trim(player_name);if n is null or length(n) not between 1 and 100 then raise exception 'Enter the player name';end if;
 if exists(select 1 from public.team_players where lower(trim(display_name))=lower(n)) then raise exception 'A matching player exists. Select their existing roster profile.';end if;
 insert into public.team_players(display_name) values(n) returning id into p;
else
 select id into p from public.team_players where id=existing_player and roster_status='active' for update;
 if p is null then raise exception 'Choose an active roster profile';end if;
end if;
if exists(select 1 from public.family_links where player_id=p and relationship='player') then raise exception 'This roster profile already has a player login';end if;
perform team_private.admin_assign_guardian(parent_user,p,false);
insert into public.account_profiles(id,display_name) select u.id,coalesce(nullif(left(trim(u.raw_user_meta_data->>'display_name'),100),''),'Player') from auth.users u where u.id=player_user on conflict(id) do nothing;
insert into public.team_memberships values(player_user,'player');
insert into public.family_links values(player_user,p,'player');
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'family_links','LINK_PLAYER_SIGNUP');
return p;end$$;
