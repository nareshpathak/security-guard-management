"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { count, date } from "@/lib/format";

/**
 * The ledger filtered to what is still out.
 *
 * The full ledger answers "what happened"; this answers "who has our kit",
 * which is the question at an exit interview.
 */
export default function IssuesPage() {
  return (
    <ResourceList
      title="Issued and outstanding"
      description="Uniform and equipment currently with guards."
      path="/api/v2/uniform/ledger"
      queryKey="uniform-issues"
      params={{ onlyOutstanding: true }}
      searchPlaceholder="Employee or item…"
      rowKey={(r, i) => String(r.IssueID ?? r.LedgerID ?? i)}
      emptyTitle="Nothing outstanding"
      emptyDescription="Everything issued has been returned or recovered."
      columns={[
        { id: "when", header: "Issued", cell: (r) => <span className="tabular">{date(r.IssueDate ?? r.Dated)}</span> },
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
          id: "out",
          header: "Still out",
          className: "text-right",
          cell: (r) => (
            <span className="tabular font-medium">
              {count(Number(r.IssuedQty ?? 0) - Number(r.RecievedQty ?? r.ReturnedQty ?? 0))}
            </span>
          ),
        },
        { id: "status", header: "Status", cell: (r) => <Status value={r.Status} /> },
      ]}
    />
  );
}
