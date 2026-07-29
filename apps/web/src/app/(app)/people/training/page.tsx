"use client";

import { ResourceList } from "@/components/resource-list";
import { cell } from "@/lib/list-query";
import { count, date, isoDate } from "@/lib/format";

export default function TrainingPage() {
  const yearAgo = new Date();
  yearAgo.setFullYear(yearAgo.getFullYear() - 1);

  return (
    <ResourceList
      title="Training"
      description="Sessions run at each site, and how many attended."
      path="/api/v2/reports/training"
      queryKey="training"
      params={{ from: isoDate(yearAgo), to: isoDate(new Date()) }}
      rowKey={(r, i) => String(r.TrainingID ?? i)}
      emptyTitle="No training recorded"
      emptyDescription="Fire drills, access control and grooming sessions are logged against a site."
      columns={[
        { id: "when", header: "Date", cell: (r) => <span className="tabular">{date(r.Dated)}</span> },
        { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
        { id: "topic", header: "Topic", cell: (r) => cell(r, "Topic") },
        { id: "timing", header: "Timing", hideOnMobile: true, cell: (r) => cell(r, "Timing") },
        {
          id: "nop",
          header: "Attended",
          className: "text-right",
          cell: (r) => <span className="tabular">{count(r.Nop ?? r.AttendeeCount)}</span>,
        },
        {
          id: "remark",
          header: "Notes",
          hideOnMobile: true,
          cell: (r) => <span className="line-clamp-2 max-w-md text-muted">{cell(r, "Remark")}</span>,
        },
      ]}
    />
  );
}
