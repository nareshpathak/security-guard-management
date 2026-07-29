"use client";

import { useState } from "react";
import { Button, Card, Input, Label, PageHeader } from "@diti365/ui";
import { useCommand } from "@/lib/use-command";

/**
 * Changing your own password.
 *
 * The current password is required: an unattended session should not be enough
 * to lock the real owner out of their account.
 */
export default function ChangePasswordPage() {
  const [form, setForm] = useState({ currentPassword: "", newPassword: "", confirm: "" });

  const change = useCommand<{ currentPassword: string; newPassword: string }>({
    path: "/api/v2/auth/password/change",
    successMessage: "Password changed. Other devices have been signed out.",
    onDone: () => setForm({ currentPassword: "", newPassword: "", confirm: "" }),
  });

  const tooShort = form.newPassword.length > 0 && form.newPassword.length < 8;
  const mismatch = form.confirm.length > 0 && form.confirm !== form.newPassword;
  const same = form.newPassword.length > 0 && form.newPassword === form.currentPassword;

  return (
    <div className="max-w-md">
      <PageHeader title="Change password" description="At least 8 characters." />

      <Card className="space-y-4">
        <div>
          <Label required>Current password</Label>
          <Input
            type="password"
            autoComplete="current-password"
            value={form.currentPassword}
            onChange={(e) => setForm((f) => ({ ...f, currentPassword: e.target.value }))}
          />
        </div>

        <div>
          <Label required>New password</Label>
          <Input
            type="password"
            autoComplete="new-password"
            value={form.newPassword}
            aria-invalid={tooShort || same}
            onChange={(e) => setForm((f) => ({ ...f, newPassword: e.target.value }))}
          />
          {tooShort ? (
            <p className="mt-1 text-xs text-danger">
              {8 - form.newPassword.length} more character{8 - form.newPassword.length === 1 ? "" : "s"} needed.
            </p>
          ) : same ? (
            <p className="mt-1 text-xs text-danger">That is your current password.</p>
          ) : null}
        </div>

        <div>
          <Label required>Confirm</Label>
          <Input
            type="password"
            autoComplete="new-password"
            value={form.confirm}
            aria-invalid={mismatch}
            onChange={(e) => setForm((f) => ({ ...f, confirm: e.target.value }))}
          />
          {mismatch ? <p className="mt-1 text-xs text-danger">These do not match.</p> : null}
        </div>

        <Button
          loading={change.isPending}
          disabled={
            !form.currentPassword || form.newPassword.length < 8 || mismatch || same
          }
          onClick={() =>
            change.mutate({ currentPassword: form.currentPassword, newPassword: form.newPassword })
          }
        >
          Change password
        </Button>

        <p className="text-xs text-muted">
          Changing your password signs you out everywhere else, including the phone app.
        </p>
      </Card>
    </div>
  );
}
