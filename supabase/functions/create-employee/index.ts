import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function respond(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getProjectKey(currentName: string, legacyName: string): string | null {
  const value = Deno.env.get(currentName);
  if (value) {
    try {
      const parsed: unknown = JSON.parse(value);
      if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
        const defaultKey = (parsed as Record<string, unknown>).default;
        if (typeof defaultKey === "string") return defaultKey;
      }
    } catch {
      return value;
    }
  }
  return Deno.env.get(legacyName) ?? null;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed." });
  }

  const authorization = request.headers.get("Authorization");
  const token = authorization?.replace(/^Bearer\s+/i, "");
  if (!token) return respond(401, { error: "Sign in as the organisation owner." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = getProjectKey(
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_ANON_KEY",
  );
  const serviceRoleKey = getProjectKey(
    "SUPABASE_SECRET_KEYS",
    "SUPABASE_SERVICE_ROLE_KEY",
  );
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Missing required Supabase function environment variables.");
    return respond(500, { error: "Employee account service is not configured." });
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await callerClient.auth.getUser(
    token,
  );
  if (userError || !userData.user) {
    return respond(401, { error: "The sign-in session is invalid or expired." });
  }

  let bodyValue: unknown;
  try {
    bodyValue = await request.json();
  } catch {
    return respond(400, { error: "Request body must be valid JSON." });
  }
  if (
    typeof bodyValue !== "object" ||
    bodyValue === null ||
    Array.isArray(bodyValue)
  ) {
    return respond(400, { error: "Request body must be a JSON object." });
  }
  const body = bodyValue as Record<string, unknown>;

  const organisationId = body.organisation_id;
  const name = typeof body.name === "string" ? body.name.trim() : "";
  const loginId = typeof body.login_id === "string"
    ? body.login_id.trim()
    : "";

  const jobTitle = typeof body.job_title === "string"
    ? body.job_title.trim()
    : "";
  const payType = body.pay_type;
  const salaryAmount = Number(body.salary_amount);
  const password = typeof body.password === "string" ? body.password : "";

  if (
    typeof organisationId !== "string" ||
    !name ||
    !/^\d{8}$/.test(loginId) ||
    !jobTitle ||
    (payType !== "hourly" && payType !== "monthly") ||
    !Number.isFinite(salaryAmount) ||
    salaryAmount <= 0 ||
    password.length < 6
  ) {
    return respond(400, {
      error:
        "Provide an organisation, name, 8-digit ID, job title, valid pay details, and a password of at least 6 characters.",
    });
  }

  const { data: membership, error: membershipError } = await adminClient
    .from("organisation_members")
    .select("role")
    .eq("organisation_id", organisationId)
    .eq("user_id", userData.user.id)
    .maybeSingle();

  if (membershipError) {
    console.error("Unable to check owner membership:", membershipError);
    return respond(500, { error: "Could not verify organisation permissions." });
  }
  if (membership?.role !== "owner") {
    return respond(403, { error: "Only the organisation owner can create employee accounts." });
  }

  // Create auth user with email_confirm: true so NO verification is ever needed!
  const loginEmail = `id-${loginId}@chef.local`;
  const { data: authData, error: authError } = await adminClient.auth.admin
    .createUser({
      email: loginEmail,
      password,
      email_confirm: true,
      user_metadata: { full_name: name, login_id: loginId },
    });

  if (authError || !authData.user) {
    return respond(400, {
      error: authError?.message ?? "Could not create the employee login.",
    });
  }

  let employeeId: string | null = null;
  try {
    const { data: employee, error: employeeError } = await adminClient
      .from("employees")
      .insert({
        organisation_id: organisationId,
        full_name: name,
        login_id: loginId,
        job_title: jobTitle,
        hourly_rate: payType === "hourly" ? salaryAmount : 0,
        pay_type: payType,
        monthly_salary: payType === "monthly" ? salaryAmount : null,
        employment_status: "active",
      })
      .select("id")
      .single();

    if (employeeError || !employee) {
      throw employeeError ?? new Error("Could not create the employee profile.");
    }
    employeeId = employee.id;

    const { error: accountIdError } = await adminClient
      .from("account_login_ids")
      .insert({ login_id: loginId, user_id: authData.user.id });
    if (accountIdError) throw accountIdError;

    const { error: linkError } = await adminClient
      .from("organisation_members")
      .insert({
        organisation_id: organisationId,
        user_id: authData.user.id,
        role: "employee",
        employee_id: employeeId,
      });

    if (linkError) throw linkError;
    return respond(201, { employee_id: employeeId, login_id: loginId });
  } catch (error) {
    const cleanupErrors: string[] = [];
    const { error: deleteLoginIdError } = await adminClient
      .from("account_login_ids")
      .delete()
      .eq("user_id", authData.user.id);
    if (deleteLoginIdError) cleanupErrors.push(deleteLoginIdError.message);
    if (employeeId) {
      const { error: deleteEmployeeError } = await adminClient
        .from("employees")
        .delete()
        .eq("id", employeeId);
      if (deleteEmployeeError) {
        cleanupErrors.push(deleteEmployeeError.message);
      }
    }
    const { error: deleteUserError } = await adminClient.auth.admin
      .deleteUser(authData.user.id);
    if (deleteUserError) cleanupErrors.push(deleteUserError.message);
    if (cleanupErrors.length > 0) {
      console.error("Employee creation rollback failed:", cleanupErrors);
    }
    const message = error instanceof Error ? error.message : String(error);
    console.error("Employee account creation failed:", message);
    return respond(500, {
      error: cleanupErrors.length
        ? "Employee creation failed and cleanup needs administrator attention."
        : "Could not finish creating the employee account.",
    });
  }
});
