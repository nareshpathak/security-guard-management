"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date, dateTime } from "@/lib/format";

export default function ComplaintsPage() {
  return (
    <ResourceList
      title="Complaints"
      description="What clients have raised, and how long it has been open."
      path="/api/v2/complaints"
      queryKey="complaints"
      searchPlaceholder="Client, site or subject…"
      rowKey={(r, i) => String(r.ComplaintID ?? i)}
      emptyTitle="No complaints"
      emptyDescription="Complaints raised by a client, or logged on their behalf, appear here."
      columns={[
        {
          id: "raised",
          header: "Raised",
          cell: (r) => <span className="tabular">{date(r.ComplaintDate ?? r.InsertDate)}</span>,
        },
        {
          id: "client",
          header: "Client / site",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "ClientName")}</div>
              <div className="text-xs text-muted">{cell(r, "UnitName")}</div>
            </div>
          ),
        },
        { id: "type", header: "Type", hideOnMobile: true, cell: (r) => cell(r, "ComplaintTypeName", "TypeName") },
        {
          id: "subject",
          header: "Subject",
          cell: (r) => (
            <span className="line-clamp-2 max-w-md">{cell(r, "Subject", "Description", "Remark")}</span>
          ),
        },
        {
          id: "age",
          header: "Open for",
          className: "text-right",
          cell: (r) => {
            if (r.IsClosed) return <span className="text-muted">closed</span>;
            const raised = new Date(String(r.ComplaintDate ?? r.InsertDate));
            if (Number.isNaN(raised.getTime())) return <span className="text-muted">—</span>;
            const days = Math.floor((Date.now() - raised.getTime()) / 86_400_000);
            // Seven days open is the point at which a complaint stops being a
            // ticket and starts being a reason the client leaves.
            return (
              <span className={days >= 7 ? "tabular font-medium text-danger" : "tabular"}>
                {days} d
              </span>
            );
          },
        },
        {
          id: "status",
          header: "Status",
          cell: (r) => <Status value={r.IsClosed ? "Closed" : (r.Status ?? "Open")} />,
        },
        {
          id: "closed",
          header: "Closed",
          hideOnMobile: true,
          cell: (r) => <span className="text-muted">{dateTime(r.ClosedOn)}</span>,
        },
      ]}
    />
  );
}
