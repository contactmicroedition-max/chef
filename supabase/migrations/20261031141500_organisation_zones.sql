create extension if not exists postgis with schema extensions;

create table public.organisation_zones (
  id uuid primary key default gen_random_uuid(),
  organisation_id uuid not null unique
    references public.organisations(id) on delete cascade,
  name text not null default 'Work zone',
  polygon extensions.geography(Polygon, 4326) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint organisation_zones_polygon_valid
    check (extensions.st_isvalid(polygon::extensions.geometry))
);

create index organisation_zones_polygon_gist
  on public.organisation_zones using gist (polygon);

alter table public.organisation_zones enable row level security;

create or replace function public.is_organisation_owner(
  p_organisation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.organisations organisation
    where organisation.id = p_organisation_id
      and organisation.owner_id = auth.uid()
  );
$$;

revoke all on function public.is_organisation_owner(uuid) from public;
grant execute on function public.is_organisation_owner(uuid) to authenticated;

create policy "owners read organisation zones"
  on public.organisation_zones for select
  using (public.is_organisation_owner(organisation_id));

create policy "owners manage organisation zones"
  on public.organisation_zones for all
  using (public.is_organisation_owner(organisation_id))
  with check (public.is_organisation_owner(organisation_id));

grant select, insert, update, delete
  on public.organisation_zones to authenticated;

create policy "owners insert own organisations"
  on public.organisations for insert
  with check (owner_id = auth.uid());

create policy "owners insert own organisation membership"
  on public.organisation_members for insert
  with check (
    user_id = auth.uid()
    and role = 'owner'
    and public.is_organisation_owner(organisation_id)
  );

create or replace function public.create_organisation_with_zone(
  p_name text,
  p_address text,
  p_phone text,
  p_logo_url text,
  p_currency text,
  p_timezone text,
  p_polygon jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  new_organisation_id uuid := pg_catalog.gen_random_uuid();
  zone_geometry extensions.geometry;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;
  if nullif(pg_catalog.btrim(p_name), '') is null then
    raise exception 'Organisation name is required';
  end if;
  if p_currency not in ('TND', 'EUR', 'USD', 'GBP') then
    raise exception 'Unsupported organisation currency';
  end if;
  if nullif(pg_catalog.btrim(p_timezone), '') is null then
    raise exception 'Timezone is required';
  end if;
  if p_polygon is null
     or pg_catalog.jsonb_typeof(p_polygon) <> 'object'
     or p_polygon ->> 'type' <> 'Polygon' then
    raise exception 'Work zone must be a GeoJSON Polygon';
  end if;

  zone_geometry := extensions.st_setsrid(
    extensions.st_geomfromgeojson(p_polygon::text),
    4326
  );
  if extensions.st_geometrytype(zone_geometry) <> 'ST_Polygon'
     or extensions.st_isempty(zone_geometry)
     or not extensions.st_isvalid(zone_geometry)
     or extensions.st_npoints(zone_geometry) < 4
     or not extensions.st_isclosed(
       extensions.st_exteriorring(zone_geometry)
     ) then
    raise exception 'Work zone polygon is invalid or its ring is not closed';
  end if;
  if extensions.st_xmin(zone_geometry) < -180
     or extensions.st_xmax(zone_geometry) > 180
     or extensions.st_ymin(zone_geometry) < -90
     or extensions.st_ymax(zone_geometry) > 90 then
    raise exception 'Work zone coordinates must be longitude/latitude';
  end if;
  if extensions.st_area(zone_geometry::extensions.geography) > 10000000 then
    raise exception 'Work zone cannot exceed 10 square kilometres';
  end if;

  insert into public.organisations (
    id, name, address, phone, logo_url, currency, timezone, owner_id
  )
  values (
    new_organisation_id,
    pg_catalog.btrim(p_name),
    nullif(pg_catalog.btrim(p_address), ''),
    nullif(pg_catalog.btrim(p_phone), ''),
    nullif(pg_catalog.btrim(p_logo_url), ''),
    p_currency,
    pg_catalog.btrim(p_timezone),
    auth.uid()
  );

  insert into public.organisation_members (organisation_id, user_id, role)
  values (new_organisation_id, auth.uid(), 'owner');

  insert into public.organisation_zones (organisation_id, polygon)
  values (
    new_organisation_id,
    zone_geometry::extensions.geography
  );

  return new_organisation_id;
end;
$$;

revoke all on function public.create_organisation_with_zone(
  text, text, text, text, text, text, jsonb
) from public;
grant execute on function public.create_organisation_with_zone(
  text, text, text, text, text, text, jsonb
) to authenticated;

create or replace function public.get_organisation_zone_geojson(
  p_organisation_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select extensions.st_asgeojson(zone.polygon::extensions.geometry)::jsonb
  from public.organisation_zones zone
  where zone.organisation_id = p_organisation_id;
$$;

revoke all on function public.get_organisation_zone_geojson(uuid) from public;
grant execute on function public.get_organisation_zone_geojson(uuid)
  to authenticated;

create or replace function public.update_organisation_zone(
  p_organisation_id uuid,
  p_polygon jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  zone_geometry extensions.geometry;
begin
  if not public.is_organisation_owner(p_organisation_id) then
    raise exception 'Only the organisation owner can update its work zone';
  end if;
  if p_polygon is null
     or pg_catalog.jsonb_typeof(p_polygon) <> 'object'
     or p_polygon ->> 'type' <> 'Polygon' then
    raise exception 'Work zone must be a GeoJSON Polygon';
  end if;

  zone_geometry := extensions.st_setsrid(
    extensions.st_geomfromgeojson(p_polygon::text),
    4326
  );
  if extensions.st_geometrytype(zone_geometry) <> 'ST_Polygon'
     or extensions.st_isempty(zone_geometry)
     or not extensions.st_isvalid(zone_geometry)
     or extensions.st_npoints(zone_geometry) < 4
     or not extensions.st_isclosed(
       extensions.st_exteriorring(zone_geometry)
     ) then
    raise exception 'Work zone polygon is invalid or its ring is not closed';
  end if;
  if extensions.st_xmin(zone_geometry) < -180
     or extensions.st_xmax(zone_geometry) > 180
     or extensions.st_ymin(zone_geometry) < -90
     or extensions.st_ymax(zone_geometry) > 90 then
    raise exception 'Work zone coordinates must be longitude/latitude';
  end if;
  if extensions.st_area(zone_geometry::extensions.geography) > 10000000 then
    raise exception 'Work zone cannot exceed 10 square kilometres';
  end if;

  update public.organisation_zones
  set polygon = zone_geometry::extensions.geography,
      updated_at = pg_catalog.now()
  where organisation_id = p_organisation_id;

  if not found then
    raise exception 'Organisation work zone was not found';
  end if;
end;
$$;

revoke all on function public.update_organisation_zone(uuid, jsonb) from public;
grant execute on function public.update_organisation_zone(uuid, jsonb)
  to authenticated;
