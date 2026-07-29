"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { count, date, money } from "@/lib/format";

export default function LedgerPage() {
  return (
    <ResourceList
      title="Uniform ledger"
      description="Every issue and return, and what is still recoverable from salary."
      path="/api/v2/uniform/ledger"
      queryKey="uniform-ledger"
      searchPlaceholder="Employee or item…"
      rowKey={(r, i) => String(r.IssueID ?? r.LedgerID ?? i)}
      emptyTitle="Nothing issued yet"
      emptyDescription="Uniform issued to a guard is tracked here until it is returned or recovered."
      columns={[
        { id: "when", header: "Date", cell: (r) => <span className="tabular">{date(r.IssueDate ?? r.Dated)}</span> },
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
        { id: "item", header: "Item", cell: (r) => cell(r, "ItemName") },
        {
          id: "issued",
          header: "Issued",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.IssuedQty)}</span>,
        },
        {
          id: "returned",
          header: "Returned",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.RecievedQty ?? r.ReturnedQty)}</span>,
        },
        {
          id: "recover",
          header: "To recover",
          className: "text-right",
          cell: (r) => {
            const amount = Number(r.RecoverableAmount ?? r.BalanceAmount ?? 0);
            return (
              <span className={amount > 0 ? "tabular font-medium text-warning" : "tabular text-muted"}>
                {money(amount)}
              </span>
            );
          },
        },
        { id: "status", header: "Status", cell: (r) => <Status value={r.Status} /> },
      ]}
    />
  );
}
