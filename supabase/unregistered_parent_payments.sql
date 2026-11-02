-- Admin-entered receipts identify the payer by name; no fabricated auth account.
alter table public.manual_dues alter column payer_id drop not null;
create or replace function team_private.create_manual_dues(p uuid,billing_month date) returns uuid language plpgsql security definer set search_path='' as $$
declare r public.team_players; d jsonb; s jsonb; cents integer; result uuid;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501';end if;
 if billing_month is null or extract(day from billing_month)<>1 then raise exception 'Choose a billing month';end if;
 select * into r from public.team_players where id=p for update;
 if not found or r.roster_status<>'active' then raise exception 'Choose an active player';end if;
 if r.billing_parent_id is not null and not exists(select 1 from public.family_links where user_id=r.billing_parent_id and player_id=p and relationship='parent') then raise exception 'Responsible parent must be linked to the player';end if;
 select data into d from public.team_documents where key='dues';if d is null then raise exception 'Configure team dues first';end if;
 s:=d->'support'->p::text;
 cents:=greatest(0,(d->>'monthly')::integer-case when coalesce((s->>'full')::boolean,false) then (d->>'monthly')::integer else least((d->>'monthly')::integer,coalesce((s->>'amount')::integer,0)) end);
 if exists(select 1 from public.manual_dues where player_id=p and period=billing_month) then raise exception 'Dues already recorded for this player and month';end if;
 insert into public.manual_dues(player_id,payer_id,period,amount_cents,created_by,updated_by) values(p,r.billing_parent_id,billing_month,cents,auth.uid(),auth.uid()) returning id into result;
 insert into public.manual_dues_history(dues_id,actor,action,snapshot) select result,auth.uid(),'created',to_jsonb(m) from public.manual_dues m where id=result;
 return result;
end$$;

-- Preserve the current report function and its role checks, but fail closed for unassigned dues.
do $migration$ declare definition text; begin
 definition:=pg_get_functiondef('team_private.report_venmo(uuid,date,text)'::regprocedure);
 if position('d.payer_id<>auth.uid()' in definition)=0 then raise exception 'Review report_venmo ownership check before upgrading';end if;
 execute replace(definition,'d.payer_id<>auth.uid()','d.payer_id is distinct from auth.uid()');
end $migration$;
notify pgrst,'reload schema';
