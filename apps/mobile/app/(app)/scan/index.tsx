import { useState } from "react";
import { Text, View } from "react-native";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions } from "expo-camera";
import { Button, Card, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";
import { enqueue } from "@/lib/outbox";
import { getFix, LocationError, requestForegroundPermission } from "@/lib/location";

type Outcome =
  | { kind: "idle" }
  | { kind: "checking" }
  | { kind: "rejected"; distance: number; allowed: number; name: string }
  | { kind: "accepted"; distance: number; name: string };

/**
 * The patrol scanner.
 *
 * The rule that matters: a scan taken beyond the checkpoint's MaxDistanceMeters
 * is REFUSED, with the number shown. The legacy app accepted it and let the
 * report sort it out later, which meant a guard could walk a floor below the
 * checkpoint and still register a round.
 *
 * When offline the distance cannot be checked against the server, so the scan
 * queues with its GPS and timestamp and the server decides. Nothing is lost and
 * nothing is quietly waved through.
 */
export default function ScanScreen() {
  const router = useRouter();
  const [permission, requestPermission] = useCameraPermissions();
  const [outcome, setOutcome] = useState<Outcome>({ kind: "idle" });
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onScanned(qrCode: string) {
    if (outcome.kind !== "idle") return;
    setOutcome({ kind: "checking" });
    setError(null);

    try {
      if (!(await requestForegroundPermission())) {
        setError("Location permission is needed to prove you were at the checkpoint.");
        setOutcome({ kind: "idle" });
        return;
      }

      const fix = await getFix();

      let distance = 0;
      let allowed = 0;
      let name = qrCode;
      let known = false;

      try {
        const { data } = await getApi().get<{
          qrName: string;
          distanceMeters: number;
          maxDistanceMeters: number;
        }>(`/api/v2/patrol/checkpoints/${encodeURIComponent(qrCode)}/distance`, {
          latitude: fix.latitude,
          longitude: fix.longitude,
        });
        distance = data.distanceMeters;
        allowed = data.maxDistanceMeters;
        name = data.qrName ?? qrCode;
        known = true;
      } catch {
        // Offline. Queue it and let the server judge the distance.
        known = false;
      }

      if (known && distance > allowed) {
        setOutcome({ kind: "rejected", distance, allowed, name });
        return;
      }

      setBusy(true);
      await enqueue({
        endpoint: "/api/v2/patrol/scan",
        payload: {
          qrCode,
          latitude: fix.latitude,
          longitude: fix.longitude,
          accuracy: fix.accuracy,
          isMockLocation: fix.isMocked,
          scanAt: fix.capturedAt,
          isOffline: !known,
        },
        label: `Patrol scan · ${name}`,
      });
      setBusy(false);
      setOutcome({ kind: "accepted", distance, name });
    } catch (err) {
      setError(err instanceof LocationError ? err.message : "Could not record this scan.");
      setOutcome({ kind: "idle" });
    }
  }

  if (!permission?.granted) {
    return (
      <View className="flex-1 justify-between bg-bg px-6 pb-10 pt-24">
        <View className="gap-3">
          <Text className="text-2xl font-semibold text-text">Camera access</Text>
          <Text className="text-base text-muted">
            The scanner reads the QR code fixed at each checkpoint. Diti365 does not use the camera
            at any other time.
          </Text>
        </View>
        <View className="gap-3">
          <Button title="Allow camera" onPress={() => void requestPermission()} />
          <Button title="Not now" tone="ghost" onPress={() => router.back()} />
        </View>
      </View>
    );
  }

  return (
    <View className="flex-1 bg-black">
      {outcome.kind === "idle" ? (
        <CameraView
          style={{ flex: 1 }}
          barcodeScannerSettings={{ barcodeTypes: ["qr"] }}
          onBarcodeScanned={({ data }) => void onScanned(data)}
        />
      ) : (
        <View className="flex-1 justify-center px-6">
          <Card className="gap-4">
            {outcome.kind === "checking" ? (
              <Text className="text-lg text-text">Checking where you are…</Text>
            ) : outcome.kind === "rejected" ? (
              <>
                <Pill text="Too far from the checkpoint" tone="danger" />
                <Text className="text-xl font-semibold text-text">{outcome.name}</Text>
                <Text className="text-base text-muted">
                  You are {outcome.distance} m away. This checkpoint must be scanned within{" "}
                  {outcome.allowed} m. Walk to the checkpoint and scan again.
                </Text>
              </>
            ) : (
              <>
                <Pill text="Scan recorded" tone="success" />
                <Text className="text-xl font-semibold text-text">{outcome.name}</Text>
                <Text className="text-base text-muted">
                  {outcome.distance > 0 ? `${outcome.distance} m from the checkpoint. ` : ""}
                  Saved on this phone and sent when you have signal.
                </Text>
              </>
            )}
          </Card>
        </View>
      )}

      <View className="gap-3 bg-black px-6 pb-10 pt-4">
        {error ? (
          <View accessibilityLiveRegion="assertive" className="rounded-xl bg-danger/20 px-4 py-3">
            <Text className="text-sm text-white">{error}</Text>
          </View>
        ) : null}

        {outcome.kind === "idle" ? (
          <Text className="text-center text-sm text-white/70">
            Point the camera at the checkpoint QR code
          </Text>
        ) : (
          <Button
            title={outcome.kind === "checking" ? "Please wait…" : "Scan another"}
            loading={busy || outcome.kind === "checking"}
            onPress={() => setOutcome({ kind: "idle" })}
          />
        )}
        <Button title="Close" tone="ghost" onPress={() => router.back()} />
      </View>
    </View>
  );
}
