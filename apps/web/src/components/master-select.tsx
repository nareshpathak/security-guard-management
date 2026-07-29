"use client";

import { useQuery } from "@tanstack/react-query";
import { Label, Select } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";

/**
 * A dropdown backed by reference data.
 *
 * Every one of these used to be a free-text box in the legacy app, which is why
 * the production database has four spellings of "Security Guard". The options
 * come from the masters bootstrap, which is fetched once and cached.
 */
const BOOTSTRAP_INDEX: Record<string, number> = {
  branches: 0,
  designations: 1,
  shifts: 2,
  roles: 3,
  documentTypes: 4,
  complaintTypes: 5,
  incidentTypes: 6,
  leaveTypes: 7,
  itemCategories: 8,
  items: 9,
  salaryHeads: 10,
  taskTypes: 11,
  qualifications: 12,
};

/** Sets that have a dedicated endpoint worth preferring over the bootstrap. */
const DEDICATED: Partial<Record<keyof typeof BOOTSTRAP_INDEX, string>> = {
  designations: "/api/v2/masters/designations",
  qualifications: "/api/v2/masters/qualifications",
};

export function MasterSelect({
  label,
  set,
  value,
  onChange,
  required,
  placeholder = "Choose…",
  idKey,
  nameKey,
}: {
  label: string;
  set: keyof typeof BOOTSTRAP_INDEX;
  value: string;
  onChange: (value: string) => void;
  required?: boolean;
  placeholder?: string;
  /** Override when the column is not the obvious <Thing>ID / <Thing>Name. */
  idKey?: string;
  nameKey?: string;
}) {
  const bootstrap = useQuery({
    queryKey: ["masters-bootstrap"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/masters/bootstrap"),
    staleTime: 10 * 60 * 1000,
    enabled: !DEDICATED[set],
  });

  /*  Designations and qualifications have their own endpoints and are the two
      lists a tenant actually edits, so they are read fresh rather than from the
      ten-minute bootstrap cache. Somebody adding a designation and not seeing
      it in the next dropdown concludes the save failed.  */
  const dedicated = useQuery({
    queryKey: ["masters", set],
    queryFn: () => getApi().get<Row[]>(DEDICATED[set]!),
    staleTime: 60_000,
    enabled: Boolean(DEDICATED[set]),
  });

  const rows = DEDICATED[set]
    ? (dedicated.data?.data ?? [])
    : (bootstrap.data?.data?.[BOOTSTRAP_INDEX[set]] ?? []);

  const loading = DEDICATED[set] ? dedicated.isLoading : bootstrap.isLoading;

  // Work out the id and name columns from the first row rather than hard-coding
  // thirteen pairs: every master follows <Thing>ID / <Thing>Name.
  const first = rows[0] ?? {};
  const id = idKey ?? Object.keys(first).find((k) => /ID$/i.test(k)) ?? "Id";
  const name = nameKey ?? Object.keys(first).find((k) => /Name$/i.test(k)) ?? "Name";

  return (
    <div>
      <Label required={required}>{label}</Label>
      <Select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        disabled={loading}
        aria-busy={loading}
      >
        <option value="">{loading ? "Loading…" : placeholder}</option>
        {rows.map((r, i) => (
          <option key={String(r[id] ?? i)} value={String(r[id] ?? "")}>
            {String(r[name] ?? "")}
          </option>
        ))}
      </Select>
    </div>
  );
}

/**
 * States, districts and cities are a three-level cascade served by their own
 * endpoints rather than the bootstrap, because there are thousands of cities
 * and nobody needs them all on every page load.
 */
export function StateSelect({
  label = "State",
  value,
  onChange,
  required,
}: {
  label?: string;
  value: string;
  onChange: (value: string) => void;
  required?: boolean;
}) {
  const states = useQuery({
    queryKey: ["masters-states"],
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/states"),
    staleTime: Infinity,
  });

  return (
    <div>
      <Label required={required}>{label}</Label>
      <Select value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Choose a state…</option>
        {(states.data?.data ?? []).map((s, i) => (
          <option key={String(s.StateID ?? i)} value={String(s.StateID ?? "")}>
            {String(s.StateName ?? "")}
          </option>
        ))}
      </Select>
    </div>
  );
}

export function DistrictSelect({
  stateId,
  value,
  onChange,
}: {
  stateId: string;
  value: string;
  onChange: (value: string) => void;
}) {
  const districts = useQuery({
    queryKey: ["masters-districts", stateId],
    enabled: Boolean(stateId),
    queryFn: () => getApi().get<Row[]>(`/api/v2/masters/districts/${stateId}`),
    staleTime: Infinity,
  });

  return (
    <div>
      <Label>District</Label>
      <Select value={value} onChange={(e) => onChange(e.target.value)} disabled={!stateId}>
        <option value="">{stateId ? "Choose a district…" : "Pick a state first"}</option>
        {(districts.data?.data ?? []).map((d, i) => (
          <option key={String(d.DistrictID ?? i)} value={String(d.DistrictID ?? "")}>
            {String(d.DistrictName ?? "")}
          </option>
        ))}
      </Select>
    </div>
  );
}

export function CitySelect({
  districtId,
  value,
  onChange,
}: {
  districtId: string;
  value: string;
  onChange: (value: string) => void;
}) {
  const cities = useQuery({
    queryKey: ["masters-cities", districtId],
    enabled: Boolean(districtId),
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/cities", { districtId }),
    staleTime: Infinity,
  });

  return (
    <div>
      <Label>City</Label>
      <Select value={value} onChange={(e) => onChange(e.target.value)} disabled={!districtId}>
        <option value="">{districtId ? "Choose a city…" : "Pick a district first"}</option>
        {(cities.data?.data ?? []).map((c, i) => (
          <option key={String(c.CityID ?? i)} value={String(c.CityID ?? "")}>
            {String(c.CityName ?? "")}
          </option>
        ))}
      </Select>
    </div>
  );
}
