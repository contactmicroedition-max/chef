create table if not exists public.account_login_ids (
  login_id text primary key check (login_id ~ '^[0-9]{8}$'),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.account_login_ids enable row level security;
revoke all on public.account_login_ids from public, anon, authenticated;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employees'
      and column_name = 'phone'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employees'
      and column_name = 'login_id'
  ) then
    alter table public.employees rename column phone to login_id;
  end if;
end;
$$;

do $$
begin
  if exists (
    select 1
    from public.employees employee
    join public.organisation_members member
      on member.organisation_id = employee.organisation_id
     and member.employee_id = employee.id
     and member.role = 'employee'
    where employee.login_id ~ '^[0-9]{8}$'
    group by employee.login_id
    having count(distinct member.user_id) > 1
  ) or exists (
    select 1
    from public.employees employee
    join public.organisation_members member
      on member.organisation_id = employee.organisation_id
     and member.employee_id = employee.id
     and member.role = 'employee'
    where employee.login_id ~ '^[0-9]{8}$'
    group by member.user_id
    having count(distinct employee.login_id) > 1
  ) then
    raise exception 'Cannot migrate employee IDs: an ID is assigned to multiple accounts or an account has multiple IDs.';
  end if;
end;
$$;

insert into public.account_login_ids (login_id, user_id)
select distinct employee.login_id, member.user_id
from public.employees employee
join public.organisation_members member
  on member.organisation_id = employee.organisation_id
 and member.employee_id = employee.id
 and member.role = 'employee'
where employee.login_id ~ '^[0-9]{8}$';

alter table public.employees drop column if exists email;

create or replace function public.create_owner_account(
  p_name text,
  p_login_id text,
  p_password text,
  p_organisation_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_user_id uuid;
  v_organisation_id uuid;
  v_email text;
  v_encrypted_password text;
begin
  if nullif(trim(p_name), '') is null
    or nullif(trim(p_organisation_name), '') is null then
    raise exception 'Your name and organisation name are required.';
  end if;
  if p_login_id is null or p_login_id !~ '^[0-9]{8}$' then
    raise exception 'Your login ID must be exactly 8 digits.';
  end if;
  if p_password is null or length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters.';
  end if;
  if exists (
    select 1 from public.account_login_ids
    where login_id = p_login_id
  ) then
    raise exception using
      errcode = '23505',
      message = 'This ID is already in use.';
  end if;

  v_user_id := gen_random_uuid();
  v_email := 'id-' || p_login_id || '@chef.local';
  v_encrypted_password := extensions.crypt(
    p_password,
    extensions.gen_salt('bf')
  );

  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated', v_email,
    v_encrypted_password, now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'full_name', trim(p_name),
      'login_id', p_login_id
    ),
    false, now(), now()
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_user_id,
    jsonb_build_object(
      'sub', v_user_id::text,
      'email', v_email
    ),
    'email', v_user_id::text,
    now(), now(), now()
  );

  insert into public.account_login_ids (login_id, user_id)
  values (p_login_id, v_user_id);

  insert into public.organisations (name, owner_id)
  values (trim(p_organisation_name), v_user_id)
  returning id into v_organisation_id;

  insert into public.organisation_members (
    organisation_id, user_id, role
  ) values (v_organisation_id, v_user_id, 'owner');

  return jsonb_build_object(
    'user_id', v_user_id,
    'organisation_id', v_organisation_id,
    'login_id', p_login_id
  );
end;
$$;

revoke all on function public.create_owner_account(text, text, text, text)
from public;
grant execute on function public.create_owner_account(text, text, text, text)
to anon, authenticated;

drop function if exists public.create_employee_account(
  uuid, text, text, text, text, numeric, text
);

create function public.create_employee_account(
  p_organisation_id uuid,
  p_name text,
  p_login_id text,
  p_job_title text,
  p_pay_type text,
  p_salary_amount numeric,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_user_id uuid;
  v_employee_id uuid;
  v_email text;
begin
  if not public.has_organisation_role(p_organisation_id, array['owner']) then
    raise exception 'Only the organisation owner can create employee accounts.';
  end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_job_title), '') is null then
    raise exception 'Employee name and job title are required.';
  end if;
  if p_login_id is null or p_login_id !~ '^[0-9]{8}$' then
    raise exception 'Employee ID must be exactly 8 digits.';
  end if;
  if p_pay_type is null or p_pay_type not in ('hourly', 'monthly')
    or p_salary_amount is null
    or p_salary_amount <= 0
    or p_salary_amount >= 'Infinity'::numeric then
    raise exception 'Provide a valid pay type and positive salary amount.';
  end if;
  if p_password is null or length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters.';
  end if;
  if exists (
    select 1 from public.account_login_ids
    where login_id = p_login_id
  ) then
    raise exception using
      errcode = '23505',
      message = 'This ID is already in use.';
  end if;

  v_user_id := gen_random_uuid();
  v_email := 'id-' || p_login_id || '@chef.local';

  insert into auth.users (
    instance_id, id, aud, role, email,
    encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'full_name', trim(p_name),
      'login_id', p_login_id
    ),
    false, now(), now()
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_user_id,
    jsonb_build_object('sub', v_user_id::text, 'email', v_email),
    'email', v_user_id::text,
    now(), now(), now()
  );

  insert into public.employees (
    organisation_id, full_name, login_id, job_title,
    hourly_rate, pay_type, monthly_salary, employment_status
  ) values (
    p_organisation_id,
    trim(p_name),
    p_login_id,
    trim(p_job_title),
    case when p_pay_type = 'hourly' then p_salary_amount else 0 end,
    p_pay_type,
    case when p_pay_type = 'monthly' then p_salary_amount else null end,
    'active'
  )
  returning id into v_employee_id;

  insert into public.account_login_ids (login_id, user_id)
  values (p_login_id, v_user_id);

  insert into public.organisation_members (
    organisation_id, user_id, role, employee_id
  ) values (
    p_organisation_id, v_user_id, 'employee', v_employee_id
  );

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'user_id', v_user_id,
    'login_id', p_login_id
  );
end;
$$;

revoke all on function public.create_employee_account(
  uuid, text, text, text, text, numeric, text
) from public;
grant execute on function public.create_employee_account(
  uuid, text, text, text, text, numeric, text
) to authenticated;

drop function if exists public.add_organisation_member(
  uuid, text, text, uuid
);

create function public.add_organisation_member(
  p_organisation_id uuid,
  p_login_id text,
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
  if p_login_id is null or p_login_id !~ '^[0-9]{8}$' then
    raise exception 'Account ID must be exactly 8 digits.';
  end if;

  select account.user_id into target_user_id
  from public.account_login_ids account
  where account.login_id = p_login_id;

  if target_user_id is null then
    raise exception 'No account exists with this ID.';
  end if;

  if p_role = 'employee' then
    if p_employee_id is null or not exists (
      select 1 from public.employees employee
      where employee.id = p_employee_id
        and employee.organisation_id = p_organisation_id
        and employee.login_id = p_login_id
    ) then
      raise exception 'Choose the employee profile with the same ID.';
    end if;
  elsif p_employee_id is not null or not exists (
    select 1 from public.organisation_members member
    where member.organisation_id = p_organisation_id
      and member.user_id = target_user_id
      and member.role = 'employee'
  ) then
    raise exception 'Only an employee account in this organisation can be promoted to manager.';
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

revoke all on function public.add_organisation_member(uuid, text, text, uuid)
from public;
grant execute on function public.add_organisation_member(uuid, text, text, uuid)
to authenticated;

notify pgrst, 'reload schema';
