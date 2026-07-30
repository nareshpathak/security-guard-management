"use client";

import { useState } from "react";
import { Button, DataTable, EmptyState, Input, Label, PageHeader, Select, Skeleton, TextArea } from "@diti365/ui";
import { Calendar as CalendarIcon, Plus, MapPin, Users } from "lucide-react";
import { useQuery } from "@tanstack/react-query";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { cell, SearchField } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

export default function EventsPage() {
  const [search, setSearch] = useState("");
  const [adding, setAdding] = useState(false);

  const [form, setForm] = useState({
    eventName: "",
    clientUnitId: "",
    eventDate: isoDate(new Date()),
    endDate: isoDate(new Date()),
    location: "",
    requiredGuards: "5",
    supervisorId: "",
    eventType: "Special Duty",
    remarks: "",
  });

  const list = useQuery({
    queryKey: ["events", search],
    queryFn: async () => {
      const res = await getApi().get<Row[]>("/api/v2/deployments", { search, onlyActive: true });
      return res;
    },
  });

  const createEvent = useCommand<typeof form>({
    path: "/api/v2/contracts/temporary-event",
    invalidate: ["events", "deployments"],
    successMessage: "Temporary event deployment created",
    onDone: () => {
      setAdding(false);
      setForm({
        eventName: "",
        clientUnitId: "",
        eventDate: isoDate(new Date()),
        endDate: isoDate(new Date()),
        location: "",
        requiredGuards: "5",
        supervisorId: "",
        eventType: "Special Duty",
        remarks: "",
      });
    },
  });

  const rows = list.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Events & Special Deployment"
        description="Schedule VIP duties, temporary security deployments, exhibition security, and event staffing."
        actions={
          <Button onClick={() => setAdding(true)}>
            <Plus className="mr-1.5 size-4" /> Create Event
          </Button>
        }
      />

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <SearchField value={search} onChange={setSearch} placeholder="Search event name, location, site..." />
      </div>

      {list.isLoading ? <Skeleton className="h-64" /> : null}

      {list.data ? (
        <DataTable
          columns={[
            {
              id: "event",
              header: "Event",
              cell: (r) => (
                <div>
                  <div className="font-semibold text-text">{cell(r, "EventName", "Name", "Title")}</div>
                  <div className="text-xs text-muted">{cell(r, "EventType", "Type", "Special Duty")}</div>
                </div>
              ),
            },
            {
              id: "dates",
              header: "Date / Duration",
              cell: (r) => (
                <div className="flex items-center gap-1.5 text-xs">
                  <CalendarIcon className="size-3.5 text-muted" />
                  <span className="tabular">{date(r.EventDate ?? r.StartDate)}</span>
                  {Boolean(r.EndDate) && <span className="tabular"> - {date(r.EndDate)}</span>}
                </div>
              ),
            },
            {
              id: "location",
              header: "Location / Site",
              cell: (r) => (
                <div className="flex items-center gap-1.5">
                  <MapPin className="size-3.5 text-muted" />
                  <span>{cell(r, "Location", "UnitName", "Site")}</span>
                </div>
              ),
            },
            {
              id: "guards",
              header: "Required Guards",
              cell: (r) => (
                <div className="flex items-center gap-1.5 text-sm font-medium">
                  <Users className="size-4 text-[var(--diti-primary)]" />
                  <span>{cell(r, "RequiredGuards", "GuardsCount", "Strength")} Guards</span>
                </div>
              ),
            },
            {
              id: "status",
              header: "Status",
              cell: (r) => <Status value={r.Status ?? "Scheduled"} />,
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.EventID ?? r.Id ?? i)}
          empty={
            <EmptyState
              title="No events scheduled"
              description="Click Create Event to schedule a special security deployment or event assignment."
              action={
                <Button onClick={() => setAdding(true)}>
                  <Plus className="mr-1.5 size-4" /> Create Event
                </Button>
              }
            />
          }
        />
      ) : null}

      <Modal
        open={adding}
        onOpenChange={setAdding}
        title="Create Special Event Deployment"
        description="Configure guard requirements, dates, and supervisor for temporary site events."
        footer={
          <Button
            loading={createEvent.isPending}
            disabled={!form.eventName || !form.location}
            onClick={() => createEvent.mutate(form)}
          >
            Create Event
          </Button>
        }
      >
        <div className="space-y-4">
          <div>
            <Label required>Event Title</Label>
            <Input
              value={form.eventName}
              placeholder="e.g. Apex Tech Park Annual Expo Security"
              onChange={(e) => setForm((f) => ({ ...f, eventName: e.target.value }))}
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label required>Start Date</Label>
              <Input
                type="date"
                value={form.eventDate}
                onChange={(e) => setForm((f) => ({ ...f, eventDate: e.target.value }))}
              />
            </div>
            <div>
              <Label required>End Date</Label>
              <Input
                type="date"
                value={form.endDate}
                onChange={(e) => setForm((f) => ({ ...f, endDate: e.target.value }))}
              />
            </div>
          </div>

          <div>
            <Label required>Event Location / Venue</Label>
            <Input
              value={form.location}
              placeholder="e.g. Convention Hall B, Gate 4 Parking"
              onChange={(e) => setForm((f) => ({ ...f, location: e.target.value }))}
            />
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div>
              <Label required>Required Guards</Label>
              <Input
                type="number"
                min="1"
                value={form.requiredGuards}
                onChange={(e) => setForm((f) => ({ ...f, requiredGuards: e.target.value }))}
              />
            </div>
            <div>
              <Label>Event Type</Label>
              <Select
                value={form.eventType}
                onChange={(e) => setForm((f) => ({ ...f, eventType: e.target.value }))}
              >
                <option value="Special Duty">Special Duty</option>
                <option value="Exhibition">Exhibition / Expo</option>
                <option value="VIP Security">VIP Escort</option>
                <option value="Crowd Control">Crowd Control</option>
                <option value="Night Patrol">Night Event</option>
              </Select>
            </div>
          </div>

          <div>
            <Label>Remarks / Instructions</Label>
            <TextArea
              value={form.remarks}
              placeholder="Uniform requirements, shift timings, emergency contact protocols..."
              onChange={(e) => setForm((f) => ({ ...f, remarks: e.target.value }))}
            />
          </div>
        </div>
      </Modal>
    </div>
  );
}
