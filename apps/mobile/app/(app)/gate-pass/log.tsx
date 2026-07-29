import { MobileList, shortDate, shortTime } from "@/components/mobile-list";

/** Gatepassreport_frag. */
export default function GatePassLogScreen() {
  return (
    <MobileList
      title="Gate pass log"
      subtitle="Everything issued at this site"
      path="/api/v2/gate-passes"
      queryKey="gate-pass-log"
      emptyTitle="Nothing issued"
      line={{
        title: (r) => String(r.Name ?? ""),
        subtitle: (r) => `${shortDate(r.Dated ?? r.InsertDate)} · ${String(r.Purpose ?? "")}`,
        badge: (r) =>
          r.ExitAt || r.ExitTime
            ? { text: `Out ${shortTime(r.ExitAt ?? r.ExitTime)}`, tone: "neutral" }
            : { text: "Still inside", tone: "warning" },
        detail: (r) => (r.Material ? String(r.Material) : null),
      }}
    />
  );
}
