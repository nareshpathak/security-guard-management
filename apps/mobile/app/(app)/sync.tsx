import { useCallback, useState } from "react";
import { FlatList, RefreshControl, Text, View } from "react-native";
import { useFocusEffect } from "expo-router";
import { Button, Card, Empty, Pill } from "@/components/ui";
import { discard, listOutbox, retryNow, flush } from "@/lib/outbox";
import type { OutboxRow } from "@/lib/db";

/**
 * Sync centre: everything the phone still owes the server.
 *
 * Nothing is ever silently dropped. An item that has genuinely failed sits here
 * with its error and two honest choices - retry, or discard and lose it - which
 * is a decision only a person should make.
 */
export default function SyncScreen() {
  const [items, setItems] = useState<OutboxRow[]>([]);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setItems(await listOutbox());
  }, []);

  useFocusEffect(
    useCallback(() => {
      void load();
    }, [load]),
  );

  async function syncAll() {
    setBusy(true);
    await flush();
    await load();
    setBusy(false);
  }

  return (
    <View className="flex-1 bg-bg">
      <FlatList
        data={items}
        keyExtractor={(i) => i.id}
        contentContainerClassName="gap-3 p-4"
        refreshControl={<RefreshControl refreshing={busy} onRefresh={syncAll} />}
        ListEmptyComponent={
          <Empty title="Everything is synced" hint="Anything recorded offline appears here until it reaches the server." />
        }
        ListHeaderComponent={
          items.length > 0 ? (
            <Button title="Sync everything now" loading={busy} onPress={syncAll} className="mb-1" />
          ) : null
        }
        renderItem={({ item }) => (
          <Card>
            <View className="flex-row items-start justify-between gap-3">
              <View className="flex-1">
                <Text className="text-base font-medium text-text">{item.label}</Text>
                <Text className="mt-0.5 text-xs text-muted">
                  {new Date(item.createdAt).toLocaleString()}
                  {item.attempts > 0 ? ` · ${item.attempts} attempt${item.attempts === 1 ? "" : "s"}` : ""}
                </Text>
              </View>
              <Pill
                text={item.status === "failed" ? "Needs attention" : item.status === "syncing" ? "Sending" : "Queued"}
                tone={item.status === "failed" ? "danger" : item.status === "syncing" ? "info" : "warning"}
              />
            </View>

            {item.lastError ? (
              <Text className="mt-3 text-sm text-danger">{item.lastError}</Text>
            ) : null}

            {item.status === "failed" ? (
              <View className="mt-4 flex-row gap-3">
                <Button
                  title="Try again"
                  tone="outline"
                  className="flex-1"
                  onPress={async () => {
                    await retryNow(item.id);
                    await load();
                  }}
                />
                <Button
                  title="Discard"
                  tone="ghost"
                  className="flex-1"
                  onPress={async () => {
                    await discard(item.id);
                    await load();
                  }}
                />
              </View>
            ) : null}
          </Card>
        )}
      />
    </View>
  );
}
