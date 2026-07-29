import { MobileList, shortDate, shortTime } from "@/components/mobile-list";

/**
 * Patrol proof for the client.
 *
 * This is the screen that justifies the invoice: every checkpoint scan, with
 * the time and whether the guard was actually within range of it.
 */
export default function PatrolProofScreen() {
  const from = new Date();
  from.setDate(from.getDate() - 7);

  return (
    <MobileList
      title="Patrol proof"
      subtitle="Every checkpoint scanned at your sites this week"
      path="/api/v2/patrol/logs"
      queryKey="client-patrol"
      params={{ from: from.toISOString().slice(0, 10) }}
      emptyTitle="No scans this week"
      emptyHint="If rounds were expected, raise this with the agency."
      line={{
        title: (r) => String(r.QrName ?? r.CheckpointName ?? "Checkpoint"),
        subtitle: (r) =>
          `${String(r.UnitName ?? "")} · ${shortDate(r.Scantime ?? r.ScanTime)} ${shortTime(r.Scantime ?? r.ScanTime)}`,
        badge: (r) =>
          r.IsWithinRange === true || r.IsWithinRange === 1
            ? { text: "Verified", tone: "success" }
            : { text: "Out of range", tone: "danger" },
      }}
    />
  );
}
