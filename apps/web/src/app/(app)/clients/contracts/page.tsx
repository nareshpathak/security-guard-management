"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Input, Label, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { date, isoDate, money } from "@/lib/format";

export default function ContractsPage() {
  const { has } = useAuth();
  const yearAgo = new Date();
  yearAgo.setFullYear(yearAgo.getFullYear() - 1);

  const [createModal, setCreateModal] = useState(false);
  const [selectedContract, setSelectedContract] = useState<Row | null>(null);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [termReason, setTermReason] = useState("");
  const [termDate, setTermDate] = useState(isoDate(new Date()));

  const [form, setForm] = useState({
    contractType: "Regular",
    clientId: "",
    unitId: "",
    dated: isoDate(new Date()),
    nop: "5",
    timing: "8 Hours Shift",
    effectiveFrom: isoDate(new Date()),
    effectiveTo: isoDate(new Date(Date.now() + 365 * 86400000)),
    remark: "",
  });

  const clientsQuery = useQuery({
    queryKey: ["clients-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients"),
    staleTime: 5 * 60 * 1000,
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown", form.clientId],
    enabled: !!form.clientId,
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { clientId: Number(form.clientId) }),
  });

  const createCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/contracts",
    invalidate: ["contracts"],
    successMessage: "Contract agreement created successfully",
    onDone: () => {
      setCreateModal(false);
      setForm({
        contractType: "Regular",
        clientId: "",
        unitId: "",
        dated: isoDate(new Date()),
        nop: "5",
        timing: "8 Hours Shift",
        effectiveFrom: isoDate(new Date()),
        effectiveTo: isoDate(new Date(Date.now() + 365 * 86400000)),
        remark: "",
      });
    },
  });

  const terminateCmd = useCommand<{ terminationDate: string; reason: string }>({
    path: `/api/v2/contracts/${selectedContract?.ContractID ?? selectedContract?.Id ?? 0}/terminate`,
    invalidate: ["contracts"],
    successMessage: "Contract terminated successfully",
    onDone: () => {
      setSelectedContract(null);
      setTermReason("");
    },
  });

  const clients = clientsQuery.data?.data ?? [];
  const units = unitsQuery.data?.data ?? [];

  const actions = (
    <div className="flex items-center gap-2">
      <Button variant="outline" onClick={() => setShowPrintModal(true)}>
        <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="6 9 6 2 18 2 18 9" />
          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
          <rect x="6" y="14" width="12" height="8" />
        </svg>
        Print Contract Agreements
      </Button>
      {has(Perm.clientEdit) ? (
        <Button variant="primary" onClick={() => setCreateModal(true)}>
          + Create Contract
        </Button>
      ) : null}
    </div>
  );

  return (
    <>
      <ResourceList
        title="Client Contracts & SLA Agreements"
        description="Active security contracts per site unit, contracted guard strength, rates, and renewal alerts."
        actions={actions}
        path="/api/v2/reports/contract"
        queryKey="contracts"
        params={{ from: isoDate(yearAgo), to: isoDate(new Date()) }}
        rowKey={(r, i) => String(r.ContractID ?? r.Id ?? i)}
        emptyTitle="No contracts registered"
        emptyDescription="A contract fixes the guard strength, shift timings, and billing rate agreed for a client site."
        columns={[
          {
            id: "client",
            header: "Client / Site Unit",
            cell: (r) => (
              <div>
                <div className="font-semibold text-text">{cell(r, "ClientName")}</div>
                <div className="text-xs text-muted">{cell(r, "UnitName")}</div>
              </div>
            ),
          },
          {
            id: "from",
            header: "Effective From",
            cell: (r) => <span className="tabular font-medium">{date(r.StartDate ?? r.FromDate)}</span>,
          },
          {
            id: "to",
            header: "Expiry Date",
            cell: (r) => {
              const end = r.EndDate ?? r.ExpiryDate ?? r.AgreementExpDate;
              if (!end) return <span className="text-muted">—</span>;
              const days = Math.round((new Date(String(end)).getTime() - Date.now()) / 86_400_000);
              const tone =
                days < 0 ? "text-danger font-bold" : days <= 30 ? "text-warning font-bold" : "";
              return (
                <div>
                  <div className={`tabular ${tone}`}>{date(end)}</div>
                  {days < 0 ? (
                    <div className="text-xs font-bold text-danger">EXPIRED</div>
                  ) : days <= 30 ? (
                    <div className="text-xs font-bold text-warning">{days} days left</div>
                  ) : null}
                </div>
              );
            },
          },
          {
            id: "value",
            header: "Monthly Value",
            className: "text-right",
            hideOnMobile: true,
            cell: (r) => (
              <span className="tabular font-semibold">
                {money(r.MonthlyValue ?? r.ContractValue ?? r.Amount)}
              </span>
            ),
          },
          {
            id: "status",
            header: "Status",
            cell: (r) => <Status value={r.Status ?? (r.IsActive ? "Active Agreement" : "Terminated")} />,
          },
          {
            id: "actions",
            header: "Action",
            className: "text-right",
            cell: (r) =>
              has(Perm.clientEdit) ? (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={r.Status === "Terminated" || r.IsActive === false}
                  onClick={() => setSelectedContract(r)}
                >
                  Terminate
                </Button>
              ) : null,
          },
        ]}
      />

      {/* Create Contract Modal */}
      <Modal
        open={createModal}
        onOpenChange={setCreateModal}
        title="Create Client Security Contract"
        description="Draft a security service contract with contracted guard strength."
        footer={
          <Button
            loading={createCmd.isPending}
            disabled={!form.clientId || !form.unitId || !form.nop}
            onClick={() =>
              createCmd.mutate({
                contractType: form.contractType,
                clientId: Number(form.clientId),
                unitId: Number(form.unitId),
                dated: form.dated,
                nop: Number(form.nop),
                timing: form.timing || undefined,
                effectiveFrom: form.effectiveFrom,
                effectiveTo: form.effectiveTo,
                remark: form.remark || undefined,
              })
            }
          >
            Create Contract Agreement
          </Button>
        }
      >
        <div>
          <Label required>Client Organisation</Label>
          <Select
            value={form.clientId}
            onChange={(e) => setForm((f) => ({ ...f, clientId: e.target.value, unitId: "" }))}
          >
            <option value="">Select Client Account...</option>
            {clients.map((c, i) => (
              <option key={String(c.ClientID ?? c.Id ?? i)} value={String(c.ClientID ?? c.Id ?? "")}>
                {String(c.ClientName ?? c.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Client Site Unit</Label>
          <Select
            value={form.unitId}
            onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))}
            disabled={!form.clientId}
          >
            <option value="">Select Deployment Site Unit...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Contract Start Date</Label>
            <Input
              type="date"
              value={form.effectiveFrom}
              onChange={(e) => setForm((f) => ({ ...f, effectiveFrom: e.target.value }))}
            />
          </div>
          <div>
            <Label required>Contract Expiry Date</Label>
            <Input
              type="date"
              value={form.effectiveTo}
              onChange={(e) => setForm((f) => ({ ...f, effectiveTo: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Contracted Guard Strength (Nop)</Label>
            <Input
              type="number"
              placeholder="e.g. 5"
              value={form.nop}
              onChange={(e) => setForm((f) => ({ ...f, nop: e.target.value }))}
            />
          </div>
          <div>
            <Label>Shift Timing / Pattern</Label>
            <Input
              placeholder="e.g. 8 Hours 3-Shift Roster"
              value={form.timing}
              onChange={(e) => setForm((f) => ({ ...f, timing: e.target.value }))}
            />
          </div>
        </div>
        <div>
          <Label>Contract Terms & Remarks</Label>
          <TextArea
            placeholder="Key SLA clauses, replacement guarantees, and billing payment terms..."
            value={form.remark}
            onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Contract Termination Modal */}
      <Modal
        open={Boolean(selectedContract)}
        onOpenChange={(open) => !open && setSelectedContract(null)}
        title="Contract Termination"
        description={`Terminate contract for ${cell(selectedContract ?? {}, "ClientName")} (${cell(selectedContract ?? {}, "UnitName")})`}
        footer={
          <Button
            variant="danger"
            loading={terminateCmd.isPending}
            disabled={!termReason.trim() || !termDate}
            onClick={() => terminateCmd.mutate({ terminationDate: termDate, reason: termReason })}
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

      {/* Printable Contract Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="CLIENT CONTRACT AGREEMENTS & RATE REPORT"
      >
        <GenericReportPrintTemplate
          title="CLIENT CONTRACT AGREEMENTS & RATE REPORT"
          columns={[
            { key: "ClientName", label: "Client Account" },
            { key: "UnitName", label: "Site Unit" },
            { key: "StartDate", label: "Effective From" },
            { key: "EndDate", label: "Expiry Date" },
            { key: "MonthlyValue", label: "Monthly Rate", align: "right" },
          ]}
          rows={[]}
        />
      </PrintModal>
    </>
  );
}
