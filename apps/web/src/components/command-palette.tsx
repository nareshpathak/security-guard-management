"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Command } from "cmdk";
import { defaultNav } from "@diti365/ui";

/**
 * Ctrl/Cmd-K to jump anywhere.
 *
 * Destinations come from the same nav definition the sidebar uses, so a screen
 * added to one is reachable from the other without a second list to maintain.
 */
export function CommandPalette() {
  const router = useRouter();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((v) => !v);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  const items = useMemo(
    () => defaultNav.flatMap((g) => g.items.map((i) => ({ ...i, group: g.label }))),
    [],
  );

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center bg-[var(--diti-overlay)] p-4 pt-[15vh]"
      onClick={() => setOpen(false)}
      role="presentation"
    >
      <Command
        label="Jump to"
        className="w-full max-w-lg overflow-hidden rounded-xl border border-border bg-surface shadow-lg"
        onClick={(e) => e.stopPropagation()}
        loop
      >
        <Command.Input
          autoFocus
          placeholder="Jump to a screen…"
          className="w-full border-b border-border bg-transparent px-4 py-3 text-sm text-text outline-none placeholder:text-muted"
        />
        <Command.List className="max-h-80 overflow-y-auto p-2">
          <Command.Empty className="px-3 py-6 text-center text-sm text-muted">
            Nothing matches that.
          </Command.Empty>
          {defaultNav.map((group) => (
            <Command.Group
              key={group.label}
              heading={group.label}
              className="px-2 py-1 text-[11px] font-semibold uppercase tracking-wide text-muted"
            >
              {group.items.map((item) => (
                <Command.Item
                  key={item.href}
                  value={`${group.label} ${item.label}`}
                  onSelect={() => {
                    router.push(item.href);
                    setOpen(false);
                  }}
                  className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-2 text-sm text-text data-[selected=true]:bg-primary-subtle data-[selected=true]:text-primary"
                >
                  <item.icon className="size-4" />
                  {item.label}
                </Command.Item>
              ))}
            </Command.Group>
          ))}
        </Command.List>
      </Command>
      <span className="sr-only" aria-live="polite">
        {items.length} destinations available
      </span>
    </div>
  );
}
