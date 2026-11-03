alter table public.attendance_records
  add column shift_id uuid,
  add column approval_status text not null default 'approved',
  add column reviewed_by uuid,
  add column reviewed_at timestamptz,
  add column auto_closed boolean not null default false,
  add constraint attendance_records_approval_status_check
    check (approval_status in ('pending', 'approved', 'rejected'));

alter table public.attendance_records
  add constraint attendance_records_organisation_shift_fkey
  foreign key (organisation_id, shift_id)
  references public.organisation_shifts (organisation_id, id)
  on delete set null (shift_id);

create index attendance_records_pending_review_idx
  on public.attendance_records (organisation_id, shift_date desc)
  where approval_status = 'pending';

create or replace function public.record_employee_clock_in(
  p_organisation_id uuid,
  p_employee_id uuid,
  p_shift_id uuid,
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
  assigned_shift_id uuid;
  attendance_id uuid;
  auto_closed_count integer := 0;
begin
  if p_approval_status is null
     or p_approval_status not in ('approved', 'pending') then
    raise exception 'Invalid attendance approval status';
  end if;

  perform 1
  from public.organisations organisation
  where organisation.id = p_organisation_id
  for update;
  if not found then
    raise exception 'Organisation does not exist';
  end if;

  select employee.shift_id
    into assigned_shift_id
  from public.employees employee
  where employee.id = p_employee_id
    and employee.organisation_id = p_organisation_id
    and employee.employment_status = 'active'
  for update;
  if not found then
    raise exception 'Only active employees can record attendance';
  end if;
  if assigned_shift_id is distinct from p_shift_id then
    raise exception 'Employee shift assignment changed; refresh and try again';
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
    if p_shift_id is null or p_approval_status <> 'approved' then
      raise exception 'Only an in-window assigned shift can close the previous shift';
    end if;

    update public.attendance_records attendance
    set clock_out = p_clock_in,
        auto_closed = true
    where attendance.organisation_id = p_organisation_id
      and attendance.clock_out is null
      and attendance.shift_id is not null
      and attendance.shift_id <> p_shift_id;
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
    shift_date,
    clock_in,
    status,
    approval_status
  )
  values (
    p_organisation_id,
    p_employee_id,
    p_shift_id,
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
  uuid, uuid, uuid, date, timestamptz, text, boolean
) from public, anon, authenticated;
grant execute on function public.record_employee_clock_in(
  uuid, uuid, uuid, date, timestamptz, text, boolean
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
      reviewed_at = pg_catalog.now()
  where id = p_attendance_id;
end;
$$;

revoke all on function public.review_attendance_record(uuid, text)
  from public, anon;
grant execute on function public.review_attendance_record(uuid, text)
  to authenticated;

create or replace function public.guard_attendance_approval_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.approval_status is distinct from old.approval_status then
    if old.approval_status <> 'pending'
       or new.approval_status not in ('approved', 'rejected')
       or new.reviewed_by is distinct from auth.uid()
       or new.reviewed_at is null
       or not public.has_organisation_role(
         old.organisation_id,
         array['owner', 'manager']
       ) then
      raise exception 'Attendance approval must be reviewed by an organisation owner or manager';
    end if;
  elsif new.reviewed_by is distinct from old.reviewed_by
     or new.reviewed_at is distinct from old.reviewed_at then
    raise exception 'Attendance review details cannot be changed independently';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_attendance_approval_review() from public;

create trigger guard_attendance_approval_review
  before update of approval_status, reviewed_by, reviewed_at
  on public.attendance_records
  for each row
  execute function public.guard_attendance_approval_review();

notify pgrst, 'reload schema';
