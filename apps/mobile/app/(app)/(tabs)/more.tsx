import { Pressable, ScrollView, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Button, Card } from "@/components/ui";
import { SyncChip } from "@/components/sync-chip";
import { personaFor, useAuth } from "@/lib/auth";

type Persona = ReturnType<typeof personaFor>;
type Item = { label: string; href: string; roles?: Persona[] };
type Group = { heading: string; items: Item[] };

/**
 * Everything that is not a tab.
 *
 * Grouped and role-filtered rather than one long list: the legacy app put
 * forty-odd entries in a single drawer and people stopped scrolling past the
 * first screenful.
 */
const GROUPS: Group[] = [
  {
    heading: "Me",
    items: [
      { label: "My profile", href: "/(app)/profile" },
      { label: "Salary slip", href: "/(app)/salary-slip", roles: ["guard", "supervisor", "patrol", "gatekeeper", "sales"] },
      { label: "My documents", href: "/(app)/documents" },
      { label: "Uniform ledger", href: "/(app)/uniform/ledger", roles: ["guard", "supervisor"] },
      { label: "Make a request", href: "/(app)/request/new", roles: ["guard", "supervisor", "patrol", "gatekeeper"] },
      { label: "My requests", href: "/(app)/my-requests", roles: ["guard", "supervisor", "patrol", "gatekeeper", "sales"] },
      { label: "Notifications", href: "/(app)/notifications" },
    ],
  },
  {
    heading: "Report something",
    items: [
      { label: "Raise a complaint", href: "/(app)/complaint/new" },
      { label: "My complaints", href: "/(app)/my-complaints" },
      { label: "Report an incident", href: "/(app)/incident/new", roles: ["guard", "supervisor", "patrol", "gatekeeper", "admin"] },
      { label: "Make a suggestion", href: "/(app)/suggestion/new" },
    ],
  },
  {
    heading: "Patrol",
    items: [
      { label: "Scan a checkpoint", href: "/(app)/scan", roles: ["patrol", "guard", "supervisor"] },
      { label: "My scans", href: "/(app)/my-scans", roles: ["patrol", "guard", "supervisor"] },
      { label: "Missed rounds", href: "/(app)/missed-rounds", roles: ["patrol", "supervisor", "admin"] },
      { label: "Night report", href: "/(app)/night-report", roles: ["patrol", "supervisor"] },
    ],
  },
  {
    heading: "Supervision",
    items: [
      { label: "My sites", href: "/(app)/my-units", roles: ["supervisor", "admin"] },
      { label: "Field report", href: "/(app)/field-report/new", roles: ["supervisor", "admin"] },
      { label: "My field reports", href: "/(app)/field-reports", roles: ["supervisor", "admin"] },
      { label: "Turnout entry", href: "/(app)/turnout/new", roles: ["supervisor", "admin"] },
      { label: "Move a guard", href: "/(app)/movement/new", roles: ["supervisor", "admin"] },
      { label: "Record training", href: "/(app)/training/new", roles: ["supervisor", "admin"] },
      { label: "Assign a task", href: "/(app)/task/assign", roles: ["supervisor", "admin"] },
    ],
  },
  {
    heading: "Gate",
    items: [
      { label: "New gate pass", href: "/(app)/gate-pass/new", roles: ["gatekeeper", "supervisor"] },
      { label: "Record an exit", href: "/(app)/gate-pass/exit", roles: ["gatekeeper", "supervisor"] },
      { label: "Gate pass log", href: "/(app)/gate-pass/log", roles: ["gatekeeper", "supervisor", "admin"] },
    ],
  },
  {
    heading: "Sales",
    items: [
      { label: "Log a visit", href: "/(app)/visit/new", roles: ["sales", "admin"] },
      { label: "Log a follow-up", href: "/(app)/follow-up/new", roles: ["sales", "admin"] },
      { label: "Client relation visit", href: "/(app)/client-relation/new", roles: ["sales", "supervisor", "admin"] },
    ],
  },
  {
    heading: "Operations",
    items: [
      { label: "Vacant posts", href: "/(app)/vacant-posts", roles: ["admin", "supervisor"] },
      { label: "Live map", href: "/(app)/live-map", roles: ["admin", "supervisor"] },
      { label: "Uniform stock", href: "/(app)/uniform/stock", roles: ["admin", "supervisor"] },
      { label: "Issue an advance", href: "/(app)/advance/new", roles: ["admin"] },
      { label: "Reports", href: "/(app)/reports", roles: ["admin", "supervisor", "sales"] },
    ],
  },
  {
    heading: "Your service",
    items: [
      { label: "Guards on duty", href: "/(app)/client/guards", roles: ["client"] },
      { label: "Patrol proof", href: "/(app)/client/patrol-proof", roles: ["client"] },
      { label: "Invoices", href: "/(app)/client/invoices", roles: ["client"] },
    ],
  },
  {
    heading: "App",
    items: [
      { label: "Sync centre", href: "/(app)/sync" },
      { label: "Settings", href: "/(app)/settings" },
    ],
  },
];

export default function MoreScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { user, logout } = useAuth();
  const persona = personaFor(user);

  const groups = GROUPS.map((g) => ({
    ...g,
    items: g.items.filter((i) => !i.roles || i.roles.includes(persona)),
  })).filter((g) => g.items.length > 0);

  return (
    <ScrollView
      className="flex-1 bg-bg"
      contentContainerStyle={{ paddingTop: insets.top + 16, paddingBottom: 32 }}
      contentContainerClassName="px-4 gap-5"
    >
      <View className="gap-2">
        <Text className="text-2xl font-semibold text-text">{user?.name ?? "You"}</Text>
        <Text className="text-sm text-muted">
          {user?.empCode ? `${user.empCode} · ` : ""}
          {user?.designation ?? user?.roleCode}
        </Text>
        <SyncChip />
      </View>

      {groups.map((group) => (
        <View key={group.heading} className="gap-2">
          <Text className="px-1 text-xs font-semibold uppercase tracking-wide text-muted">
            {group.heading}
          </Text>
          <Card className="p-0">
            {group.items.map((item, i) => (
              <Pressable
                key={item.href}
                accessibilityRole="button"
                accessibilityLabel={item.label}
                onPress={() => router.push(item.href as never)}
                className={`min-h-[52px] justify-center px-4 ${
                  i < group.items.length - 1 ? "border-b border-border" : ""
                }`}
              >
                <Text className="text-base text-text">{item.label}</Text>
              </Pressable>
            ))}
          </Card>
        </View>
      ))}

      <Button title="Sign out" tone="outline" onPress={() => void logout()} />
      <Text className="text-center text-xs text-muted">Diti365 · version 1.0.0</Text>
    </ScrollView>
  );
}
