"use client";

import { useMutation } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { toast } from "sonner";
import { Button, Input, Label, PageHeader } from "@diti365/ui";
import { ApiError, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";

export default function NewClientPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    clientName: "",
    contactPerson: "",
    contactNo: "",
    email: "",
    gstin: "",
    address: "",
  });

  const save = useMutation({
    mutationFn: async () =>
      (
        await getApi().post<SpResult>("/api/v2/clients", {
          clientName: form.clientName.trim(),
          contactPerson: form.contactPerson.trim() || undefined,
          contactNo: form.contactNo.trim() || undefined,
          email: form.email.trim() || undefined,
          gstin: form.gstin.trim().toUpperCase() || undefined,
          address: form.address.trim() || undefined,
        })
      ).data,
    onSuccess: (res) => {
      toast.success(res.message || "Client saved");
      router.push("/clients");
    },
    onError: (err) =>
      toast.error(err instanceof ApiError ? err.message : "Could not save this client."),
  });

  const set = (key: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  // GSTIN is 15 characters. Checking it here saves a round trip; the API and
  // the database check it too, because a browser is never the authority.
  const gstinLooksWrong = form.gstin.length > 0 && form.gstin.length !== 15;
  const canSave = form.clientName.trim().length > 1 && !gstinLooksWrong && !save.isPending;

  return (
    <div className="max-w-2xl">
      <PageHeader
        title="New client"
        description="The organisation you invoice. Sites and posts are created underneath it."
      />

      <form
        className="grid gap-4 rounded-xl border border-border bg-surface p-5 shadow-sm md:grid-cols-2"
        onSubmit={(e) => {
          e.preventDefault();
          if (canSave) save.mutate();
        }}
      >
        <div className="md:col-span-2">
          <Label required>Client name</Label>
          <Input value={form.clientName} onChange={set("clientName")} autoFocus />
        </div>

        <div>
          <Label>Contact person</Label>
          <Input value={form.contactPerson} onChange={set("contactPerson")} />
        </div>

        <div>
          <Label>Contact number</Label>
          <Input value={form.contactNo} onChange={set("contactNo")} inputMode="tel" />
        </div>

        <div>
          <Label>Email</Label>
          <Input value={form.email} onChange={set("email")} type="email" />
        </div>

        <div>
          <Label>GSTIN</Label>
          <Input
            value={form.gstin}
            onChange={set("gstin")}
            maxLength={15}
            className={gstinLooksWrong ? "border-danger" : undefined}
            aria-invalid={gstinLooksWrong}
            aria-describedby={gstinLooksWrong ? "gstin-error" : undefined}
          />
          {gstinLooksWrong ? (
            <p id="gstin-error" className="mt-1 text-xs text-danger">
              A GSTIN is exactly 15 characters. This one has {form.gstin.length}.
            </p>
          ) : null}
        </div>

        <div className="md:col-span-2">
          <Label>Address</Label>
          <Input value={form.address} onChange={set("address")} />
        </div>

        <div className="flex gap-2 md:col-span-2">
          <Button type="submit" loading={save.isPending} disabled={!canSave}>
            Save client
          </Button>
          <Button type="button" variant="outline" onClick={() => router.push("/clients")}>
            Cancel
          </Button>
        </div>
      </form>
    </div>
  );
}
