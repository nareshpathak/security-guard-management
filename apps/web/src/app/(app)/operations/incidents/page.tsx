"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

export default function IncidentsPage() {
  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

  return (
    <ResourceList
      title="Incidents"
      description="What went wrong at a site, who reported it and whether it is closed."
      // Incidents are read through the report surface: the same procedure backs
      // the printed incident report, so there is one definition of the shape.
      path="/api/v2/reports/incident"
      queryKey="incidents"
      params={{ from: isoDate(ninetyDaysAgo), to: isoDate(new Date()) }}
      rowKey={(r, i) => String(r.IncidentID ?? i)}
      emptyTitle="No incidents in the last 90 days"
      emptyDescription="Guards and supervisors raise incidents from the mobile app."
      columns={[
        {
          id: "when",
          header: "Occurred",
          cell: (r) => <span className="tabular">{date(r.IncidentDate ?? r.Dated ?? r.InsertDate)}</span>,
        },
        {
          id: "unit",
          header: "Site",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "UnitName")}</div>
              <div className="text-xs text-muted">{cell(r, "ClientName")}</div>
            </div>
          ),
        },
        { id: "type", header: "Type", cell: (r) => cell(r, "IncidentTypeName", "TypeName") },
        {
          id: "what",
          header: "What happened",
          cell: (r) => (
            <span className="line-clamp-2 max-w-md">{cell(r, "Description", "Remark", "Subject")}</span>
          ),
        },
        { id: "by", header: "Reported by", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName", "ReportedByName") },
        {
          id: "status",
          header: "Status",
          cell: (r) => <Status value={r.IsClosed ? "Closed" : (r.Status ?? "Open")} />,
        },
      ]}
    />
  );
}
