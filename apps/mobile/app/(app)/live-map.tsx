import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Text, View } from "react-native";
import MapView, { Marker } from "react-native-maps";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";

/**
 * HomeMapsActivity / Locationlog_frag: where the field staff are.
 *
 * Spoofed positions are excluded by the server, but the count of attempts comes
 * back per person and is shown - a supervisor should be able to see that
 * somebody tried, not just that the map looks fine.
 */
export default function LiveMapScreen() {
  const [selected, setSelected] = useState<Row | null>(null);

  const live = useQuery({
    queryKey: ["tracking-live"],
    queryFn: () => getApi().get<Row[]>("/api/v2/tracking/live", { staleMinutes: 30 }),
    refetchInterval: 30_000,
  });

  if (live.isLoading) return <Loading />;

  const people = (live.data?.data ?? []).filter((p) => p.Latitude && p.Longitude);

  if (people.length === 0) {
    return <Empty title="Nobody is reporting" hint="Field staff report while they are on duty." />;
  }

  const first = people[0];

  return (
    <View className="flex-1">
      <MapView
        style={{ flex: 1 }}
        initialRegion={{
          latitude: Number(first.Latitude),
          longitude: Number(first.Longitude),
          latitudeDelta: 0.08,
          longitudeDelta: 0.08,
        }}
      >
        {people.map((p, i) => (
          <Marker
            key={String(p.UserID ?? i)}
            coordinate={{ latitude: Number(p.Latitude), longitude: Number(p.Longitude) }}
            title={String(p.EmpFullName ?? p.UserName ?? "")}
            description={String(p.CurrentUnit ?? "")}
            pinColor={p.IsStale ? "orange" : Number(p.MockPingsToday ?? 0) > 0 ? "red" : "green"}
            onPress={() => setSelected(p)}
          />
        ))}
      </MapView>

      {selected ? (
        <View className="absolute bottom-6 left-4 right-4">
          <Card className="gap-2">
            <Text className="text-base font-medium text-text">
              {String(selected.EmpFullName ?? selected.UserName ?? "")}
            </Text>
            <Text className="text-xs text-muted">
              {String(selected.CurrentUnit ?? "")} · {String(selected.MinutesAgo ?? 0)} min ago
            </Text>
            <View className="flex-row gap-2">
              {selected.IsStale ? <Pill text="Stale" tone="warning" /> : <Pill text="Live" tone="success" />}
              {Number(selected.MockPingsToday ?? 0) > 0 ? (
                <Pill text={`${String(selected.MockPingsToday)} spoofed pings`} tone="danger" />
              ) : null}
            </View>
          </Card>
        </View>
      ) : null}
    </View>
  );
}
