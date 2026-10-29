alter table public.organisation_members
  add column if not exists employee_id uuid
  references public.employees(id) on delete set null;

create or replace function public.has_organisation_role(
  p_organisation_id uuid,
  p_roles text[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisation_members member
    where member.organisation_id = p_organisation_id
      and member.user_id = auth.uid()
      and member.role = any (p_roles)
  );
$$;

revoke all on function public.has_organisation_role(uuid, text[]) from public;
grant execute on function public.has_organisation_role(uuid, text[]) to authenticated;

create or replace function public.create_organisation(
  p_name text,
  p_address text default null,
  p_phone text default null,
  p_currency text default 'TND'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_organisation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if nullif(trim(p_name), '') is null then
    raise exception 'Organisation name is required';
  end if;
  if p_currency not in ('TND', 'EUR', 'USD', 'GBP') then
    raise exception 'Unsupported organisation currency';
  end if;

  insert into public.organisations (name, address, phone, currency, owner_id)
  values (trim(p_name), nullif(trim(p_address), ''), nullif(trim(p_phone), ''),
          p_currency, auth.uid())
  returning id into new_organisation_id;

  insert into public.organisation_members (organisation_id, user_id, role)
  values (new_organisation_id, auth.uid(), 'owner');

  return new_organisation_id;
end;
$$;

revoke all on function public.create_organisation(text, text, text, text) from public;
grant execute on function public.create_organisation(text, text, text, text) to authenticated;

create or replace function public.add_organisation_member(
  p_organisation_id uuid,
  p_email text,
  p_role text,
  p_employee_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user_id uuid;
begin
  if not public.has_organisation_role(p_organisation_id, array['owner']) then
    raise exception 'Only an organisation owner can assign roles';
  end if;
  if p_role not in ('manager', 'employee') then
    raise exception 'Role must be manager or employee';
  end if;
  if p_role = 'employee' then
    if p_employee_id is null or not exists (
      select 1 from public.employees employee
      where employee.id = p_employee_id
        and employee.organisation_id = p_organisation_id
        and lower(employee.email) = lower(trim(p_email))
    ) then
      raise exception 'Choose an employee profile in this organisation with the same email';
    end if;
  elsif p_employee_id is not null then
    raise exception 'Only employee members can be linked to an employee profile';
  end if;

  select auth_user.id into target_user_id
  from auth.users auth_user
  where lower(auth_user.email) = lower(trim(p_email))
  limit 1;

  if target_user_id is null then
    raise exception 'Create the user account before assigning an organisation role';
  end if;

  insert into public.organisation_members (
    organisation_id, user_id, role, employee_id
  )
  values (p_organisation_id, target_user_id, p_role, p_employee_id)
  on conflict (organisation_id, user_id)
  do update set role = excluded.role, employee_id = excluded.employee_id;

  return target_user_id;
end;
$$;

revoke all on function public.add_organisation_member(uuid, text, text, uuid) from public;
grant execute on function public.add_organisation_member(uuid, text, text, uuid) to authenticated;

drop policy if exists "members can read their organisation data" on public.organisations;
drop policy if exists "owners can manage organisation" on public.organisations;
drop policy if exists "organisation members can read employees" on public.employees;
drop policy if exists "owners and managers manage attendance" on public.attendance_records;
drop policy if exists "organisation members read organisations" on public.organisations;
drop policy if exists "owners update organisations" on public.organisations;
drop policy if exists "members read own memberships" on public.organisation_members;
drop policy if exists "members can read employees" on public.employees;
drop policy if exists "managers manage employees" on public.employees;
drop policy if exists "attendance visible by role" on public.attendance_records;
drop policy if exists "managers write attendance" on public.attendance_records;
drop policy if exists "advances visible by role" on public.salary_advances;
drop policy if exists "managers write advances" on public.salary_advances;
drop policy if exists "payments visible by role" on public.salary_payments;
drop policy if exists "managers write payments" on public.salary_payments;

create policy "organisation members read organisations"
on public.organisations for select
using (public.has_organisation_role(id, array['owner', 'manager', 'employee']));

create policy "owners update organisations"
on public.organisations for update
using (public.has_organisation_role(id, array['owner']))
with check (public.has_organisation_role(id, array['owner']));

create policy "members read own memberships"
on public.organisation_members for select
using (
  user_id = auth.uid()
  or public.has_organisation_role(organisation_id, array['owner', 'manager'])
);

create policy "members can read employees"
on public.employees for select
using (
  public.has_organisation_role(organisation_id, array['owner', 'manager'])
  or exists (
    select 1 from public.organisation_members member
    where member.organisation_id = employees.organisation_id
      and member.user_id = auth.uid()
      and member.role = 'employee'
      and member.employee_id = employees.id
  )
);

create policy "managers manage employees"
on public.employees for all
using (public.has_organisation_role(organisation_id, array['owner', 'manager']))
with check (public.has_organisation_role(organisation_id, array['owner', 'manager']));

create policy "attendance visible by role"
on public.attendance_records for select
using (
  public.has_organisation_role(organisation_id, array['owner', 'manager'])
  or exists (
    select 1 from public.organisation_members member
    where member.organisation_id = attendance_records.organisation_id
      and member.user_id = auth.uid()
      and member.role = 'employee'
      and member.employee_id = attendance_records.employee_id
  )
);

create policy "managers insert attendance"
on public.attendance_records for insert
with check (public.has_organisation_role(organisation_id, array['owner', 'manager']));

create policy "managers correct attendance"
on public.attendance_records for update
using (public.has_organisation_role(organisation_id, array['owner', 'manager']))
with check (public.has_organisation_role(organisation_id, array['owner', 'manager']));

create policy "advances visible by role"
on public.salary_advances for select
using (
  public.has_organisation_role(organisation_id, array['owner', 'manager'])
  or exists (
    select 1 from public.organisation_members member
    where member.organisation_id = salary_advances.organisation_id
      and member.user_id = auth.uid()
      and member.role = 'employee'
      and member.employee_id = salary_advances.employee_id
  )
);

create policy "managers insert advances"
on public.salary_advances for insert
with check (public.has_organisation_role(organisation_id, array['owner', 'manager']));

create policy "owners update advances"
on public.salary_advances for update
using (public.has_organisation_role(organisation_id, array['owner']))
with check (public.has_organisation_role(organisation_id, array['owner']));

create policy "payments visible by role"
on public.salary_payments for select
using (
  public.has_organisation_role(organisation_id, array['owner', 'manager'])
  or exists (
    select 1 from public.organisation_members member
    where member.organisation_id = salary_payments.organisation_id
      and member.user_id = auth.uid()
      and member.role = 'employee'
      and member.employee_id = salary_payments.employee_id
  )
);

create policy "owners insert payments"
on public.salary_payments for insert
with check (public.has_organisation_role(organisation_id, array['owner']));

grant usage on schema public to authenticated;
grant select on public.organisations, public.organisation_members,
  public.employees, public.attendance_records, public.salary_advances,
  public.salary_payments to authenticated;
grant update on public.organisations to authenticated;
grant insert, update on public.employees to authenticated;
grant insert, update on public.attendance_records to authenticated;
grant insert, update on public.salary_advances to authenticated;
grant insert on public.salary_payments to authenticated;
