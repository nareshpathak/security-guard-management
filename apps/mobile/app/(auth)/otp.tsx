import { useState } from "react";
import { ScrollView, Text, TextInput, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import { ApiError } from "@diti365/shared";
import { Button } from "@/components/ui";
import { getApi } from "@/lib/api";

export default function OtpScreen() {
  const router = useRouter();
  const { mobileNo } = useLocalSearchParams<{ mobileNo: string }>();
  const [otp, setOtp] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function verify() {
    setBusy(true);
    setError(null);
    try {
      const { data } = await getApi().post<{ resetToken: string }>("/api/v2/auth/otp/verify", {
        mobileNo,
        otp,
        purpose: "Reset",
      });
      // The token is passed forward in navigation params rather than stored:
      // it is valid for ten minutes and for exactly one action.
      router.replace({ pathname: "/(auth)/reset-password", params: { resetToken: data.resetToken } });
    } catch (err) {
      setError(err instanceof ApiError ? (err.detail ?? err.message) : "That code was not accepted.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="flex-grow justify-between px-6 pb-10 pt-20">
      <View>
        <Text className="text-3xl font-semibold text-text">Enter the code</Text>
        <Text className="mt-2 text-base text-muted">Six digits, sent to {mobileNo}.</Text>

        <TextInput
          value={otp}
          onChangeText={(t) => setOtp(t.replace(/\D/g, ""))}
          keyboardType="number-pad"
          maxLength={6}
          autoFocus
          textContentType="oneTimeCode"
          accessibilityLabel="Six digit code"
          className="mt-8 min-h-[60px] rounded-xl border border-border bg-surface px-4 text-center text-2xl tracking-[12px] text-text"
        />

        {error ? (
          <View accessibilityLiveRegion="assertive" className="mt-4 rounded-xl bg-danger/10 px-4 py-3">
            <Text className="text-sm text-danger">{error}</Text>
          </View>
        ) : null}
      </View>

      <View className="gap-3">
        <Button title="Verify" loading={busy} disabled={otp.length !== 6} onPress={verify} />
        <Button title="Send a new code" tone="ghost" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}
