import { useState } from "react";
import { ScrollView, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { ApiError } from "@diti365/shared";
import { Button } from "@/components/ui";
import { getApi } from "@/lib/api";

export default function ResetPasswordScreen() {
  const router = useRouter();
  const { resetToken } = useLocalSearchParams<{ resetToken: string }>();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const tooShort = password.length > 0 && password.length < 8;
  const mismatch = confirm.length > 0 && confirm !== password;

  async function save() {
    setBusy(true);
    setError(null);
    try {
      await getApi().post("/api/v2/auth/password/reset", { resetToken, newPassword: password });
      router.replace("/(auth)/login");
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : "Could not set the password. Request a new code.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="flex-grow justify-between px-6 pb-10 pt-20">
      <View>
        <Text className="text-3xl font-semibold text-text">New password</Text>
        <Text className="mt-2 text-base text-muted">
          At least 8 characters. You will be signed out on other devices.
        </Text>

        <View className="mt-8 gap-4">
          <View>
            <Text className="mb-1.5 text-sm font-medium text-text">New password</Text>
            <TextInput
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              className="min-h-[52px] rounded-xl border border-border bg-surface px-4 text-base text-text"
            />
            {tooShort ? (
              <Text className="mt-1 text-xs text-danger">
                {8 - password.length} more character{8 - password.length === 1 ? "" : "s"} needed.
              </Text>
            ) : null}
          </View>

          <View>
            <Text className="mb-1.5 text-sm font-medium text-text">Confirm</Text>
            <TextInput
              value={confirm}
              onChangeText={setConfirm}
              secureTextEntry
              className="min-h-[52px] rounded-xl border border-border bg-surface px-4 text-base text-text"
            />
            {mismatch ? <Text className="mt-1 text-xs text-danger">These do not match.</Text> : null}
          </View>
        </View>

        {error ? (
          <View accessibilityLiveRegion="assertive" className="mt-4 rounded-xl bg-danger/10 px-4 py-3">
            <Text className="text-sm text-danger">{error}</Text>
          </View>
        ) : null}
      </View>

      <Button
        title="Set password"
        loading={busy}
        disabled={password.length < 8 || confirm !== password}
        onPress={save}
      />
    </ScrollView>
  );
}
