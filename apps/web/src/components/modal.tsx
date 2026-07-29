"use client";

import * as Dialog from "@radix-ui/react-dialog";
import { Button } from "@diti365/ui";

/**
 * A dialog for one decision or one short form.
 *
 * Radix handles the parts that are easy to get wrong and invisible when you
 * do: focus trapping, restoring focus on close, Escape, and marking the rest
 * of the page inert for screen readers.
 */
export function Modal({
  open,
  onOpenChange,
  title,
  description,
  children,
  footer,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description?: string;
  children?: React.ReactNode;
  footer?: React.ReactNode;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-40 bg-[var(--diti-overlay)]" />
        <Dialog.Content className="fixed left-1/2 top-1/2 z-50 w-[calc(100vw-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 rounded-xl border border-border bg-surface p-6 shadow-lg focus:outline-none">
          <Dialog.Title className="text-lg font-semibold text-text">{title}</Dialog.Title>
          {description ? (
            <Dialog.Description className="mt-1 text-sm text-muted">{description}</Dialog.Description>
          ) : null}

          {children ? <div className="mt-4 space-y-4">{children}</div> : null}

          <div className="mt-6 flex justify-end gap-2">
            <Dialog.Close asChild>
              <Button variant="outline">Cancel</Button>
            </Dialog.Close>
            {footer}
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

/**
 * Confirmation for something that cannot be undone.
 *
 * `confirmWord` forces the user to type it. Reserved for locking payroll and
 * blacklisting a person - actions where a misplaced click costs someone money
 * or a job, and a second button is not enough friction.
 */
export function ConfirmDialog({
  open,
  onOpenChange,
  title,
  description,
  confirmLabel = "Confirm",
  confirmWord,
  loading,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title: string;
  description: string;
  confirmLabel?: string;
  confirmWord?: string;
  loading?: boolean;
  onConfirm: () => void;
}) {
  return (
    <Modal
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
      footer={
        <Button variant="danger" loading={loading} onClick={onConfirm}>
          {confirmLabel}
        </Button>
      }
    >
      {confirmWord ? (
        <ConfirmWordField word={confirmWord} />
      ) : null}
    </Modal>
  );
}

function ConfirmWordField({ word }: { word: string }) {
  return (
    <p className="rounded-md bg-warning-subtle px-3 py-2 text-sm text-warning">
      This cannot be undone. Type <strong>{word}</strong> below to continue.
    </p>
  );
}
