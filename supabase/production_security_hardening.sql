-- RLS controls which roster row can be edited; this controls protected columns.
create function team_private.guard_roster_fields() returns trigger
language plpgsql security invoker set search_path='' as $$begin
-- Trusted backend operations and existing checked SECURITY DEFINER workflows.
if current_user in ('postgres','service_role','supabase_admin') then return new;end if;
if team_private.has_role('administrator') then return new;end if;
if new.id is distinct from old.id or new.billing_parent_id is distinct from old.billing_parent_id then
 raise exception 'Administrator access required to change player identity or billing responsibility' using errcode='42501';end if;
if new.roster_status is distinct from old.roster_status and not team_private.has_role('coach') then
 raise exception 'Staff access required to change roster status' using errcode='42501';end if;
return new;end$$;
revoke all on function team_private.guard_roster_fields() from public,anon,authenticated;
create trigger protect_roster_fields before update on public.team_players for each row execute function team_private.guard_roster_fields();

-- Client-supplied timestamps must not override the ordering of consent history.
create function team_private.stamp_parent_consent() returns trigger
language plpgsql security invoker set search_path='' as $$begin
new.recorded_at:=clock_timestamp();
if current_user not in ('postgres','service_role','supabase_admin') then
 if auth.uid() is null or new.parent_id is distinct from auth.uid() then raise exception 'Record consent using your own guardian account' using errcode='42501';end if;
 if octet_length(new.payload::text)>65536 then raise exception 'Consent record is too large';end if;
end if;
return new;end$$;
revoke all on function team_private.stamp_parent_consent() from public,anon,authenticated;
create trigger stamp_consent_record before insert on public.parent_consents for each row execute function team_private.stamp_parent_consent();
