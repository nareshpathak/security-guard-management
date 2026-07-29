import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { ScrollView, Text, View } from "react-native";
import type { Row } from "@diti365/shared";
import { Button, Card, Empty, Loading } from "@/components/ui";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";

function monthKey(offset: number): string {
  const d = new Date();
  d.setMonth(d.getMonth() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
});

function money(v: unknown): string {
  const n = Number(v);
  return Number.isFinite(n) ? inr.format(n) : "—";
}

/**
 * The guard's own slip.
 *
 * Amounts are shown to the paisa. This is a statement of what someone earning
 * close to minimum wage is owed; rounding it for tidiness would be a wrong
 * number, not a display choice.
 */
export default function SalarySlipScreen() {
  const { user } = useAuth();
  const [offset, setOffset] = useState(-1);
  const month = monthKey(offset);

  const slip = useQuery({
    queryKey: ["salary-slip", user?.empId, month],
    enabled: Boolean(user?.empId),
    queryFn: () => getApi().get<Row | null>(`/api/v2/payroll/slips/${user!.empId}/${month}`),
  });

  const s = slip.data?.data ?? null;

  return (
    <ScrollView className="flex-1 bg-bg" contentContainerClassName="gap-4 p-4 pt-16">
      <Text className="text-2xl font-semibold text-text">Salary slip</Text>

      <View className="flex-row items-center gap-3">
        <Button title="←" tone="outline" onPress={() => setOffset((o) => o - 1)} />
        <Text className="flex-1 text-center text-base font-medium text-text">
          {new Date(`${month}-01`).toLocaleDateString("en-IN", { month: "long", year: "numeric" })}
        </Text>
        <Button title="→" tone="outline" disabled={offset >= -1} onPress={() => setOffset((o) => o + 1)} />
      </View>

      {slip.isLoading ? <Loading /> : null}

      {!slip.isLoading && !s ? (
        <Empty
          title="No slip for this month"
          hint="Payroll may not have run yet, or your attendance is still awaiting approval."
        />
      ) : null}

      {s ? (
        <>
          <Card className="gap-2">
            <Text className="text-sm font-semibold text-text">Earnings</Text>
            {[
              ["Basic", s.BasicSalary ?? s.Basic],
              ["HRA", s.Hra],
              ["Conveyance", s.Conveyance],
              ["Washing allowance", s.WashingAllowance],
              ["Overtime", s.OtAmount],
            ].map(([label, value]) => (
              <View key={String(label)} className="flex-row justify-between py-1">
                <Text className="text-sm text-muted">{String(label)}</Text>
                <Text className="text-sm text-text">{money(value)}</Text>
              </View>
            ))}
            <View className="mt-1 flex-row justify-between border-t border-border pt-2">
              <Text className="text-sm font-semibold text-text">Gross</Text>
              <Text className="text-sm font-semibold text-text">{money(s.GrossSalary ?? s.Gross)}</Text>
            </View>
          </Card>

          <Card className="gap-2">
            <Text className="text-sm font-semibold text-text">Deductions</Text>
            {[
              ["Provident fund", s.Pf],
              ["ESIC", s.Esic],
              ["Professional tax", s.Pt],
              ["Advance recovered", s.AdvanceDeduction],
              ["Uniform recovered", s.UniformDeduction],
            ].map(([label, value]) => (
              <View key={String(label)} className="flex-row justify-between py-1">
                <Text className="text-sm text-muted">{String(label)}</Text>
                <Text className="text-sm text-text">{money(value)}</Text>
              </View>
            ))}
            <View className="mt-1 flex-row justify-between border-t border-border pt-2">
              <Text className="text-sm font-semibold text-text">Total</Text>
              <Text className="text-sm font-semibold text-text">
                {money(s.TotalDeduction ?? s.Deductions)}
              </Text>
            </View>
          </Card>

          <Card className="flex-row items-center justify-between">
            <Text className="text-base font-semibold text-text">Net payable</Text>
            <Text className="text-2xl font-semibold text-text">
              {money(s.NetPayble ?? s.NetPayable)}
            </Text>
          </Card>
        </>
      ) : null}
    </ScrollView>
  );
}
