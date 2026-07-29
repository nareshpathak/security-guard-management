import { MobileList, shortDate } from "@/components/mobile-list";

/** Mycomplaints_frag. */
export default function MyComplaintsScreen() {
  return (
    <MobileList
      title="My complaints"
      subtitle="What you have raised, and where it has reached"
      path="/api/v2/complaints"
      queryKey="my-complaints"
      emptyTitle="You have not raised any"
      emptyHint="Use “Raise a complaint” under More."
      line={{
        title: (r) => String(r.Subject ?? r.Description ?? "Complaint"),
        subtitle: (r) => `${String(r.UnitName ?? "")} · ${shortDate(r.ComplaintDate ?? r.InsertDate)}`,
        badge: (r) =>
          r.IsClosed
            ? { text: "Closed", tone: "neutral" }
            : { text: String(r.Status ?? "Open"), tone: "warning" },
        detail: (r) => (r.Remark ? String(r.Remark) : null),
      }}
    />
  );
}
