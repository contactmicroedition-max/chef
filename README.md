# CHEF

Flutter employee management and payroll app for small businesses.

## Secure Supabase setup

1. Copy `.env.example` to `.env`.
2. Fill in your project values from the Supabase dashboard:
   - Project URL: `https://bcnguysnegveixtctjjz.supabase.co`
   - Anon key: Project Settings > API > `anon public`
3. Keep `.env` local and never commit it. It is already ignored by `.gitignore`.
4. Put only the project URL and publishable/anon key in `.env`. Flutter assets
   are bundled into the application; never put a database password or service
   role/secret key in `.env`.

Example `.env`:

```env
SUPABASE_URL=https://bcnguysnegveixtctjjz.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

## Test project reachability

From a terminal:

```bash
curl -I https://bcnguysnegveixtctjjz.supabase.co
```

You should see an HTTP response from Supabase. For API calls, use the project URL plus the anon key from the dashboard, and keep any service-role key server-only.

## Run locally

```bash
flutter pub get
flutter run
```

## Authentication and organisation roles

Owners sign in with an 8-digit ID and password. Owner signup asks for the
owner's name, ID, password, and organisation name. When creating an employee,
the owner enters the employee's name, login email, password, job title, and pay
details. The email is generated from the employee and organisation names (for
example, `john_smith@tunis-cafe.tn`) and can be edited. If an address is already
in use, the app adds a number to make it unique. Employees sign in with that
email and the password set by the owner; they do not need phone verification.
The generated `.tn` address is an app login address, not necessarily a real
mailbox that can receive messages.

Supabase Auth confirms employee login addresses when their accounts are
created, so employees can sign in without SMS or email confirmation. Owners
continue to use the existing 8-digit ID login flow.

Before using the new account flow, run the SQL files in Supabase Dashboard >
SQL Editor in order. In the Supabase Dashboard for your project, open **SQL
Editor > New query**, open each file below in VS Code, copy its full contents
into the query editor, and click **Run**. Run one file at a time in this order:
[`supabase/migrations/001_initial_schema.sql`](./supabase/migrations/001_initial_schema.sql),
[`supabase/migrations/002_auth_roles_and_rls.sql`](./supabase/migrations/002_auth_roles_and_rls.sql),
[`supabase/migrations/003_push_tokens_and_shift_guard.sql`](./supabase/migrations/003_push_tokens_and_shift_guard.sql),
[`supabase/migrations/004_employee_pay_types_and_phone_login.sql`](./supabase/migrations/004_employee_pay_types_and_phone_login.sql),
[`supabase/migrations/005_normalize_employee_phone_ids.sql`](./supabase/migrations/005_normalize_employee_phone_ids.sql),
[`supabase/migrations/007_create_employee_rpc.sql`](./supabase/migrations/007_create_employee_rpc.sql),
[`supabase/migrations/008_id_based_accounts.sql`](./supabase/migrations/008_id_based_accounts.sql),
and
[`supabase/migrations/009_employee_email_logins.sql`](./supabase/migrations/009_employee_email_logins.sql).
If migrations 001–007 are already applied, apply migrations 008 and 009. If
migration 008 has already been applied, apply only migration 009. Migration 008 removes
`employees.email`, renames the employee phone field to `employees.login_id`,
creates the private account-ID mapping, and updates the account-creation RPCs.
Dropping `employees.email` permanently deletes values in that column, so
export them first if you still need them. The migration imports IDs from
linked employees when they are already exactly 8 digits. Resolve duplicate
linked IDs before running it if the migration reports a conflict.

The migration does not convert existing owner email accounts into ID accounts.
Owners should create new accounts through the new signup screen. Linked
employee accounts with 8-digit IDs are imported into the ID registry; accounts
created through older login methods may need their password/account reset by
an administrator.
Migration 009 adds the employee login email field and updates employee account
storage and manager assignment to accept email addresses while preserving
legacy ID sign-in. Deploy the employee account Edge Function after applying the
migration: `supabase functions deploy create-employee`. It creates employee
users through Supabase Auth's supported admin API, confirms the login email,
then links the employee profile and membership. Deploy the updated function
each time its source changes.

Hourly salary is calculated as the hourly rate times hours recorded in the
current calendar month. Monthly-salary employees receive the fixed amount
entered by the owner; clocked hours are displayed for reference only. The
employee's remaining monthly pay subtracts that month's advances and recorded
payments. The Salaries screen lists each employee's rate or monthly salary and
their advances with timestamps.

Managers can record advances for active employees from the **Give advance**
button on the employee card. The app records the amount and timestamp; the
employee can view their own advance history and timestamp in their panel.

### Enable owner push notifications and employee clock-in/out

The employee Attendance screen provides **Clock in** and **Clock out**. Times
are recorded by the server, only for the signed-in employee, and only one open
shift is allowed at a time. Each successful action sends a push notification
to the organisation owner. Deploy the attendance function with
`supabase functions deploy employee-attendance`. Push delivery requires Firebase
setup:

1. In Firebase Console, add an Android app with package name
   `com.example.zone`. The downloaded file is configured at
   `android/app/google-services.json`. The Android app initializes Firebase
   automatically; the extra copies in the project root and `android/` are not
   used by the build.
2. Ensure the Firebase Cloud Messaging API is enabled. Create/download a
   Firebase service-account JSON with permission to send
   Firebase Cloud Messaging messages. In Supabase Dashboard > Edge Function
   Secrets, create `FIREBASE_SERVICE_ACCOUNT_JSON` and paste the full JSON
   there. Never commit or share this private key.
3. Rebuild and install the app. The owner must sign in on their Android device
   and allow notifications once so CHEF can register that device for pushes.
   The employee can then clock in/out; the owner receives notifications even
   when CHEF is closed. Push text is generic and does not include the
   employee's name or shift time.

The attendance is still saved if FCM is not configured or no owner device has
registered. The employee sees a message that notification delivery failed; set
up Firebase and have the owner sign in again to enable delivery.

An owner can promote an employee account to manager using the employee's
8-digit ID and the role button in Employees. The app does not provide email
password-reset links; keep the login ID and password safe.

Owners and managers enter the management panel. Employees are routed to their
own panel; employee profile, attendance, advances, and payments are filtered
again by RLS in PostgreSQL. If a valid account cannot load organisation data,
check that migration `002` has been run and that the user has an
`organisation_members` row with the correct role.

For quick role-path testing, create an owner account and organisation, then
create an employee login from the Employees screen. Sign out and sign in with
the employee's 8-digit ID and password entered by the owner.
The owner/manager should see the management navigation; the employee should
only see their own panel, attendance, and advances.
#
