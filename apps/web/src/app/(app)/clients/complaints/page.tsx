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
import { date, dateTime } from "@/lib/format";

export default function ComplaintsPage() {
  const { has } = useAuth();
  const [logModal, setLogModal] = useState(false);
  const [statusModal, setStatusModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [selectedComplaint, setSelectedComplaint] = useState<Row | null>(null);

  const [logForm, setLogForm] = useState({
    clientId: "",
    unitId: "",
    description: "",
    photoUrl: "",
  });

  const [statusForm, setStatusForm] = useState({
    status: "In Progress",
    assignedToEmpId: "",
    remark: "",
  });

  const clientsQuery = useQuery({
    queryKey: ["clients-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients"),
    staleTime: 5 * 60 * 1000,
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown", logForm.clientId],
    enabled: !!logForm.clientId,
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { clientId: Number(logForm.clientId) }),
  });

  const logCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/complaints",
    invalidate: ["complaints"],
    successMessage: "Client complaint registered successfully",
    onDone: () => {
      setLogModal(false);
      setLogForm({
        clientId: "",
        unitId: "",
        description: "",
        photoUrl: "",
      });
    },
  });

  const statusCmd = useCommand<Record<string, unknown>>({
    path: selectedComplaint
      ? `/api/v2/complaints/${cell(selectedComplaint, "ComplaintID", "Id")}/status`
      : "",
    invalidate: ["complaints"],
    successMessage: "Complaint status updated",
    onDone: () => {
      setStatusModal(false);
      setSelectedComplaint(null);
      setStatusForm({
        status: "In Progress",
        assignedToEmpId: "",
        remark: "",
      });
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
        Print Complaint Register
      </Button>
      {has(Perm.complaintEdit) ? (
        <Button variant="primary" onClick={() => setLogModal(true)}>
          + Log Client Complaint
        </Button>
      ) : null}
    </div>
  );

  return (
    <>
      <ResourceList
        title="Client Complaints & SLA SLA Tracking"
        description="Site complaints raised by clients, resolution SLA tracking, and assignment to field officers."
        actions={actions}
        path="/api/v2/complaints"
        queryKey="complaints"
        searchPlaceholder="Client, site unit, or complaint details…"
        rowKey={(r, i) => String(r.ComplaintID ?? i)}
        emptyTitle="No client complaints"
        emptyDescription="Complaints raised by clients or logged on site appear here."
        columns={[
          {
            id: "raised",
            header: "Raised On",
            cell: (r) => <span className="tabular font-medium">{date(r.ComplaintDate ?? r.InsertDate)}</span>,
          },
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
          { id: "type", header: "Type", hideOnMobile: true, cell: (r) => cell(r, "ComplaintTypeName", "TypeName") },
          {
            id: "subject",
            header: "Complaint Details",
            cell: (r) => (
              <span className="line-clamp-2 max-w-md font-normal">{cell(r, "Subject", "Description", "Remark")}</span>
            ),
          },
          {
            id: "age",
            header: "SLA Open Age",
            className: "text-right",
            cell: (r) => {
              if (r.IsClosed) return <span className="text-muted">Closed</span>;
              const raised = new Date(String(r.ComplaintDate ?? r.InsertDate));
              if (Number.isNaN(raised.getTime())) return <span className="text-muted">—</span>;
              const days = Math.floor((Date.now() - raised.getTime()) / 86_400_000);
              return (
                <span className={days >= 7 ? "tabular font-bold text-danger" : "tabular font-medium"}>
                  {days} days
                </span>
              );
            },
          },
          {
            id: "status",
            header: "Resolution Status",
            cell: (r) => <Status value={r.IsClosed ? "Resolved & Closed" : (r.Status ?? "Open")} />,
          },
          {
            id: "actions",
            header: "Action",
            className: "text-right",
            cell: (r) =>
              has(Perm.complaintEdit) ? (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    setSelectedComplaint(r);
                    setStatusModal(true);
                  }}
                >
                  Update / Resolve
                </Button>
              ) : null,
          },
        ]}
      />

      {/* Log Complaint Modal */}
      <Modal
        open={logModal}
        onOpenChange={setLogModal}
        title="Log Client Complaint"
        description="Record a complaint raised by client or reported during site visit."
        footer={
          <Button
            loading={logCmd.isPending}
            disabled={!logForm.unitId || !logForm.description}
            onClick={() =>
              logCmd.mutate({
                unitId: Number(logForm.unitId),
                clientId: logForm.clientId ? Number(logForm.clientId) : undefined,
                description: logForm.description,
                photoUrl: logForm.photoUrl || undefined,
              })
            }
          >
            Submit Complaint Ticket
          </Button>
        }
      >
        <div>
          <Label required>Client Account</Label>
          <Select
            value={logForm.clientId}
            onChange={(e) => setLogForm((f) => ({ ...f, clientId: e.target.value, unitId: "" }))}
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
            value={logForm.unitId}
            onChange={(e) => setLogForm((f) => ({ ...f, unitId: e.target.value }))}
            disabled={!logForm.clientId}
          >
            <option value="">Select Site Unit...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Complaint Description</Label>
          <TextArea
            placeholder="Detailed description of guard issue, absenteeism, post neglect, or misconduct..."
            value={logForm.description}
            onChange={(e) => setLogForm((f) => ({ ...f, description: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Update Complaint Status Modal */}
      <Modal
        open={statusModal}
        onOpenChange={setStatusModal}
        title="Update Complaint Resolution"
        description={
          selectedComplaint
            ? `Updating complaint #${cell(selectedComplaint, "ComplaintID")} for ${cell(selectedComplaint, "ClientName")}`
            : "Update Status"
        }
        footer={
          <Button
            loading={statusCmd.isPending}
            disabled={!selectedComplaint || !statusForm.status}
            onClick={() =>
              statusCmd.mutate({
                status: statusForm.status,
                assignedToEmpId: statusForm.assignedToEmpId ? Number(statusForm.assignedToEmpId) : undefined,
                remark: statusForm.remark || undefined,
              })
            }
          >
            Update Resolution Status
          </Button>
        }
      >
        <div>
          <Label required>Complaint Status</Label>
          <Select
            value={statusForm.status}
            onChange={(e) => setStatusForm((f) => ({ ...f, status: e.target.value }))}
          >
            <option value="In Progress">In Progress (Assigned)</option>
            <option value="Resolved">Resolved (Action Taken)</option>
            <option value="Closed">Closed (Client Confirmed)</option>
          </Select>
        </div>
        <div>
          <Label>Assign Field Officer (Employee ID)</Label>
          <Input
            type="number"
            placeholder="e.g. 1001"
            value={statusForm.assignedToEmpId}
            onChange={(e) => setStatusForm((f) => ({ ...f, assignedToEmpId: e.target.value }))}
          />
        </div>
        <div>
          <Label>Resolution Notes & Action Taken</Label>
          <TextArea
            placeholder="Action taken to address complaint (e.g. Guard replaced, supervisor warned)..."
            value={statusForm.remark}
            onChange={(e) => setStatusForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Complaint Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="CLIENT COMPLAINTS & SLA RESOLUTION AUDIT REPORT"
      >
        <GenericReportPrintTemplate
          title="CLIENT COMPLAINTS & SLA RESOLUTION AUDIT REPORT"
          columns={[
            { key: "ComplaintDate", label: "Date" },
            { key: "ClientName", label: "Client Account" },
            { key: "UnitName", label: "Site Unit" },
            { key: "Description", label: "Complaint Details" },
            { key: "Status", label: "Status" },
          ]}
          rows={[]}
        />
      </PrintModal>
    </>
  );
}
