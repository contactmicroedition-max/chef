-- ==============================================================================
-- 007_create_employee_rpc.sql
-- Direct PostgreSQL Employee Creation & Authentication
-- No Edge Functions needed.
-- ==============================================================================

create extension if not exists pgcrypto with schema extensions;

-- 1. Auto-confirm all existing users in Supabase Auth
update auth.users
set email_confirmed_at = coalesce(email_confirmed_at, now()),
    confirmed_at = coalesce(confirmed_at, now())
where email_confirmed_at is null or confirmed_at is null;

-- 2. Auto-confirm any future user on signup (no email verification needed)
create or replace function public.auto_confirm_new_users()
returns trigger as $$
begin
  new.email_confirmed_at := coalesce(new.email_confirmed_at, now());
  new.confirmed_at := coalesce(new.confirmed_at, now());
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created_auto_confirm on auth.users;
create trigger on_auth_user_created_auto_confirm
before insert on auth.users
for each row execute function public.auto_confirm_new_users();

-- 3. RPC function: create_employee_account
-- The phone column is treated as a simple text ID (digits or lowercase string).
-- The login email is built as: emp-<ID>@chef.local
create or replace function public.create_employee_account(
  p_organisation_id uuid,
  p_name text,
  p_phone text,        -- Simple ID, stored trimmed and lowercase
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
  v_id text;
  v_email text;
  v_user_id uuid;
  v_employee_id uuid;
  v_encrypted_pw text;
begin
  -- Permission check: only the owner can create employees
  if not public.has_organisation_role(p_organisation_id, array['owner']) then
    raise exception 'Only the organisation owner can create employee accounts.';
  end if;

  -- Clean up the ID: trim and lowercase
  v_id := lower(trim(p_phone));
  if length(v_id) < 4 then
    raise exception 'Employee ID must be at least 4 characters.';
  end if;

  if length(p_password) < 6 then
    raise exception 'Password must be at least 6 characters.';
  end if;

  -- Build login email from the ID
  v_email := 'emp-' || v_id || '@chef.local';

  -- Hash the password with bcrypt (cost 10 standard for GoTrue)
  v_encrypted_pw := extensions.crypt(p_password, extensions.gen_salt('bf', 10));

  -- Check if this auth user already exists
  select id into v_user_id
  from auth.users
  where lower(email) = v_email
  limit 1;

  if v_user_id is not null then
    -- Update existing user's password and metadata
    update auth.users
    set encrypted_password = v_encrypted_pw,
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        confirmed_at = coalesce(confirmed_at, now()),
        raw_user_meta_data = jsonb_build_object('full_name', trim(p_name), 'phone', v_id),
        updated_at = now()
    where id = v_user_id;

    -- Refresh identity
    delete from auth.identities where user_id = v_user_id;
    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_user_id::text, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email),
      'email', v_user_id::text,
      now(), now(), now()
    );
  else
    -- Create new auth user
    v_user_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email,
      encrypted_password, email_confirmed_at, confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      is_super_admin, created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id, 'authenticated', 'authenticated', v_email,
      v_encrypted_pw, now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', trim(p_name), 'phone', v_id),
      false, now(), now()
    );

    -- Create identity record for GoTrue
    delete from auth.identities where user_id = v_user_id;
    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    ) values (
      v_user_id::text, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email),
      'email', v_user_id::text,
      now(), now(), now()
    );
  end if;

  -- Check for existing employee in this organisation
  select id into v_employee_id
  from public.employees
  where organisation_id = p_organisation_id
    and lower(phone) = v_id
  limit 1;

  if v_employee_id is not null then
    -- Update existing employee
    update public.employees
    set full_name = trim(p_name),
        phone = v_id,
        email = v_email,
        job_title = trim(p_job_title),
        pay_type = p_pay_type,
        hourly_rate = case when p_pay_type = 'hourly' then p_salary_amount else 0 end,
        monthly_salary = case when p_pay_type = 'monthly' then p_salary_amount else null end,
        employment_status = 'active'
    where id = v_employee_id;
  else
    -- Insert new employee
    insert into public.employees (
      organisation_id, full_name, email, phone, job_title,
      hourly_rate, pay_type, monthly_salary, employment_status
    ) values (
      p_organisation_id, trim(p_name), v_email, v_id, trim(p_job_title),
      case when p_pay_type = 'hourly' then p_salary_amount else 0 end,
      p_pay_type,
      case when p_pay_type = 'monthly' then p_salary_amount else null end,
      'active'
    )
    returning id into v_employee_id;
  end if;

  -- Link employee to organisation membership
  insert into public.organisation_members (
    organisation_id, user_id, role, employee_id
  ) values (
    p_organisation_id, v_user_id, 'employee', v_employee_id
  )
  on conflict (organisation_id, user_id)
  do update set role = 'employee', employee_id = v_employee_id;

  return jsonb_build_object(
    'employee_id', v_employee_id,
    'user_id', v_user_id,
    'id', v_id
  );
end;
$$;

revoke all on function public.create_employee_account from public;
grant execute on function public.create_employee_account to authenticated;
