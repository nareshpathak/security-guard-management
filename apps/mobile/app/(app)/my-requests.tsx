import { MobileList, shortDate } from "@/components/mobile-list";

/** Request_frag list side: what I asked for and where it stands. */
export default function MyRequestsScreen() {
  return (
    <MobileList
      title="My requests"
      subtitle="Leave, advances, transfers and uniform"
      path="/api/v2/hr/requests"
      queryKey="my-requests"
      emptyTitle="Nothing requested"
      emptyHint="Use “Make a request” under More."
      line={{
        title: (r) => String(r.RequestType ?? "Request"),
        subtitle: (r) =>
          r.FromDate
            ? `${shortDate(r.FromDate)}${r.DayCount ? ` · ${String(r.DayCount)} day(s)` : ""}`
            : shortDate(r.InsertDate),
        badge: (r) => {
          const status = String(r.Status ?? "Pending");
          return {
            text: status,
            tone: status === "Approved" ? "success" : status === "Rejected" ? "danger" : "warning",
          };
        },
        detail: (r) => (r.Reason ? String(r.Reason) : null),
      }}
    />
  );
}
