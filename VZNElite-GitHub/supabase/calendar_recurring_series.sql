alter table public.team_events add column series_id uuid;
create index on public.team_events(series_id,date);
create function public.update_event_occurrences(event_id uuid,remaining boolean,event_title text,event_type text,event_time time,event_location text,is_cancelled boolean) returns integer language plpgsql security invoker set search_path='' as $$declare original public.team_events; affected integer;begin
if auth.uid() is null or not (team_private.has_role('administrator') or team_private.has_role('coach')) then raise exception 'Staff access required' using errcode='42501';end if;
select * into original from public.team_events where id=event_id for update;if not found then raise exception 'Event not found';end if;
if remaining and original.series_id is null then raise exception 'This event is not part of a series';end if;
update public.team_events set title=event_title,type=event_type,time=event_time,location=event_location,cancelled=is_cancelled where id=event_id or (remaining and series_id=original.series_id and date>=original.date);
get diagnostics affected=row_count;return affected;end$$;
revoke all on function public.update_event_occurrences(uuid,boolean,text,text,time,text,boolean) from public,anon;
grant execute on function public.update_event_occurrences(uuid,boolean,text,text,time,text,boolean) to authenticated;
