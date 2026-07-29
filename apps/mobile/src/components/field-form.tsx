import { useState } from "react";
import { Image, ScrollView, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";
import { CameraView, useCameraPermissions } from "expo-camera";
import * as ImageManipulator from "expo-image-manipulator";
import { Button, Card, Pill } from "@/components/ui";
import { enqueue } from "@/lib/outbox";
import { getFix, LocationError, requestForegroundPermission, type Fix } from "@/lib/location";

export type Field = {
  name: string;
  label: string;
  required?: boolean;
  multiline?: boolean;
  keyboard?: "default" | "phone-pad" | "number-pad";
  maxLength?: number;
  hint?: string;
};

/**
 * Everything a guard or executive fills in from the field looks the same:
 * some text, optionally a photograph, always a GPS stamp, then into the outbox.
 *
 * Writing that five times produced five slightly different answers to "what
 * happens when the GPS is slow" and "is the photo compressed". One form, one
 * answer.
 */
export function FieldForm({
  title,
  intro,
  endpoint,
  fields,
  label,
  withPhoto = true,
  withLocation = true,
  extraPayload,
}: {
  title: string;
  intro?: string;
  endpoint: string;
  fields: Field[];
  /** Sync Centre description, e.g. "Incident - Tower A". */
  label: (values: Record<string, string>) => string;
  withPhoto?: boolean;
  withLocation?: boolean;
  extraPayload?: Record<string, unknown>;
}) {
  const router = useRouter();
  const [values, setValues] = useState<Record<string, string>>({});
  const [photo, setPhoto] = useState<string | null>(null);
  const [shooting, setShooting] = useState(false);
  const [fix, setFix] = useState<Fix | null>(null);
  const [locating, setLocating] = useState(false);
  const [locationNote, setLocationNote] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [permission, requestPermission] = useCameraPermissions();
  const [camera, setCamera] = useState<CameraView | null>(null);

  const missing = fields.filter((f) => f.required && !values[f.name]?.trim());

  async function stampLocation() {
    setLocating(true);
    setLocationNote(null);
    try {
      if (!(await requestForegroundPermission())) {
        setLocationNote("Location permission refused. The report will be sent without a position.");
        return;
      }
      setFix(await getFix());
    } catch (err) {
      /*  A weak fix does not block the report. Losing an incident because the
          GPS was poor is far worse than recording one without coordinates.  */
      setLocationNote(
        err instanceof LocationError
          ? `${err.message} The report will be sent without a position.`
          : "Could not get a position. The report will be sent without one.",
      );
    } finally {
      setLocating(false);
    }
  }

  async function capture() {
    if (!permission?.granted) {
      const granted = await requestPermission();
      if (!granted.granted) return;
    }
    setShooting(true);
  }

  async function shoot() {
    const shot = await camera?.takePictureAsync({ quality: 0.6 });
    if (!shot?.uri) return;
    const small = await ImageManipulator.manipulateAsync(
      shot.uri,
      [{ resize: { width: 1080 } }],
      { compress: 0.5, format: ImageManipulator.SaveFormat.JPEG },
    );
    setPhoto(small.uri);
    setShooting(false);
  }

  async function submit() {
    setBusy(true);
    try {
      await enqueue({
        endpoint,
        payload: {
          ...values,
          ...extraPayload,
          ...(fix
            ? { latitude: fix.latitude, longitude: fix.longitude, accuracy: fix.accuracy }
            : {}),
        },
        files: photo ? [photo] : undefined,
        label: label(values),
      });
      setDone(true);
    } finally {
      setBusy(false);
    }
  }

  if (shooting) {
    return (
      <View className="flex-1 bg-black">
        <CameraView ref={setCamera} facing="back" style={{ flex: 1 }} />
        <View className="gap-3 px-6 pb-10 pt-4">
          <Button title="Take photo" onPress={shoot} />
          <Button title="Cancel" tone="ghost" onPress={() => setShooting(false)} />
        </View>
      </View>
    );
  }

  if (done) {
    return (
      <View className="flex-1 justify-between bg-bg px-6 pb-10 pt-24">
        <View className="items-center gap-4">
          <View className="h-20 w-20 items-center justify-center rounded-full bg-success/15">
            <Text className="text-4xl text-success">✓</Text>
          </View>
          <Text className="text-2xl font-semibold text-text">Saved</Text>
          <Text className="text-center text-base text-muted">
            Recorded on this phone. It reaches the office automatically when you have signal.
          </Text>
        </View>
        <Button title="Done" onPress={() => router.back()} />
      </View>
    );
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="flex-grow justify-between px-4 pb-10 pt-16 gap-4">
      <View className="gap-4">
        <View className="px-1">
          <Text className="text-2xl font-semibold text-text">{title}</Text>
          {intro ? <Text className="mt-1 text-sm text-muted">{intro}</Text> : null}
        </View>

        <Card className="gap-4">
          {fields.map((f) => (
            <View key={f.name}>
              <Text className="mb-1.5 text-sm font-medium text-text">
                {f.label}
                {f.required ? <Text className="text-danger"> *</Text> : null}
              </Text>
              <TextInput
                value={values[f.name] ?? ""}
                onChangeText={(t) => setValues((v) => ({ ...v, [f.name]: t }))}
                multiline={f.multiline}
                keyboardType={f.keyboard ?? "default"}
                maxLength={f.maxLength}
                accessibilityLabel={f.label}
                className={`rounded-xl border border-border bg-surface px-4 text-base text-text ${
                  f.multiline ? "min-h-[96px] py-3" : "min-h-[52px]"
                }`}
              />
              {f.hint ? <Text className="mt-1 text-xs text-muted">{f.hint}</Text> : null}
            </View>
          ))}
        </Card>

        {withLocation ? (
          <Card className="gap-3">
            <Text className="text-sm font-medium text-text">Location</Text>
            {fix ? (
              <Pill text={`Stamped · accurate to ${Math.round(fix.accuracy)} m`} tone="success" />
            ) : (
              <Button
                title={locating ? "Getting position…" : "Stamp my location"}
                tone="outline"
                loading={locating}
                onPress={stampLocation}
              />
            )}
            {locationNote ? <Text className="text-xs text-warning">{locationNote}</Text> : null}
          </Card>
        ) : null}

        {withPhoto ? (
          <Card className="gap-3">
            <Text className="text-sm font-medium text-text">Photo</Text>
            {photo ? (
              <>
                <Image source={{ uri: photo }} className="h-48 w-full rounded-xl" resizeMode="cover" />
                <Button title="Retake" tone="ghost" onPress={() => setPhoto(null)} />
              </>
            ) : (
              <Button title="Add a photo" tone="outline" onPress={capture} />
            )}
          </Card>
        ) : null}
      </View>

      <View className="gap-3">
        {missing.length > 0 ? (
          <Text className="text-center text-xs text-muted">
            Still needed: {missing.map((f) => f.label).join(", ")}
          </Text>
        ) : null}
        <Button title="Submit" loading={busy} disabled={missing.length > 0} onPress={submit} />
        <Button title="Cancel" tone="ghost" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}
