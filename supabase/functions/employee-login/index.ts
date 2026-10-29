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

function normalizePhone(value: string): string {
  let phone = value.replace(/\D/g, "");
  if (phone.startsWith("00216")) phone = phone.slice(5);
  else if (phone.startsWith("00")) phone = phone.slice(2);
  if (phone.startsWith("216") && phone.length > 8) phone = phone.slice(3);
  return phone;
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return respond(405, { error: "Method not allowed." });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = getProjectKey(
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_ANON_KEY",
  );
  const secretKey = getProjectKey(
    "SUPABASE_SECRET_KEYS",
    "SUPABASE_SERVICE_ROLE_KEY",
  );
  if (!supabaseUrl || !publishableKey || !secretKey) {
    console.error("Missing required Supabase function environment variables.");
    return respond(500, { error: "Employee sign-in is not configured." });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return respond(400, { error: "Request body must be valid JSON." });
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return respond(400, { error: "Request body must be a JSON object." });
  }

  const input = body as Record<string, unknown>;
  const phone = typeof input.phone === "string" ? normalizePhone(input.phone) : "";
  const password = typeof input.password === "string" ? input.password : "";
  if (!/^\d{8,15}$/.test(phone) || !password) {
    return respond(400, { error: "Enter a valid phone ID and password." });
  }

  const adminClient = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const loginClient = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Match pure phone or phone with prefix
  const candidatePhones = [phone, `216${phone}`, `+216${phone}`];
  const { data: employees, error: employeeError } = await adminClient
    .from("employees")
    .select("id, phone")
    .in("phone", candidatePhones);

  if (employeeError) {
    console.error("Could not find employee by phone ID:", employeeError);
    return respond(500, { error: "Could not look up the employee account." });
  }
  if (!employees || employees.length === 0) {
    return respond(401, { error: "Phone ID or password is incorrect." });
  }

  const employeeIds = employees.map((employee) => employee.id as string);
  const { data: memberships, error: membershipError } = await adminClient
    .from("organisation_members")
    .select("user_id")
    .in("employee_id", employeeIds)
    .eq("role", "employee");

  if (membershipError) {
    console.error("Could not resolve employee login account:", membershipError);
    return respond(500, { error: "Could not look up the employee account." });
  }
  const userIds = [...new Set((memberships ?? []).map(
    (membership) => membership.user_id as string,
  ))];

  if (userIds.length !== 1) {
    return respond(
      userIds.length === 0 ? 401 : 409,
      {
        error: userIds.length === 0
          ? "Phone ID or password is incorrect."
          : "This phone ID is linked to more than one employee login. Ask the owner to correct the employee records.",
      },
    );
  }

  const userId = userIds[0];
  const { data: userResult, error: userError } = await adminClient.auth.admin
    .getUserById(userId);

  if (userError || !userResult.user) {
    console.error("Could not load employee auth account:", userError);
    return respond(500, { error: "Could not load the employee login." });
  }

  // Ensure email is confirmed so password sign-in never fails on verification
  if (!userResult.user.email_confirmed_at) {
    await adminClient.auth.admin.updateUserById(userId, { email_confirm: true });
  }

  const loginEmail = userResult.user.email ?? `employee-${phone}@employee-login.invalid`;

  const { data: authData, error: authError } = await loginClient.auth
    .signInWithPassword({ email: loginEmail, password });

  if (authError || !authData.session) {
    // If sign-in failed, attempt legacy fallback
    const legacyPhone = userResult.user.phone;
    if (legacyPhone) {
      const { data: legacyAuthData, error: legacyAuthError } = await loginClient
        .auth.signInWithPassword({ phone: legacyPhone, password });
      if (legacyAuthData?.session) {
        return respond(200, {
          access_token: legacyAuthData.session.access_token,
          refresh_token: legacyAuthData.session.refresh_token,
        });
      }
    }
    return respond(401, { error: "Phone ID or password is incorrect." });
  }

  return respond(200, {
    access_token: authData.session.access_token,
    refresh_token: authData.session.refresh_token,
  });
});
