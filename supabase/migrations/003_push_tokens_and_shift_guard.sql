create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null,
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

alter table public.user_push_tokens enable row level security;

drop policy if exists "users manage their own push tokens"
on public.user_push_tokens;

create policy "users manage their own push tokens"
on public.user_push_tokens for all
using (user_id = auth.uid())
with check (user_id = auth.uid());

grant select, insert, update, delete on public.user_push_tokens to authenticated;
grant all on public.user_push_tokens to service_role;

create unique index if not exists attendance_one_open_shift_per_employee
on public.attendance_records (employee_id)
where clock_out is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'salary_advances_positive_amount'
      and conrelid = 'public.salary_advances'::regclass
  ) then
    alter table public.salary_advances
    add constraint salary_advances_positive_amount
    check (amount > 0 and amount < 'Infinity'::numeric) not valid;
  end if;
end;
$$;
