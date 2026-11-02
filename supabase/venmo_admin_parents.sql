create or replace function team_private.report_venmo(dues_key uuid,paid_on date,venmo_reference text) returns uuid
language plpgsql security definer set search_path='' as $$
declare d public.manual_dues; result uuid;
begin
 if auth.uid() is null or (not team_private.has_role('parent') and not team_private.has_role('administrator')) then raise exception 'Parent access required' using errcode='42501'; end if;
 select * into d from public.manual_dues where id=dues_key for update;
 if not found or d.payer_id<>auth.uid() or not exists(select 1 from public.family_links where player_id=d.player_id and user_id=auth.uid() and relationship='parent') then raise exception 'Not your dues record' using errcode='42501'; end if;
 if d.paid or d.amount_cents=0 then raise exception 'Dues are already paid or covered'; end if;
 if paid_on is null or paid_on>(now() at time zone 'America/Chicago')::date or length(trim(coalesce(venmo_reference,''))) not between 1 and 120 then raise exception 'Enter a valid date and Venmo reference'; end if;
 insert into public.venmo_reports(dues_id,parent_id,payment_date,reference) values(dues_key,auth.uid(),paid_on,trim(venmo_reference)) returning id into result;
 return result;
end $$;
