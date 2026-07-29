import { MobileList } from "@/components/mobile-list";

/**
 * The operations screen that actually matters: posts falling vacant in the next
 * hour, while there is still time to send someone.
 */
export default function VacantPostsScreen() {
  return (
    <MobileList
      title="Vacant posts"
      subtitle="Falling empty within the hour"
      path="/api/v2/turnout/vacant-posts"
      queryKey="vacant-posts"
      params={{ minutesAhead: 60 }}
      emptyTitle="Nothing falling vacant"
      emptyHint="Every post in the next hour is covered."
      line={{
        title: (r) => String(r.UnitName ?? "Site"),
        subtitle: (r) => `${String(r.PostName ?? "")} · ${String(r.ShiftName ?? "")}`,
        badge: () => ({ text: "Needs a guard", tone: "danger" }),
        detail: (r) => (r.ClientName ? String(r.ClientName) : null),
      }}
    />
  );
}
