import { useEffect, useState } from "react";
import { ScrollView, Switch, Text, View } from "react-native";
import * as LocalAuthentication from "expo-local-authentication";
import { Card } from "@/components/ui";
import { isAppLockEnabled, setAppLockEnabled } from "@/lib/session";
import { API_BASE_URL } from "@/lib/api";

export default function SettingsScreen() {
  const [lock, setLock] = useState(false);
  const [biometricAvailable, setBiometricAvailable] = useState(false);

  useEffect(() => {
    void (async () => {
      setLock(await isAppLockEnabled());
      const hasHardware = await LocalAuthentication.hasHardwareAsync();
      const enrolled = await LocalAuthentication.isEnrolledAsync();
      setBiometricAvailable(hasHardware && enrolled);
    })();
  }, []);

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-4 p-4 pt-16">
      <Text className="text-2xl font-semibold text-text">Settings</Text>

      <Card className="gap-3">
        <View className="flex-row items-center justify-between">
          <View className="flex-1 pr-4">
            <Text className="text-base text-text">Unlock with fingerprint</Text>
            <Text className="mt-0.5 text-xs text-muted">
              {biometricAvailable
                ? "Ask for your fingerprint when the app is reopened."
                : "No fingerprint is registered on this phone."}
            </Text>
          </View>
          <Switch
            value={lock}
            disabled={!biometricAvailable}
            onValueChange={async (v) => {
              setLock(v);
              await setAppLockEnabled(v);
            }}
          />
        </View>
      </Card>

      <Card className="gap-2">
        <Text className="text-sm font-semibold text-text">About</Text>
        <View className="flex-row justify-between">
          <Text className="text-sm text-muted">Version</Text>
          <Text className="text-sm text-text">1.0.0</Text>
        </View>
        <View className="flex-row justify-between">
          <Text className="text-sm text-muted">Server</Text>
          <Text className="text-sm text-text" numberOfLines={1}>
            {API_BASE_URL.replace(/^https?:\/\//, "")}
          </Text>
        </View>
      </Card>
    </ScrollView>
  );
}
