import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { FlatList, Linking, Pressable, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Button, Card, Empty, Loading, Pill } from "@/components/ui";
import { SyncChip } from "@/components/sync-chip";
import { getApi } from "@/lib/api";
import { enqueue } from "@/lib/outbox";

const MARKS = [
  { code: "P ", label: "Present", tone: "success" as const },
  { code: "A ", label: "Absent", tone: "danger" as const },
  { code: "HD", label: "Half day", tone: "warning" as const },
];

/**
 * Dutylist_frag / Stafflist_frag: the roster for one site.
 *
 * Two things a supervisor does here, and nothing else: mark someone, or ring
 * someone who has not turned up. The call button is why the mobile number is
 * fetched at all.
 */
export default function UnitRosterScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();
  const [marked, setMarked] = useState<Record<number, string>>({});

  const roster = useQuery({
    queryKey: ["unit-roster", id],
    queryFn: () => getApi().get<Row[]>(`/api/v2/units/${id}/employees`),
  });

  const mark = useMutation({
    mutationFn: async ({ empId, status }: { empId: number; status: string }) => {
      await enqueue({
        endpoint: "/api/v2/attendance/bulk",
        payload: {
          unitId: Number(id),
          date: new Date().toISOString().slice(0, 10),
          empIds: [empId],
          status,
        },
        label: `Mark ${status.trim()} · employee ${empId}`,
      });
    },
    onMutate: ({ empId, status }) => {
      setMarked((m) => ({ ...m, [empId]: status }));
    },
    onSettled: () => void qc.invalidateQueries({ queryKey: ["unit-roster", id] }),
  });

  if (roster.isLoading) return <Loading />;

  const rows = roster.data?.data ?? [];
  const unmarked = rows.filter((r) => !r.Status && !marked[Number(r.EmpID)]);

  return (
    <View className="flex-1 bg-bg" style={{ paddingTop: insets.top + 16 }}>
      <View className="gap-2 px-4 pb-3">
        <Text className="text-2xl font-semibold text-text">Today&rsquo;s roster</Text>
        <Text className="text-sm text-muted">
          {rows.length} deployed · {unmarked.length} not yet marked
        </Text>
        <SyncChip />
      </View>

      <FlatList
        data={rows}
        keyExtractor={(r, i) => String(r.EmpID ?? i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        ListEmptyComponent={<Empty title="Nobody deployed here" />}
        renderItem={({ item }) => {
          const empId = Number(item.EmpID);
          const current = marked[empId] ?? String(item.Status ?? "").trim();
          const mobile = String(item.Mobile1 ?? item.MobileNo ?? "");

          return (
            <Card className="gap-3">
              <View className="flex-row items-start justify-between gap-3">
                <View className="flex-1">
                  <Text className="text-base font-medium text-text">{String(item.EmpFullName ?? "")}</Text>
                  <Text className="text-xs text-muted">
                    {String(item.EmpCode ?? "")} · {String(item.DesignationName ?? "")}
                  </Text>
                </View>
                {current ? (
                  <Pill
                    text={MARKS.find((m) => m.code.trim() === current.trim())?.label ?? current}
                    tone={MARKS.find((m) => m.code.trim() === current.trim())?.tone ?? "neutral"}
                  />
                ) : null}
              </View>

              <View className="flex-row gap-2">
                {MARKS.map((m) => (
                  <Button
                    key={m.code}
                    title={m.label}
                    tone={current.trim() === m.code.trim() ? "primary" : "outline"}
                    className="flex-1"
                    onPress={() => mark.mutate({ empId, status: m.code })}
                  />
                ))}
              </View>

              {mobile && !current ? (
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`Call ${String(item.EmpFullName ?? "")}`}
                  onPress={() => void Linking.openURL(`tel:${mobile}`)}
                >
                  <Text className="text-sm text-primary">Call {mobile}</Text>
                </Pressable>
              ) : null}
            </Card>
          );
        }}
      />
    </View>
  );
}
