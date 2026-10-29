alter table public.employees
  alter column email drop not null,
  add column if not exists pay_type text not null default 'hourly',
  add column if not exists monthly_salary numeric(10, 2);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'employees_pay_type_valid'
      and conrelid = 'public.employees'::regclass
  ) then
    alter table public.employees
      add constraint employees_pay_type_valid
      check (pay_type in ('hourly', 'monthly')) not valid;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'employees_pay_amount_valid'
      and conrelid = 'public.employees'::regclass
  ) then
    alter table public.employees
      add constraint employees_pay_amount_valid
      check (
        hourly_rate >= 0
        and hourly_rate < 'Infinity'::numeric
        and (
          monthly_salary is null
          or (
            monthly_salary > 0
            and monthly_salary < 'Infinity'::numeric
          )
        )
        and (pay_type <> 'monthly' or monthly_salary is not null)
      ) not valid;
  end if;
end;
$$;
