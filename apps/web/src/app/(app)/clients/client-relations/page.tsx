"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, Input, Label, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { ResourceList } from "@/components/resource-list";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

export default function ClientRelationsPage() {
  const { has } = useAuth();
  const [recordModal, setRecordModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [form, setForm] = useState({
    unitId: "",
    contactPerson: "",
    mobileNo: "",
    dated: isoDate(new Date()),
    timing: "10:00 AM",
    remark: "",
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units"),
    staleTime: 5 * 60 * 1000,
  });

  const recordCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/sales/client-relations",
    invalidate: ["client-relations"],
    successMessage: "Client relationship visit recorded successfully",
    onDone: () => {
      setRecordModal(false);
      setForm({
        unitId: "",
        contactPerson: "",
        mobileNo: "",
        dated: isoDate(new Date()),
        timing: "10:00 AM",
        remark: "",
      });
    },
  });

  const units = unitsQuery.data?.data ?? [];

  const actions = (
    <div className="flex items-center gap-2">
      <Button variant="outline" onClick={() => setShowPrintModal(true)}>
        <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="6 9 6 2 18 2 18 9" />
          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
          <rect x="6" y="14" width="12" height="8" />
        </svg>
        Print Visit Audit Report
      </Button>
      {has(Perm.salesEdit) ? (
        <Button variant="primary" onClick={() => setRecordModal(true)}>
          + Record Relation Visit
        </Button>
      ) : null}
    </div>
  );

  return (
    <>
      <ResourceList
        title="Client Relationship Visits & Feedback Audit"
        description="Courtesy visits to existing clients by relationship managers and field officers to spot churn risks early."
        actions={actions}
        path="/api/v2/sales/client-relations"
        queryKey="client-relations"
        searchPlaceholder="Site unit, contact person or notes…"
        rowKey={(r, i) => String(r.VisitID ?? i)}
        emptyTitle="No relation visits recorded"
        emptyDescription="Courtesy site visits logged by field executives appear here."
        columns={[
          {
            id: "when",
            header: "Visit Date",
            cell: (r) => <span className="tabular font-medium">{date(r.Dated)}</span>,
          },
          {
            id: "unit",
            header: "Unit Site",
            cell: (r) => <span className="font-semibold text-text">{cell(r, "UnitName")}</span>,
          },
          {
            id: "contact",
            header: "Person Met",
            cell: (r) => (
              <div>
                <div className="font-medium">{cell(r, "ContactPerson")}</div>
                <div className="tabular text-xs text-muted">{cell(r, "MobileNo")}</div>
              </div>
            ),
          },
          {
            id: "by",
            header: "Field Executive",
            hideOnMobile: true,
            cell: (r) => cell(r, "EmpFullName", "ExecutiveName"),
          },
          { id: "timing", header: "Time", hideOnMobile: true, cell: (r) => cell(r, "Timing") },
          {
            id: "remark",
            header: "Discussion & Feedback",
            cell: (r) => <span className="line-clamp-2 max-w-md text-muted">{cell(r, "Remark")}</span>,
          },
        ]}
      />

      {/* Record Visit Modal */}
      <Modal
        open={recordModal}
        onOpenChange={setRecordModal}
        title="Record Client Relationship Visit"
        description="Log courtesy visit notes and client feedback for a site unit."
        footer={
          <Button
            loading={recordCmd.isPending}
            disabled={!form.unitId || !form.contactPerson}
            onClick={() =>
              recordCmd.mutate({
                unitId: Number(form.unitId),
                contactPerson: form.contactPerson,
                mobileNo: form.mobileNo || undefined,
                dated: form.dated,
                timing: form.timing || undefined,
                remark: form.remark || undefined,
              })
            }
          >
            Save Visit Record
          </Button>
        }
      >
        <div>
          <Label required>Client Site Unit</Label>
          <Select
            value={form.unitId}
            onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))}
          >
            <option value="">Select Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Person Met (Client Official)</Label>
            <Input
              placeholder="e.g. Mr. Sharma (Facility Manager)"
              value={form.contactPerson}
              onChange={(e) => setForm((f) => ({ ...f, contactPerson: e.target.value }))}
            />
          </div>
          <div>
            <Label>Contact Mobile No</Label>
            <Input
              placeholder="e.g. +91 98765 43210"
              value={form.mobileNo}
              onChange={(e) => setForm((f) => ({ ...f, mobileNo: e.target.value }))}
            />
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Visit Date</Label>
            <Input
              type="date"
              value={form.dated}
              onChange={(e) => setForm((f) => ({ ...f, dated: e.target.value }))}
            />
          </div>
          <div>
            <Label>Visit Time</Label>
            <Input
              placeholder="10:30 AM"
              value={form.timing}
              onChange={(e) => setForm((f) => ({ ...f, timing: e.target.value }))}
            />
          </div>
        </div>
        <div>
          <Label>Client Feedback & Discussion Summary</Label>
          <TextArea
            placeholder="Feedback on guard performance, uniform standards, billing issues, or extension scope..."
            value={form.remark}
            onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Visit Audit Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="CLIENT RELATIONSHIP VISITS AUDIT REPORT"
      >
        <GenericReportPrintTemplate
          title="CLIENT RELATIONSHIP VISITS AUDIT REPORT"
          columns={[
            { key: "Dated", label: "Date" },
            { key: "UnitName", label: "Site Unit" },
            { key: "ContactPerson", label: "Person Met" },
            { key: "EmpFullName", label: "Executive" },
            { key: "Remark", label: "Feedback Notes" },
          ]}
          rows={[]}
        />
      </PrintModal>
    </>
  );
}
