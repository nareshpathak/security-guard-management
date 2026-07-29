"use client";

import { useAuth } from "@/lib/auth";
import { ResourceList } from "@/components/resource-list";
import { Status } from "@/components/status";
import { cell } from "@/lib/list-query";
import { dateTime } from "@/lib/format";

export default function AuditPage() {
  const { user } = useAuth();

  return (
    <ResourceList
      title="Sign-in log"
      description="Who signed in, from where, and what failed."
      path={`/api/v2/companies/${user?.companyId ?? 0}/logins`}
      queryKey="login-log"
      enabled={Boolean(user?.companyId)}
      rowKey={(r, i) => String(r.LogID ?? i)}
      emptyTitle="No sign-ins recorded"
      emptyDescription="Every successful and failed sign-in is recorded here."
      columns={[
        { id: "at", header: "When", cell: (r) => <span className="tabular">{dateTime(r.LoginAt ?? r.InsertDate)}</span> },
        {
          id: "user",
          header: "User",
          cell: (r) => (
            <div>
              <div className="font-medium text-text">{cell(r, "UserName", "Name")}</div>
              <div className="text-xs text-muted">{cell(r, "RoleCode")}</div>
            </div>
          ),
        },
        { id: "ip", header: "From", hideOnMobile: true, cell: (r) => <span className="tabular text-muted">{cell(r, "IpAddress", "Ip")}</span> },
        { id: "device", header: "Device", hideOnMobile: true, cell: (r) => cell(r, "DeviceModel", "DeviceID", "Platform") },
        {
          id: "result",
          header: "Result",
          cell: (r) => <Status value={r.IsSuccess === false ? "Rejected" : "Approved"} />,
        },
        { id: "out", header: "Signed out", hideOnMobile: true, cell: (r) => <span className="tabular text-muted">{dateTime(r.LogoutAt)}</span> },
      ]}
    />
  );
}
