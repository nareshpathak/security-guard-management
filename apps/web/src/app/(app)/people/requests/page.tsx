"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date, money } from "@/lib/format";

export default function RequestsPage() {
  return (
    <ResourceList
      title="Requests"
      description="Leave, advances, transfers and uniform. Pending ones come first."
      path="/api/v2/hr/requests"
      queryKey="hr-requests"
      searchPlaceholder="Employee, code or reason…"
      rowKey={(r, i) => String(r.RequestID ?? i)}
      emptyTitle="Nothing requested"
      emptyDescription="Guards raise these from the mobile app; approvals happen here."
      columns={[
        {
          id: "emp",
          header: "Employee",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "EmpFullName")}</div>
              <div className="tabular text-xs text-muted">
                {cell(r, "EmpCode")} · {cell(r, "UnitName")}
              </div>
            </div>
          ),
        },
        { id: "type", header: "Type", cell: (r) => <Status value={r.RequestType} /> },
        {
          id: "when",
          header: "For",
          cell: (r) =>
            r.FromDate ? (
              <div>
                <div className="tabular">{date(r.FromDate)}</div>
                {r.DayCount ? (
                  <div className="text-xs text-muted">{String(r.DayCount)} day(s)</div>
                ) : null}
              </div>
            ) : (
              <span className="text-muted">—</span>
            ),
        },
        {
          id: "amount",
          header: "Amount",
          className: "text-right",
          cell: (r) =>
            r.Amount ? <span className="tabular">{money(r.Amount)}</span> : <span className="text-muted">—</span>,
        },
        {
          id: "reason",
          header: "Reason",
          hideOnMobile: true,
          cell: (r) => <span className="line-clamp-2 max-w-sm text-muted">{cell(r, "Reason")}</span>,
        },
        { id: "status", header: "Status", cell: (r) => <Status value={r.Status} /> },
        {
          id: "by",
          header: "Decided by",
          hideOnMobile: true,
          cell: (r) => cell(r, "ApprovedByName"),
        },
      ]}
    />
  );
}
