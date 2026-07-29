import { useEffect, useRef, useState } from "react";
import { Image, ScrollView, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImageManipulator from "expo-image-manipulator";
import { useQuery } from "@tanstack/react-query";
import type { Row } from "@diti365/shared";
import { Button, Card, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { enqueue } from "@/lib/outbox";
import { distanceMeters, getFix, LocationError, requestForegroundPermission, type Fix } from "@/lib/location";
import { startDutyTracking, stopDutyTracking } from "@/lib/tracking";

type Step = "locating" | "confirm" | "selfie" | "done";

/**
 * The punch.
 *
 * Order matters and is deliberate: GPS first, then the geofence answer, then
 * the selfie. Asking for a photograph before telling someone they are 800 m
 * from site wastes their time and teaches them the app is stupid.
 *
 * Nothing here decides whether the punch is valid - the server recomputes the
 * distance from the coordinates and can reject it. This screen exists to give
 * an honest answer in the two seconds before that happens.
 */
export default function PunchScreen() {
  const router = useRouter();
  const { user } = useAuth();
  const [step, setStep] = useState<Step>("locating");
  const [fix, setFix] = useState<Fix | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [photo, setPhoto] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [trackingNote, setTrackingNote] = useState<string | null>(null);
  const [permission, requestPermission] = useCameraPermissions();
  const camera = useRef<CameraView>(null);

  const today = useQuery({
    queryKey: ["my-attendance-today"],
    queryFn: () => getApi().get<{ days: Row[] }>("/api/v2/attendance/me"),
  });

  const unit = useQuery({
    queryKey: ["my-unit"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 1 }),
  });

  const site = unit.data?.data?.[0];
  const siteLat = site ? Number(site.Latitude) : null;
  const siteLon = site ? Number(site.Longitude) : null;
  const radius = site ? Number(site.GeofenceRadiusMeters ?? 100) : 100;

  const distance =
    fix && siteLat !== null && siteLon !== null
      ? distanceMeters(fix.latitude, fix.longitude, siteLat, siteLon)
      : null;

  const outside = distance !== null && distance > radius;

  // The direction is decided by what is already recorded, not by two buttons.
  // A guard who has punched in can only punch out.
  const days = today.data?.data?.days ?? [];
  const alreadyIn = days.some((d) => Boolean(d.InTime) && !d.OutTime);
  const direction: "IN" | "OUT" = alreadyIn ? "OUT" : "IN";

  useEffect(() => {
    void acquire();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function acquire() {
    setStep("locating");
    setError(null);
    try {
      if (!(await requestForegroundPermission())) {
        setError("Diti365 needs location permission to record your duty.");
        return;
      }
      setFix(await getFix());
      setStep("confirm");
    } catch (err) {
      setError(err instanceof LocationError ? err.message : "Could not get your location.");
    }
  }

  async function takeSelfie() {
    if (!permission?.granted) {
      const granted = await requestPermission();
      if (!granted.granted) {
        setError("Diti365 needs the camera for the duty selfie.");
        return;
      }
    }

    const shot = await camera.current?.takePictureAsync({ quality: 0.6 });
    if (!shot?.uri) return;

    /*  Compressed to roughly 200 KB before it ever touches the queue. A guard
        on 2G in an industrial estate cannot upload a 4 MB photograph, and an
        outbox full of them fills the handset.  */
    const small = await ImageManipulator.manipulateAsync(
      shot.uri,
      [{ resize: { width: 720 } }],
      { compress: 0.5, format: ImageManipulator.SaveFormat.JPEG },
    );

    setPhoto(small.uri);
  }

  async function submit() {
    if (!fix) return;
    setBusy(true);
    try {
      await enqueue({
        endpoint: direction === "IN" ? "/api/v2/attendance/punch-in" : "/api/v2/attendance/punch-out",
        payload: {
          empId: user?.empId,
          unitId: site?.UnitID,
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracy: fix.accuracy,
          isMockLocation: fix.isMocked,
          punchAt: fix.capturedAt,
          allowOutOfGeofence: outside,
          remark: outside ? reason.trim() : undefined,
          appVersion: "1.0.0",
        },
        files: photo ? [photo] : undefined,
        label: `Punch ${direction === "IN" ? "in" : "out"}${site ? ` · ${String(site.UnitName)}` : ""}`,
      });

      /*  Duty tracking follows the punch, not a separate switch. Starting it at
          punch-in and stopping it at punch-out is the only arrangement a guard
          would consider fair, and the only one that survives a battery
          optimiser - nothing runs while nobody is on shift.  */
      if (direction === "IN") {
        const result = await startDutyTracking();
        if (!result.started) setTrackingNote(result.reason ?? null);
      } else {
        await stopDutyTracking();
      }

      setStep("done");
    } finally {
      setBusy(false);
    }
  }

  if (today.isLoading || unit.isLoading) return <Loading />;

  if (step === "done") {
    return (
      <View className="flex-1 justify-between bg-bg px-6 pb-10 pt-24">
        <View className="items-center gap-4">
          <View className="h-20 w-20 items-center justify-center rounded-full bg-success/15">
            <Text className="text-4xl text-success">✓</Text>
          </View>
          <Text className="text-2xl font-semibold text-text">
            Punch {direction === "IN" ? "in" : "out"} recorded
          </Text>
          <Text className="text-center text-base text-muted">
            {new Date().toLocaleTimeString()} · {distance !== null ? `${distance} m from site` : ""}
          </Text>
          <Text className="text-center text-sm text-muted">
            Saved on this phone. It reaches the office automatically when you have signal.
          </Text>
          {trackingNote ? (
            <Text className="text-center text-sm text-warning">{trackingNote}</Text>
          ) : direction === "IN" ? (
            <Text className="text-center text-xs text-muted">
              Your duty location is now being recorded. It stops when you punch out.
            </Text>
          ) : null}
        </View>
        <Button title="Done" onPress={() => router.back()} />
      </View>
    );
  }

  if (step === "selfie") {
    return (
      <View className="flex-1 bg-black">
        {photo ? (
          <Image source={{ uri: photo }} className="flex-1" resizeMode="cover" />
        ) : (
          <CameraView ref={camera} facing="front" style={{ flex: 1 }} />
        )}
        <View className="gap-3 bg-black px-6 pb-10 pt-4">
          {photo ? (
            <>
              <Button title={busy ? "Saving…" : "Submit punch"} loading={busy} onPress={submit} />
              <Button title="Retake" tone="ghost" onPress={() => setPhoto(null)} />
            </>
          ) : (
            <Button title="Take photo" onPress={takeSelfie} />
          )}
        </View>
      </View>
    );
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="flex-grow justify-between px-6 pb-10 pt-16">
      <View className="gap-4">
        <Text className="text-2xl font-semibold text-text">
          Punch {direction === "IN" ? "in" : "out"}
        </Text>

        <Card className="gap-3">
          <Text className="text-sm text-muted">Site</Text>
          <Text className="text-lg font-medium text-text">{String(site?.UnitName ?? "No site assigned")}</Text>

          {step === "locating" ? (
            <Text className="text-sm text-muted">Finding your location…</Text>
          ) : distance !== null ? (
            <View className="gap-2">
              <Pill
                text={outside ? `${distance} m away — outside the site` : `${distance} m from the site`}
                tone={outside ? "danger" : "success"}
              />
              <Text className="text-xs text-muted">
                Accurate to about {Math.round(fix?.accuracy ?? 0)} m. The site allows {radius} m.
              </Text>
            </View>
          ) : (
            <Text className="text-sm text-muted">This site has no coordinates set.</Text>
          )}
        </Card>

        {error ? (
          <View accessibilityLiveRegion="assertive" className="rounded-xl bg-danger/10 px-4 py-3">
            <Text className="text-sm text-danger">{error}</Text>
          </View>
        ) : null}

        {outside ? (
          <Card className="gap-2">
            <Text className="text-sm font-medium text-text">Why are you away from the site?</Text>
            <Text className="text-xs text-muted">
              Your supervisor will see this with the punch. It is not automatically approved.
            </Text>
            <TextInput
              value={reason}
              onChangeText={setReason}
              multiline
              placeholder="Reliever duty at the next gate, escorting material…"
              className="min-h-[80px] rounded-xl border border-border bg-surface px-4 py-3 text-base text-text"
            />
          </Card>
        ) : null}
      </View>

      <View className="gap-3">
        {error ? <Button title="Try again" tone="outline" onPress={acquire} /> : null}
        <Button
          title="Continue"
          disabled={step !== "confirm" || (outside && reason.trim().length < 5)}
          onPress={() => setStep("selfie")}
        />
        <Button title="Cancel" tone="ghost" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}
