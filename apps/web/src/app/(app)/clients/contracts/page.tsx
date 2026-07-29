"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { date, isoDate, money } from "@/lib/format";

export default function ContractsPage() {
  const yearAgo = new Date();
  yearAgo.setFullYear(yearAgo.getFullYear() - 1);

  return (
    <ResourceList
      title="Contracts"
      description="Agreements per site, with the ones expiring soon called out."
      path="/api/v2/reports/contract"
      queryKey="contracts"
      params={{ from: isoDate(yearAgo), to: isoDate(new Date()) }}
      rowKey={(r, i) => String(r.ContractID ?? i)}
      emptyTitle="No contracts"
      emptyDescription="A contract fixes the rate and strength agreed for a site."
      columns={[
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
        { id: "from", header: "From", cell: (r) => <span className="tabular">{date(r.StartDate ?? r.FromDate)}</span> },
        {
          id: "to",
          header: "Expires",
          cell: (r) => {
            const end = r.EndDate ?? r.ExpiryDate ?? r.AgreementExpDate;
            if (!end) return <span className="text-muted">—</span>;
            const days = Math.round((new Date(String(end)).getTime() - Date.now()) / 86_400_000);
            // Thirty days is the point at which renewal has to start, which is
            // why the column shades rather than just prints a date.
            const tone =
              days < 0 ? "text-danger font-medium" : days <= 30 ? "text-warning font-medium" : "";
            return (
              <div>
                <div className={`tabular ${tone}`}>{date(end)}</div>
                {days < 0 ? (
                  <div className="text-xs text-danger">expired</div>
                ) : days <= 30 ? (
                  <div className="text-xs text-warning">{days} d left</div>
                ) : null}
              </div>
            );
          },
        },
        {
          id: "value",
          header: "Monthly value",
          className: "text-right",
          hideOnMobile: true,
          cell: (r) => <span className="tabular">{money(r.MonthlyValue ?? r.ContractValue ?? r.Amount)}</span>,
        },
        { id: "status", header: "Status", cell: (r) => <Status value={r.Status ?? (r.IsActive ? "Active" : "Inactive")} /> },
      ]}
    />
  );
}
