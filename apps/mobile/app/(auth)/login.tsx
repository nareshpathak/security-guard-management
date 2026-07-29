import { useState } from "react";
import { Image, Text, TextInput, View, KeyboardAvoidingView, Platform, ScrollView } from "react-native";
import { Link } from "expo-router";
import { ApiError } from "@diti365/shared";
import { Button } from "@/components/ui";
import { useAuth } from "@/lib/auth";
import { verifyDevice } from "@/lib/device";

export default function LoginScreen() {
  const { login } = useAuth();
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function onSubmit() {
    setBusy(true);
    setError(null);
    try {
      /*  Device binding is checked BEFORE the password is sent. Signing in and
          then being told the handset is wrong would leave a valid session on a
          phone that is not meant to have one.  */
      const device = await verifyDevice();
      if (!device.ok) {
        setError(device.reason);
        return;
      }

      await login(loginId.trim(), password);
    } catch (err) {
      setError(
        err instanceof ApiError
          ? (err.detail ?? err.message)
          : "Could not sign in. Check your details and your connection.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView
      className="flex-1 bg-bg"
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      <ScrollView contentContainerClassName="flex-grow justify-between px-6 pb-10 pt-20">
        <View>
          <View className="h-14 w-14 items-center justify-center rounded-2xl bg-primary">
            <Text className="text-2xl font-bold text-white">D</Text>
          </View>
          <Text className="mt-6 text-3xl font-semibold text-text">Sign in</Text>
          <Text className="mt-2 text-base text-muted">
            Use the login id or mobile number your agency gave you.
          </Text>

          <View className="mt-8 gap-4">
            <View>
              <Text className="mb-1.5 text-sm font-medium text-text">Login id or mobile</Text>
              <TextInput
                value={loginId}
                onChangeText={setLoginId}
                autoCapitalize="none"
                autoComplete="username"
                accessibilityLabel="Login id or mobile number"
                className="min-h-[52px] rounded-xl border border-border bg-surface px-4 text-base text-text"
              />
            </View>

            <View>
              <Text className="mb-1.5 text-sm font-medium text-text">Password</Text>
              <TextInput
                value={password}
                onChangeText={setPassword}
                secureTextEntry
                autoComplete="current-password"
                accessibilityLabel="Password"
                className="min-h-[52px] rounded-xl border border-border bg-surface px-4 text-base text-text"
              />
            </View>

            {error ? (
              <View
                accessibilityLiveRegion="assertive"
                className="rounded-xl bg-danger/10 px-4 py-3"
              >
                <Text className="text-sm text-danger">{error}</Text>
              </View>
            ) : null}
          </View>
        </View>

        {/* Primary action in the bottom third: this app is used one-handed. */}
        <View className="gap-4">
          <Button
            title="Sign in"
            loading={busy}
            disabled={loginId.length < 3 || password.length < 4}
            onPress={onSubmit}
          />
          <Link href="/(auth)/forgot-password" asChild>
            <Text className="text-center text-base text-primary">Forgotten your password?</Text>
          </Link>
          <Text className="text-center text-xs text-muted">
            This handset will be linked to your account. Tell your supervisor before changing phones.
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
