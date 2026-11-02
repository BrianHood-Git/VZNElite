create table public.player_private_details (
 player_id uuid primary key references public.team_players(id) on delete cascade,
 date_of_birth date check(date_of_birth is null or date_of_birth >= date '1900-01-01'),
 updated_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now()
);
alter table public.player_private_details enable row level security;
revoke all on public.player_private_details from public,anon,authenticated;
grant select on public.player_private_details to authenticated;
create policy private_player_admin_read on public.player_private_details for select to authenticated
using((select team_private.has_role('administrator')));
create function team_private.save_player_birthday(p uuid,birthday date) returns void language plpgsql security definer set search_path='' as $$begin
if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator access required' using errcode='42501';end if;
if birthday is not null and (birthday < date '1900-01-01' or birthday > (now() at time zone 'America/Chicago')::date) then raise exception 'Enter a valid birthday that is not in the future';end if;
if not exists(select 1 from public.team_players where id=p) then raise exception 'Player not found';end if;
insert into public.player_private_details(player_id,date_of_birth,updated_by) values(p,birthday,auth.uid()) on conflict(player_id) do update set date_of_birth=excluded.date_of_birth,updated_by=auth.uid(),updated_at=now();
insert into public.team_change_history(actor,resource,action) values(auth.uid(),'player_private_details',case when birthday is null then 'CLEAR_BIRTHDAY' else 'SAVE_BIRTHDAY' end);
end$$;
revoke all on function team_private.save_player_birthday(uuid,date) from public,anon;
grant execute on function team_private.save_player_birthday(uuid,date) to authenticated;
create function public.save_player_birthday(p uuid,birthday date) returns void language sql security invoker set search_path='' as $$select team_private.save_player_birthday(p,birthday)$$;
revoke all on function public.save_player_birthday(uuid,date) from public,anon;
grant execute on function public.save_player_birthday(uuid,date) to authenticated;
