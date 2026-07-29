"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date } from "@/lib/format";

export default function SalesVisitsPage() {
  return (
    <ResourceList
      title="Sales visits"
      description="Prospect visits logged in the field, with the next follow-up due."
      path="/api/v2/sales/visits"
      queryKey="sales-visits"
      searchPlaceholder="Company or contact…"
      rowKey={(r, i) => String(r.SalesVisitID ?? r.VisitID ?? i)}
      emptyTitle="No visits logged"
      emptyDescription="Field executives log visits from the mobile app; they appear here immediately."
      columns={[
        {
          id: "dated",
          header: "Visited",
          cell: (r) => <span className="tabular">{date(r.Dated ?? r.VisitDate)}</span>,
        },
        {
          id: "company",
          header: "Company",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "CompanyName")}</div>
              <div className="text-xs text-muted">{cell(r, "Address", "CityName")}</div>
            </div>
          ),
        },
        {
          id: "contact",
          header: "Contact",
          hideOnMobile: true,
          cell: (r) => (
            <div>
              <div>{cell(r, "ContactPerson")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "MobileNo", "ContactNo")}</div>
            </div>
          ),
        },
        { id: "by", header: "Executive", hideOnMobile: true, cell: (r) => cell(r, "EmpFullName", "ExecutiveName") },
        {
          id: "followup",
          header: "Follow-up due",
          cell: (r) => {
            const due = r.NextFollowUpDate ?? r.FollowUpDate;
            if (!due) return <span className="text-muted">—</span>;
            const overdue = new Date(String(due)) < new Date();
            return (
              <span className={overdue ? "tabular font-medium text-danger" : "tabular"}>
                {date(due)}
              </span>
            );
          },
        },
        { id: "stage", header: "Stage", cell: (r) => <Status value={r.Status ?? r.Stage} /> },
      ]}
    />
  );
}
