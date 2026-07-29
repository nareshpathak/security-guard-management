"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date, money } from "@/lib/format";

/** Days overdue, bucketed the way an accounts team chases them. */
function bucket(days: number): string {
  if (days <= 0) return "Not due";
  if (days <= 30) return "1-30 days";
  if (days <= 60) return "31-60 days";
  if (days <= 90) return "61-90 days";
  return "90+ days";
}

export default function AgeingPage() {
  return (
    <ResourceList
      title="Ageing"
      description="Unpaid invoices, oldest debt first. This is the chase list."
      path="/api/v2/invoices"
      queryKey="ageing"
      params={{ onlyOutstanding: true }}
      rowKey={(r, i) => String(r.Bid ?? i)}
      emptyTitle="Nothing outstanding"
      emptyDescription="Every invoice raised has been paid in full."
      columns={[
        {
          id: "invoice",
          header: "Invoice",
          cell: (r) => (
            <div>
              <div className="tabular font-medium text-text">{cell(r, "InvoiceNo")}</div>
              <div className="text-xs text-muted">{date(r.InvoiceDate)}</div>
            </div>
          ),
        },
        { id: "client", header: "Client", cell: (r) => cell(r, "ClientName") },
        {
          id: "due",
          header: "Due",
          hideOnMobile: true,
          cell: (r) => <span className="tabular">{date(r.DueDate)}</span>,
        },
        {
          id: "bucket",
          header: "Overdue by",
          cell: (r) => {
            if (!r.DueDate) return <span className="text-muted">—</span>;
            const days = Math.floor((Date.now() - new Date(String(r.DueDate)).getTime()) / 86_400_000);
            const label = bucket(days);
            return (
              <div>
                <Status value={label} />
                {days > 0 ? <div className="mt-0.5 text-xs text-muted">{days} d</div> : null}
              </div>
            );
          },
        },
        {
          id: "total",
          header: "Invoiced",
          className: "text-right",
          hideOnMobile: true,
          cell: (r) => <span className="tabular">{money(r.GrandTotal)}</span>,
        },
        {
          id: "received",
          header: "Received",
          className: "text-right",
          hideOnMobile: true,
          cell: (r) => <span className="tabular text-success">{money(r.ReceivedAmount)}</span>,
        },
        {
          id: "balance",
          header: "Outstanding",
          className: "text-right",
          cell: (r) => (
            <span className="tabular font-medium">
              {money(Number(r.GrandTotal ?? 0) - Number(r.ReceivedAmount ?? 0))}
            </span>
          ),
        },
      ]}
    />
  );
}
