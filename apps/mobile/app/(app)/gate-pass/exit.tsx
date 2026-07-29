import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { FlatList, Text, View } from "react-native";
import type { Row } from "@diti365/shared";
import { Button, Card, Empty, Loading } from "@/components/ui";
import { getApi } from "@/lib/api";
import { enqueue } from "@/lib/outbox";

/**
 * Stamping an exit.
 *
 * The list is "who is still inside" rather than every pass ever issued: at
 * shift handover the only question a gatekeeper has is who has not left.
 */
export default function GatePassExitScreen() {
  const [stamped, setStamped] = useState<Set<number>>(new Set());

  const passes = useQuery({
    queryKey: ["gate-passes-inside"],
    queryFn: () => getApi().get<Row[]>("/api/v2/gate-passes", { page: 1, pageSize: 50 }),
  });

  if (passes.isLoading) return <Loading />;

  const inside = (passes.data?.data ?? []).filter(
    (p) => !p.ExitAt && !p.ExitTime && !stamped.has(Number(p.GatePassID)),
  );

  return (
    <View className="flex-1 bg-bg pt-16">
      <Text className="px-4 pb-1 text-2xl font-semibold text-text">Still inside</Text>
      <Text className="px-4 pb-3 text-sm text-muted">{inside.length} not yet stamped out</Text>

      <FlatList
        data={inside}
        keyExtractor={(r, i) => String(r.GatePassID ?? i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        ListEmptyComponent={<Empty title="Everyone has left" hint="No open gate passes at your site." />}
        renderItem={({ item }) => {
          const id = Number(item.GatePassID);
          return (
            <Card className="gap-3">
              <View>
                <Text className="text-base font-medium text-text">{String(item.Name ?? "")}</Text>
                <Text className="text-xs text-muted">
                  {String(item.Purpose ?? item.Material ?? "")}
                  {item.MobileNo ? ` · ${String(item.MobileNo)}` : ""}
                </Text>
              </View>
              <Button
                title="Stamp exit"
                onPress={async () => {
                  setStamped((s) => new Set(s).add(id));
                  await enqueue({
                    endpoint: `/api/v2/gate-passes/${id}/exit`,
                    payload: { exitAt: new Date().toISOString() },
                    label: `Gate pass exit · ${String(item.Name ?? id)}`,
                  });
                }}
              />
            </Card>
          );
        }}
      />
    </View>
  );
}
