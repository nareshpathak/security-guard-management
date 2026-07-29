"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date } from "@/lib/format";

export default function LifecyclePage() {
  return (
    <ResourceList
      title="Joining and exits"
      description="Every change of employment status: joins, resignations, exits and rejoins."
      path="/api/v2/hr/lifecycle"
      queryKey="hr-lifecycle"
      searchPlaceholder="Employee name or code…"
      rowKey={(r, i) => String(r.EventID ?? r.HistoryID ?? i)}
      emptyTitle="No lifecycle events"
      emptyDescription="Joins, resignations and exits recorded against employees appear here."
      columns={[
        { id: "when", header: "Date", cell: (r) => <span className="tabular">{date(r.EventDate)}</span> },
        {
          id: "emp",
          header: "Employee",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "EmpFullName")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "EmpCode")}</div>
            </div>
          ),
        },
        { id: "event", header: "Event", cell: (r) => <Status value={r.EventType} /> },
        { id: "unit", header: "Site", hideOnMobile: true, cell: (r) => cell(r, "UnitName") },
        {
          id: "remark",
          header: "Reason",
          cell: (r) => <span className="line-clamp-2 max-w-md">{cell(r, "Remark", "Reason")}</span>,
        },
        {
          id: "approved",
          header: "Approved",
          cell: (r) => <Status value={r.IsApproved ? "Approved" : "Pending"} />,
        },
      ]}
    />
  );
}
