alter table public.manual_dues drop constraint manual_dues_check;
alter table public.manual_dues add constraint manual_dues_check check (not paid or (amount_cents>0 and payment_date is not null and method in ('cash','check','cash_app','bank_transfer','other','venmo')));
