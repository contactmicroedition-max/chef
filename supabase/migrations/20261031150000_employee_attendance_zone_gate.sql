create or replace function public.get_employee_work_zone_status(
  p_organisation_id uuid,
  p_latitude double precision default null,
  p_longitude double precision default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  zone_geometry extensions.geometry;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if not exists (
    select 1
    from public.organisation_members membership
    join public.employees employee
      on employee.id = membership.employee_id
     and employee.organisation_id = membership.organisation_id
    where membership.organisation_id = p_organisation_id
      and membership.user_id = auth.uid()
      and membership.role = 'employee'
      and employee.employment_status = 'active'
  ) then
    raise exception 'An active employee membership is required';
  end if;

  if (p_latitude is null) <> (p_longitude is null) then
    raise exception 'Both latitude and longitude must be provided';
  end if;
  if p_latitude is not null
     and (
       p_latitude < -90 or p_latitude > 90
       or p_longitude < -180 or p_longitude > 180
     ) then
    raise exception 'Coordinates are outside the valid range';
  end if;

  select zone.polygon::extensions.geometry
    into zone_geometry
  from public.organisation_zones zone
  where zone.organisation_id = p_organisation_id;

  if zone_geometry is null then
    raise exception 'This organisation has no work zone configured';
  end if;

  return pg_catalog.jsonb_build_object(
    'polygon',
    extensions.st_asgeojson(zone_geometry)::jsonb,
    'is_inside',
    case
      when p_latitude is null then null
      else extensions.st_covers(
        zone_geometry,
        extensions.st_setsrid(
          extensions.st_makepoint(p_longitude, p_latitude),
          4326
        )
      )
    end
  );
end;
$$;

revoke all on function public.get_employee_work_zone_status(
  uuid, double precision, double precision
) from public;
grant execute on function public.get_employee_work_zone_status(
  uuid, double precision, double precision
) to authenticated;
