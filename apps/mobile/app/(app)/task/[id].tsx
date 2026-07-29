import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ScrollView, Text, View } from "react-native";
import { useLocalSearchParams, useRouter } from "expo-router";
import type { Row } from "@diti365/shared";
import { Button, Card, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";
import { enqueue } from "@/lib/outbox";

export default function TaskScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const qc = useQueryClient();

  const task = useQuery({
    queryKey: ["task", id],
    queryFn: () => getApi().get<Row[][]>(`/api/v2/tasks/${id}`),
  });

  const setStatus = useMutation({
    mutationFn: async (status: string) => {
      // Through the outbox: a guard marking a task done in a stairwell should
      // not have to remember to do it again outside.
      await enqueue({
        endpoint: `/api/v2/tasks/${id}/status`,
        payload: { status },
        label: `Task ${status} · #${id}`,
      });
    },
    onSettled: () => void qc.invalidateQueries({ queryKey: ["task", id] }),
  });

  if (task.isLoading) return <Loading />;

  const [details = [], checklist = [], history = []] = task.data?.data ?? [];
  const t = details[0] ?? {};
  const status = String(t.Status ?? "").toLowerCase();
  const done = ["completed", "done", "closed"].includes(status);

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-4 p-4 pt-16 pb-10">
      <View className="gap-2">
        <Text className="text-2xl font-semibold text-text">
          {String(t.Heading ?? t.Title ?? `Task ${id}`)}
        </Text>
        <Text className="text-sm text-muted">{String(t.UnitName ?? "")}</Text>
        <Pill
          text={String(t.Status ?? "New")}
          tone={done ? "success" : status === "new" ? "info" : "warning"}
        />
      </View>

      {t.Description ? (
        <Card>
          <Text className="text-sm text-text">{String(t.Description)}</Text>
        </Card>
      ) : null}

      {checklist.length > 0 ? (
        <Card className="gap-2">
          <Text className="text-sm font-semibold text-text">Checklist</Text>
          {checklist.map((c, i) => (
            <View key={i} className="flex-row items-center gap-2 py-1">
              <Text className={c.IsDone ? "text-success" : "text-muted"}>{c.IsDone ? "☑" : "☐"}</Text>
              <Text className={c.IsDone ? "flex-1 text-sm text-muted" : "flex-1 text-sm text-text"}>
                {String(c.ItemText ?? c.Title ?? "")}
              </Text>
            </View>
          ))}
        </Card>
      ) : null}

      {history.length > 0 ? (
        <Card className="gap-2">
          <Text className="text-sm font-semibold text-text">History</Text>
          {history.map((h, i) => (
            <View key={i} className="border-b border-border py-2 last:border-0">
              <Text className="text-sm text-text">{String(h.ToStatus ?? h.Status ?? "")}</Text>
              <Text className="text-xs text-muted">
                {String(h.ChangedByName ?? "")} · {new Date(String(h.ChangedOn ?? h.InsertDate)).toLocaleString()}
              </Text>
            </View>
          ))}
        </Card>
      ) : null}

      <View className="gap-3">
        {!done ? (
          <Button
            title={status === "new" ? "Start this task" : "Mark complete"}
            loading={setStatus.isPending}
            onPress={() => setStatus.mutate(status === "new" ? "In Progress" : "Completed")}
          />
        ) : null}
        <Button title="Back" tone="ghost" onPress={() => router.back()} />
      </View>
    </ScrollView>
  );
}
