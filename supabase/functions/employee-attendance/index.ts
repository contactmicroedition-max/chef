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

function localSecondOfDay(value: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat("en", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(value);
  const timeParts = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  return (
    Number(timeParts.hour) * 3600 +
    Number(timeParts.minute) * 60 +
    Number(timeParts.second)
  );
}

function timeToSecondOfDay(value: string): number {
  const [hour, minute, second = 0] = value.split(":").map(Number);
  if (
    !Number.isInteger(hour) ||
    !Number.isInteger(minute) ||
    !Number.isInteger(second) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59
  ) {
    throw new Error("The assigned shift has an invalid time.");
  }
  return hour * 3600 + minute * 60 + second;
}

function isCurrentlyWithinShift(
  now: Date,
  timeZone: string,
  startTime: string,
  endTime: string,
): boolean {
  const localSecond = localSecondOfDay(now, timeZone);
  return localSecond >= timeToSecondOfDay(startTime) &&
    localSecond <= timeToSecondOfDay(endTime);
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

async function notifyAdmins(
  adminClient: ReturnType<typeof createClient>,
  organisationId: string,
  action: "clock_in" | "clock_out",
  approvalStatus: "pending" | "approved",
  employeeUserId: string,
  mismatchDetails?: {
    employeeName: string;
    assignedShiftName: string;
    currentShiftName: string;
  },
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

  const { data: admins, error: adminsError } = await adminClient
    .from("organisation_members")
    .select("user_id")
    .eq("organisation_id", organisationId)
    .in("role", ["owner", "manager"]);
  if (adminsError) {
    console.error("Could not load organisation admins for push:", adminsError);
    return { sent: false, message: "Could not load admin notification targets." };
  }
  const adminIds = [
    ...new Set((admins ?? []).map((admin) => admin.user_id as string)),
  ];
  const notifyEmployee =
    action === "clock_in" && approvalStatus === "pending";
  if (adminIds.length === 0 && !notifyEmployee) {
    return { sent: false, message: "No admin account is linked to this organisation." };
  }
  const notificationUserIds = [
    ...new Set([
      ...adminIds,
      ...(notifyEmployee ? [employeeUserId] : []),
    ]),
  ];
  if (notificationUserIds.length === 0) {
    return { sent: false, message: "No notification recipients are available." };
  }

  const { data: devices, error: devicesError } = await adminClient
    .from("user_push_tokens")
    .select("token, user_id")
    .in("user_id", notificationUserIds);
  if (devicesError) {
    console.error("Could not load attendance push devices:", devicesError);
    return { sent: false, message: "Could not load notification devices." };
  }
  const uniqueDevices = [
    ...new Map(
      (devices ?? []).map((device) => [
        device.token as string,
        { token: device.token as string, userId: device.user_id as string },
      ]),
    ).values(),
  ];
  if (uniqueDevices.length === 0) {
    return {
      sent: false,
      message: "No recipient device has registered for push notifications yet.",
    };
  }

  try {
    const accessToken = await getFirebaseAccessToken(account);
    const results = await Promise.all(
      uniqueDevices.map(async (device) => {
        const isEmployeeAlert = device.userId === employeeUserId &&
          action === "clock_in" && approvalStatus === "pending";
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
                token: device.token,
                notification: {
                  title: isEmployeeAlert
                    ? "Clock-in outside your assigned shift"
                    : action === "clock_in" && approvalStatus === "pending"
                    ? "Attendance needs approval"
                    : "CHEF attendance update",
                  body: isEmployeeAlert
                    ? `You are assigned to ${mismatchDetails?.assignedShiftName ?? "another shift"}, but clocked in during ${mismatchDetails?.currentShiftName ?? "a different shift"}. Your attendance needs admin approval.`
                    : action === "clock_in" && approvalStatus === "pending"
                    ? `${mismatchDetails?.employeeName ?? "An employee"} is assigned to ${mismatchDetails?.assignedShiftName ?? "another shift"} but clocked in during ${mismatchDetails?.currentShiftName ?? "a different shift"}. Review attendance.`
                    : action === "clock_in"
                    ? "An employee clocked in."
                    : "An employee clocked out.",
                },
                data: {
                  organisation_id: organisationId,
                  action,
                  approval_status: approvalStatus,
                },
                android: { priority: "HIGH" },
              },
            }),
          },
        );
        if (!response.ok) {
          const errorBody = await response.text();
          console.error("FCM rejected an attendance notification:", errorBody);
          return false;
        }
        return true;
      }),
    );
    const sentCount = results.filter(Boolean).length;
    return sentCount > 0
      ? {
          sent: true,
          message: `Notification sent to ${sentCount} device(s).`,
        }
      : { sent: false, message: "FCM could not deliver to any recipient device." };
  } catch (error) {
    console.error("Attendance push notification failed:", error);
    return { sent: false, message: "Attendance push notifications could not be sent." };
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
    global: { headers: { Authorization: `Bearer ${token}` } },
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
  const coordinates =
    typeof body.latitude === "number" && typeof body.longitude === "number"
      ? { latitude: body.latitude, longitude: body.longitude }
      : null;
  if (
    typeof organisationId !== "string" ||
    (action !== "clock_in" && action !== "clock_out") ||
    (action === "clock_in" &&
      (!coordinates ||
        !Number.isFinite(coordinates.latitude) ||
        !Number.isFinite(coordinates.longitude) ||
        coordinates.latitude < -90 ||
        coordinates.latitude > 90 ||
        coordinates.longitude < -180 ||
        coordinates.longitude > 180))
  ) {
    return respond(400, {
      error: "Provide an organisation, valid clock action, and clock-in location.",
    });
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
    .select("id, full_name, employment_status, shift_id")
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
  if (action === "clock_in" && !employee.shift_id) {
    return respond(409, {
      error: "You need an assigned shift before you can clock in. Contact an admin.",
    });
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

  if (action === "clock_in") {
    if (!coordinates) {
      return respond(400, { error: "Current location is required to clock in." });
    }
    const { data: zoneStatus, error: zoneError } = await callerClient.rpc(
      "get_employee_work_zone_status",
      {
        p_organisation_id: organisationId,
        p_latitude: coordinates.latitude,
        p_longitude: coordinates.longitude,
      },
    );
    if (zoneError) {
      console.error("Could not verify employee location against work zone:", zoneError);
      if (zoneError.message.includes("no work zone configured")) {
        return respond(409, {
          error: "Your organisation has no work zone configured. Contact the owner.",
        });
      }
      return respond(500, { error: "Could not verify your work-zone location." });
    }
    if (
      typeof zoneStatus !== "object" ||
      zoneStatus === null ||
      !("is_inside" in zoneStatus)
    ) {
      console.error("Work-zone verification returned an invalid response.");
      return respond(500, { error: "Could not verify your work-zone location." });
    }
    if (zoneStatus.is_inside !== true) {
      return respond(403, {
        error: "You must be inside your organisation's work zone to clock in.",
      });
    }
  }

  const now = new Date();
  const timestamp = now.toISOString();
  let approvalStatus: "pending" | "approved" = "approved";
  let shift: { data: { id: string } | null; error: { code?: string } | null };
  let assignedShiftName: string | undefined;
  let currentShiftName: string | undefined;
  if (action === "clock_in") {
    const { data: organisationShifts, error: shiftsError } = await adminClient
      .from("organisation_shifts")
      .select("id, name, start_time, end_time")
      .eq("organisation_id", organisationId)
      .order("start_time");
    if (shiftsError) {
      console.error("Could not load organisation shifts:", shiftsError);
      return respond(500, { error: "Could not load organisation shifts." });
    }
    const assignedShift = (organisationShifts ?? []).find(
      (item) => item.id === employee.shift_id,
    );
    if (!assignedShift) {
      return respond(409, {
        error: "The assigned shift no longer exists. Contact an admin.",
      });
    }

    let autoClosePrevious = false;
    let attendanceShiftId: string | null = null;
    try {
      const timeZone = organisation.timezone || "UTC";
      const activeShifts = (organisationShifts ?? []).filter((item) =>
        isCurrentlyWithinShift(
          now,
          timeZone,
          item.start_time,
          item.end_time,
        )
      );
      const currentShift = activeShifts[0];
      if (!currentShift) {
        return respond(409, {
          error: "No organisation shift is active right now. You can clock in only while a scheduled shift is in progress.",
        });
      }
      attendanceShiftId = currentShift.id;
      assignedShiftName = assignedShift.name;
      currentShiftName = currentShift.name;
      approvalStatus =
        currentShift?.id === assignedShift.id ? "approved" : "pending";
    } catch (error) {
      console.error("Could not evaluate employee shift time:", error);
      return respond(500, { error: "Could not verify the assigned shift time zone." });
    }
    autoClosePrevious = approvalStatus === "approved";

    const { data: clockInResult, error: clockInError } = await adminClient.rpc(
      "record_employee_clock_in",
      {
        p_organisation_id: organisationId,
        p_employee_id: employee.id,
        p_shift_id: attendanceShiftId,
        p_assigned_shift_id: employee.shift_id,
        p_shift_date: localShiftDate(now, organisation.timezone || "UTC"),
        p_clock_in: timestamp,
        p_approval_status: approvalStatus,
        p_auto_close_previous: autoClosePrevious,
      },
    );
    if (clockInError) {
      console.error("Could not record employee clock-in:", clockInError);
      return respond(
        clockInError.code === "23505" ? 409 : 500,
        {
          error: clockInError.message.includes("already has an open")
            ? "You already have an open shift. Clock out first."
            : clockInError.code === "23505"
            ? "A shift was started already. Refresh and try again."
            : "Could not record the shift.",
        },
      );
    }
    shift = {
      data: clockInResult && typeof clockInResult.attendance_id === "string"
        ? { id: clockInResult.attendance_id }
        : null,
      error: null,
    };
  } else {
    shift = await adminClient
      .from("attendance_records")
      .update({ clock_out: timestamp })
      .eq("id", openShift!.id)
      .is("clock_out", null)
      .select("id")
      .maybeSingle();
  }

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

  const notification = await notifyAdmins(
    adminClient,
    organisationId,
    action,
    approvalStatus,
    userData.user.id,
    approvalStatus === "pending"
      ? {
          employeeName: employee.full_name,
          assignedShiftName: assignedShiftName ?? "another shift",
          currentShiftName: currentShiftName ?? "a different shift",
        }
      : undefined,
  );
  return respond(200, {
    attendance_id: shift.data.id,
    action,
    approval_status: approvalStatus,
    assigned_shift_name: assignedShiftName ?? null,
    attendance_shift_name: currentShiftName ?? null,
    notification_sent: notification.sent,
    notification_message: notification.message,
  });
});
