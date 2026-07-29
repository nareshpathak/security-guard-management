"use client";

import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { date } from "@/lib/format";

export default function ClientRelationsPage() {
  return (
    <ResourceList
      title="Client relations"
      description="Courtesy visits to clients you already serve. This is how churn is spotted early."
      path="/api/v2/sales/client-relations"
      queryKey="client-relations"
      searchPlaceholder="Site or contact person…"
      rowKey={(r, i) => String(r.VisitID ?? i)}
      emptyTitle="No relation visits"
      emptyDescription="Field executives log these from the mobile app."
      columns={[
        { id: "when", header: "Visited", cell: (r) => <span className="tabular">{date(r.Dated)}</span> },
        { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
        {
          id: "contact",
          header: "Person met",
          cell: (r) => (
            <div>
              <div>{cell(r, "ContactPerson")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "MobileNo")}</div>
            </div>
          ),
        },
        { id: "by", header: "Executive", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName", "ExecutiveName") },
        { id: "timing", header: "Timing", hideOnMobile: true, cell: (r) => cell(r, "Timing") },
        {
          id: "remark",
          header: "Discussed",
          cell: (r) => <span className="line-clamp-2 max-w-md text-muted">{cell(r, "Remark")}</span>,
        },
      ]}
    />
  );
}
