alter table public.organisation_shifts
  add constraint organisation_shifts_organisation_id_id_unique
  unique (organisation_id, id);

alter table public.employees
  add column shift_id uuid;

alter table public.employees
  add constraint employees_organisation_shift_fkey
  foreign key (organisation_id, shift_id)
  references public.organisation_shifts (organisation_id, id)
  on delete set null (shift_id);

create index employees_organisation_shift_idx
  on public.employees (organisation_id, shift_id)
  where shift_id is not null;

create or replace function public.prevent_archiving_employee_with_open_shift()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.employment_status = 'active'
     and new.employment_status <> 'active'
     and exists (
       select 1
       from public.attendance_records attendance
       where attendance.employee_id = old.id
         and attendance.organisation_id = old.organisation_id
         and attendance.clock_out is null
     ) then
    raise exception 'Clock out the employee before archiving them';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_archiving_employee_with_open_shift()
  from public;

create trigger prevent_archiving_employee_with_open_shift
  before update of employment_status
  on public.employees
  for each row
  execute function public.prevent_archiving_employee_with_open_shift();
