"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date } from "@/lib/format";

export default function FollowUpsPage() {
  return (
    <ResourceList
      title="Follow-ups"
      description="What is due, and what has already slipped."
      path="/api/v2/sales/follow-ups"
      queryKey="follow-ups"
      searchPlaceholder="Company or contact…"
      rowKey={(r, i) => String(r.FollowUpID ?? i)}
      emptyTitle="Nothing to follow up"
      emptyDescription="Follow-ups are created from a sales visit."
      columns={[
        {
          id: "due",
          header: "Due",
          cell: (r) => {
            const due = r.FollowUpDate ?? r.NextFollowUpDate;
            if (!due) return <span className="text-muted">—</span>;
            const overdue = new Date(String(due)) < new Date();
            return (
              <div>
                <div className={overdue ? "tabular font-medium text-danger" : "tabular"}>
                  {date(due)}
                </div>
                {overdue ? <div className="text-xs text-danger">overdue</div> : null}
              </div>
            );
          },
        },
        {
          id: "company",
          header: "Company",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "CompanyName")}</div>
              <div className="text-xs text-muted">{cell(r, "ContactPerson")}</div>
            </div>
          ),
        },
        {
          id: "mobile",
          header: "Contact",
          hideOnMobile: true,
          cell: (r) => <span className="tabular">{cell(r, "MobileNo", "ContactNo")}</span>,
        },
        { id: "by", header: "Owner", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName", "ExecutiveName") },
        {
          id: "remark",
          header: "Last note",
          cell: (r) => <span className="line-clamp-2 max-w-md text-muted">{cell(r, "Remark")}</span>,
        },
        { id: "status", header: "Stage", cell: (r) => <Status value={r.Status ?? r.Stage} /> },
      ]}
    />
  );
}
