import { useQuery } from "@tanstack/react-query";
import { RefreshControl, ScrollView, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Button, Card, Loading, Pill, Stat } from "@/components/ui";
import { SyncChip } from "@/components/sync-chip";
import { getApi } from "@/lib/api";
import { personaFor, useAuth } from "@/lib/auth";
import { useSyncEngine } from "@/lib/sync";

/**
 * One home screen, seven faces.
 *
 * The legacy app shipped a separate Activity per role, which meant a fix to the
 * turnout card had to be made six times. Here the persona picks the sections.
 */
export default function HomeScreen() {
  const { user } = useAuth();
  const persona = personaFor(user);
  const { syncNow } = useSyncEngine();
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const dashboard = useQuery({
    queryKey: ["dashboard"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/me/dashboard"),
  });

  const myAttendance = useQuery({
    queryKey: ["my-attendance-counts"],
    enabled: persona === "guard",
    queryFn: () =>
      getApi().get<{ presentCount: number; absentCount: number; pendingCount: number }>(
        "/api/v2/attendance/counts",
      ),
  });

  const patrol = useQuery({
    queryKey: ["my-patrol-progress"],
    enabled: persona === "patrol",
    queryFn: () => getApi().get<Row[]>("/api/v2/patrol/my-progress"),
  });

  const turnout = useQuery({
    queryKey: ["turnout-live"],
    enabled: persona === "admin" || persona === "supervisor",
    queryFn: () => getApi().get<Row[]>("/api/v2/turnout/live"),
  });

  if (dashboard.isLoading) return <Loading />;

  const units = turnout.data?.data ?? [];
  const required = units.reduce((n, r) => n + Number(r.RequiredNos ?? 0), 0);
  const present = units.reduce((n, r) => n + Number(r.PresentNos ?? 0), 0);
  const short = units.filter((r) => Number(r.VacantNos ?? 0) > 0).length;

  return (
    <ScrollView
      className="flex-1 bg-bg"
      contentContainerStyle={{ paddingTop: insets.top + 16, paddingBottom: 32 }}
      contentContainerClassName="px-4 gap-4"
      refreshControl={
        <RefreshControl
          refreshing={dashboard.isFetching}
          onRefresh={async () => {
            // Pull-to-refresh is also a sync trigger: it is the gesture a guard
            // reaches for when he suspects something has not gone through.
            await syncNow();
            await dashboard.refetch();
          }}
        />
      }
    >
      <View className="gap-2">
        <Text className="text-2xl font-semibold text-text">
          {greeting()}, {user?.name?.split(" ")[0] ?? "there"}
        </Text>
        <Text className="text-sm text-muted">
          {user?.designation ?? user?.roleCode} {user?.unit ? `· ${user.unit}` : ""}
        </Text>
        <SyncChip />
      </View>

      {persona === "guard" ? (
        <>
          <Card className="items-center gap-4 py-8">
            <Text className="text-sm text-muted">Your duty today</Text>
            <Button
              title="Punch in / out"
              className="w-full"
              onPress={() => router.push("/(app)/punch")}
            />
            <Text className="text-center text-xs text-muted">
              Works without signal. Your punch is saved on the phone and sent when you have network.
            </Text>
          </Card>

          <Card>
            <Text className="mb-3 text-sm font-semibold text-text">This month</Text>
            <View className="flex-row gap-4">
              <Stat label="Present" value={String(myAttendance.data?.data?.presentCount ?? "—")} tone="success" />
              <Stat label="Absent" value={String(myAttendance.data?.data?.absentCount ?? "—")} tone="danger" />
              <Stat label="Pending" value={String(myAttendance.data?.data?.pendingCount ?? "—")} tone="warning" />
            </View>
          </Card>
        </>
      ) : null}

      {persona === "patrol" ? (
        <>
          <Card className="gap-4 py-6">
            <Text className="text-sm text-muted">Tonight&rsquo;s rounds</Text>
            {(patrol.data?.data ?? []).map((r, i) => (
              <View key={i} className="flex-row items-center justify-between">
                <View>
                  <Text className="text-base font-medium text-text">{String(r.RoundName ?? r.UnitName ?? "Round")}</Text>
                  <Text className="text-xs text-muted">
                    {String(r.ScannedCount ?? 0)} of {String(r.TotalCheckpoints ?? 0)} checkpoints
                  </Text>
                </View>
                <Pill
                  text={Number(r.ScannedCount ?? 0) >= Number(r.TotalCheckpoints ?? 0) ? "Done" : "In progress"}
                  tone={Number(r.ScannedCount ?? 0) >= Number(r.TotalCheckpoints ?? 0) ? "success" : "warning"}
                />
              </View>
            ))}
            <Button title="Scan a checkpoint" onPress={() => router.push("/(app)/scan")} />
          </Card>
        </>
      ) : null}

      {persona === "admin" || persona === "supervisor" ? (
        <Card>
          <Text className="mb-3 text-sm font-semibold text-text">Turnout right now</Text>
          <View className="flex-row gap-4">
            <Stat label="On duty" value={`${present}/${required}`} tone={present < required ? "warning" : "success"} />
            <Stat label="Sites short" value={String(short)} tone={short > 0 ? "danger" : "success"} />
          </View>
        </Card>
      ) : null}

      {persona === "gatekeeper" ? (
        <Card className="gap-4 py-6">
          <Text className="text-sm text-muted">Gate</Text>
          <Button title="New gate pass" onPress={() => router.push("/(app)/gate-pass/new")} />
          <Button title="Record an exit" tone="outline" onPress={() => router.push("/(app)/gate-pass/exit")} />
        </Card>
      ) : null}

      {persona === "sales" ? (
        <Card className="gap-4 py-6">
          <Text className="text-sm text-muted">Field</Text>
          <Button title="Log a visit" onPress={() => router.push("/(app)/visit/new")} />
          <Button title="Follow-ups due" tone="outline" onPress={() => router.push("/(app)/(tabs)/tasks")} />
        </Card>
      ) : null}

      {/* Every role gets the dashboard widgets the API decided they should see. */}
      {(dashboard.data?.data ?? []).slice(0, 3).map((set, i) =>
        set.length === 0 ? null : (
          <Card key={i}>
            <Text className="mb-2 text-sm font-semibold text-text">{widgetTitle(i)}</Text>
            {set.slice(0, 5).map((row, j) => (
              <View key={j} className="flex-row justify-between border-b border-border py-2 last:border-0">
                <Text className="flex-1 text-sm text-text" numberOfLines={1}>
                  {String(Object.values(row)[0] ?? "")}
                </Text>
                <Text className="text-sm font-medium text-text">
                  {String(Object.values(row)[1] ?? "")}
                </Text>
              </View>
            ))}
          </Card>
        ),
      )}
    </ScrollView>
  );
}

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

function widgetTitle(index: number): string {
  return ["Needs attention", "Today", "Recent"][index] ?? "More";
}
