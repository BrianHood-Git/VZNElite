alter function public.manage_team_role(uuid,text,boolean) set schema team_private;
create function public.manage_team_role(target_user uuid,wanted_role text,grant_role boolean) returns void language sql security invoker set search_path='' as $$ select team_private.manage_team_role(target_user,wanted_role,grant_role) $$;
revoke all on function public.manage_team_role(uuid,text,boolean) from public,anon;
grant execute on function public.manage_team_role(uuid,text,boolean) to authenticated;
