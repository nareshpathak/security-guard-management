"use client";

import { useMemo } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Input } from "@diti365/ui";

export function useListQueryState() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const state = useMemo(
    () => ({
      page: Number(searchParams.get("page") ?? "1") || 1,
      pageSize: Number(searchParams.get("pageSize") ?? "50") || 50,
      search: searchParams.get("search") ?? "",
      status: searchParams.get("status") ?? "",
      // Date range, as yyyy-MM-dd. The API's PagedQuery binds these to DateOnly,
      // so anything else comes back as a 400 rather than being silently ignored.
      from: searchParams.get("from") ?? undefined,
      to: searchParams.get("to") ?? undefined,
      unitId: searchParams.get("unitId") ? Number(searchParams.get("unitId")) : undefined,
      branchId: searchParams.get("branchId") ? Number(searchParams.get("branchId")) : undefined,
      clientId: searchParams.get("clientId") ? Number(searchParams.get("clientId")) : undefined,
      empId: searchParams.get("empId") ? Number(searchParams.get("empId")) : undefined,
      sortBy: searchParams.get("sortBy") ?? undefined,
      sortDir: (searchParams.get("sortDir") as "asc" | "desc" | null) ?? undefined,
    }),
    [searchParams],
  );

  function setParams(patch: Record<string, string | number | undefined | null>) {
    const next = new URLSearchParams(searchParams.toString());
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined || v === null || v === "") next.delete(k);
      else next.set(k, String(v));
    }
    router.push(`${pathname}?${next.toString()}`);
  }

  return { ...state, setParams };
}

export function SearchField({
  value,
  onChange,
  placeholder = "Search…",
}: {
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
}) {
  return (
    <Input
      value={value}
      placeholder={placeholder}
      onChange={(e) => onChange(e.target.value)}
      className="max-w-xs"
    />
  );
}

export function cell(row: Record<string, unknown>, ...keys: string[]) {
  for (const key of keys) {
    const value = row[key];
    if (value !== undefined && value !== null && value !== "") return String(value);
  }
  return "—";
}
