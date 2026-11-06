# CHEF project handover

## Project summary
CHEF is a Flutter-based employee management and payroll app for small businesses. It combines a mobile app front end with Supabase Auth, Postgres/RLS, Edge Functions, and Firebase Cloud Messaging for staff attendance, payroll, organisation management, and role-based access.

The application is structured around a role-based workflow:
- Owners can manage the organisation, employees, attendance reviews, payroll, and settings.
- Managers can access management features with a limited role.
- Employees are routed to a dedicated employee panel and only see their own data.

## Key stack
- Flutter + Dart
- Riverpod state management
- Go Router
- Supabase Flutter client
- Supabase Postgres + Row Level Security
- Supabase Edge Functions for employee creation and attendance processing
- Firebase Cloud Messaging for push notifications

## Entry points and app structure
- `lib/main.dart` initializes environment variables, Firebase push support, and Supabase.
- `lib/app/app.dart` bootstraps the app shell and locale/theme configuration.
- `lib/app/router.dart` defines route guards and navigation for splash/login/register/home.
- `lib/providers/app_state.dart` holds the central app state, authentication state, organisation selection, and profile loading logic.
- `lib/app/home_shell.dart` contains the main tabbed workspace for owners/managers/employees.

## Feature map
- `lib/features/auth/` – login, registration, auth helpers, ID/email/phone login handling
- `lib/features/organisations/` – organisation creation, zone setup, switching organisations, role assignment
- `lib/features/employees/` – employee records, shift management, advances, role promotion
- `lib/features/attendance/` – clock-in/clock-out, approval flow, attendance records and shift-linked review
- `lib/features/payroll/` – salaries, advances, payments, monthly vs hourly pay calculations
- `lib/features/dashboard/` – dashboard and worker panel screens
- `lib/features/settings/` – settings screen and user controls
- `lib/services/push/` – Firebase push notification service
- `lib/core/` – shared config, formatting, and widgets

## Working data model and auth flows
The product supports multiple login styles:
- Owner accounts can use an 8-digit ID and password.
- Employee credentials are created by the owner and may include a generated email login (`name_org@domain` style), with the app supporting editable addresses.
- Legacy ID-based flows and phone/email login variants are normalized in the auth repository.

Important app behaviour from the project README:
- Owners create employees by entering their name, email/login, password, job title, and pay details.
- Employees log in using the generated email and password, not with phone verification.
- Owners continue through the 8-digit ID login flow.
- The app enforces organisation membership and role checks via Supabase RLS.

## Supabase and database setup
The project depends on a series of Supabase SQL migrations in `supabase/migrations/`.

Core migrations:
1. `001_initial_schema.sql`
2. `002_auth_roles_and_rls.sql`
3. `003_push_tokens_and_shift_guard.sql`
4. `004_employee_pay_types_and_phone_login.sql`
5. `005_normalize_employee_phone_ids.sql`
6. `007_create_employee_rpc.sql`
7. `008_id_based_accounts.sql`
8. `009_employee_email_logins.sql`

Follow-up attendance/shift related migrations:
- `20261031141500_organisation_zones.sql`
- `20261031150000_employee_attendance_zone_gate.sql`
- `20261103220000_organisation_shifts.sql`
- `20261103220700_employee_shift_assignment.sql`
- `20261103221500_shift_attendance_approval.sql`
- `20261103224100_attendance_actual_shift.sql`
- `20261104001000_attendance_shift_review_fixes.sql`

Important migration notes from the README:
- Run migrations in order and do not re-run ones already applied.
- Migration 008 permanently removes `employees.email`; export existing values first if needed.
- Migration 009 adds employee login email support and requires the `create-employee` Edge Function to be deployed.
- Shift and attendance logic is tightly coupled: the app expects active organisational shifts, approval flows, and shift assignment metadata to exist in the database.

## Edge functions and backend services
The app expects these backend functions/services to be active:
- `supabase/functions/create-employee/index.ts`
- `supabase/functions/employee-attendance/index.ts`
- `supabase/functions/employee-login/index.ts`

The README calls out the deployment flow:
- Deploy the employee creation function after migration 009.
- Deploy the updated attendance function after the attendance review fix migrations.

## Push notification and Firebase setup
Push notifications are part of the attendance review and approval flow.

The app expects Firebase to be configured for Android:
1. Add an Android app with package name `com.example.zone`.
2. Download the Firebase `google-services.json` and place it in the Android config path used by the project.
3. Enable the Firebase Cloud Messaging API.
4. Add a Firebase service account JSON in Supabase Edge Function secrets as `FIREBASE_SERVICE_ACCOUNT_JSON`.

Never commit the service account JSON or any secret material.

## Local run guide
From the project root:

```bash
flutter pub get
flutter run
```

Before first use, set up the local environment file:

```bash
cp .env.example .env
```

Then populate `.env` with:

```env
SUPABASE_URL=https://<project>.supabase.co
SUPABASE_ANON_KEY=<anon-public-key>
```

Important:
- Keep `.env` local and uncommitted.
- Do not put secret or service-role keys in the Flutter app.
- Use only the project URL and anon key in the client app.

## Common operational notes
- The app uses the current Supabase Auth session to determine the authenticated user and redirects based on auth state.
- Route redirection is managed in `lib/app/router.dart`.
- Organisation selection is dynamic; the app can switch between multiple organisations when the current user belongs to more than one.
- Employees and managers are filtered by role and database RLS; invalid organisation membership typically points to missing migration setup or missing membership rows.
- Attendance is saved even if FCM is unavailable; notifications may fail silently if the recipient device is not registered.

## Known gotchas / risks to watch
- Supabase email confirmation settings can block auth flows if email sign-up is configured with confirmation enabled.
- Migration ordering matters. The README explicitly warns not to re-run already applied SQL.
- The app assumes organisation shift records exist before clock-ins and attendance approvals can work.
- The app expects an active shift configuration plus valid work-zone setup for attendance validation.
- Some features rely on Firebase push delivery and recipient device registration; if that is missing, approval notifications may not reach users.

## Recommended next steps for handoff
1. Verify the Supabase project is live and the migrations are all applied in the correct order.
2. Confirm `.env` values are set for the live project and the app launches without auth errors.
3. Deploy the relevant Edge Functions: `create-employee` and any attendance function revisions.
4. Validate a realistic owner flow: create organisation, create employee, login as employee, record clock-in/out, and review attendance.
5. Check Firebase push registration on devices participating in approval flows.
6. Run a final smoke test for the main management screens: Dashboard, Employees, Attendance, Salaries, Organisations, Settings.

## Files worth checking first when continuing work
- `README.md` – most current product + setup instructions
- `lib/main.dart` – app bootstrap and env initialization
- `lib/app/router.dart` – route/auth flow
- `lib/providers/app_state.dart` – central app state and auth lifecycle
- `lib/features/auth/data/auth_repository.dart` – login and registration logic
- `lib/features/attendance/data/attendance_repository.dart` – employee clock-in/out and approval logic
- `supabase/migrations/` – database contract and required schema evolution

## Handover summary
This project is a production-style internal business app with a strong Supabase backend contract. The biggest risks are configuration drift (Supabase migrations, Firebase setup, secret management) and auth/attendance behaviour depending on correct database state. The app is serviceable but any continuation work should start with the README, then the auth, organisation, and attendance flows, and only then move into payroll or UI refinement.
