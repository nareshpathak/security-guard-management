import { MobileList, shortTime } from "@/components/mobile-list";

/** Qrloglist_frag: what I have scanned tonight. */
export default function MyScansScreen() {
  const from = new Date();
  from.setHours(0, 0, 0, 0);

  return (
    <MobileList
      title="My scans"
      subtitle="Checkpoints you have covered today"
      path="/api/v2/patrol/logs"
      queryKey="my-scans"
      params={{ from: from.toISOString().slice(0, 10) }}
      emptyTitle="No scans yet today"
      emptyHint="Scans queued offline appear here once they reach the server."
      line={{
        title: (r) => String(r.QrName ?? r.CheckpointName ?? "Checkpoint"),
        subtitle: (r) => `${String(r.UnitName ?? "")} · ${shortTime(r.Scantime ?? r.ScanTime)}`,
        badge: (r) =>
          r.IsWithinRange === true || r.IsWithinRange === 1
            ? { text: `${String(r.DistanceMeters ?? 0)} m`, tone: "success" }
            : { text: `${String(r.DistanceMeters ?? 0)} m — out of range`, tone: "danger" },
      }}
    />
  );
}
