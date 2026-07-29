"use client";

import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { count, dateTime } from "@/lib/format";

export default function FieldReportsPage() {
  return (
    <ResourceList
      title="Field reports"
      description="What supervisors found when they visited each site."
      path="/api/v2/field-reports"
      queryKey="field-reports"
      searchPlaceholder="Site, contact person or remark…"
      rowKey={(r, i) => String(r.ReportID ?? i)}
      emptyTitle="No field reports"
      emptyDescription="Supervisors file these from the mobile app during a site visit."
      columns={[
        {
          id: "when",
          header: "Visited",
          cell: (r) => <span className="tabular">{dateTime(r.Createdate)}</span>,
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
        { id: "by", header: "Supervisor", hideOnMobile: true, cell: (r) => cell(r, "SupervisorName") },
        { id: "met", header: "Person met", hideOnMobile: true, cell: (r) => cell(r, "ContactPerson") },
        {
          id: "remark",
          header: "Findings",
          cell: (r) => <span className="line-clamp-2 max-w-md">{cell(r, "Remark")}</span>,
        },
        {
          id: "guards",
          header: "Guard notes",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.GuardRemarkCount)}</span>,
        },
      ]}
    />
  );
}
