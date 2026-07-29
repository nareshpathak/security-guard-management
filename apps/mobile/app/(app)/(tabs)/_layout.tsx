import { Tabs } from "expo-router";
import { Text } from "react-native";
import { useAuth, personaFor } from "@/lib/auth";

/**
 * The tab bar is role-driven, mirroring the legacy app's separate home
 * fragments - but as one build rather than seven activities.
 *
 * A guard does not get an Approvals tab; a gatekeeper does not get Attendance.
 * Showing tabs that lead to a 403 is how people learn to distrust an app.
 */
function icon(char: string) {
  return ({ color }: { color: string }) => (
    <Text style={{ color, fontSize: 20 }} accessibilityElementsHidden>
      {char}
    </Text>
  );
}

export default function TabsLayout() {
  const { user } = useAuth();
  const persona = personaFor(user);

  const showAttendance = persona === "guard" || persona === "supervisor";
  const showApprovals = persona === "supervisor" || persona === "admin";

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: "#0B5FFF",
        tabBarInactiveTintColor: "#71717A",
        tabBarStyle: { height: 62, paddingBottom: 8, paddingTop: 6 },
        tabBarLabelStyle: { fontSize: 12 },
      }}
    >
      <Tabs.Screen name="index" options={{ title: "Home", tabBarIcon: icon("\u2302") }} />
      <Tabs.Screen
        name="attendance"
        options={{ title: "Attendance", tabBarIcon: icon("\u2713"), href: showAttendance ? undefined : null }}
      />
      <Tabs.Screen
        name="approvals"
        options={{ title: "Approvals", tabBarIcon: icon("\u2611"), href: showApprovals ? undefined : null }}
      />
      <Tabs.Screen name="tasks" options={{ title: "Tasks", tabBarIcon: icon("\u2261") }} />
      <Tabs.Screen name="more" options={{ title: "More", tabBarIcon: icon("\u22EF") }} />
    </Tabs>
  );
}
