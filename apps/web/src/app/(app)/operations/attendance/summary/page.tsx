"use client";

import { useState } from "react";
import { Input, Label } from "@diti365/ui";
import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { count, currentMonth, percent } from "@/lib/format";

/** Attendancesummary_frag: present, absent and half days per employee for a month. */
export default function AttendanceSummaryPage() {
  const [monthYear, setMonthYear] = useState(currentMonth());

  return (
    <ResourceList
      title="Attendance summary"
      description="Days present, absent and half-day for the month, per employee."
      path="/api/v2/attendance/summary"
      queryKey="attendance-summary"
      params={{ monthYear }}
      searchPlaceholder="Employee name or code…"
      rowKey={(r, i) => String(r.EmpID ?? i)}
      emptyTitle="Nothing for this month"
      emptyDescription="Attendance appears here once it has been recorded and approved."
      filters={
        <div>
          <Label>Month</Label>
          <Input type="month" value={monthYear} onChange={(e) => setMonthYear(e.target.value)} />
        </div>
      }
      columns={[
        {
          id: "emp",
          header: "Employee",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "EmpFullName")}</div>
              <div className="tabular text-xs text-muted">
                {cell(r, "EmpCode")} · {cell(r, "UnitName")}
              </div>
            </div>
          ),
        },
        { id: "p", header: "Present", className: "text-right", cell: (r) => <span className="tabular text-success">{count(r.PresentDays)}</span> },
        { id: "a", header: "Absent", className: "text-right", cell: (r) => <span className="tabular text-danger">{count(r.AbsentDays)}</span> },
        { id: "hd", header: "Half day", className: "text-right", hideOnMobile: true, cell: (r) => <span className="tabular text-warning">{count(r.HalfDays)}</span> },
        { id: "wo", header: "Week off", className: "text-right", hideOnMobile: true, cell: (r) => <span className="tabular text-muted">{count(r.WeekOffDays)}</span> },
        { id: "ot", header: "OT hours", className: "text-right", hideOnMobile: true, cell: (r) => <span className="tabular">{count(r.OtHours)}</span> },
        {
          id: "pct",
          header: "Attendance",
          className: "text-right",
          cell: (r) => {
            const present = Number(r.PresentDays ?? 0) + Number(r.HalfDays ?? 0) / 2;
            const working = present + Number(r.AbsentDays ?? 0);
            if (working === 0) return <span className="text-muted">—</span>;
            const pct = (present / working) * 100;
            // Below 90% is where a supervisor should be asking questions.
            return (
              <span className={pct < 90 ? "tabular font-medium text-warning" : "tabular"}>
                {percent(pct)}
              </span>
            );
          },
        },
      ]}
    />
  );
}
