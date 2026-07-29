"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { dateTime } from "@/lib/format";

export default function GatePassPage() {
  return (
    <ResourceList
      title="Gate passes"
      description="Material and visitors leaving a site, and whether they have actually left."
      path="/api/v2/gate-passes"
      queryKey="gate-passes"
      searchPlaceholder="Name, mobile or material…"
      rowKey={(r, i) => String(r.GatePassID ?? i)}
      emptyTitle="No gate passes"
      emptyDescription="A gate pass is raised at the site when material or a visitor leaves."
      columns={[
        {
          id: "dated",
          header: "Raised",
          cell: (r) => <span className="tabular">{dateTime(r.Dated ?? r.InsertDate)}</span>,
        },
        { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
        {
          id: "person",
          header: "Person",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "Name")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "MobileNo", "Mobile")}</div>
            </div>
          ),
        },
        {
          id: "material",
          header: "Material",
          hideOnMobile: true,
          cell: (r) => cell(r, "Material", "ItemName", "Purpose"),
        },
        {
          id: "exit",
          header: "Exit recorded",
          cell: (r) => {
            const exitAt = r.ExitAt ?? r.ExitTime;
            return exitAt ? (
              <span className="tabular">{dateTime(exitAt)}</span>
            ) : (
              // Still on site is the state that needs attention at shift end.
              <Status value="Still inside" />
            );
          },
        },
        {
          id: "by",
          header: "Authorised by",
          hideOnMobile: true,
          cell: (r) => cell(r, "AuthorisedBy", "ApprovedByName", "EmpFullName"),
        },
      ]}
    />
  );
}
