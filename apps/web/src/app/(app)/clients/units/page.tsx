"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
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
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";

export default function UnitsPage() {
  const router = useRouter();
  const q = useListQueryState();
  const { has } = useAuth();
  const [addModal, setAddModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [form, setForm] = useState({
    clientId: "",
    unitName: "",
    address: "",
    geofenceRadiusMeters: "150",
  });

  const list = useQuery({
    queryKey: ["units", q.page, q.pageSize, q.search, q.unitId],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/units", {
        page: q.page,
        pageSize: q.pageSize,
        search: q.search || undefined,
      }),
  });

  const clientsQuery = useQuery({
    queryKey: ["clients-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients"),
    staleTime: 5 * 60 * 1000,
  });

  const createCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/units",
    invalidate: ["units"],
    successMessage: "Site unit created successfully",
    onDone: () => {
      setAddModal(false);
      setForm({
        clientId: "",
        unitName: "",
        address: "",
        geofenceRadiusMeters: "150",
      });
    },
  });

  const rows = list.data?.data ?? [];
  const clients = clientsQuery.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Client Deployment Sites / Units"
        description="Physical client sites, geofence radius parameters, and guard post allocations."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Site Directory
            </Button>
            {has(Perm.clientEdit) ? (
              <Button variant="primary" onClick={() => setAddModal(true)}>
                + Create Site Unit
              </Button>
            ) : null}
          </div>
        }
      />

      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState
          message={list.error instanceof Error ? list.error.message : "Failed to load site units"}
          onRetry={() => list.refetch()}
        />
      ) : null}

      {list.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "name",
                header: "Unit Site Name",
                cell: (r) => <span className="font-semibold text-text">{cell(r, "UnitName")}</span>,
              },
              {
                id: "client",
                header: "Client Organisation",
                cell: (r) => <span className="font-medium">{cell(r, "ClientName")}</span>,
              },
              {
                id: "code",
                header: "Site Code",
                hideOnMobile: true,
                cell: (r) => <span className="tabular text-muted font-mono">{cell(r, "UnitCode")}</span>,
              },
              {
                id: "geo",
                header: "Geofence Radius",
                className: "text-right",
                cell: (r) => (
                  <span className="tabular font-medium">{cell(r, "GeofenceRadiusMeters")} m</span>
                ),
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.UnitID ?? r.UnitId ?? i)}
            onRowClick={(r) => router.push(`/clients/units/${r.UnitID ?? r.UnitId}`)}
            empty={
              <EmptyState
                title="No site units registered"
                description="Click Create Site Unit to configure a client deployment location."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={list.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Add Unit Site Modal */}
      <Modal
        open={addModal}
        onOpenChange={setAddModal}
        title="Create Client Site Unit"
        description="Register a physical site unit for security guard deployment."
        footer={
          <Button
            loading={createCmd.isPending}
            disabled={!form.clientId || !form.unitName}
            onClick={() =>
              createCmd.mutate({
                clientId: Number(form.clientId),
                unitName: form.unitName,
                address: form.address || undefined,
                geofenceRadiusMeters: Number(form.geofenceRadiusMeters) || 150,
              })
            }
          >
            Save Site Unit
          </Button>
        }
      >
        <div>
          <Label required>Client Organisation</Label>
          <Select
            value={form.clientId}
            onChange={(e) => setForm((f) => ({ ...f, clientId: e.target.value }))}
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
          <Label required>Unit Site Name</Label>
          <Input
            placeholder="e.g. Acme Tower North Wing Gate 1"
            value={form.unitName}
            onChange={(e) => setForm((f) => ({ ...f, unitName: e.target.value }))}
          />
        </div>
        <div>
          <Label>Geofence Radius (Meters)</Label>
          <Input
            type="number"
            placeholder="150"
            value={form.geofenceRadiusMeters}
            onChange={(e) => setForm((f) => ({ ...f, geofenceRadiusMeters: e.target.value }))}
          />
        </div>
        <div>
          <Label>Site Address & Landmarks</Label>
          <Input
            placeholder="Complete physical site address"
            value={form.address}
            onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Site Units Report */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="CLIENT SITE UNITS DIRECTORY REPORT"
      >
        <GenericReportPrintTemplate
          title="CLIENT SITE UNITS DIRECTORY REPORT"
          columns={[
            { key: "UnitName", label: "Site Unit Name" },
            { key: "ClientName", label: "Client Account" },
            { key: "UnitCode", label: "Site Code" },
            { key: "GeofenceRadiusMeters", label: "Geofence (m)", align: "right" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
