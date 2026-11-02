CREATE OR REPLACE FUNCTION team_private.review_player_request(request_id uuid, approve boolean, existing_player uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$declare r public.player_requests;p uuid;begin
if auth.uid() is null or not (team_private.has_role('administrator') or team_private.has_role('coach')) then raise exception 'Staff access required' using errcode='42501';end if;
select * into r from public.player_requests where id=request_id for update;if not found or r.status<>'pending' then raise exception 'Request is no longer pending';end if;
if approve then
 if existing_player is not null then select id into p from public.team_players where id=existing_player and roster_status='active' for update;if p is null then raise exception 'Select an active player';end if;
 
 else insert into public.team_players(display_name,jersey_number,position,bio,billing_parent_id) values(r.child_name,r.jersey_number,r.position,r.bio,r.requested_by) returning id into p;end if;
 insert into public.team_memberships values(r.requested_by,'parent') on conflict do nothing;
 insert into public.family_links values(r.requested_by,p,'parent') on conflict(user_id,player_id) do update set relationship='parent';
 update public.team_players set billing_parent_id=coalesce(billing_parent_id,r.requested_by) where id=p;
end if;
update public.player_requests set status=case when approve then 'approved' else 'declined' end,resolved_player_id=p,reviewed_by=auth.uid() where id=request_id;
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'player_requests',case when approve then 'APPROVE' else 'DECLINE' end);
return p;end$function$
