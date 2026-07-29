import { MobileList, shortDate } from "@/components/mobile-list";

/**
 * The notification inbox.
 *
 * Backed by tasks rather than a separate feed: in this product every push a
 * guard receives is a task, an approval or an incident, and all three are
 * already addressable records. A parallel notification table would drift.
 */
export default function NotificationsScreen() {
  return (
    <MobileList
      title="Notifications"
      subtitle="What has come in for you"
      path="/api/v2/tasks"
      queryKey="notifications"
      params={{ scope: "assigned-to-me" }}
      emptyTitle="Nothing new"
      line={{
        title: (r) => String(r.Heading ?? r.Title ?? "Notification"),
        subtitle: (r) => `${String(r.UnitName ?? "")} · ${shortDate(r.InsertDate)}`,
        badge: (r) =>
          r.IsRead ? null : { text: "New", tone: "info" },
        detail: (r) => (r.Description ? String(r.Description) : null),
      }}
    />
  );
}
