"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

export default function DeploymentPage() {
  const q = useListQueryState();
  const { has } = useAuth();
  const [deployModal, setDeployModal] = useState(false);
  const [endModal, setEndModal] = useState(false);
  const [movementModal, setMovementModal] = useState(false);
  const [relieversModal, setRelieversModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);
  const [selectedDeployment, setSelectedDeployment] = useState<Row | null>(null);

  const [deployForm, setDeployForm] = useState({
    empId: "",
    unitId: "",
    shiftId: "",
    fromDate: isoDate(new Date()),
    isReliever: false,
    remark: "",
  });

  const [endForm, setEndForm] = useState({
    toDate: isoDate(new Date()),
    remark: "",
  });

  const [movementForm, setMovementForm] = useState({
    empId: "",
    fromUnitId: "",
    toUnitId: "",
    movementDate: isoDate(new Date()),
    instructionBy: "",
    remark: "",
  });

  const listQuery = useQuery({
    queryKey: ["deployments", q.page, q.pageSize, q.unitId, q.search],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/deployments", {
        page: q.page,
        pageSize: q.pageSize,
        unitId: q.unitId,
        search: q.search || undefined,
        onlyActive: true,
      }),
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units"),
    staleTime: 5 * 60 * 1000,
  });

  const relieversQuery = useQuery({
    queryKey: ["available-relievers", q.unitId],
    queryFn: () =>
      getApi().get<Row[]>(`/api/v2/units/${q.unitId ?? 0}/relievers`, {
        onDate: isoDate(new Date()),
      }),
    enabled: !!q.unitId && relieversModal,
  });

  const deployCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/deployments",
    invalidate: ["deployments"],
    successMessage: "Guard deployed successfully",
    onDone: () => {
      setDeployModal(false);
      setDeployForm({
        empId: "",
        unitId: "",
        shiftId: "",
        fromDate: isoDate(new Date()),
        isReliever: false,
        remark: "",
      });
    },
  });

  const endCmd = useCommand<Record<string, unknown>>({
    path: selectedDeployment
      ? `/api/v2/deployments/${cell(selectedDeployment, "DeploymentID", "DeploymentId")}/end`
      : "",
    invalidate: ["deployments"],
    successMessage: "Guard deployment ended successfully",
    onDone: () => {
      setEndModal(false);
      setSelectedDeployment(null);
    },
  });

  const movementCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/deployments/movement",
    invalidate: ["deployments"],
    successMessage: "Guard site transfer recorded successfully",
    onDone: () => {
      setMovementModal(false);
      setMovementForm({
        empId: "",
        fromUnitId: "",
        toUnitId: "",
        movementDate: isoDate(new Date()),
        instructionBy: "",
        remark: "",
      });
    },
  });

  const rows = listQuery.data?.data ?? [];
  const units = unitsQuery.data?.data ?? [];
  const availableRelievers = relieversQuery.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Guard Deployments & Site Movement"
        description="Allocate security guards to client sites, posts, shifts, and record site-to-site transfers."
        actions={
          <div className="flex items-center gap-2">
            {q.unitId ? (
              <Button variant="outline" onClick={() => setRelieversModal(true)}>
                Find Available Relievers
              </Button>
            ) : null}
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Deployment Roster
            </Button>
            {has(Perm.deploymentEdit) ? (
              <>
                <Button variant="outline" onClick={() => setMovementModal(true)}>
                  Transfer Guard
                </Button>
                <Button variant="primary" onClick={() => setDeployModal(true)}>
                  + Deploy Guard
                </Button>
              </>
            ) : null}
          </div>
        }
      />

      {/* Toolbar & Unit Filter */}
      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="w-64">
          <Select
            value={String(q.unitId ?? "")}
            onChange={(e) =>
              q.setParams({ unitId: e.target.value ? Number(e.target.value) : undefined, page: 1 })
            }
          >
            <option value="">All Deployed Units...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
      </div>

      {listQuery.isLoading ? <Skeleton className="h-64" /> : null}
      {listQuery.isError ? (
        <ErrorState
          message={
            listQuery.error instanceof Error ? listQuery.error.message : "Failed to load deployments"
          }
          onRetry={() => listQuery.refetch()}
        />
      ) : null}

      {listQuery.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "emp",
                header: "Guard / Employee",
                cell: (r) => (
                  <div>
                    <div className="font-semibold text-text">{cell(r, "EmpFullName")}</div>
                    <div className="tabular text-xs text-muted">ID: {cell(r, "EmpCode", "EmpId")}</div>
                  </div>
                ),
              },
              {
                id: "unit",
                header: "Deployed Unit Site",
                cell: (r) => <span className="font-medium">{cell(r, "UnitName")}</span>,
              },
              {
                id: "shift",
                header: "Shift",
                hideOnMobile: true,
                cell: (r) => <span className="tabular">{cell(r, "ShiftName", "ShiftID")}</span>,
              },
              {
                id: "from",
                header: "Deployed Since",
                cell: (r) => <span className="tabular">{date(r.FromDate ?? r.Dated)}</span>,
              },
              {
                id: "status",
                header: "Status",
                cell: (r) => (
                  <StatusPill
                    tone={
                      String(r.IsActive) === "1" || String(r.IsActive) === "true"
                        ? "success"
                        : "neutral"
                    }
                  >
                    {r.IsReliever ? "Reliever" : "Active Guard"}
                  </StatusPill>
                ),
              },
              {
                id: "actions",
                header: "Actions",
                className: "text-right",
                cell: (r) =>
                  has(Perm.deploymentEdit) ? (
                    <Button
                      size="sm"
                      variant="danger"
                      onClick={() => {
                        setSelectedDeployment(r);
                        setEndModal(true);
                      }}
                    >
                      End Deployment
                    </Button>
                  ) : null,
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.DeploymentID ?? r.DeploymentId ?? i)}
            empty={
              <EmptyState
                title="No active deployments"
                description="Click Deploy Guard to assign personnel to client sites."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={listQuery.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Deploy Guard Modal */}
      <Modal
        open={deployModal}
        onOpenChange={setDeployModal}
        title="Deploy Guard to Site"
        description="Allocate employee to client unit site and shift."
        footer={
          <Button
            loading={deployCmd.isPending}
            disabled={!deployForm.empId || !deployForm.unitId}
            onClick={() =>
              deployCmd.mutate({
                empId: Number(deployForm.empId),
                unitId: Number(deployForm.unitId),
                shiftId: deployForm.shiftId ? Number(deployForm.shiftId) : undefined,
                fromDate: deployForm.fromDate,
                isReliever: deployForm.isReliever,
                remark: deployForm.remark || undefined,
              })
            }
          >
            Confirm Deployment
          </Button>
        }
      >
        <div>
          <Label required>Employee ID</Label>
          <Input
            type="number"
            placeholder="e.g. 1001"
            value={deployForm.empId}
            onChange={(e) => setDeployForm((f) => ({ ...f, empId: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Unit Site</Label>
          <Select
            value={deployForm.unitId}
            onChange={(e) => setDeployForm((f) => ({ ...f, unitId: e.target.value }))}
          >
            <option value="">Select Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label>Deployment Start Date</Label>
          <Input
            type="date"
            value={deployForm.fromDate}
            onChange={(e) => setDeployForm((f) => ({ ...f, fromDate: e.target.value }))}
          />
        </div>
        <div className="flex items-center gap-2 pt-2">
          <input
            type="checkbox"
            id="isReliever"
            checked={deployForm.isReliever}
            onChange={(e) => setDeployForm((f) => ({ ...f, isReliever: e.target.checked }))}
            className="size-4 rounded border-[var(--diti-border)] text-blue-600 focus:ring-blue-500"
          />
          <Label htmlFor="isReliever" className="!mb-0 cursor-pointer">
            Deploy as Reliever Guard (Temporary replacement)
          </Label>
        </div>
        <div>
          <Label>Deployment Remarks</Label>
          <Input
            placeholder="Remarks or special instructions"
            value={deployForm.remark}
            onChange={(e) => setDeployForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* End Deployment Modal */}
      <Modal
        open={endModal}
        onOpenChange={setEndModal}
        title="End Guard Deployment"
        description={
          selectedDeployment
            ? `Ending deployment for ${cell(selectedDeployment, "EmpFullName")} at ${cell(selectedDeployment, "UnitName")}`
            : "End Deployment"
        }
        footer={
          <Button
            loading={endCmd.isPending}
            disabled={!selectedDeployment || !endForm.toDate}
            onClick={() =>
              endCmd.mutate({
                toDate: endForm.toDate,
                remark: endForm.remark || undefined,
              })
            }
          >
            Confirm End Deployment
          </Button>
        }
      >
        <div>
          <Label required>Effective End Date</Label>
          <Input
            type="date"
            value={endForm.toDate}
            onChange={(e) => setEndForm((f) => ({ ...f, toDate: e.target.value }))}
          />
        </div>
        <div>
          <Label>Reason / Remarks</Label>
          <Input
            placeholder="e.g. Transferred to another site / Resigned"
            value={endForm.remark}
            onChange={(e) => setEndForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Transfer Guard Modal */}
      <Modal
        open={movementModal}
        onOpenChange={setMovementModal}
        title="Site-to-Site Guard Transfer"
        description="Transfer guard from one client site to another."
        footer={
          <Button
            loading={movementCmd.isPending}
            disabled={!movementForm.empId || !movementForm.toUnitId}
            onClick={() =>
              movementCmd.mutate({
                empId: Number(movementForm.empId),
                fromUnitId: movementForm.fromUnitId ? Number(movementForm.fromUnitId) : undefined,
                toUnitId: Number(movementForm.toUnitId),
                movementDate: movementForm.movementDate,
                instructionBy: movementForm.instructionBy || undefined,
                remark: movementForm.remark || undefined,
              })
            }
          >
            Execute Guard Transfer
          </Button>
        }
      >
        <div>
          <Label required>Guard Employee ID</Label>
          <Input
            type="number"
            placeholder="e.g. 1001"
            value={movementForm.empId}
            onChange={(e) => setMovementForm((f) => ({ ...f, empId: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Transfer To Unit Site</Label>
          <Select
            value={movementForm.toUnitId}
            onChange={(e) => setMovementForm((f) => ({ ...f, toUnitId: e.target.value }))}
          >
            <option value="">Select Target Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label required>Transfer Effective Date</Label>
          <Input
            type="date"
            value={movementForm.movementDate}
            onChange={(e) => setMovementForm((f) => ({ ...f, movementDate: e.target.value }))}
          />
        </div>
        <div>
          <Label>Instruction By (Supervisor Name)</Label>
          <Input
            placeholder="e.g. Field Officer Operations"
            value={movementForm.instructionBy}
            onChange={(e) => setMovementForm((f) => ({ ...f, instructionBy: e.target.value }))}
          />
        </div>
        <div>
          <Label>Transfer Remarks</Label>
          <Input
            placeholder="Transfer reason or client request note"
            value={movementForm.remark}
            onChange={(e) => setMovementForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Available Relievers Drawer */}
      <Modal
        open={relieversModal}
        onOpenChange={setRelieversModal}
        title="Nearest Available Relievers"
        description="Available relievers sorted by nearest distance to selected site."
      >
        {relieversQuery.isLoading ? <Skeleton className="h-48" /> : null}
        {relieversQuery.data ? (
          <DataTable
            columns={[
              { id: "name", header: "Reliever Guard", cell: (r) => cell(r, "EmpFullName") },
              { id: "code", header: "Emp Code", cell: (r) => cell(r, "EmpCode") },
              { id: "mobile", header: "Mobile", cell: (r) => cell(r, "Mobile1") },
            ]}
            rows={availableRelievers}
            rowKey={(r, i) => String(r.EmpID ?? i)}
            empty={<EmptyState title="No relievers available nearby" />}
          />
        ) : null}
      </Modal>

      {/* Printable Deployment Roster Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="SITE GUARD DEPLOYMENT ROSTER REPORT"
      >
        <GenericReportPrintTemplate
          title="SITE GUARD DEPLOYMENT ROSTER REPORT"
          columns={[
            { key: "EmpFullName", label: "Guard Name" },
            { key: "EmpCode", label: "Emp Code" },
            { key: "UnitName", label: "Deployed Unit" },
            { key: "ShiftName", label: "Shift" },
            { key: "FromDate", label: "Deployed Since" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
