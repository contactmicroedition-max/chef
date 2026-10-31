alter table public.employees
  add column if not exists login_email text;

create unique index if not exists employees_login_email_unique
  on public.employees (lower(login_email))
  where login_email is not null;

drop function if exists public.create_employee_account(
  uuid, text, text, text, text, numeric, text
);

create function public.create_employee_account(
  p_organisation_id uuid,
  p_name text,
  p_login_email text,
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
  v_local_part text;
  v_domain text;
  v_suffix integer := 2;
begin
  if not public.has_organisation_role(p_organisation_id, array['owner']) then
    raise exception 'Only the organisation owner can create employee accounts.';
  end if;
  if nullif(trim(p_name), '') is null
    or nullif(trim(p_job_title), '') is null then
    raise exception 'Employee name and job title are required.';
  end if;
  if p_login_email is null
    or p_login_email !~* '^[a-z0-9._%+-]+@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$' then
    raise exception 'Enter a valid employee email address.';
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

  v_email := lower(trim(p_login_email));
  v_local_part := split_part(v_email, '@', 1);
  v_domain := split_part(v_email, '@', 2);

  loop
    if not exists (
      select 1 from auth.users where lower(email) = v_email
    ) then
      v_user_id := gen_random_uuid();
      begin
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
            'login_email', v_email
          ),
          false, now(), now()
        );
        exit;
      exception when unique_violation then
        v_email := v_local_part || v_suffix || '@' || v_domain;
        v_suffix := v_suffix + 1;
      end;
    else
      v_email := v_local_part || v_suffix || '@' || v_domain;
      v_suffix := v_suffix + 1;
    end if;

    if v_suffix > 10000 then
      raise exception 'Could not generate a unique employee email address.';
    end if;
  end loop;

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
    organisation_id, full_name, login_email, job_title,
    hourly_rate, pay_type, monthly_salary, employment_status
  ) values (
    p_organisation_id,
    trim(p_name),
    v_email,
    trim(p_job_title),
    case when p_pay_type = 'hourly' then p_salary_amount else 0 end,
    p_pay_type,
    case when p_pay_type = 'monthly' then p_salary_amount else null end,
    'active'
  )
  returning id into v_employee_id;

  insert into public.organisation_members (
    organisation_id, user_id, role, employee_id
  ) values (
    p_organisation_id, v_user_id, 'employee', v_employee_id
  );

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'user_id', v_user_id,
    'login_email', v_email
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
  p_login_identifier text,
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
    raise exception 'Only the organisation owner can assign roles';
  end if;
  if p_role not in ('manager', 'employee') then
    raise exception 'Role must be manager or employee';
  end if;

  if p_login_identifier ~ '^[0-9]{8}$' then
    select account.user_id into target_user_id
    from public.account_login_ids account
    where account.login_id = p_login_identifier;
  else
    select auth_user.id into target_user_id
    from auth.users auth_user
    where lower(auth_user.email) = lower(trim(p_login_identifier))
    limit 1;
  end if;

  if target_user_id is null then
    raise exception 'No account exists with this ID or email.';
  end if;

  if p_role = 'employee' then
    if p_employee_id is null or not exists (
      select 1 from public.employees employee
      where employee.id = p_employee_id
        and employee.organisation_id = p_organisation_id
        and (
          employee.login_id = p_login_identifier
          or lower(employee.login_email) = lower(trim(p_login_identifier))
        )
    ) then
      raise exception 'Choose the employee profile with the same ID or email.';
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
