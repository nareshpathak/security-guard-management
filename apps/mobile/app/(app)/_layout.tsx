import { Stack } from "expo-router";

export default function AppLayout() {
  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="(tabs)" />
      {/* Full-screen flows: the camera and scanner need the whole display. */}
      <Stack.Screen name="punch" options={{ presentation: "fullScreenModal" }} />
      <Stack.Screen name="scan" options={{ presentation: "fullScreenModal" }} />
      <Stack.Screen name="sync" options={{ presentation: "modal", headerShown: true, title: "Sync centre" }} />
    </Stack>
  );
}
