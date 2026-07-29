import { MobileList, shortDate } from "@/components/mobile-list";

/** Fieldreport list: my visits, so a supervisor can see what he already filed. */
export default function FieldReportsScreen() {
  return (
    <MobileList
      title="Field reports"
      subtitle="Site visits you have filed"
      path="/api/v2/field-reports"
      queryKey="field-reports"
      emptyTitle="No reports yet"
      emptyHint="File one from More → Field report while you are at a site."
      line={{
        title: (r) => String(r.UnitName ?? "Site"),
        subtitle: (r) => `${shortDate(r.Createdate)} · met ${String(r.ContactPerson ?? "—")}`,
        badge: (r) => {
          const n = Number(r.GuardRemarkCount ?? 0);
          return n > 0 ? { text: `${n} guard notes`, tone: "info" } : null;
        },
        detail: (r) => (r.Remark ? String(r.Remark) : null),
      }}
    />
  );
}
