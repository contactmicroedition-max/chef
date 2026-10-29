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
  const loginId = typeof input.login_id === "string" ? input.login_id.trim() : "";
  const password = typeof input.password === "string" ? input.password : "";
  if (!/^\d{8}$/.test(loginId) || !password) {
    return respond(400, { error: "Enter an 8-digit ID and password." });
  }

  const adminClient = createClient(supabaseUrl, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const loginClient = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: account, error: accountError } = await adminClient
    .from("account_login_ids")
    .select("user_id")
    .eq("login_id", loginId)
    .maybeSingle();

  if (accountError) {
    console.error("Could not resolve login ID:", accountError);
    return respond(500, { error: "Could not look up the account." });
  }
  if (!account) {
    return respond(401, { error: "ID or password is incorrect." });
  }

  const userId = account.user_id as string;
  const { data: userResult, error: userError } = await adminClient.auth.admin
    .getUserById(userId);

  if (userError || !userResult.user) {
    console.error("Could not load account:", userError);
    return respond(500, { error: "Could not load the account login." });
  }

  // Ensure email is confirmed so password sign-in never fails on verification
  if (!userResult.user.email_confirmed_at) {
    await adminClient.auth.admin.updateUserById(userId, { email_confirm: true });
  }

  const loginEmail = userResult.user.email;
  if (!loginEmail) {
    console.error("Account has no internal Auth alias:", userId);
    return respond(500, { error: "Could not load the account login." });
  }

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
    return respond(401, { error: "ID or password is incorrect." });
  }

  return respond(200, {
    access_token: authData.session.access_token,
    refresh_token: authData.session.refresh_token,
  });
});
