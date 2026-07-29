import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { FlatList, Pressable, ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading } from "@/components/ui";
import { getApi } from "@/lib/api";

/**
 * All the *rpt_frag screens in one.
 *
 * The legacy app shipped roughly twenty report fragments that differed only in
 * which endpoint they called. Here the allow-list comes from the API and the
 * rows are rendered from whatever shape comes back.
 */
export default function ReportsScreen() {
  const insets = useSafeAreaInsets();
  const [active, setActive] = useState<string | null>(null);

  const keys = useQuery({
    queryKey: ["report-keys"],
    queryFn: () => getApi().get<{ key?: string; name?: string }[]>("/api/v2/reports"),
    staleTime: Infinity,
  });

  const report = useQuery({
    queryKey: ["report", active],
    enabled: Boolean(active),
    queryFn: () => getApi().get<Row[]>(`/api/v2/reports/${active}`, { page: 1, pageSize: 100 }),
  });

  if (keys.isLoading) return <Loading />;

  return (
    <View className="flex-1 bg-bg" style={{ paddingTop: insets.top + 16 }}>
      <Text className="px-4 pb-3 text-2xl font-semibold text-text">Reports</Text>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2 px-4 pb-3">
        {(keys.data?.data ?? []).map((k, i) => {
          const key = String(k.key ?? k ?? "");
          return (
            <Pressable
              key={key || i}
              accessibilityRole="button"
              onPress={() => setActive(key)}
              className={`min-h-[40px] justify-center rounded-full px-4 ${
                active === key ? "bg-primary" : "border border-border bg-surface"
              }`}
            >
              <Text className={active === key ? "text-sm text-white" : "text-sm text-text"}>
                {String(k.name ?? key).replace(/([a-z])([A-Z])/g, "$1 $2")}
              </Text>
            </Pressable>
          );
        })}
      </ScrollView>

      {!active ? (
        <Empty title="Pick a report" hint="Each one runs against live data." />
      ) : report.isLoading ? (
        <Loading />
      ) : (
        <FlatList
          data={report.data?.data ?? []}
          keyExtractor={(_, i) => String(i)}
          contentContainerClassName="gap-3 px-4 pb-8"
          ListEmptyComponent={<Empty title="Nothing in this period" />}
          renderItem={({ item }) => {
            const entries = Object.entries(item)
              .filter(([k]) => !/^(CompanyID|IsCancel|InsertUserID|UpdateUserID|TotalRows)$/i.test(k))
              .slice(0, 5);
            return (
              <Card className="gap-1">
                {entries.map(([k, v], i) => (
                  <View key={k} className="flex-row justify-between gap-3">
                    <Text className={i === 0 ? "flex-1 text-base font-medium text-text" : "text-sm text-muted"}>
                      {i === 0 ? String(v ?? "—") : k.replace(/([a-z])([A-Z])/g, "$1 $2")}
                    </Text>
                    {i > 0 ? (
                      <Text className="text-sm text-text">{v === null || v === undefined ? "—" : String(v)}</Text>
                    ) : null}
                  </View>
                ))}
              </Card>
            );
          }}
        />
      )}
    </View>
  );
}
