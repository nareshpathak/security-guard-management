import { useState } from "react";
import { ScrollView, Text, TextInput, View } from "react-native";
import { useRouter } from "expo-router";
import { ApiError } from "@diti365/shared";
import { Button } from "@/components/ui";
import { getApi } from "@/lib/api";
import { mobileExists } from "@/lib/device";

export default function ForgotPasswordScreen() {
  const router = useRouter();
  const [mobileNo, setMobileNo] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function send() {
    setBusy(true);
    setError(null);
    try {
      /*  Ask the server whether the number is registered before spending an
          SMS on it. The ANSWER is never shown - telling a stranger "no such
          number" turns this form into a way to enumerate the agency's staff -
          it only decides whether to send.  */
      const registered = await mobileExists(mobileNo);
      if (registered) {
        await getApi().post("/api/v2/auth/otp/request", { mobileNo, purpose: "Reset" });
      }
      router.push({ pathname: "/(auth)/otp", params: { mobileNo } });
    } catch (err) {
      setError(err instanceof ApiError ? (err.detail ?? err.message) : "Could not send the code.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="flex-grow justify-between px-6 pb-10 pt-20">
      <View>
        <Text className="text-3xl font-semibold text-text">Reset password</Text>
        <Text className="mt-2 text-base text-muted">
          We will text a six-digit code to your registered mobile number.
        </Text>

        <View className="mt-8">
          <Text className="mb-1.5 text-sm font-medium text-text">Mobile number</Text>
          <TextInput
            value={mobileNo}
            onChangeText={(t) => setMobileNo(t.replace(/\D/g, ""))}
            keyboardType="phone-pad"
            maxLength={10}
            accessibilityLabel="Mobile number"
            className="min-h-[52px] rounded-xl border border-border bg-surface px-4 text-base text-text"
          />
        </View>

        {error ? (
          <View accessibilityLiveRegion="assertive" className="mt-4 rounded-xl bg-danger/10 px-4 py-3">
            <Text className="text-sm text-danger">{error}</Text>
          </View>
        ) : null}
      </View>

      <View className="gap-3">
        <Button title="Send code" loading={busy} disabled={mobileNo.length < 10} onPress={send} />
        <Button title="Back to sign in" tone="ghost" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}
