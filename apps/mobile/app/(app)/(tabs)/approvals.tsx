import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { FlatList, RefreshControl, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Button, Card, Empty, Loading, Pill } from "@/components/ui";
import { SyncChip } from "@/components/sync-chip";
import { getApi } from "@/lib/api";
import { enqueue } from "@/lib/outbox";

/**
 * The supervisor's approval queue.
 *
 * Decisions go through the outbox like every other field write, so a supervisor
 * standing in a stairwell can clear the queue and have it land when he reaches
 * the street. The row disappears optimistically; if the server later rejects it
 * the item surfaces in the Sync Centre rather than silently reverting.
 */
export default function ApprovalsScreen() {
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();
  const [decided, setDecided] = useState<Set<number>>(new Set());

  const queue = useQuery({
    queryKey: ["approvals"],
    queryFn: () => getApi().get<Row[]>("/api/v2/attendance/pending-approval", { page: 1, pageSize: 50 }),
  });

  const decide = useMutation({
    mutationFn: async ({ id, approve }: { id: number; approve: boolean }) => {
      await enqueue({
        endpoint: "/api/v2/attendance/approve",
        payload: {
          attendanceIds: [id],
          approve,
          rejectReason: approve ? undefined : "Rejected on the mobile app",
        },
        label: `${approve ? "Approve" : "Reject"} attendance #${id}`,
      });
    },
    onMutate: ({ id }) => {
      setDecided((s) => new Set(s).add(id));
    },
    onSettled: () => {
      void qc.invalidateQueries({ queryKey: ["approvals"] });
    },
  });

  if (queue.isLoading) return <Loading />;

  const rows = (queue.data?.data ?? []).filter((r) => !decided.has(Number(r.AttendanceID)));

  return (
    <View className="flex-1 bg-bg" style={{ paddingTop: insets.top + 16 }}>
      <View className="gap-2 px-4 pb-3">
        <Text className="text-2xl font-semibold text-text">Approvals</Text>
        <SyncChip />
      </View>

      <FlatList
        data={rows}
        keyExtractor={(r, i) => String(r.AttendanceID ?? i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        refreshControl={<RefreshControl refreshing={queue.isFetching} onRefresh={() => void queue.refetch()} />}
        ListEmptyComponent={
          <Empty title="Nothing waiting" hint="Attendance from the last three days appears here for approval." />
        }
        renderItem={({ item }) => {
          const id = Number(item.AttendanceID);
          const distance = Number(item.InDistanceMeters ?? 0);
          const far = distance > Number(item.GeofenceRadiusMeters ?? 100);

          return (
            <Card className="gap-3">
              <View className="flex-row items-start justify-between gap-3">
                <View className="flex-1">
                  <Text className="text-base font-medium text-text">{String(item.EmpFullName ?? "")}</Text>
                  <Text className="text-xs text-muted">
                    {String(item.UnitName ?? "")} ·{" "}
                    {new Date(String(item.AttendanceDate)).toLocaleDateString("en-IN", {
                      day: "2-digit",
                      month: "short",
                    })}
                  </Text>
                </View>
                {/* The distance is the whole decision, so it leads. */}
                <Pill text={`${distance} m`} tone={far ? "danger" : "success"} />
              </View>

              {item.Remark ? (
                <Text className="text-sm text-muted">Reason given: {String(item.Remark)}</Text>
              ) : null}

              <View className="flex-row gap-3">
                <Button
                  title="Approve"
                  className="flex-1"
                  onPress={() => decide.mutate({ id, approve: true })}
                />
                <Button
                  title="Reject"
                  tone="outline"
                  className="flex-1"
                  onPress={() => decide.mutate({ id, approve: false })}
                />
              </View>
            </Card>
          );
        }}
      />
    </View>
  );
}
