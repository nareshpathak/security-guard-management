"use client";

import { useState } from "react";
import { Button, DataTable, EmptyState, Input, Label, PageHeader, Select, Skeleton } from "@diti365/ui";
import { QrCode, Printer, Plus, MapPin } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { MasterSelect } from "@/components/master-select";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { cell, SearchField } from "@/lib/list-query";

export default function QrManagementPage() {
  const [search, setSearch] = useState("");
  const [adding, setAdding] = useState(false);
  const [selectedQr, setSelectedQr] = useState<Row | null>(null);

  const [form, setForm] = useState({
    unitId: "",
    postName: "",
    checkpointName: "",
    locationType: "Checkpoint",
    latitude: "",
    longitude: "",
  });

  const list = useQuery({
    queryKey: ["qr-codes", search],
    queryFn: async () => {
      const res = await getApi().get<Row[]>("/api/v2/patrol/checkpoints", { search });
      return res;
    },
  });

  const createQr = useCommand<typeof form>({
    path: "/api/v2/patrol/checkpoints",
    invalidate: ["qr-codes"],
    successMessage: "QR Checkpoint generated",
    onDone: () => {
      setAdding(false);
      setForm({ unitId: "", postName: "", checkpointName: "", locationType: "Checkpoint", latitude: "", longitude: "" });
    },
  });

  const rows = list.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="QR Code Management"
        description="Generate, print, and assign QR code checkpoints for site patrol & attendance scanning."
        actions={
          <Button onClick={() => setAdding(true)}>
            <Plus className="mr-1.5 size-4" /> Generate QR Code
          </Button>
        }
      />

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <SearchField value={search} onChange={setSearch} placeholder="Search site, checkpoint, post..." />
      </div>

      {list.isLoading ? <Skeleton className="h-64" /> : null}

      {list.data ? (
        <DataTable
          columns={[
            {
              id: "code",
              header: "QR Code ID",
              cell: (r) => (
                <div className="flex items-center gap-2 font-mono text-xs font-semibold text-[var(--diti-primary)]">
                  <QrCode className="size-4" />
                  {cell(r, "QrCode", "Code", "CheckpointID")}
                </div>
              ),
            },
            {
              id: "name",
              header: "Checkpoint / Post",
              cell: (r) => (
                <div>
                  <div className="font-medium text-text">{cell(r, "CheckpointName", "Name")}</div>
                  <div className="text-xs text-muted">{cell(r, "PostName", "Post")}</div>
                </div>
              ),
            },
            {
              id: "site",
              header: "Unit / Site",
              cell: (r) => (
                <div className="flex items-center gap-1.5">
                  <MapPin className="size-3.5 text-muted" />
                  <span>{cell(r, "UnitName", "Site")}</span>
                </div>
              ),
            },
            {
              id: "type",
              header: "Type",
              cell: (r) => cell(r, "LocationType", "Type", "Checkpoint"),
            },
            {
              id: "actions",
              header: "Actions",
              className: "text-right",
              cell: (r) => (
                <Button size="sm" variant="outline" onClick={() => setSelectedQr(r)}>
                  <Printer className="mr-1 size-3.5" /> View & Print
                </Button>
              ),
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.CheckpointID ?? r.Id ?? i)}
          empty={
            <EmptyState
              title="No QR codes generated"
              description="Click Generate QR Code to create a site checkpoint for patrol scanning."
              action={
                <Button onClick={() => setAdding(true)}>
                  <Plus className="mr-1.5 size-4" /> Generate QR Code
                </Button>
              }
            />
          }
        />
      ) : null}

      {/* Create QR Modal */}
      <Modal
        open={adding}
        onOpenChange={setAdding}
        title="Generate Site QR Code"
        description="Create a scannable QR checkpoint tag for patrol routes or guard attendance."
        footer={
          <Button
            loading={createQr.isPending}
            disabled={!form.unitId || !form.checkpointName}
            onClick={() => createQr.mutate(form)}
          >
            Generate QR Code
          </Button>
        }
      >
        <div className="space-y-4">
          <MasterSelect
            label="Unit / Site"
            set="units"
            value={form.unitId}
            onChange={(v) => setForm((f) => ({ ...f, unitId: v }))}
          />
          <div>
            <Label required>Post Name</Label>
            <Input
              value={form.postName}
              placeholder="e.g. Main Gate, Tower A Rear, Loading Dock"
              onChange={(e) => setForm((f) => ({ ...f, postName: e.target.value }))}
            />
          </div>
          <div>
            <Label required>Checkpoint Name</Label>
            <Input
              value={form.checkpointName}
              placeholder="e.g. CP-01 Main Entrance Scanner"
              onChange={(e) => setForm((f) => ({ ...f, checkpointName: e.target.value }))}
            />
          </div>
          <div>
            <Label>Location Type</Label>
            <Select
              value={form.locationType}
              onChange={(e) => setForm((f) => ({ ...f, locationType: e.target.value }))}
            >
              <option value="Checkpoint">Patrol Checkpoint</option>
              <option value="Gate">Gate Entrance</option>
              <option value="Turnout">Turnout Point</option>
              <option value="Asset">Key Asset Locker</option>
            </Select>
          </div>
        </div>
      </Modal>

      {/* View & Print Modal */}
      <Modal
        open={Boolean(selectedQr)}
        onOpenChange={(open) => !open && setSelectedQr(null)}
        title="QR Code Tag Preview"
        footer={
          <Button onClick={() => window.print()}>
            <Printer className="mr-1.5 size-4" /> Print Tag
          </Button>
        }
      >
        {selectedQr && (
          <div className="flex flex-col items-center justify-center space-y-4 py-4 text-center">
            <div className="relative flex size-48 flex-col items-center justify-center rounded-2xl border-4 border-dashed border-[var(--diti-primary)] bg-white p-4 shadow-md">
              {/* SVG QR Code Illustration */}
              <svg className="size-36 text-black" viewBox="0 0 100 100" fill="currentColor">
                <path d="M0,0 h35 v35 h-35 z M5,5 v25 h25 v-25 z M10,10 h15 v15 h-15 z" />
                <path d="M65,0 h35 v35 h-35 z M70,5 v25 h25 v-25 z M75,10 h15 v15 h-15 z" />
                <path d="M0,65 h35 v35 h-35 z M5,70 v25 h25 v-25 z M10,75 h15 v15 h-15 z" />
                <rect x="42" y="10" width="16" height="16" />
                <rect x="42" y="42" width="16" height="16" />
                <rect x="10" y="42" width="16" height="16" />
                <rect x="74" y="42" width="16" height="16" />
                <rect x="65" y="65" width="16" height="16" />
                <rect x="42" y="74" width="16" height="16" />
                <rect x="74" y="74" width="16" height="16" />
              </svg>
            </div>
            <div>
              <p className="font-mono text-sm font-bold tracking-wider text-[var(--diti-primary)]">
                {cell(selectedQr, "QrCode", "Code", "CheckpointID")}
              </p>
              <p className="text-base font-semibold text-[var(--diti-text)]">
                {cell(selectedQr, "CheckpointName", "Name")}
              </p>
              <p className="text-xs text-[var(--diti-muted)]">
                {cell(selectedQr, "UnitName")} · {cell(selectedQr, "PostName")}
              </p>
            </div>
          </div>
        )}
      </Modal>
    </div>
  );
}
