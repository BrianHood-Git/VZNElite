create function team_private.admin_assign_guardian(parent_user uuid,p uuid,responsible boolean default false) returns void language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
if not exists(select 1 from auth.users where id=parent_user and email_confirmed_at is not null) then raise exception 'Parent must have a verified account';end if;
perform 1 from public.team_players where id=p for update;if not found then raise exception 'Player not found';end if;
if exists(select 1 from public.family_links where user_id=parent_user and player_id=p and relationship='player') then raise exception 'This account belongs to the player. Select a separate guardian account.';end if;
insert into public.team_memberships values(parent_user,'parent') on conflict do nothing;
insert into public.family_links values(parent_user,p,'parent') on conflict(user_id,player_id) do update set relationship='parent';
if responsible or (select billing_parent_id from public.team_players where id=p) is null then update public.team_players set billing_parent_id=parent_user where id=p;end if;
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'family_links','ASSIGN_GUARDIAN');end$$;
create function team_private.admin_unlink_guardian(parent_user uuid,p uuid) returns void language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
perform 1 from public.team_players where id=p for update;
if (select billing_parent_id from public.team_players where id=p)=parent_user then raise exception 'Assign another responsible billing parent before removing this link';end if;
delete from public.family_links where user_id=parent_user and player_id=p and relationship='parent';
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'family_links','UNLINK_GUARDIAN');end$$;
revoke all on function team_private.admin_assign_guardian(uuid,uuid,boolean),team_private.admin_unlink_guardian(uuid,uuid) from public;
grant execute on function team_private.admin_assign_guardian(uuid,uuid,boolean),team_private.admin_unlink_guardian(uuid,uuid) to authenticated;
create function public.admin_assign_guardian(parent_user uuid,p uuid,responsible boolean default false) returns void language sql security invoker set search_path='' as $$ select team_private.admin_assign_guardian(parent_user,p,responsible) $$;
create function public.admin_unlink_guardian(parent_user uuid,p uuid) returns void language sql security invoker set search_path='' as $$ select team_private.admin_unlink_guardian(parent_user,p) $$;
revoke all on function public.admin_assign_guardian(uuid,uuid,boolean),public.admin_unlink_guardian(uuid,uuid) from public,anon;
grant execute on function public.admin_assign_guardian(uuid,uuid,boolean),public.admin_unlink_guardian(uuid,uuid) to authenticated;
