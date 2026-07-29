"use client";

import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { ago } from "@/lib/format";

export default function UsersPage() {
  return (
    <ResourceList
      title="Users"
      description="Who can sign in, as what role, and when they were last seen."
      path="/api/v2/users"
      queryKey="users"
      searchPlaceholder="Name, login or mobile…"
      rowKey={(r, i) => String(r.UserID ?? i)}
      emptyTitle="No users"
      emptyDescription="Users are created against an employee record and given a role."
      columns={[
        {
          id: "user",
          header: "User",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "Name", "EmpFullName", "UserName")}</div>
              <div className="tabular text-xs text-muted">{cell(r, "UserName", "LoginId")}</div>
            </div>
          ),
        },
        { id: "role", header: "Role", cell: (r) => <Status value={r.RoleName ?? r.RoleCode} /> },
        { id: "branch", header: "Branch", hideOnMobile: true, cell: (r) => cell(r, "BranchName") },
        {
          id: "mobile",
          header: "Mobile",
          hideOnMobile: true,
          cell: (r) => <span className="tabular">{cell(r, "MobileNo", "Mobile1")}</span>,
        },
        {
          id: "seen",
          header: "Last seen",
          cell: (r) => <span className="text-muted">{ago(r.LastLoginAt ?? r.LastLogin)}</span>,
        },
        {
          id: "status",
          header: "Status",
          cell: (r) => (
            <Status
              value={
                r.IsLocked ? "Locked" : r.IsActive === false ? "Inactive" : "Active"
              }
            />
          ),
        },
      ]}
    />
  );
}
