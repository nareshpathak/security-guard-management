import { MobileList } from "@/components/mobile-list";

/** The client's view: who is on their site right now. */
export default function ClientGuardsScreen() {
  return (
    <MobileList
      title="Guards on duty"
      subtitle="Deployed at your sites today"
      path="/api/v2/turnout/live"
      queryKey="client-guards"
      emptyTitle="Nobody on duty"
      emptyHint="If this looks wrong, raise a complaint and the agency is notified at once."
      line={{
        title: (r) => String(r.UnitName ?? "Site"),
        subtitle: (r) => `${String(r.ShiftName ?? "")}`,
        badge: (r) => {
          const gap = Number(r.VacantNos ?? 0);
          return gap > 0
            ? { text: `${gap} short of contract`, tone: "danger" }
            : { text: "Full strength", tone: "success" };
        },
        detail: (r) => `${String(r.PresentNos ?? 0)} present of ${String(r.RequiredNos ?? 0)} contracted`,
      }}
    />
  );
}
