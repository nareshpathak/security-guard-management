import { useQuery } from "@tanstack/react-query";
import { FlatList, RefreshControl, Text, View } from "react-native";
import { useRouter } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";

export default function TasksScreen() {
  const insets = useSafeAreaInsets();
  const router = useRouter();

  const tasks = useQuery({
    queryKey: ["my-tasks"],
    queryFn: () => getApi().get<Row[]>("/api/v2/tasks", { scope: "assigned-to-me", page: 1, pageSize: 50 }),
  });

  if (tasks.isLoading) return <Loading />;

  return (
    <View className="flex-1 bg-bg" style={{ paddingTop: insets.top + 16 }}>
      <Text className="px-4 pb-3 text-2xl font-semibold text-text">My tasks</Text>

      <FlatList
        data={tasks.data?.data ?? []}
        keyExtractor={(r, i) => String(r.TaskID ?? i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        refreshControl={<RefreshControl refreshing={tasks.isFetching} onRefresh={() => void tasks.refetch()} />}
        ListEmptyComponent={<Empty title="Nothing assigned to you" hint="Tasks from your supervisor appear here." />}
        renderItem={({ item }) => {
          const due = item.DueDate ?? item.TargetDate;
          const status = String(item.Status ?? "").toLowerCase();
          const overdue =
            due && new Date(String(due)) < new Date() && !["completed", "done", "closed"].includes(status);

          return (
            <Card className="gap-2">
              <Text className="text-base font-medium text-text">{String(item.Heading ?? item.Title ?? "")}</Text>
              {item.UnitName ? <Text className="text-xs text-muted">{String(item.UnitName)}</Text> : null}
              <View className="flex-row items-center gap-2">
                <Pill
                  text={String(item.Status ?? "New")}
                  tone={status === "completed" ? "success" : status === "new" ? "info" : "warning"}
                />
                {due ? (
                  <Pill
                    text={`Due ${new Date(String(due)).toLocaleDateString("en-IN", { day: "2-digit", month: "short" })}`}
                    tone={overdue ? "danger" : "neutral"}
                  />
                ) : null}
              </View>
            </Card>
          );
        }}
      />
    </View>
  );
}
