import { useQuery } from "@tanstack/react-query";
import { ScrollView, Text, View } from "react-native";
import type { Row } from "@diti365/shared";
import { Card, Loading } from "@/components/ui";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";

export default function ProfileScreen() {
  const { user } = useAuth();

  const profile = useQuery({
    queryKey: ["profile"],
    queryFn: () => getApi().get<Row>("/api/v2/me/profile"),
  });

  if (profile.isLoading) return <Loading />;
  const p = profile.data?.data ?? {};

  const rows: [string, unknown][] = [
    ["Employee code", p.EmpCode ?? user?.empCode],
    ["Designation", p.DesignationName ?? user?.designation],
    ["Site", p.UnitName ?? user?.unit],
    ["Mobile", p.Mobile1 ?? user?.mobileNo],
    ["Blood group", p.BloodGroup],
    ["Date of joining", p.DateOfJoining],
    ["Police verification", p.PvStatus ?? p.VerificationStatus],
  ];

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-4 p-4 pt-16">
      <Text className="text-2xl font-semibold text-text">{String(p.EmpFullName ?? user?.name ?? "")}</Text>

      <Card className="gap-3">
        {rows.map(([label, value]) => (
          <View key={label} className="flex-row justify-between border-b border-border py-2 last:border-0">
            <Text className="text-sm text-muted">{label}</Text>
            <Text className="text-sm font-medium text-text">
              {value === null || value === undefined || value === "" ? "—" : String(value)}
            </Text>
          </View>
        ))}
      </Card>
    </ScrollView>
  );
}
