"use client";

import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { date, moneyExact } from "@/lib/format";

export default function ReceiptsPage() {
  return (
    <ResourceList
      title="Receipts"
      description="Money actually collected, newest first."
      path="/api/v2/receipts"
      queryKey="receipts"
      searchPlaceholder="Client, invoice number or reference…"
      rowKey={(r, i) => String(r.ReceiptID ?? i)}
      emptyTitle="No receipts recorded"
      emptyDescription="Receipts are recorded against an invoice from the invoice screen."
      columns={[
        {
          id: "received",
          header: "Received",
          cell: (r) => <span className="tabular">{date(r.ReceivedOn)}</span>,
        },
        {
          id: "client",
          header: "Client",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "ClientName")}</div>
              <div className="text-xs text-muted">{cell(r, "ClientCode")}</div>
            </div>
          ),
        },
        {
          id: "invoice",
          header: "Against invoice",
          hideOnMobile: true,
          cell: (r) => (
            <div>
              <div className="tabular">{cell(r, "InvoiceNo")}</div>
              <div className="text-xs text-muted">{date(r.InvoiceDate)}</div>
            </div>
          ),
        },
        {
          id: "mode",
          header: "Mode",
          hideOnMobile: true,
          cell: (r) => cell(r, "Mode"),
        },
        {
          id: "ref",
          header: "Reference",
          hideOnMobile: true,
          cell: (r) => <span className="tabular text-muted">{cell(r, "RefNo")}</span>,
        },
        {
          id: "amount",
          header: "Amount",
          className: "text-right",
          // Paise matter: this is a statement of what a client actually paid.
          cell: (r) => <span className="tabular font-medium">{moneyExact(r.Amount)}</span>,
        },
        {
          id: "balance",
          header: "Invoice balance",
          className: "text-right",
          hideOnMobile: true,
          cell: (r) => {
            const balance = r.InvoiceBalance;
            if (balance === null || balance === undefined) return <span className="text-muted">—</span>;
            const n = Number(balance);
            return (
              <span className={n > 0 ? "tabular text-warning" : "tabular text-success"}>
                {moneyExact(n)}
              </span>
            );
          },
        },
      ]}
    />
  );
}
