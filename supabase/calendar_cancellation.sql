create function public.set_event_cancellation(event_key uuid,event_scope text,cancel_event boolean) returns integer
language plpgsql security invoker set search_path='' as $$
declare original public.team_events; affected integer;
begin
 if auth.uid() is null or not (team_private.has_role('administrator') or team_private.has_role('coach')) then raise exception 'Staff access required' using errcode='42501';end if;
 if event_scope is null or event_scope not in ('one','month','remaining','series') or cancel_event is null then raise exception 'Choose a cancellation scope';end if;
 select * into original from public.team_events where id=event_key for update;
 if not found then raise exception 'Event no longer exists. Refresh the calendar.';end if;
 if event_scope<>'one' and original.series_id is null then raise exception 'This event is not recurring';end if;
 update public.team_events set cancelled=cancel_event where id=event_key or (series_id=original.series_id and (
 event_scope='series' or (event_scope='remaining' and date>=original.date) or
 (event_scope='month' and date>=date_trunc('month',original.date)::date and date<(date_trunc('month',original.date)+interval '1 month')::date)));
 get diagnostics affected=row_count;return affected;
end$$;
revoke all on function public.set_event_cancellation(uuid,text,boolean) from public,anon;
grant execute on function public.set_event_cancellation(uuid,text,boolean) to authenticated;
