create function team_private.coach_player_dues() returns table(id uuid,player_id uuid,period date,amount_cents integer,paid boolean)
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not (team_private.has_role('coach') or team_private.has_role('administrator')) then raise exception 'Staff access required' using errcode='42501';end if;
 return query select d.id,d.player_id,d.period,d.amount_cents,d.paid from public.manual_dues d order by d.period desc;
end$$;
create function team_private.coach_tournament_contacts() returns table(id uuid,name text,event_date date,location text,contact_name text,contact_phone text)
language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null or not (team_private.has_role('coach') or team_private.has_role('administrator')) then raise exception 'Staff access required' using errcode='42501';end if;
 return query select t.id,t.name,t.event_date,t.location,t.contact_name,t.contact_phone from public.team_tournaments t where not t.archived order by t.event_date desc nulls last;
end$$;
revoke all on function team_private.coach_player_dues(),team_private.coach_tournament_contacts() from public,anon;
grant execute on function team_private.coach_player_dues(),team_private.coach_tournament_contacts() to authenticated;
create function public.coach_player_dues() returns table(id uuid,player_id uuid,period date,amount_cents integer,paid boolean) language sql security invoker set search_path='' as $$select * from team_private.coach_player_dues()$$;
create function public.coach_tournament_contacts() returns table(id uuid,name text,event_date date,location text,contact_name text,contact_phone text) language sql security invoker set search_path='' as $$select * from team_private.coach_tournament_contacts()$$;
revoke all on function public.coach_player_dues(),public.coach_tournament_contacts() from public,anon;
grant execute on function public.coach_player_dues(),public.coach_tournament_contacts() to authenticated;
