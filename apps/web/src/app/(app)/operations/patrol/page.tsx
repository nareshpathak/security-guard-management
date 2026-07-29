"use client";

import { useSearchParams } from "next/navigation";
import { Button } from "@diti365/ui";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell, useListQueryState } from "@/lib/list-query";
import { dateTime, isoDate } from "@/lib/format";

type Tab = "logs" | "checkpoints" | "missed";

export default function PatrolPage() {
  const params = useSearchParams();
  const q = useListQueryState();
  const tab = (params.get("tab") as Tab) ?? "logs";

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  const tabs: { id: Tab; label: string }[] = [
    { id: "logs", label: "Scan log" },
    { id: "checkpoints", label: "Checkpoints" },
    { id: "missed", label: "Missed rounds" },
  ];

  const switcher = (
    <div className="flex gap-2">
      {tabs.map((t) => (
        <Button
          key={t.id}
          size="sm"
          variant={tab === t.id ? "primary" : "outline"}
          onClick={() => q.setParams({ tab: t.id === "logs" ? undefined : t.id, page: 1 })}
        >
          {t.label}
        </Button>
      ))}
    </div>
  );

  if (tab === "checkpoints") {
    return (
      <ResourceList
        title="Patrol"
        description="QR checkpoints, where they are and how far a guard may stand from them."
        actions={switcher}
        path="/api/v2/patrol/checkpoints"
        queryKey="patrol-checkpoints"
        rowKey={(r, i) => String(r.QrID ?? i)}
        emptyTitle="No checkpoints"
        emptyDescription="Checkpoints are QR codes fixed at a site and scanned on each round."
        columns={[
          { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
          { id: "name", header: "Checkpoint", cell: (r) => cell(r, "QrName", "CheckpointName") },
          {
            id: "code",
            header: "Code",
            hideOnMobile: true,
            cell: (r) => <span className="tabular text-muted">{cell(r, "QrCode")}</span>,
          },
          {
            id: "radius",
            header: "Max distance",
            className: "text-right",
            hideOnMobile: true,
            cell: (r) => <span className="tabular">{cell(r, "MaxDistanceMeters")} m</span>,
          },
          {
            id: "photo",
            header: "Photo",
            cell: (r) => <Status value={r.RequirePhoto ? "Required" : "Optional"} />,
          },
          {
            id: "active",
            header: "Status",
            cell: (r) => <Status value={r.IsActive ? "Active" : "Inactive"} />,
          },
        ]}
      />
    );
  }

  if (tab === "missed") {
    return (
      <ResourceList
        title="Patrol"
        description="Rounds that were due and never scanned. This is the screen that catches an unguarded site."
        actions={switcher}
        path="/api/v2/patrol/missed"
        queryKey="patrol-missed"
        rowKey={(r, i) => String(r.RoundID ?? i)}
        emptyTitle="Nothing missed"
        emptyDescription="Every scheduled round in this period was scanned."
        columns={[
          { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
          { id: "round", header: "Round", cell: (r) => cell(r, "RoundName", "RoundNo") },
          {
            id: "due",
            header: "Was due",
            cell: (r) => <span className="tabular">{dateTime(r.DueAt ?? r.StartTime)}</span>,
          },
          {
            id: "missed",
            header: "Checkpoints missed",
            className: "text-right",
            cell: (r) => (
              <span className="tabular font-medium text-danger">
                {cell(r, "MissedCount", "MissedCheckpoints")}
              </span>
            ),
          },
        ]}
      />
    );
  }

  return (
    <ResourceList
      title="Patrol"
      description="Every QR scan, with the ones taken out of range flagged."
      actions={switcher}
      path="/api/v2/patrol/logs"
      queryKey="patrol-logs"
      params={{ from: q.from ?? isoDate(thirtyDaysAgo), to: q.to }}
      rowKey={(r, i) => String(r.ScanID ?? r.LogID ?? i)}
      emptyTitle="No scans in this period"
      emptyDescription="Widen the date range, or check that rounds are configured for these sites."
      columns={[
        {
          id: "when",
          header: "Scanned at",
          cell: (r) => <span className="tabular">{dateTime(r.Scantime ?? r.ScanTime)}</span>,
        },
        { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
        {
          id: "checkpoint",
          header: "Checkpoint",
          cell: (r) => (
            <div>
              <div>{cell(r, "QrName", "CheckpointName")}</div>
              <div className="text-xs text-muted">Round {cell(r, "RoundNo")}</div>
            </div>
          ),
        },
        { id: "guard", header: "Guard", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName") },
        {
          id: "distance",
          header: "Distance",
          className: "text-right",
          cell: (r) => {
            const metres = Number(r.DistanceMeters ?? 0);
            const inRange = r.IsWithinRange === true || r.IsWithinRange === 1;
            return (
              <span className={inRange ? "tabular text-muted" : "tabular font-medium text-danger"}>
                {metres} m
              </span>
            );
          },
        },
        {
          id: "range",
          header: "In range",
          // A scan taken 130 m from the checkpoint is the single most useful
          // signal on this screen, so it gets its own column rather than being
          // inferred from the distance.
          cell: (r) => (
            <Status value={r.IsWithinRange === true || r.IsWithinRange === 1 ? "Yes" : "Out of range"} />
          ),
        },
      ]}
    />
  );
}
