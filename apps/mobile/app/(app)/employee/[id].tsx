import { useQuery } from "@tanstack/react-query";
import { Linking, Pressable, ScrollView, Text, View } from "react-native";
import { useLocalSearchParams } from "expo-router";
import type { Row } from "@diti365/shared";
import { Card, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";

/**
 * One guard, as a supervisor needs him: who he is, where he is posted, and a
 * button to ring him. Statutory and bank details are deliberately absent -
 * those need M6.Employee.ViewSensitive and belong on the web console.
 */
export default function EmployeeScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();

  const employee = useQuery({
    queryKey: ["employee", id],
    queryFn: () => getApi().get<Row[][]>(`/api/v2/employees/${id}`),
  });

  if (employee.isLoading) return <Loading />;

  const e = employee.data?.data?.[0]?.[0] ?? {};
  const mobile = String(e.Mobile1 ?? e.MobileNo ?? "");

  const rows: [string, unknown][] = [
    ["Code", e.EmpCode],
    ["Designation", e.DesignationName],
    ["Site", e.UnitName],
    ["Blood group", e.BloodGroup],
    ["Joined", e.DateOfJoining],
    ["Police verification", e.PvStatus ?? e.VerificationStatus],
  ];

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-4 p-4 pt-16">
      <View className="gap-1">
        <Text className="text-2xl font-semibold text-text">{String(e.EmpFullName ?? "Employee")}</Text>
        {e.Status ? <Pill text={String(e.Status)} tone="neutral" /> : null}
      </View>

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

      {mobile ? (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Call ${String(e.EmpFullName ?? "this employee")}`}
          onPress={() => void Linking.openURL(`tel:${mobile}`)}
          className="min-h-[52px] items-center justify-center rounded-xl bg-primary"
        >
          <Text className="text-base font-semibold text-white">Call {mobile}</Text>
        </Pressable>
      ) : null}
    </ScrollView>
  );
}
