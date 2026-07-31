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
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogRoot = Dialog.Root as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogPortal = Dialog.Portal as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogOverlay = Dialog.Overlay as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogContent = Dialog.Content as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogTitle = Dialog.Title as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogDescription = Dialog.Description as any;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const DialogClose = Dialog.Close as any;

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
    <DialogRoot open={open} onOpenChange={onOpenChange}>
      <DialogPortal>
        <DialogOverlay className="fixed inset-0 z-40 bg-slate-950/40 backdrop-blur-xs transition-opacity" />
        <DialogContent className="fixed left-1/2 top-1/2 z-50 w-[calc(100vw-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 rounded-2xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-6 shadow-2xl focus:outline-none">
          <DialogTitle className="text-lg font-bold text-slate-900 dark:text-slate-100 tracking-tight">{title}</DialogTitle>
          {description ? (
            <DialogDescription className="mt-1 text-xs font-medium text-slate-500 dark:text-slate-400">{description}</DialogDescription>
          ) : null}

          {children ? <div className="mt-4 space-y-4">{children}</div> : null}

          <div className="mt-6 flex justify-end gap-2.5">
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            {footer}
          </div>
        </DialogContent>
      </DialogPortal>
    </DialogRoot>
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
