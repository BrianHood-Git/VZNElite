-- Additive reconciliation; existing sponsorship and issued dues amounts stay intact.
alter table public.venmo_receipts
 add column contribution_kind text check (contribution_kind in ('dues','voluntary')),
 add column dues_id uuid unique references public.manual_dues(id),
 add column player_id uuid references public.team_players(id),
 add constraint venmo_assignment_shape check (
  (contribution_kind is null and dues_id is null and player_id is null) or
  (contribution_kind='dues' and dues_id is not null and player_id is not null) or
  (contribution_kind='voluntary' and dues_id is null and player_id is not null)),
 add constraint venmo_assignment_report check (report_id is null or contribution_kind is null);

create table public.venmo_reconciliation_history (
 id bigint generated always as identity primary key,
 transaction_id text not null references public.venmo_receipts(transaction_id),
 actor uuid not null references auth.users(id),
 recorded_at timestamptz not null default now(),
 reason text not null, snapshot jsonb not null
);
alter table public.venmo_reconciliation_history enable row level security;
revoke all on public.venmo_reconciliation_history from public,anon,authenticated;
grant select on public.venmo_reconciliation_history to authenticated;
create policy reconciliation_admin_read on public.venmo_reconciliation_history for select to authenticated
 using ((select team_private.has_role('administrator')));

create function team_private.reconcile_venmo(tx_key text,kind text,player_key uuid,dues_key uuid,reason text) returns void
language plpgsql security definer set search_path='' as $$
declare receipt public.venmo_receipts; d public.manual_dues;
begin
 if auth.uid() is null or not team_private.has_role('administrator') then raise exception 'Administrator required' using errcode='42501'; end if;
 if kind is null or kind not in ('dues','voluntary') or length(trim(coalesce(reason,''))) not between 1 and 500 then raise exception 'Choose a contribution type and enter a verification note'; end if;
 if not exists(select 1 from public.team_players where id=player_key) then raise exception 'Choose a player'; end if;
 -- Same dues-before-receipt locking order as parent-report confirmation.
 if kind='dues' then
  select * into d from public.manual_dues where id=dues_key for update;
  if not found or d.player_id<>player_key or d.paid or d.amount_cents=0 then raise exception 'Choose unpaid dues for this player; sponsored dues cannot be paid again'; end if;
  if exists(select 1 from public.venmo_reports where dues_id=dues_key and status in ('pending','confirmed')) then raise exception 'Review the existing parent report instead'; end if;
 elsif dues_key is not null then raise exception 'Voluntary contributions cannot pay dues';
 end if;
 select * into receipt from public.venmo_receipts where transaction_id=tx_key for update;
 if not found or receipt.report_id is not null or receipt.contribution_kind is not null then raise exception 'Receipt already assigned or not found; refresh records'; end if;
 if kind='dues' then
  if receipt.gross_cents<>d.amount_cents then raise exception 'Gross payment must match issued dues; net after fees is not the dues credit'; end if;
  update public.manual_dues set paid=true,payment_date=receipt.payment_date,method='venmo',note='Venmo '||tx_key,version=version+1,updated_by=auth.uid(),updated_at=now() where id=dues_key;
  insert into public.manual_dues_history(dues_id,actor,action,snapshot) select dues_key,auth.uid(),'venmo_reconciled',to_jsonb(m) from public.manual_dues m where id=dues_key;
 end if;
 update public.venmo_receipts set contribution_kind=kind,player_id=player_key,dues_id=case when kind='dues' then dues_key end where transaction_id=tx_key;
 insert into public.venmo_reconciliation_history(transaction_id,actor,reason,snapshot) select tx_key,auth.uid(),trim(reason),to_jsonb(r) from public.venmo_receipts r where transaction_id=tx_key;
end $$;
create function public.reconcile_venmo(tx_key text,kind text,player_key uuid,dues_key uuid,reason text) returns void
language sql security invoker set search_path='' as $$select team_private.reconcile_venmo(tx_key,kind,player_key,dues_key,reason)$$;
revoke all on function team_private.reconcile_venmo(text,text,uuid,uuid,text),public.reconcile_venmo(text,text,uuid,uuid,text) from public,anon;
grant execute on function team_private.reconcile_venmo(text,text,uuid,uuid,text),public.reconcile_venmo(text,text,uuid,uuid,text) to authenticated;
notify pgrst,'reload schema';
