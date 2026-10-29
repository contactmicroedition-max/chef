import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type FirebaseServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
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
      if (
        typeof parsed === "object" &&
        parsed !== null &&
        !Array.isArray(parsed)
      ) {
        const defaultKey = (parsed as Record<string, unknown>).default;
        if (typeof defaultKey === "string") return defaultKey;
      }
    } catch {
      return value;
    }
  }
  return Deno.env.get(legacyName) ?? null;
}

function localShiftDate(value: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(value);
  const dateParts = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  return `${dateParts.year}-${dateParts.month}-${dateParts.day}`;
}

async function getFirebaseAccessToken(
  account: FirebaseServiceAccount,
): Promise<string> {
  const privateKey = await importPKCS8(
    account.private_key.replace(/\\n/g, "\n"),
    "RS256",
  );
  const assertion = await new SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(account.client_email)
    .setSubject(account.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt()
    .setExpirationTime("1h")
    .sign(privateKey);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const result = await response.json();
  if (!response.ok || typeof result.access_token !== "string") {
    throw new Error("Google did not issue an FCM access token.");
  }
  return result.access_token;
}

async function notifyOwners(
  adminClient: ReturnType<typeof createClient>,
  organisationId: string,
  action: "clock_in" | "clock_out",
): Promise<{ sent: boolean; message: string }> {
  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    console.error("FCM is not configured: Firebase service account secret is missing.");
    return { sent: false, message: "FCM is not configured on the server." };
  }

  let account: FirebaseServiceAccount;
  try {
    account = JSON.parse(serviceAccountJson) as FirebaseServiceAccount;
  } catch (error) {
    console.error("Firebase service account secret is not valid JSON:", error);
    return { sent: false, message: "FCM server configuration is invalid." };
  }
  if (!account.client_email || !account.private_key || !account.project_id) {
    console.error("Firebase service account secret is missing required fields.");
    return { sent: false, message: "FCM server configuration is incomplete." };
  }

  const { data: owners, error: ownersError } = await adminClient
    .from("organisation_members")
    .select("user_id")
    .eq("organisation_id", organisationId)
    .eq("role", "owner");
  if (ownersError) {
    console.error("Could not load organisation owners for push:", ownersError);
    return { sent: false, message: "Could not load the owner notification target." };
  }
  const ownerIds = (owners ?? []).map((owner) => owner.user_id as string);
  if (ownerIds.length === 0) {
    return { sent: false, message: "No owner account is linked to this organisation." };
  }

  const { data: devices, error: devicesError } = await adminClient
    .from("user_push_tokens")
    .select("token")
    .in("user_id", ownerIds);
  if (devicesError) {
    console.error("Could not load owner push devices:", devicesError);
    return { sent: false, message: "Could not load owner notification devices." };
  }
  const tokens = [...new Set((devices ?? []).map((device) => device.token as string))];
  if (tokens.length === 0) {
    return {
      sent: false,
      message: "No owner device has registered for push notifications yet.",
    };
  }

  try {
    const accessToken = await getFirebaseAccessToken(account);
    const results = await Promise.all(
      tokens.map(async (token) => {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token,
                notification: {
                  title: "CHEF attendance update",
                  body: action === "clock_in"
                    ? "An employee clocked in."
                    : "An employee clocked out.",
                },
                android: { priority: "HIGH" },
              },
            }),
          },
        );
        if (!response.ok) {
          const errorBody = await response.text();
          console.error("FCM rejected an owner notification:", errorBody);
          return false;
        }
        return true;
      }),
    );
    const sentCount = results.filter(Boolean).length;
    return sentCount > 0
      ? { sent: true, message: `Notification sent to ${sentCount} owner device(s).` }
      : { sent: false, message: "FCM could not deliver to any owner device." };
  } catch (error) {
    console.error("Owner push notification failed:", error);
    return { sent: false, message: "The owner push notification could not be sent." };
  }
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
  if (!token) return respond(401, { error: "Sign in to record your shift." });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = getProjectKey(
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_ANON_KEY",
  );
  const secretKey = getProjectKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !publishableKey || !secretKey) {
    console.error("Missing required Supabase function environment variables.");
    return respond(500, { error: "Attendance service is not configured." });
  }

  const callerClient = createClient(supabaseUrl, publishableKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const adminClient = createClient(supabaseUrl, secretKey, {
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
  const action = body.action;
  if (
    typeof organisationId !== "string" ||
    (action !== "clock_in" && action !== "clock_out")
  ) {
    return respond(400, { error: "Provide an organisation and valid clock action." });
  }

  const { data: membership, error: membershipError } = await adminClient
    .from("organisation_members")
    .select("employee_id")
    .eq("organisation_id", organisationId)
    .eq("user_id", userData.user.id)
    .eq("role", "employee")
    .maybeSingle();
  if (membershipError) {
    console.error("Could not verify employee membership:", membershipError);
    return respond(500, { error: "Could not verify employee permissions." });
  }
  if (!membership?.employee_id) {
    return respond(403, { error: "This account is not linked to an employee profile." });
  }

  const { data: employee, error: employeeError } = await adminClient
    .from("employees")
    .select("id, full_name, employment_status")
    .eq("id", membership.employee_id)
    .eq("organisation_id", organisationId)
    .maybeSingle();
  if (employeeError) {
    console.error("Could not load employee profile:", employeeError);
    return respond(500, { error: "Could not load the employee profile." });
  }
  if (!employee || employee.employment_status !== "active") {
    return respond(403, { error: "Only active employees can record shifts." });
  }

  const { data: organisation, error: organisationError } = await adminClient
    .from("organisations")
    .select("timezone")
    .eq("id", organisationId)
    .single();
  if (organisationError) {
    console.error("Could not load organisation timezone:", organisationError);
    return respond(500, { error: "Could not load organisation settings." });
  }

  const { data: openShift, error: openShiftError } = await adminClient
    .from("attendance_records")
    .select("id, clock_in")
    .eq("organisation_id", organisationId)
    .eq("employee_id", employee.id)
    .is("clock_out", null)
    .maybeSingle();
  if (openShiftError) {
    console.error("Could not check the employee's open shift:", openShiftError);
    return respond(500, { error: "Could not check the current shift." });
  }
  if (action === "clock_in" && openShift) {
    return respond(409, { error: "You already have an open shift. Clock out first." });
  }
  if (action === "clock_out" && !openShift) {
    return respond(409, { error: "There is no open shift to clock out from." });
  }

  const now = new Date();
  const timestamp = now.toISOString();
  const shift = action === "clock_in"
    ? await adminClient
      .from("attendance_records")
      .insert({
        organisation_id: organisationId,
        employee_id: employee.id,
        shift_date: localShiftDate(now, organisation.timezone || "UTC"),
        clock_in: timestamp,
        status: "approved",
      })
      .select("id")
      .single()
    : await adminClient
      .from("attendance_records")
      .update({ clock_out: timestamp })
      .eq("id", openShift!.id)
      .is("clock_out", null)
      .select("id")
      .maybeSingle();

  if (shift.error || !shift.data) {
    console.error("Could not record employee shift:", shift.error);
    if (!shift.data && !shift.error) {
      return respond(409, { error: "The shift was already changed. Refresh and try again." });
    }
    return respond(
      shift.error?.code === "23505" ? 409 : 500,
      {
        error: shift.error?.code === "23505"
          ? "A shift was started already. Refresh and try again."
          : "Could not record the shift.",
      },
    );
  }

  const notification = await notifyOwners(
    adminClient,
    organisationId,
    action,
  );
  return respond(200, {
    attendance_id: shift.data.id,
    action,
    notification_sent: notification.sent,
    notification_message: notification.message,
  });
});
