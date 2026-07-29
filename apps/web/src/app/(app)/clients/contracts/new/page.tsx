"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Input, Label, PageHeader, Select, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { useCommand } from "@/lib/use-command";
import { isoDate } from "@/lib/format";

/**
 * A contract, or a one-off event.
 *
 * A temporary event - a wedding, a rally, an exhibition - is billed and staffed
 * differently from a standing contract, which is why the legacy app had a
 * separate fragment for it. Same page, one switch.
 */
export default function NewContractPage() {
  const router = useRouter();
  const [temporary, setTemporary] = useState(false);

  const clients = useQuery({
    queryKey: ["clients-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  const units = useQuery({
    queryKey: ["units-for-select"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units", { page: 1, pageSize: 200 }),
    staleTime: 5 * 60 * 1000,
  });

  const [form, setForm] = useState({
    clientId: "",
    unitId: "",
    startDate: isoDate(new Date()),
    endDate: "",
    guardNos: "",
    ratePerGuard: "",
    eventName: "",
    remark: "",
  });

  const save = useCommand<Record<string, unknown>>({
    path: () => (temporary ? "/api/v2/contracts/temporary-event" : "/api/v2/contracts"),
    invalidate: ["contracts", "clients"],
    successMessage: temporary ? "Event recorded" : "Contract saved",
    onDone: () => router.push("/clients/contracts"),
  });

  return (
    <div className="max-w-2xl">
      <PageHeader
        title={temporary ? "New temporary event" : "New contract"}
        description={
          temporary
            ? "A one-off deployment: an event, a rally, an exhibition."
            : "The standing agreement for a site: strength, rate and term."
        }
        actions={
          <Button variant="outline" onClick={() => router.push("/clients/contracts")}>
            Back
          </Button>
        }
      />

      <Card className="grid gap-4 md:grid-cols-2">
        <label className="flex items-center gap-2 text-sm text-text md:col-span-2">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={temporary}
            onChange={(e) => setTemporary(e.target.checked)}
          />
          This is a one-off event, not a standing contract
        </label>

        <div>
          <Label required>Client</Label>
          <Select value={form.clientId} onChange={(e) => setForm((f) => ({ ...f, clientId: e.target.value }))}>
            <option value="">Choose a client…</option>
            {(clients.data?.data ?? []).map((c, i) => (
              <option key={String(c.ClientID ?? i)} value={String(c.ClientID ?? "")}>
                {String(c.ClientName ?? "")}
              </option>
            ))}
          </Select>
        </div>

        <div>
          <Label>Site</Label>
          <Select value={form.unitId} onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))}>
            <option value="">Any / not yet created</option>
            {(units.data?.data ?? [])
              .filter((u) => !form.clientId || String(u.ClientID) === form.clientId)
              .map((u, i) => (
                <option key={String(u.UnitID ?? i)} value={String(u.UnitID ?? "")}>
                  {String(u.UnitName ?? "")}
                </option>
              ))}
          </Select>
        </div>

        {temporary ? (
          <div className="md:col-span-2">
            <Label required>Event</Label>
            <Input value={form.eventName} onChange={(e) => setForm((f) => ({ ...f, eventName: e.target.value }))} />
          </div>
        ) : null}

        <div>
          <Label required>{temporary ? "Starts" : "From"}</Label>
          <Input type="date" value={form.startDate} onChange={(e) => setForm((f) => ({ ...f, startDate: e.target.value }))} />
        </div>
        <div>
          <Label required={temporary}>{temporary ? "Ends" : "Expires"}</Label>
          <Input type="date" value={form.endDate} onChange={(e) => setForm((f) => ({ ...f, endDate: e.target.value }))} />
        </div>

        <div>
          <Label required>Guards</Label>
          <Input
            inputMode="numeric"
            value={form.guardNos}
            onChange={(e) => setForm((f) => ({ ...f, guardNos: e.target.value.replace(/\D/g, "") }))}
          />
        </div>
        <div>
          <Label required>Rate per guard</Label>
          <Input
            type="number"
            step="0.01"
            value={form.ratePerGuard}
            onChange={(e) => setForm((f) => ({ ...f, ratePerGuard: e.target.value }))}
          />
        </div>

        <div className="md:col-span-2">
          <Label>Remark</Label>
          <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
        </div>

        <div className="md:col-span-2">
          <Button
            loading={save.isPending}
            disabled={
              !form.clientId ||
              !form.guardNos ||
              !form.ratePerGuard ||
              (temporary && (!form.eventName || !form.endDate))
            }
            onClick={() =>
              save.mutate({
                clientId: Number(form.clientId),
                unitId: form.unitId ? Number(form.unitId) : undefined,
                startDate: form.startDate,
                endDate: form.endDate || undefined,
                guardNos: Number(form.guardNos),
                ratePerGuard: Number(form.ratePerGuard),
                eventName: temporary ? form.eventName : undefined,
                remark: form.remark || undefined,
              })
            }
          >
            {temporary ? "Record event" : "Save contract"}
          </Button>
        </div>
      </Card>
    </div>
  );
}
