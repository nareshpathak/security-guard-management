"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button, Input, Label } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, date, money } from "@/lib/format";

export default function ClientsPage() {
  const router = useRouter();
  const { has } = useAuth();
  const [addModal, setAddModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [form, setForm] = useState({
    clientName: "",
    clientCode: "",
    contactPerson: "",
    contactNo: "",
    email: "",
    address: "",
    gstin: "",
    panNo: "",
  });

  const createCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/clients",
    invalidate: ["clients"],
    successMessage: "Client account created successfully",
    onDone: () => {
      setAddModal(false);
      setForm({
        clientName: "",
        clientCode: "",
        contactPerson: "",
        contactNo: "",
        email: "",
        address: "",
        gstin: "",
        panNo: "",
      });
    },
  });

  const actions = (
    <div className="flex items-center gap-2">
      <Button variant="outline" onClick={() => setShowPrintModal(true)}>
        <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="6 9 6 2 18 2 18 9" />
          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
          <rect x="6" y="14" width="12" height="8" />
        </svg>
        Print Client Directory
      </Button>
      {has(Perm.clientEdit) ? (
        <Button variant="primary" onClick={() => setAddModal(true)}>
          + Add Client
        </Button>
      ) : null}
    </div>
  );

  return (
    <div>
      <ResourceList
        title="Client Accounts Directory"
        description="Every organisation guarded by the agency, deployed sites, contracts, and outstanding balances."
        actions={actions}
        path="/api/v2/clients"
        queryKey="clients"
        searchPlaceholder="Client name, code, contact person or GSTIN…"
        rowKey={(r, i) => String(r.ClientID ?? i)}
        onRowClick={(r) => router.push(`/clients/units?clientId=${r.ClientID}`)}
        emptyTitle="No clients registered"
        emptyDescription="A client is the organisation you bill. Sites and guard deployments are configured under it."
        columns={[
          {
            id: "client",
            header: "Client Account",
            cell: (r) => (
              <div>
                <div className="font-semibold text-text">{cell(r, "ClientName")}</div>
                <div className="text-xs text-muted">Code: {cell(r, "ClientCode", "GSTIN")}</div>
              </div>
            ),
          },
          {
            id: "contact",
            header: "Primary Contact",
            hideOnMobile: true,
            cell: (r) => (
              <div>
                <div className="font-medium">{cell(r, "ContactPerson")}</div>
                <div className="tabular text-xs text-muted">{cell(r, "ContactNo")}</div>
              </div>
            ),
          },
          {
            id: "sites",
            header: "Sites",
            className: "text-right",
            cell: (r) => <span className="tabular font-medium">{count(r.UnitCount)}</span>,
          },
          {
            id: "deployed",
            header: "Guards On Duty",
            className: "text-right",
            cell: (r) => <span className="tabular font-bold text-success">{count(r.DeployedNos)}</span>,
          },
          {
            id: "complaints",
            header: "Open Complaints",
            className: "text-right",
            hideOnMobile: true,
            cell: (r) => {
              const n = Number(r.OpenComplaints ?? 0);
              return (
                <span className={n > 0 ? "tabular font-bold text-danger" : "tabular text-muted"}>
                  {count(n)}
                </span>
              );
            },
          },
          {
            id: "outstanding",
            header: "Outstanding Balance",
            className: "text-right",
            cell: (r) => {
              const amount = Number(r.OutstandingAmt ?? 0);
              const overdue = Number(r.OverdueInvoices ?? 0);
              return (
                <div className="text-right">
                  <div className={amount > 0 ? "tabular font-semibold" : "tabular text-muted"}>
                    {money(amount)}
                  </div>
                  {overdue > 0 ? (
                    <div className="text-xs font-semibold text-danger">{overdue} overdue</div>
                  ) : null}
                </div>
              );
            },
          },
          {
            id: "last",
            header: "Last Invoiced",
            hideOnMobile: true,
            cell: (r) => <span className="tabular text-muted">{date(r.LastInvoiceOn)}</span>,
          },
          {
            id: "status",
            header: "Account Status",
            cell: (r) => (
              <Status value={r.IsExpired ? "Expired" : r.IsActive ? "Active Client" : "Inactive"} />
            ),
          },
        ]}
      />

      {/* Add Client Modal */}
      <Modal
        open={addModal}
        onOpenChange={setAddModal}
        title="Add New Client Account"
        description="Register a new commercial or residential client organisation."
        footer={
          <Button
            loading={createCmd.isPending}
            disabled={!form.clientName}
            onClick={() => createCmd.mutate(form)}
          >
            Create Client Account
          </Button>
        }
      >
        <div>
          <Label required>Client Organisation Name</Label>
          <Input
            placeholder="e.g. Acme Commercial Complex Pvt Ltd"
            value={form.clientName}
            onChange={(e) => setForm((f) => ({ ...f, clientName: e.target.value }))}
          />
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Client Code / Ref ID</Label>
            <Input
              placeholder="e.g. CLI-1001"
              value={form.clientCode}
              onChange={(e) => setForm((f) => ({ ...f, clientCode: e.target.value }))}
            />
          </div>
          <div>
            <Label>Contact Person</Label>
            <Input
              placeholder="e.g. John Doe (Security Manager)"
              value={form.contactPerson}
              onChange={(e) => setForm((f) => ({ ...f, contactPerson: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>Mobile / Contact No</Label>
            <Input
              placeholder="e.g. +91 98765 43210"
              value={form.contactNo}
              onChange={(e) => setForm((f) => ({ ...f, contactNo: e.target.value }))}
            />
          </div>
          <div>
            <Label>Billing Email Address</Label>
            <Input
              type="email"
              placeholder="e.g. accounts@acme.com"
              value={form.email}
              onChange={(e) => setForm((f) => ({ ...f, email: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label>GSTIN</Label>
            <Input
              placeholder="27AAAAA0000A1Z5"
              value={form.gstin}
              onChange={(e) => setForm((f) => ({ ...f, gstin: e.target.value }))}
            />
          </div>
          <div>
            <Label>PAN No</Label>
            <Input
              placeholder="AAAAA0000A"
              value={form.panNo}
              onChange={(e) => setForm((f) => ({ ...f, panNo: e.target.value }))}
            />
          </div>
        </div>
        <div>
          <Label>Corporate / Billing Address</Label>
          <Input
            placeholder="Complete postal address"
            value={form.address}
            onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Client Directory Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="CLIENT ACCOUNTS DIRECTORY REPORT"
      >
        <GenericReportPrintTemplate
          title="CLIENT ACCOUNTS DIRECTORY REPORT"
          columns={[
            { key: "ClientName", label: "Client Account Name" },
            { key: "ClientCode", label: "Client Code" },
            { key: "ContactPerson", label: "Contact Person" },
            { key: "ContactNo", label: "Mobile" },
            { key: "UnitCount", label: "Sites", align: "right" },
            { key: "DeployedNos", label: "Guards", align: "right" },
            { key: "OutstandingAmt", label: "Outstanding", align: "right" },
          ]}
          rows={[]}
        />
      </PrintModal>
    </div>
  );
}
