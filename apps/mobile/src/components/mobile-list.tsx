import { useQuery } from "@tanstack/react-query";
import { FlatList, RefreshControl, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";
import { useSyncEngine } from "@/lib/sync";

export type ListLine = {
  /** Bold first line. */
  title: (r: Row) => string;
  /** Grey second line. */
  subtitle?: (r: Row) => string;
  /** Right-hand pill. */
  badge?: (r: Row) => { text: string; tone: "success" | "danger" | "warning" | "info" | "neutral" } | null;
  /** Third line, for a remark or amount. */
  detail?: (r: Row) => string | null;
};

/**
 * A read-only list, which is most of what this app shows.
 *
 * Pull-to-refresh also flushes the outbox: it is the gesture people reach for
 * when they suspect something has not gone through, so it should do the thing
 * they actually mean.
 */
export function MobileList({
  title,
  subtitle,
  path,
  queryKey,
  params,
  line,
  emptyTitle,
  emptyHint,
  header,
}: {
  title: string;
  subtitle?: string;
  path: string;
  queryKey: string;
  params?: Record<string, string | number | boolean | undefined>;
  line: ListLine;
  emptyTitle: string;
  emptyHint?: string;
  header?: React.ReactNode;
}) {
  const insets = useSafeAreaInsets();
  const { syncNow } = useSyncEngine();

  const query = useQuery({
    queryKey: [queryKey, params],
    queryFn: () => getApi().get<Row[]>(path, { page: 1, pageSize: 100, ...params }),
  });

  if (query.isLoading) return <Loading />;

  return (
    <View className="flex-1 bg-bg" style={{ paddingTop: insets.top + 16 }}>
      <View className="px-4 pb-3">
        <Text className="text-2xl font-semibold text-text">{title}</Text>
        {subtitle ? <Text className="mt-1 text-sm text-muted">{subtitle}</Text> : null}
      </View>

      <FlatList
        data={query.data?.data ?? []}
        keyExtractor={(_, i) => String(i)}
        contentContainerClassName="gap-3 px-4 pb-8"
        ListHeaderComponent={header ? <View className="mb-1">{header}</View> : null}
        refreshControl={
          <RefreshControl
            refreshing={query.isFetching}
            onRefresh={async () => {
              await syncNow();
              await query.refetch();
            }}
          />
        }
        ListEmptyComponent={<Empty title={emptyTitle} hint={emptyHint} />}
        renderItem={({ item }) => {
          const badge = line.badge?.(item) ?? null;
          const detail = line.detail?.(item) ?? null;
          return (
            <Card className="gap-1.5">
              <View className="flex-row items-start justify-between gap-3">
                <View className="flex-1">
                  <Text className="text-base font-medium text-text">{line.title(item)}</Text>
                  {line.subtitle ? (
                    <Text className="mt-0.5 text-xs text-muted">{line.subtitle(item)}</Text>
                  ) : null}
                </View>
                {badge ? <Pill text={badge.text} tone={badge.tone} /> : null}
              </View>
              {detail ? <Text className="text-sm text-muted">{detail}</Text> : null}
            </Card>
          );
        }}
      />
    </View>
  );
}

/** Shared date helper so every list formats a date the same way. */
export function shortDate(v: unknown): string {
  if (!v) return "";
  const d = new Date(String(v));
  return Number.isNaN(d.getTime())
    ? ""
    : d.toLocaleDateString("en-IN", { day: "2-digit", month: "short" });
}

export function shortTime(v: unknown): string {
  if (!v) return "";
  const d = new Date(String(v));
  return Number.isNaN(d.getTime())
    ? ""
    : d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", hour12: false });
}
