drop function if exists public.record_employee_clock_in(
  uuid, uuid, uuid, date, timestamptz, text, boolean
);

create or replace function public.record_employee_clock_in(
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
  organisation_timezone text;
  local_clock_in time without time zone;
  shift_start time without time zone;
  shift_end time without time zone;
  auto_closed_count integer := 0;
begin
  if p_approval_status is null
     or p_approval_status not in ('approved', 'pending') then
    raise exception 'Invalid attendance approval status';
  end if;
  if p_clock_in is null or p_shift_date is null
     or p_auto_close_previous is null then
    raise exception 'Clock-in timestamp, date, and auto-close decision are required';
  end if;
  if p_assigned_shift_id is null or p_shift_id is null then
    raise exception 'An assigned and active shift are required to clock in';
  end if;

  select organisation.timezone
    into organisation_timezone
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

  select shift.start_time, shift.end_time
    into shift_start, shift_end
  from public.organisation_shifts shift
  where shift.id = p_shift_id
    and shift.organisation_id = p_organisation_id;
  if not found then
    raise exception 'The active shift does not belong to this organisation';
  end if;

  local_clock_in := (p_clock_in at time zone organisation_timezone)::time;
  if local_clock_in < shift_start or local_clock_in > shift_end then
    raise exception 'Clock-in time is outside the recorded active shift';
  end if;

  if p_assigned_shift_id = p_shift_id
     and p_approval_status <> 'approved' then
    raise exception 'Clock-in during the assigned shift must be approved';
  end if;
  if p_assigned_shift_id <> p_shift_id
     and p_approval_status <> 'pending' then
    raise exception 'Clock-in during a different shift requires admin approval';
  end if;

  if p_auto_close_previous then
    if p_approval_status <> 'approved'
       or p_assigned_shift_id <> p_shift_id then
      raise exception 'Only an approved clock-in during the assigned shift can close previous shifts';
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

create or replace function public.review_attendance_record(
  p_attendance_id uuid,
  p_approval_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_record public.attendance_records%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if p_approval_status is null
     or p_approval_status not in ('approved', 'rejected') then
    raise exception 'Review status must be approved or rejected';
  end if;

  select attendance.*
    into target_record
  from public.attendance_records attendance
  where attendance.id = p_attendance_id
  for update;
  if not found then
    raise exception 'Attendance record does not exist';
  end if;
  if not public.has_organisation_role(
    target_record.organisation_id,
    array['owner', 'manager']
  ) then
    raise exception 'Only organisation owners or managers can review attendance';
  end if;
  if target_record.approval_status <> 'pending' then
    raise exception 'Only pending attendance records can be reviewed';
  end if;

  update public.attendance_records
  set approval_status = p_approval_status,
      reviewed_by = auth.uid(),
      reviewed_at = pg_catalog.now(),
      clock_out = case
        when p_approval_status = 'rejected' then target_record.clock_in
        else target_record.clock_out
      end
  where id = p_attendance_id;
end;
$$;

revoke all on function public.review_attendance_record(uuid, text)
  from public, anon;
grant execute on function public.review_attendance_record(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
