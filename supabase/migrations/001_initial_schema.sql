create extension if not exists "uuid-ossp";

create table if not exists organisations (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  logo_url text,
  address text,
  phone text,
  currency text not null default 'TND',
  timezone text not null default 'Africa/Tunis',
  owner_id uuid not null,
  status text not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists organisation_members (
  id uuid primary key default uuid_generate_v4(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  user_id uuid not null,
  role text not null check (role in ('owner','manager','employee')),
  created_at timestamptz not null default now(),
  unique (organisation_id, user_id)
);

create table if not exists employees (
  id uuid primary key default uuid_generate_v4(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  full_name text not null,
  email text not null,
  job_title text not null,
  hourly_rate numeric(10,2) not null default 0,
  employment_status text not null default 'active',
  phone text,
  hire_date date,
  created_at timestamptz not null default now()
);

create table if not exists attendance_records (
  id uuid primary key default uuid_generate_v4(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  shift_date date not null,
  clock_in timestamptz not null,
  clock_out timestamptz,
  note text,
  status text not null default 'approved',
  created_at timestamptz not null default now()
);

create table if not exists salary_advances (
  id uuid primary key default uuid_generate_v4(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  amount numeric(10,2) not null,
  requested_at timestamptz not null default now(),
  status text not null default 'pending'
);

create table if not exists salary_payments (
  id uuid primary key default uuid_generate_v4(),
  organisation_id uuid not null references organisations(id) on delete cascade,
  employee_id uuid not null references employees(id) on delete cascade,
  amount numeric(10,2) not null,
  paid_at timestamptz not null default now(),
  reference text not null
);

alter table organisations enable row level security;
alter table organisation_members enable row level security;
alter table employees enable row level security;
alter table attendance_records enable row level security;
alter table salary_advances enable row level security;
alter table salary_payments enable row level security;

create policy "members can read their organisation data" on organisations
for select using (true);

create policy "owners can manage organisation" on organisations
for all using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);

create policy "organisation members can read employees" on employees
for select using (exists (
  select 1 from organisation_members om
  where om.organisation_id = employees.organisation_id
    and om.user_id = auth.uid()
));

create policy "owners and managers manage attendance" on attendance_records
for all using (exists (
  select 1 from organisation_members om
  where om.organisation_id = attendance_records.organisation_id
    and om.user_id = auth.uid()
    and om.role in ('owner','manager')
))
with check (exists (
  select 1 from organisation_members om
  where om.organisation_id = attendance_records.organisation_id
    and om.user_id = auth.uid()
    and om.role in ('owner','manager')
));
