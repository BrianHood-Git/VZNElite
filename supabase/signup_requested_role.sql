-- Requested role is user-supplied information, never authorization.
create function team_private.account_signup_reviews() returns jsonb language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
return coalesce((select jsonb_agg(to_jsonb(s)||jsonb_build_object('requested_role',case when u.raw_user_meta_data->>'requested_role' in ('parent','player') then u.raw_user_meta_data->>'requested_role' else null end) order by s.created_at desc) from team_private.unlinked_signups() s join auth.users u on u.id=s.id),'[]'::jsonb);
end$$;
revoke all on function team_private.account_signup_reviews() from public,anon;
grant execute on function team_private.account_signup_reviews() to authenticated;
create function public.account_signup_reviews() returns jsonb language sql security invoker set search_path='' as $$select team_private.account_signup_reviews()$$;
revoke all on function public.account_signup_reviews() from public,anon;
grant execute on function public.account_signup_reviews() to authenticated;
