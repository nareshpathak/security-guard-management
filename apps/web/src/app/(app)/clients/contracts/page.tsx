"use client";

import { useState } from "react";
import { Button, Input, Label, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { cell } from "@/lib/list-query";
import { date, isoDate, money } from "@/lib/format";
import { useCommand } from "@/lib/use-command";

export default function ContractsPage() {
  const yearAgo = new Date();
  yearAgo.setFullYear(yearAgo.getFullYear() - 1);

  const [selectedContract, setSelectedContract] = useState<Row | null>(null);
  const [termReason, setTermReason] = useState("");
  const [termDate, setTermDate] = useState(isoDate(new Date()));

  const terminate = useCommand<{ terminationDate: string; reason: string }>({
    path: `/api/v2/contracts/${selectedContract?.ContractID ?? selectedContract?.Id ?? 0}/terminate`,
    invalidate: ["contracts"],
    successMessage: "Contract terminated successfully",
    onDone: () => {
      setSelectedContract(null);
      setTermReason("");
    },
  });

  return (
    <>
      <ResourceList
        title="Contracts & Agreements"
        description="Active agreements per site, expiry alerts, and contract termination management."
        path="/api/v2/reports/contract"
        queryKey="contracts"
        params={{ from: isoDate(yearAgo), to: isoDate(new Date()) }}
        rowKey={(r, i) => String(r.ContractID ?? r.Id ?? i)}
        emptyTitle="No contracts found"
        emptyDescription="A contract fixes the rate and guard strength agreed for a site."
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
          { id: "status", header: "Status", cell: (r) => <Status value={r.Status ?? (r.IsActive ? "Active" : "Terminated")} /> },
          {
            id: "actions",
            header: "Action",
            className: "text-right",
            cell: (r) => (
              <Button
                size="sm"
                variant="outline"
                disabled={r.Status === "Terminated" || r.IsActive === false}
                onClick={() => setSelectedContract(r)}
              >
                Terminate
              </Button>
            ),
          },
        ]}
      />

      <Modal
        open={Boolean(selectedContract)}
        onOpenChange={(open) => !open && setSelectedContract(null)}
        title="Contract Termination"
        description={`Terminate contract for ${cell(selectedContract ?? {}, "ClientName")} (${cell(selectedContract ?? {}, "UnitName")})`}
        footer={
          <Button
            variant="danger"
            loading={terminate.isPending}
            disabled={!termReason.trim() || !termDate}
            onClick={() => terminate.mutate({ terminationDate: termDate, reason: termReason })}
          >
            Confirm Termination
          </Button>
        }
      >
        <div className="space-y-4">
          <div>
            <Label required>Termination Date</Label>
            <Input type="date" value={termDate} onChange={(e) => setTermDate(e.target.value)} />
          </div>
          <div>
            <Label required>Termination Reason & Handover Notes</Label>
            <TextArea
              value={termReason}
              onChange={(e) => setTermReason(e.target.value)}
              placeholder="State the official reason for contract termination, notice period details, and site handover instructions."
            />
          </div>
        </div>
      </Modal>
    </>
  );
}
