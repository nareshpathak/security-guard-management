import { getApi, API_BASE_URL } from "./api";
import { getDeviceId } from "./session";

/**
 * Device binding.
 *
 * The legacy app called this "checkdeviceid" and used it to stop one guard
 * lending his login to another - a real problem when attendance is money. A
 * mismatch is not a lockout: it needs an admin to release the binding, because
 * people do genuinely change phones.
 */
export type DeviceCheck =
  | { ok: true }
  | { ok: false; reason: string };

export async function verifyDevice(): Promise<DeviceCheck> {
  try {
    const { data } = await getApi().post<{ isAllowed?: boolean; message?: string }>(
      "/api/v2/auth/device/verify",
      { deviceId: await getDeviceId() },
    );

    if (data?.isAllowed === false)
      return {
        ok: false,
        reason:
          data.message ??
          "This account is registered to a different phone. Ask your supervisor to release it.",
      };

    return { ok: true };
  } catch {
    // Unreachable is not the same as rejected. Blocking sign-in because the
    // network is down would strand a guard at the gate.
    return { ok: true };
  }
}

/** Registers the FCM token so the server can push to this handset. */
export async function registerPushToken(token: string): Promise<void> {
  try {
    await getApi().post("/api/v2/auth/device/token", {
      deviceId: await getDeviceId(),
      fcmToken: token,
      platform: "android",
    });
  } catch {
    // A missing push token degrades notifications, nothing else.
  }
}

/**
 * Whether a mobile number is registered, checked before sending an OTP.
 *
 * Deliberately NOT used to tell the user "no such number" - that would let
 * anyone enumerate the agency's staff. It only decides whether to bother
 * sending an SMS.
 */
export async function mobileExists(mobileNo: string): Promise<boolean> {
  try {
    const res = await fetch(`${API_BASE_URL}/api/v2/auth/mobile/${mobileNo}/exists`);
    if (!res.ok) return true;
    const json = await res.json();
    return json?.data !== false;
  } catch {
    return true;
  }
}
