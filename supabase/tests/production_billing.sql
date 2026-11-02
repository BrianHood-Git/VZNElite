-- Run after setup in the SAME transaction; caller must append ROLLBACK.
insert into auth.users(id,email,email_confirmed_at) values
('11111111-1111-4111-8111-111111111111','billing-admin@example.invalid',now()),
('22222222-2222-4222-8222-222222222222','billing-parent@example.invalid',now()),
('33333333-3333-4333-8333-333333333333','billing-other@example.invalid',now());
insert into public.team_memberships values
('11111111-1111-4111-8111-111111111111','administrator'),
('22222222-2222-4222-8222-222222222222','parent'),
('33333333-3333-4333-8333-333333333333','parent');
insert into public.team_players(id,display_name,billing_parent_id) values('aaaaaaaa-0000-4000-8000-000000000001','Billing test','22222222-2222-4222-8222-222222222222');
insert into public.family_links values('22222222-2222-4222-8222-222222222222','aaaaaaaa-0000-4000-8000-000000000001','parent');
update public.team_documents set data='{"monthly":15000,"months":4,"support":{},"history":[]}' where key='dues';
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
do $$begin
 begin perform public.issue_monthly_invoice('aaaaaaaa-0000-4000-8000-000000000001','2026-11-01');raise exception 'Parent issued invoice';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select public.issue_monthly_invoice('aaaaaaaa-0000-4000-8000-000000000001','2026-11-01');
do $$begin
 begin perform public.issue_monthly_invoice('aaaaaaaa-0000-4000-8000-000000000001','2026-11-01');raise exception 'Duplicate invoice allowed';exception when unique_violation then null;end;
end$$;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
do $$begin
 if exists(select 1 from public.billing_invoices) then raise exception 'Other parent read invoice';end if;
 if exists(select 1 from public.admin_notifications) then raise exception 'Other parent read notifications';end if;
end$$;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
do $$begin
 if (select count(*) from public.billing_invoices)<>1 then raise exception 'Parent cannot read own invoice';end if;
 begin update public.billing_invoices set status='paid';raise exception 'Parent marked paid';exception when insufficient_privilege then null;end;
 begin perform public.record_invoice_payment('evt_fake',gen_random_uuid(),'cs_fake',15000,'pi_fake');raise exception 'Parent called payment RPC';exception when insufficient_privilege then null;end;
end$$;
reset role;
update public.billing_invoices set checkout_session_id='cs_test_verified';
set local role service_role;
do $$declare invoice uuid;begin
 select id into invoice from public.billing_invoices limit 1;
 begin perform public.record_invoice_payment('evt_bad',invoice,'cs_test_verified',1,'pi_test');raise exception 'Wrong amount accepted';exception when raise_exception then if sqlerrm<>'Payment does not match invoice' then raise;end if;end;
 perform public.record_invoice_payment('evt_ok',invoice,'cs_test_verified',15000,'pi_test');
 perform public.record_invoice_payment('evt_ok',invoice,'cs_test_verified',15000,'pi_test');
 if (select count(*) from public.billing_webhook_events)<>1 then raise exception 'Webhook replay recorded twice';end if;
 if (select status from public.billing_invoices where id=invoice)<>'paid' then raise exception 'Payment not recorded';end if;
 if (select count(*) from public.admin_notifications)<>3 then raise exception 'Verified accounts were not queued';end if;
 if (select count(*) from public.claim_admin_notifications())<>3 then raise exception 'Claim failed';end if;
 if (select count(*) from public.claim_admin_notifications())<>0 then raise exception 'Lease did not prevent duplicate claim';end if;
end$$;
reset role;
