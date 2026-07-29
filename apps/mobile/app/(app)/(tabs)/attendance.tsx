import { useQuery } from "@tanstack/react-query";
import { ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import type { Row } from "@diti365/shared";
import { Card, Empty, Loading, Pill } from "@/components/ui";
import { getApi } from "@/lib/api";

const STATUS_COLOUR: Record<string, string> = {
  "P": "bg-present",
  "A": "bg-absent",
  "HD": "bg-halfday",
  "WO": "bg-weekoff",
  "HL": "bg-holiday",
  "L": "bg-leave",
};

/**
 * My month, as a calendar.
 *
 * A guard checking whether he was marked present on the 14th should not have to
 * read a table. Colour carries the pattern; every day also states its status in
 * words when tapped, because colour alone fails one man in twelve.
 */
export default function AttendanceScreen() {
  const insets = useSafeAreaInsets();
  const month = new Date().toISOString().slice(0, 7);

  const attendance = useQuery({
    queryKey: ["my-attendance", month],
    queryFn: () => getApi().get<{ days: Row[]; summary?: Row }>("/api/v2/attendance/me", { monthYear: month }),
  });

  if (attendance.isLoading) return <Loading />;

  const days = attendance.data?.data?.days ?? [];

  return (
    <ScrollView
      className="flex-1 bg-bg"
      contentContainerStyle={{ paddingTop: insets.top + 16, paddingBottom: 32 }}
      contentContainerClassName="px-4 gap-4"
    >
      <Text className="text-2xl font-semibold text-text">My attendance</Text>
      <Text className="-mt-2 text-sm text-muted">{monthName(month)}</Text>

      {days.length === 0 ? (
        <Empty title="Nothing recorded this month" hint="Your punches appear here as soon as they sync." />
      ) : (
        <>
          <Card>
            <View className="flex-row flex-wrap gap-2">
              {days.map((d, i) => {
                const status = String(d.Status ?? "").trim();
                return (
                  <View
                    key={i}
                    accessibilityLabel={`${new Date(String(d.AttendanceDate)).getDate()}: ${statusWord(status)}`}
                    className={`h-11 w-11 items-center justify-center rounded-lg ${STATUS_COLOUR[status] ?? "bg-black/5"}`}
                  >
                    <Text className={`text-sm font-medium ${STATUS_COLOUR[status] ? "text-white" : "text-muted"}`}>
                      {new Date(String(d.AttendanceDate)).getDate()}
                    </Text>
                  </View>
                );
              })}
            </View>
          </Card>

          <View className="flex-row flex-wrap gap-2">
            {Object.entries({ P: "Present", A: "Absent", HD: "Half day", WO: "Week off", HL: "Holiday", L: "Leave" }).map(
              ([code, label]) => (
                <View key={code} className="flex-row items-center gap-1.5">
                  <View className={`h-3 w-3 rounded ${STATUS_COLOUR[code]}`} />
                  <Text className="text-xs text-muted">{label}</Text>
                </View>
              ),
            )}
          </View>

          <Card className="gap-3">
            <Text className="text-sm font-semibold text-text">Days in detail</Text>
            {days.slice(-10).reverse().map((d, i) => (
              <View key={i} className="flex-row items-center justify-between border-b border-border py-2 last:border-0">
                <View>
                  <Text className="text-sm text-text">
                    {new Date(String(d.AttendanceDate)).toLocaleDateString("en-IN", {
                      day: "2-digit",
                      month: "short",
                    })}
                  </Text>
                  <Text className="text-xs text-muted">
                    {d.InTime ? new Date(String(d.InTime)).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" }) : "—"}
                    {" – "}
                    {d.OutTime ? new Date(String(d.OutTime)).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" }) : "—"}
                  </Text>
                </View>
                <Pill
                  text={statusWord(String(d.Status ?? "").trim())}
                  tone={
                    String(d.Status ?? "").trim() === "P"
                      ? "success"
                      : String(d.Status ?? "").trim() === "A"
                        ? "danger"
                        : "neutral"
                  }
                />
              </View>
            ))}
          </Card>
        </>
      )}
    </ScrollView>
  );
}

function statusWord(code: string): string {
  return (
    { P: "Present", A: "Absent", HD: "Half day", WO: "Week off", HL: "Holiday", L: "Leave", DS: "Double shift" }[
      code
    ] ?? "Not marked"
  );
}

function monthName(m: string): string {
  return new Date(`${m}-01`).toLocaleDateString("en-IN", { month: "long", year: "numeric" });
}
