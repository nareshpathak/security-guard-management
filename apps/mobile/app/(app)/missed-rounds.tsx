import { MobileList, shortDate } from "@/components/mobile-list";

/** Shownightpatrol_frag: rounds that were due and never scanned. */
export default function MissedRoundsScreen() {
  return (
    <MobileList
      title="Missed rounds"
      subtitle="Scheduled patrols with no scan against them"
      path="/api/v2/patrol/missed"
      queryKey="missed-rounds"
      emptyTitle="Nothing missed"
      emptyHint="Every scheduled round has been scanned."
      line={{
        title: (r) => String(r.UnitName ?? "Site"),
        subtitle: (r) => `${String(r.RoundName ?? r.RoundNo ?? "Round")} · ${shortDate(r.DueAt ?? r.Dated)}`,
        badge: (r) => ({
          text: `${String(r.MissedCount ?? r.MissedCheckpoints ?? 0)} missed`,
          tone: "danger",
        }),
      }}
    />
  );
}
