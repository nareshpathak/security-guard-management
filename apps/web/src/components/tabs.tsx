"use client";

import { Button } from "@diti365/ui";
import { useListQueryState } from "@/lib/list-query";

/**
 * URL-driven tabs. The active tab lives in the query string so a tab is
 * shareable and the back button works, which is the rule for every list in
 * this app.
 */
export function Tabs<T extends string>({
  param = "tab",
  value,
  options,
  defaultValue,
}: {
  param?: string;
  value: T;
  options: { id: T; label: string; badge?: number }[];
  /** The tab that needs no query string at all. */
  defaultValue: T;
}) {
  const q = useListQueryState();

  return (
    <div role="tablist" className="flex flex-wrap gap-2">
      {options.map((o) => (
        <Button
          key={o.id}
          role="tab"
          aria-selected={value === o.id}
          size="sm"
          variant={value === o.id ? "primary" : "outline"}
          onClick={() => q.setParams({ [param]: o.id === defaultValue ? undefined : o.id, page: 1 })}
        >
          {o.label}
          {o.badge ? (
            <span className="ml-1 rounded-full bg-black/10 px-1.5 text-[11px] dark:bg-white/15">
              {o.badge}
            </span>
          ) : null}
        </Button>
      ))}
    </div>
  );
}
