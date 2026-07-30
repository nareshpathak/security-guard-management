"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

export default function RecruitsPage() {
  const q = useListQueryState();
  const { has } = useAuth();
  const [addModal, setAddModal] = useState(false);
  const [convertModal, setConvertModal] = useState(false);
  const [selectedRecruit, setSelectedRecruit] = useState<Row | null>(null);

  const [addForm, setAddForm] = useState({
    name: "",
    mobile: "",
    aadhaar: "",
    oldEmpCode: "",
    designationId: "",
    sourceBy: "",
    remark: "",
  });

  const [convertForm, setConvertForm] = useState({
    doj: isoDate(new Date()),
  });

  const [dupCheckResult, setDupCheckResult] = useState<string | null>(null);

  const recruitsQuery = useQuery({
    queryKey: ["recruits", q.status, q.search, q.page, q.pageSize],
    queryFn: async () =>
      getApi().get<Row[][]>("/api/v2/recruits", {
        status: q.status || undefined,
        search: q.search,
        page: q.page,
        pageSize: q.pageSize,
      }),
  });

  const designationsQuery = useQuery({
    queryKey: ["designations-lookup"],
    queryFn: () => getApi().get<Row[]>("/api/v2/masters/designations"),
    staleTime: 5 * 60 * 1000,
  });

  const addCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/recruits",
    invalidate: ["recruits"],
    successMessage: "Recruit candidate registered successfully",
    onDone: () => {
      setAddModal(false);
      setAddForm({
        name: "",
        mobile: "",
        aadhaar: "",
        oldEmpCode: "",
        designationId: "",
        sourceBy: "",
        remark: "",
      });
      setDupCheckResult(null);
    },
  });

  const statusCmd = useCommand<Record<string, unknown>>({
    path: selectedRecruit ? `/api/v2/recruits/${cell(selectedRecruit, "RecruitID", "RecruitId")}/status` : "",
    invalidate: ["recruits"],
    successMessage: "Recruit status updated successfully",
  });

  const convertCmd = useCommand<Record<string, unknown>>({
    path: selectedRecruit ? `/api/v2/recruits/${cell(selectedRecruit, "RecruitID", "RecruitId")}/convert` : "",
    invalidate: ["recruits", "employees"],
    successMessage: "Recruit converted to active Guard Employee successfully",
    onDone: () => {
      setConvertModal(false);
      setSelectedRecruit(null);
    },
  });

  const checkDuplicate = async (aadhaar?: string, mobile?: string) => {
    if (!aadhaar && !mobile) return;
    try {
      const res = await getApi().get<Row[]>("/api/v2/recruits/check-duplicate", {
        aadhaar: aadhaar || undefined,
        mobile: mobile || undefined,
      });
      if (res.data && res.data.length > 0) {
        const match = res.data[0];
        setDupCheckResult(
          `⚠️ Duplicate match found: ${match.EmpFullName ?? match.Name} (Status: ${match.Status}). ${
            match.IsBlacklisted ? "ALERT: BLACKLISTED!" : ""
          }`
        );
      } else {
        setDupCheckResult("✓ No duplicate candidate found.");
      }
    } catch {
      setDupCheckResult(null);
    }
  };

  const rows = recruitsQuery.data?.data?.[0] ?? [];
  const designations = designationsQuery.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Recruitment & Intake Pipeline"
        description="Candidate registration, duplicate/blacklist screening, selection, and employee conversion."
        actions={
          <div className="flex items-center gap-2">
            {has(Perm.recruitEdit) ? (
              <Button variant="primary" onClick={() => setAddModal(true)}>
                + Register New Recruit
              </Button>
            ) : null}
          </div>
        }
      />

      {/* Filter Tabs */}
      <div className="mb-4 flex flex-wrap items-center gap-2 border-b border-[var(--diti-border)] pb-2">
        {["", "New", "Approved", "Waitlist", "Rejected", "Converted"].map((st) => (
          <Button
            key={st}
            size="sm"
            variant={(q.status ?? "") === st ? "primary" : "ghost"}
            onClick={() => q.setParams({ status: st || undefined, page: 1 })}
          >
            {st || "All Candidates"}
          </Button>
        ))}
      </div>

      {recruitsQuery.isLoading ? <Skeleton className="h-64" /> : null}
      {recruitsQuery.isError ? (
        <ErrorState
          message={
            recruitsQuery.error instanceof Error ? recruitsQuery.error.message : "Failed to load recruits"
          }
          onRetry={() => recruitsQuery.refetch()}
        />
      ) : null}

      {recruitsQuery.data ? (
        <>
          <DataTable
            columns={[
              {
                id: "name",
                header: "Candidate Name",
                cell: (r) => (
                  <div>
                    <div className="font-semibold text-text">{cell(r, "Name", "EmpFullName")}</div>
                    <div className="tabular text-xs text-muted">
                      Source: {cell(r, "SourceBy", "Remark") || "Direct Walk-in"}
                    </div>
                  </div>
                ),
              },
              {
                id: "mobile",
                header: "Mobile",
                cell: (r) => <span className="tabular font-medium">{cell(r, "Mobile", "Mobile1")}</span>,
              },
              {
                id: "aadhaar",
                header: "Aadhaar / ID",
                cell: (r) => <span className="tabular text-xs text-muted">{cell(r, "Aadhaar", "AadhaarNo")}</span>,
              },
              {
                id: "status",
                header: "Status",
                cell: (r) => <StatusPill>{cell(r, "Status", "RecruitStatus")}</StatusPill>,
              },
              {
                id: "actions",
                header: "Actions",
                className: "text-right",
                cell: (r) => {
                  const currentSt = String(r.Status ?? "").toLowerCase();
                  return (
                    <div className="flex items-center justify-end gap-1.5">
                      {has(Perm.recruitApprove) && currentSt !== "approved" && currentSt !== "converted" ? (
                        <Button
                          size="sm"
                          variant="secondary"
                          onClick={() => {
                            setSelectedRecruit(r);
                            statusCmd.mutate({ status: "Approved" });
                          }}
                        >
                          Approve
                        </Button>
                      ) : null}
                      {has(Perm.recruitApprove) && currentSt !== "converted" ? (
                        <Button
                          size="sm"
                          variant="primary"
                          onClick={() => {
                            setSelectedRecruit(r);
                            setConvertModal(true);
                          }}
                        >
                          Convert to Guard
                        </Button>
                      ) : null}
                    </div>
                  );
                },
              },
            ]}
            rows={rows}
            rowKey={(r, i) => String(r.RecruitID ?? r.RecruitId ?? i)}
            empty={
              <EmptyState
                title="No recruit candidates found"
                description="Click Register New Recruit to add intake candidates."
              />
            }
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={recruitsQuery.data.meta?.total ?? rows.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}

      {/* Add Recruit Candidate Modal */}
      <Modal
        open={addModal}
        onOpenChange={setAddModal}
        title="Register Recruit Candidate"
        description="Capture candidate details for background screening and intake."
        footer={
          <Button
            loading={addCmd.isPending}
            disabled={!addForm.name || !addForm.mobile}
            onClick={() =>
              addCmd.mutate({
                name: addForm.name,
                mobile: addForm.mobile || undefined,
                aadhaar: addForm.aadhaar || undefined,
                oldEmpCode: addForm.oldEmpCode || undefined,
                designationId: addForm.designationId ? Number(addForm.designationId) : undefined,
                sourceBy: addForm.sourceBy || undefined,
                remark: addForm.remark || undefined,
              })
            }
          >
            Save Candidate
          </Button>
        }
      >
        <div>
          <Label required>Candidate Full Name</Label>
          <Input
            placeholder="e.g. Rajesh Kumar"
            value={addForm.name}
            onChange={(e) => setAddForm((f) => ({ ...f, name: e.target.value }))}
          />
        </div>
        <div>
          <Label required>Mobile Number</Label>
          <Input
            placeholder="e.g. 9876543210"
            value={addForm.mobile}
            onChange={(e) => setAddForm((f) => ({ ...f, mobile: e.target.value }))}
            onBlur={() => checkDuplicate(addForm.aadhaar, addForm.mobile)}
          />
        </div>
        <div>
          <Label>Aadhaar Number (12 digits)</Label>
          <Input
            placeholder="e.g. 123456789012"
            value={addForm.aadhaar}
            onChange={(e) => setAddForm((f) => ({ ...f, aadhaar: e.target.value }))}
            onBlur={() => checkDuplicate(addForm.aadhaar, addForm.mobile)}
          />
        </div>
        {dupCheckResult ? (
          <div
            className={`p-2.5 rounded-lg text-xs font-medium ${
              dupCheckResult.includes("ALERT")
                ? "bg-rose-500/10 text-rose-600 border border-rose-500/20"
                : dupCheckResult.includes("Duplicate")
                ? "bg-amber-500/10 text-amber-600 border border-amber-500/20"
                : "bg-emerald-500/10 text-emerald-600 border border-emerald-500/20"
            }`}
          >
            {dupCheckResult}
          </div>
        ) : null}
        <div>
          <Label>Target Designation</Label>
          <Select
            value={addForm.designationId}
            onChange={(e) => setAddForm((f) => ({ ...f, designationId: e.target.value }))}
          >
            <option value="">Select Designation...</option>
            {designations.map((d, i) => (
              <option key={String(d.DesignationID ?? d.Id ?? i)} value={String(d.DesignationID ?? d.Id ?? "")}>
                {String(d.DesignationName ?? d.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label>Source / Referral By</Label>
          <Input
            placeholder="e.g. Supervisor Name / Walk-in / Portal"
            value={addForm.sourceBy}
            onChange={(e) => setAddForm((f) => ({ ...f, sourceBy: e.target.value }))}
          />
        </div>
        <div>
          <Label>Remarks</Label>
          <Input
            placeholder="Remarks or initial screening notes"
            value={addForm.remark}
            onChange={(e) => setAddForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Convert Candidate to Active Guard Modal */}
      <Modal
        open={convertModal}
        onOpenChange={setConvertModal}
        title="Convert Candidate to Active Guard"
        description={
          selectedRecruit
            ? `Converting candidate ${cell(selectedRecruit, "Name", "EmpFullName")} into an active employee.`
            : "Convert Candidate"
        }
        footer={
          <Button
            loading={convertCmd.isPending}
            disabled={!selectedRecruit || !convertForm.doj}
            onClick={() =>
              convertCmd.mutate({
                doj: convertForm.doj,
              })
            }
          >
            Confirm Conversion & Issue Guard ID
          </Button>
        }
      >
        <div>
          <Label required>Date of Joining (DOJ)</Label>
          <Input
            type="date"
            value={convertForm.doj}
            onChange={(e) => setConvertForm({ doj: e.target.value })}
          />
        </div>
      </Modal>
    </div>
  );
}
