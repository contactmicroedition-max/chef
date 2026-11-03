alter table public.attendance_records
  add column if not exists assigned_shift_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.conname =
      'attendance_records_organisation_assigned_shift_fkey'
      and constraint_row.conrelid = 'public.attendance_records'::regclass
  ) then
    alter table public.attendance_records
      add constraint attendance_records_organisation_assigned_shift_fkey
      foreign key (organisation_id, assigned_shift_id)
      references public.organisation_shifts (organisation_id, id)
      on delete set null (assigned_shift_id);
  end if;
end;
$$;

update public.attendance_records attendance
set assigned_shift_id = employee.shift_id
from public.employees employee
where employee.id = attendance.employee_id
  and employee.organisation_id = attendance.organisation_id
  and attendance.assigned_shift_id is null;

drop function if exists public.record_employee_clock_in(
  uuid, uuid, uuid, date, timestamptz, text, boolean
);
drop function if exists public.record_employee_clock_in(
  uuid, uuid, uuid, uuid, date, timestamptz, text, boolean
);

create function public.record_employee_clock_in(
  p_organisation_id uuid,
  p_employee_id uuid,
  p_shift_id uuid,
  p_assigned_shift_id uuid,
  p_shift_date date,
  p_clock_in timestamptz,
  p_approval_status text,
  p_auto_close_previous boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_assigned_shift_id uuid;
  attendance_id uuid;
  auto_closed_count integer := 0;
begin
  if p_approval_status is null
     or p_approval_status not in ('approved', 'pending') then
    raise exception 'Invalid attendance approval status';
  end if;
  if p_assigned_shift_id is null then
    raise exception 'An assigned shift is required to clock in';
  end if;

  perform 1
  from public.organisations organisation
  where organisation.id = p_organisation_id
  for update;
  if not found then
    raise exception 'Organisation does not exist';
  end if;

  select employee.shift_id
    into current_assigned_shift_id
  from public.employees employee
  where employee.id = p_employee_id
    and employee.organisation_id = p_organisation_id
    and employee.employment_status = 'active'
  for update;
  if not found then
    raise exception 'Only active employees can record attendance';
  end if;
  if current_assigned_shift_id is distinct from p_assigned_shift_id then
    raise exception 'Employee shift assignment changed; refresh and try again';
  end if;
  if not exists (
    select 1
    from public.organisation_shifts shift
    where shift.id = p_assigned_shift_id
      and shift.organisation_id = p_organisation_id
  ) then
    raise exception 'The assigned shift does not belong to this organisation';
  end if;
  if p_shift_id is not null and not exists (
    select 1
    from public.organisation_shifts shift
    where shift.id = p_shift_id
      and shift.organisation_id = p_organisation_id
  ) then
    raise exception 'The attendance shift does not belong to this organisation';
  end if;

  if p_auto_close_previous then
    if p_approval_status <> 'approved' then
      raise exception 'Only an in-window assigned shift can close the previous shift';
    end if;

    update public.attendance_records attendance
    set clock_out = p_clock_in,
        auto_closed = true
    where attendance.organisation_id = p_organisation_id
      and attendance.clock_out is null
      and coalesce(attendance.assigned_shift_id, attendance.shift_id) is not null
      and coalesce(attendance.assigned_shift_id, attendance.shift_id)
        <> p_assigned_shift_id;
    get diagnostics auto_closed_count = row_count;
  end if;

  if exists (
    select 1
    from public.attendance_records attendance
    where attendance.organisation_id = p_organisation_id
      and attendance.employee_id = p_employee_id
      and attendance.clock_out is null
  ) then
    raise exception 'Employee already has an open attendance record';
  end if;

  insert into public.attendance_records (
    organisation_id,
    employee_id,
    shift_id,
    assigned_shift_id,
    shift_date,
    clock_in,
    status,
    approval_status
  )
  values (
    p_organisation_id,
    p_employee_id,
    p_shift_id,
    p_assigned_shift_id,
    p_shift_date,
    p_clock_in,
    'approved',
    p_approval_status
  )
  returning id into attendance_id;

  return pg_catalog.jsonb_build_object(
    'attendance_id', attendance_id,
    'auto_closed_count', auto_closed_count
  );
end;
$$;

revoke all on function public.record_employee_clock_in(
  uuid, uuid, uuid, uuid, date, timestamptz, text, boolean
) from public, anon, authenticated;
grant execute on function public.record_employee_clock_in(
  uuid, uuid, uuid, uuid, date, timestamptz, text, boolean
) to service_role;

notify pgrst, 'reload schema';
