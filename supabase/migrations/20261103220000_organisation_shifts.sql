create table public.organisation_shifts (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null
    references public.organisations(id) on delete cascade,
  name text not null
    check (pg_catalog.length(pg_catalog.btrim(name)) > 0),
  start_time time without time zone not null,
  end_time time without time zone not null,
  created_at timestamptz not null default pg_catalog.now(),
  updated_at timestamptz not null default pg_catalog.now(),
  constraint organisation_shifts_same_day
    check (end_time > start_time)
);

create index organisation_shifts_organisation_start_idx
  on public.organisation_shifts (organisation_id, start_time);

alter table public.organisation_shifts enable row level security;

create policy "organisation members read shifts"
  on public.organisation_shifts for select
  using (
    public.has_organisation_role(
      organisation_id,
      array['owner', 'manager', 'employee']
    )
  );

create policy "organisation managers manage shifts"
  on public.organisation_shifts for all
  using (
    public.has_organisation_role(organisation_id, array['owner', 'manager'])
  )
  with check (
    public.has_organisation_role(organisation_id, array['owner', 'manager'])
  );

grant select, insert, update, delete
  on public.organisation_shifts to authenticated;

create or replace function public.enforce_organisation_shift_duration_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_organisation_id uuid;
  new_organisation_found boolean := false;
  total_seconds numeric;
begin
  if new.end_time <= new.start_time then
    raise exception 'Shift end time must be later than start time';
  end if;

  if tg_op = 'UPDATE' then
    for locked_organisation_id in
      select organisation.id
      from public.organisations organisation
      where organisation.id in (old.organisation_id, new.organisation_id)
      order by organisation.id
      for update
    loop
      if locked_organisation_id = new.organisation_id then
        new_organisation_found := true;
      end if;
    end loop;
  else
    select organisation.id
      into locked_organisation_id
    from public.organisations organisation
    where organisation.id = new.organisation_id
    for update;
    new_organisation_found := found;
  end if;

  if not new_organisation_found then
    raise exception 'The shift organisation does not exist';
  end if;

  select coalesce(
    sum(extract(epoch from (shift.end_time - shift.start_time))),
    0
  )
  into total_seconds
  from public.organisation_shifts shift
  where shift.organisation_id = new.organisation_id
    and shift.id <> new.id;

  total_seconds := total_seconds +
    extract(epoch from (new.end_time - new.start_time));
  if total_seconds > 86400 then
    raise exception using
      errcode = '23514',
      message = 'The total duration of all organisation shifts cannot exceed 24 hours';
  end if;

  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

revoke all on function public.enforce_organisation_shift_duration_limit()
  from public;

create trigger enforce_organisation_shift_duration_limit
  before insert or update
  on public.organisation_shifts
  for each row
  execute function public.enforce_organisation_shift_duration_limit();
