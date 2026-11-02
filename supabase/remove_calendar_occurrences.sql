-- Explicit administrator removal of materialized occurrences and their RSVPs.
create function public.remove_event_occurrences(event_key uuid,removal_scope text) returns integer
language plpgsql security invoker set search_path='' as $$
declare original public.team_events; affected integer;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
 if removal_scope is null or removal_scope not in ('one','month','remaining','series') then raise exception 'Choose which events to remove';end if;
 select * into original from public.team_events where id=event_key for update;
 if not found then raise exception 'Event no longer exists. Refresh the calendar.';end if;
 if removal_scope<>'one' and original.series_id is null then raise exception 'This event is not recurring';end if;
 delete from public.team_events where id=event_key or (series_id=original.series_id and (
 removal_scope='series' or (removal_scope='remaining' and date>=original.date) or
 (removal_scope='month' and date>=date_trunc('month',original.date)::date and date<(date_trunc('month',original.date)+interval '1 month')::date)));
 get diagnostics affected=row_count;return affected;
end$$;
revoke all on function public.remove_event_occurrences(uuid,text) from public,anon;
grant execute on function public.remove_event_occurrences(uuid,text) to authenticated;
