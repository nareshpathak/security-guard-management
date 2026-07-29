"use client";

import { useRouter } from "next/navigation";
import { Button } from "@diti365/ui";
import { Status } from "@/components/status";
import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { count, date, money } from "@/lib/format";

export default function ClientsPage() {
  const router = useRouter();

  return (
    <ResourceList
      title="Clients"
      description="Every organisation the agency guards, with what is deployed and what is owed."
      actions={<Button onClick={() => router.push("/clients/new")}>New client</Button>}
      path="/api/v2/clients"
      queryKey="clients"
      searchPlaceholder="Name, code, contact or GSTIN…"
      rowKey={(r, i) => String(r.ClientID ?? i)}
      onRowClick={(r) => router.push(`/clients/units?clientId=${r.ClientID}`)}
      emptyTitle="No clients yet"
      emptyDescription="A client is the organisation you bill. Sites are created underneath it."
      emptyAction={
        <Button onClick={() => router.push("/clients/new")}>Add your first client</Button>
      }
      columns={[
        {
          id: "client",
          header: "Client",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "ClientName")}</div>
              <div className="text-xs text-muted">{cell(r, "ClientCode", "GSTIN")}</div>
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
              <div className="tabular text-xs text-muted">{cell(r, "ContactNo")}</div>
            </div>
          ),
        },
        {
          id: "sites",
          header: "Sites",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.UnitCount)}</span>,
        },
        {
          id: "deployed",
          header: "Guards",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.DeployedNos)}</span>,
        },
        {
          id: "complaints",
          header: "Open complaints",
          className: "text-right",
          hideOnMobile: true,
          cell: (r) => {
            const n = Number(r.OpenComplaints ?? 0);
            return (
              <span className={n > 0 ? "tabular font-medium text-danger" : "tabular text-muted"}>
                {count(n)}
              </span>
            );
          },
        },
        {
          id: "outstanding",
          header: "Outstanding",
          className: "text-right",
          cell: (r) => {
            const amount = Number(r.OutstandingAmt ?? 0);
            const overdue = Number(r.OverdueInvoices ?? 0);
            return (
              <div className="text-right">
                <div className={amount > 0 ? "tabular font-medium" : "tabular text-muted"}>
                  {money(amount)}
                </div>
                {overdue > 0 ? (
                  <div className="text-xs text-danger">{overdue} overdue</div>
                ) : null}
              </div>
            );
          },
        },
        {
          id: "last",
          header: "Last invoice",
          hideOnMobile: true,
          cell: (r) => <span className="text-muted">{date(r.LastInvoiceOn)}</span>,
        },
        {
          id: "status",
          header: "Status",
          cell: (r) => (
            <Status value={r.IsExpired ? "Expired" : r.IsActive ? "Active" : "Inactive"} />
          ),
        },
      ]}
    />
  );
}
