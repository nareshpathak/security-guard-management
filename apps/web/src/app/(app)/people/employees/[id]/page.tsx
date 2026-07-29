"use client";

import { useParams, useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import { Button, Card, ErrorState, Input, Label, PageHeader, Select, Skeleton, TextArea } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { Modal } from "@/components/modal";
import { CitySelect, DistrictSelect, MasterSelect, StateSelect } from "@/components/master-select";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { date } from "@/lib/format";

/**
 * The employee 360.
 *
 * `usp_Employee_Get` returns several result sets - core, addresses, family,
 * bank, statutory, verification, gun licence, history - and each has its own
 * save endpoint. One page with tabs keeps them together, because the question
 * "is this guard cleared to work armed" needs the licence and the verification
 * in the same place.
 */
const TABS = [
  "Overview",
  "Address",
  "Family",
  "Bank",
  "Statutory",
  "Verification",
  "Gun licence",
  "History",
] as const;

type Tab = (typeof TABS)[number];

export default function EmployeeDetailPage() {
  const params = useParams<{ id: string }>();
  const id = Number(params.id);
  const router = useRouter();
  const { has } = useAuth();
  const [tab, setTab] = useState<Tab>("Overview");
  const [blacklisting, setBlacklisting] = useState(false);

  const canEdit = has(Perm.employeeEdit);

  const detail = useQuery({
    queryKey: ["employee", id],
    enabled: Number.isFinite(id) && id > 0,
    queryFn: () => getApi().get<Row[][]>(`/api/v2/employees/${id}`),
  });

  const blacklist = useCommand<{ reason: string }>({
    path: `/api/v2/employees/${id}/blacklist`,
    invalidate: ["employee", "employees"],
    successMessage: "Employee blacklisted",
    onDone: () => setBlacklisting(false),
  });

  if (detail.isLoading) return <Skeleton className="h-96" />;
  if (detail.isError)
    return (
      <ErrorState
        message={detail.error instanceof Error ? detail.error.message : "Could not load this employee."}
        onRetry={() => detail.refetch()}
      />
    );

  const sets = detail.data?.data ?? [];
  const core = sets[0]?.[0] ?? {};
  const addresses = sets[1] ?? [];
  const family = sets[2] ?? [];
  const bank = sets[3]?.[0] ?? {};
  const statutory = sets[4]?.[0] ?? {};
  const verification = sets[5]?.[0] ?? {};
  const gunLicence = sets[6]?.[0] ?? {};
  const history = sets[8] ?? sets[7] ?? [];

  return (
    <div>
      <PageHeader
        title={String(core.EmpFullName ?? `Employee ${id}`)}
        description={`${cell(core, "EmpCode")} · ${cell(core, "DesignationName")} · ${cell(core, "UnitName")}`}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/people/employees")}>
              Back
            </Button>
            {canEdit && !core.IsBlacklisted ? (
              <Button variant="danger" onClick={() => setBlacklisting(true)}>
                Blacklist
              </Button>
            ) : null}
          </div>
        }
      />

      {core.IsBlacklisted ? (
        <div
          role="alert"
          className="mb-6 rounded-lg border border-danger/30 bg-danger-subtle px-4 py-3 text-sm text-danger"
        >
          This person is blacklisted and must not be deployed.
        </div>
      ) : null}

      <div role="tablist" className="mb-6 flex flex-wrap gap-2">
        {TABS.map((t) => (
          <Button
            key={t}
            role="tab"
            aria-selected={tab === t}
            size="sm"
            variant={tab === t ? "primary" : "outline"}
            onClick={() => setTab(t)}
          >
            {t}
          </Button>
        ))}
      </div>

      {tab === "Overview" ? <OverviewTab empId={id} core={core} canEdit={canEdit} /> : null}
      {tab === "Address" ? <AddressTab empId={id} addresses={addresses} canEdit={canEdit} /> : null}
      {tab === "Family" ? <FamilyTab empId={id} family={family} canEdit={canEdit} /> : null}
      {tab === "Bank" ? <BankTab empId={id} bank={bank} canEdit={canEdit} /> : null}
      {tab === "Statutory" ? <StatutoryTab empId={id} statutory={statutory} canEdit={canEdit} /> : null}
      {tab === "Verification" ? (
        <VerificationTab empId={id} verification={verification} canEdit={canEdit} />
      ) : null}
      {tab === "Gun licence" ? <GunLicenceTab empId={id} licence={gunLicence} canEdit={canEdit} /> : null}
      {tab === "History" ? <HistoryTab history={history} /> : null}

      <BlacklistDialog
        open={blacklisting}
        onOpenChange={setBlacklisting}
        loading={blacklist.isPending}
        onConfirm={(reason) => blacklist.mutate({ reason })}
      />
    </div>
  );
}

// ---------------------------------------------------------------- overview

function OverviewTab({ empId, core, canEdit }: { empId: number; core: Row; canEdit: boolean }) {
  const [form, setForm] = useState({
    empFullName: String(core.EmpFullName ?? ""),
    fatherName: String(core.FatherName ?? ""),
    mobile1: String(core.Mobile1 ?? ""),
    mobile2: String(core.Mobile2 ?? ""),
    email: String(core.Email ?? ""),
    dateOfBirth: String(core.DateOfBirth ?? "").slice(0, 10),
    bloodGroup: String(core.BloodGroup ?? ""),
    designationId: String(core.DesignationID ?? ""),
  });

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}`,
    method: "patch",
    invalidate: ["employee", "employees"],
    successMessage: "Details saved",
  });

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <Field label="Full name" required disabled={!canEdit} value={form.empFullName} onChange={(v) => setForm((f) => ({ ...f, empFullName: v }))} />
      <Field label="Father's name" disabled={!canEdit} value={form.fatherName} onChange={(v) => setForm((f) => ({ ...f, fatherName: v }))} />
      <Field label="Mobile" disabled={!canEdit} value={form.mobile1} onChange={(v) => setForm((f) => ({ ...f, mobile1: v }))} />
      <Field label="Alternate mobile" disabled={!canEdit} value={form.mobile2} onChange={(v) => setForm((f) => ({ ...f, mobile2: v }))} />
      <Field label="Email" type="email" disabled={!canEdit} value={form.email} onChange={(v) => setForm((f) => ({ ...f, email: v }))} />
      <Field label="Date of birth" type="date" disabled={!canEdit} value={form.dateOfBirth} onChange={(v) => setForm((f) => ({ ...f, dateOfBirth: v }))} />

      <div>
        <Label>Blood group</Label>
        <Select
          value={form.bloodGroup}
          disabled={!canEdit}
          onChange={(e) => setForm((f) => ({ ...f, bloodGroup: e.target.value }))}
        >
          <option value="">Not recorded</option>
          {["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"].map((g) => (
            <option key={g} value={g}>
              {g}
            </option>
          ))}
        </Select>
      </div>

      <MasterSelect
        label="Designation"
        set="designations"
        value={form.designationId}
        onChange={(v) => setForm((f) => ({ ...f, designationId: v }))}
      />

      {canEdit ? (
        <div className="md:col-span-2">
          <Button loading={save.isPending} disabled={!form.empFullName} onClick={() => save.mutate(form)}>
            Save details
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- address

function AddressTab({ empId, addresses, canEdit }: { empId: number; addresses: Row[]; canEdit: boolean }) {
  const [type, setType] = useState<"Permanent" | "Current">("Permanent");
  const [form, setForm] = useState({
    line1: "",
    line2: "",
    stateId: "",
    districtId: "",
    cityId: "",
    pin: "",
  });

  // Re-seed when the tab switches, or the fields keep the other address's values.
  useEffect(() => {
    const existing = addresses.find((a) => String(a.AddressType ?? "") === type) ?? {};
    setForm({
      line1: String(existing.AddressLine1 ?? existing.Address ?? ""),
      line2: String(existing.AddressLine2 ?? ""),
      stateId: String(existing.StateID ?? ""),
      districtId: String(existing.DistrictID ?? ""),
      cityId: String(existing.CityID ?? ""),
      pin: String(existing.Pin ?? ""),
    });
  }, [type, addresses]);

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/addresses/${type}`,
    method: "put",
    invalidate: ["employee"],
    successMessage: `${type} address saved`,
  });

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <div className="flex gap-2 md:col-span-2">
        {(["Permanent", "Current"] as const).map((t) => (
          <Button key={t} size="sm" variant={type === t ? "primary" : "outline"} onClick={() => setType(t)}>
            {t}
          </Button>
        ))}
      </div>

      <Field label="Address line 1" required disabled={!canEdit} value={form.line1} onChange={(v) => setForm((f) => ({ ...f, line1: v }))} />
      <Field label="Address line 2" disabled={!canEdit} value={form.line2} onChange={(v) => setForm((f) => ({ ...f, line2: v }))} />

      <StateSelect value={form.stateId} onChange={(v) => setForm((f) => ({ ...f, stateId: v, districtId: "", cityId: "" }))} />
      <DistrictSelect stateId={form.stateId} value={form.districtId} onChange={(v) => setForm((f) => ({ ...f, districtId: v, cityId: "" }))} />
      <CitySelect districtId={form.districtId} value={form.cityId} onChange={(v) => setForm((f) => ({ ...f, cityId: v }))} />
      <Field label="PIN" disabled={!canEdit} value={form.pin} onChange={(v) => setForm((f) => ({ ...f, pin: v }))} />

      {canEdit ? (
        <div className="md:col-span-2">
          <Button loading={save.isPending} disabled={!form.line1} onClick={() => save.mutate(form)}>
            Save {type.toLowerCase()} address
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- family

function FamilyTab({ empId, family, canEdit }: { empId: number; family: Row[]; canEdit: boolean }) {
  const [adding, setAdding] = useState(false);
  const [form, setForm] = useState({ name: "", relation: "", mobileNo: "", isNominee: false });

  const add = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/family`,
    invalidate: ["employee"],
    successMessage: "Family member added",
    onDone: () => {
      setAdding(false);
      setForm({ name: "", relation: "", mobileNo: "", isNominee: false });
    },
  });

  return (
    <>
      <Card className="mb-4 divide-y divide-border">
        {family.length === 0 ? (
          <p className="py-4 text-sm text-muted">
            Nobody recorded. A nominee matters: it is who gets called, and paid, if something
            happens on duty.
          </p>
        ) : (
          family.map((m, i) => (
            <div key={i} className="flex items-center justify-between gap-4 py-3 first:pt-0 last:pb-0">
              <div>
                <div className="font-medium text-text">{String(m.Name ?? "")}</div>
                <div className="text-xs text-muted">
                  {String(m.Relation ?? "")} · {String(m.MobileNo ?? "—")}
                </div>
              </div>
              {m.IsNominee ? <Status value="Nominee" /> : null}
            </div>
          ))
        )}
      </Card>

      {canEdit ? <Button onClick={() => setAdding(true)}>Add family member</Button> : null}

      <Modal
        open={adding}
        onOpenChange={setAdding}
        title="Add family member"
        footer={
          <Button loading={add.isPending} disabled={!form.name || !form.relation} onClick={() => add.mutate(form)}>
            Add
          </Button>
        }
      >
        <Field label="Name" required value={form.name} onChange={(v) => setForm((f) => ({ ...f, name: v }))} />
        <Field label="Relation" required value={form.relation} onChange={(v) => setForm((f) => ({ ...f, relation: v }))} />
        <Field label="Mobile" value={form.mobileNo} onChange={(v) => setForm((f) => ({ ...f, mobileNo: v }))} />
        <label className="flex items-center gap-2 text-sm text-text">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={form.isNominee}
            onChange={(e) => setForm((f) => ({ ...f, isNominee: e.target.checked }))}
          />
          This person is the nominee
        </label>
      </Modal>
    </>
  );
}

// ---------------------------------------------------------------- bank

function BankTab({ empId, bank, canEdit }: { empId: number; bank: Row; canEdit: boolean }) {
  const [form, setForm] = useState({
    bankName: String(bank.BankName ?? ""),
    branchName: String(bank.BranchName ?? ""),
    accountNo: String(bank.AccountNo ?? ""),
    ifsc: String(bank.IFSC ?? bank.Ifsc ?? ""),
    accountHolder: String(bank.AccountHolder ?? ""),
  });

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/bank`,
    method: "put",
    invalidate: ["employee"],
    successMessage: "Bank details saved",
  });

  // An IFSC is 11 characters with a zero in the fifth position. Checking here
  // costs nothing; the alternative is a failed salary transfer three weeks on.
  const ifscWrong = form.ifsc.length > 0 && !/^[A-Z]{4}0[A-Z0-9]{6}$/.test(form.ifsc.toUpperCase());

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <Field label="Bank" required disabled={!canEdit} value={form.bankName} onChange={(v) => setForm((f) => ({ ...f, bankName: v }))} />
      <Field label="Branch" disabled={!canEdit} value={form.branchName} onChange={(v) => setForm((f) => ({ ...f, branchName: v }))} />
      <Field label="Account holder" disabled={!canEdit} value={form.accountHolder} onChange={(v) => setForm((f) => ({ ...f, accountHolder: v }))} />
      <Field label="Account number" required disabled={!canEdit} value={form.accountNo} onChange={(v) => setForm((f) => ({ ...f, accountNo: v }))} />

      <div>
        <Label required>IFSC</Label>
        <Input
          value={form.ifsc}
          disabled={!canEdit}
          maxLength={11}
          aria-invalid={ifscWrong}
          className={ifscWrong ? "border-danger" : undefined}
          onChange={(e) => setForm((f) => ({ ...f, ifsc: e.target.value.toUpperCase() }))}
        />
        {ifscWrong ? (
          <p className="mt-1 text-xs text-danger">
            An IFSC is 11 characters: four letters, a zero, then six more.
          </p>
        ) : null}
      </div>

      {canEdit ? (
        <div className="md:col-span-2">
          <Button
            loading={save.isPending}
            disabled={!form.bankName || !form.accountNo || ifscWrong}
            onClick={() => save.mutate(form)}
          >
            Save bank details
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- statutory

function StatutoryTab({ empId, statutory, canEdit }: { empId: number; statutory: Row; canEdit: boolean }) {
  const [form, setForm] = useState({
    pfNo: String(statutory.PfNo ?? ""),
    uan: String(statutory.Uan ?? statutory.UAN ?? ""),
    esicNo: String(statutory.EsicNo ?? ""),
    aadhaarNo: String(statutory.AadhaarNo ?? ""),
    panNo: String(statutory.PanNo ?? ""),
    isPfApplicable: statutory.IsPfApplicable !== false,
    isEsicApplicable: statutory.IsEsicApplicable !== false,
  });

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/statutory`,
    method: "put",
    invalidate: ["employee"],
    successMessage: "Statutory details saved",
  });

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <Field label="PF number" disabled={!canEdit} value={form.pfNo} onChange={(v) => setForm((f) => ({ ...f, pfNo: v }))} />
      <Field label="UAN" disabled={!canEdit} value={form.uan} onChange={(v) => setForm((f) => ({ ...f, uan: v }))} />
      <Field label="ESIC number" disabled={!canEdit} value={form.esicNo} onChange={(v) => setForm((f) => ({ ...f, esicNo: v }))} />
      <Field label="Aadhaar" maxLength={12} disabled={!canEdit} value={form.aadhaarNo} onChange={(v) => setForm((f) => ({ ...f, aadhaarNo: v }))} />
      <Field label="PAN" maxLength={10} disabled={!canEdit} value={form.panNo} onChange={(v) => setForm((f) => ({ ...f, panNo: v.toUpperCase() }))} />

      <div className="space-y-2 md:col-span-2">
        <label className="flex items-center gap-2 text-sm text-text">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={form.isPfApplicable}
            disabled={!canEdit}
            onChange={(e) => setForm((f) => ({ ...f, isPfApplicable: e.target.checked }))}
          />
          Provident fund applies
        </label>
        <label className="flex items-center gap-2 text-sm text-text">
          <input
            type="checkbox"
            className="size-4 accent-[var(--diti-primary)]"
            checked={form.isEsicApplicable}
            disabled={!canEdit}
            onChange={(e) => setForm((f) => ({ ...f, isEsicApplicable: e.target.checked }))}
          />
          ESIC applies
        </label>
        <p className="text-xs text-muted">
          These two switches change what payroll deducts. Turning one off for someone who is
          eligible is a statutory problem, not a preference.
        </p>
      </div>

      {canEdit ? (
        <div className="md:col-span-2">
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>
            Save statutory details
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- verification

function VerificationTab({
  empId,
  verification,
  canEdit,
}: {
  empId: number;
  verification: Row;
  canEdit: boolean;
}) {
  const [form, setForm] = useState({
    pvStatus: String(verification.PvStatus ?? verification.Status ?? "Pending"),
    pvDate: String(verification.PvDate ?? "").slice(0, 10),
    pvValidTill: String(verification.PvValidTill ?? "").slice(0, 10),
    policeStation: String(verification.PoliceStation ?? ""),
    remark: String(verification.Remark ?? ""),
  });

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/verification`,
    method: "put",
    invalidate: ["employee"],
    successMessage: "Verification saved",
  });

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      <div>
        <Label required>Police verification</Label>
        <Select
          value={form.pvStatus}
          disabled={!canEdit}
          onChange={(e) => setForm((f) => ({ ...f, pvStatus: e.target.value }))}
        >
          {["Pending", "Applied", "Verified", "Rejected"].map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </Select>
      </div>

      <Field label="Police station" disabled={!canEdit} value={form.policeStation} onChange={(v) => setForm((f) => ({ ...f, policeStation: v }))} />
      <Field label="Verified on" type="date" disabled={!canEdit} value={form.pvDate} onChange={(v) => setForm((f) => ({ ...f, pvDate: v }))} />
      <Field label="Valid till" type="date" disabled={!canEdit} value={form.pvValidTill} onChange={(v) => setForm((f) => ({ ...f, pvValidTill: v }))} />

      <div className="md:col-span-2">
        <Label>Remark</Label>
        <TextArea
          value={form.remark}
          disabled={!canEdit}
          onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))}
        />
      </div>

      {canEdit ? (
        <div className="md:col-span-2">
          <Button loading={save.isPending} onClick={() => save.mutate(form)}>
            Save verification
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- gun licence

function GunLicenceTab({ empId, licence, canEdit }: { empId: number; licence: Row; canEdit: boolean }) {
  const [form, setForm] = useState({
    licenceNo: String(licence.LicenceNo ?? ""),
    issuedBy: String(licence.IssuedBy ?? ""),
    issueDate: String(licence.IssueDate ?? "").slice(0, 10),
    expiryDate: String(licence.ExpiryDate ?? "").slice(0, 10),
    weaponType: String(licence.WeaponType ?? ""),
  });

  const save = useCommand<typeof form>({
    path: `/api/v2/employees/${empId}/gun-licence`,
    method: "put",
    invalidate: ["employee"],
    successMessage: "Gun licence saved",
  });

  const expired = Boolean(form.expiryDate) && new Date(form.expiryDate) < new Date();

  return (
    <Card className="grid gap-4 md:grid-cols-2">
      {expired ? (
        <div role="alert" className="rounded-md bg-danger-subtle px-3 py-2 text-sm text-danger md:col-span-2">
          This licence has expired. An armed guard on an expired licence is a criminal liability
          for the agency, not a paperwork problem.
        </div>
      ) : null}

      <Field label="Licence number" required disabled={!canEdit} value={form.licenceNo} onChange={(v) => setForm((f) => ({ ...f, licenceNo: v }))} />
      <Field label="Weapon type" disabled={!canEdit} value={form.weaponType} onChange={(v) => setForm((f) => ({ ...f, weaponType: v }))} />
      <Field label="Issued by" disabled={!canEdit} value={form.issuedBy} onChange={(v) => setForm((f) => ({ ...f, issuedBy: v }))} />
      <Field label="Issued on" type="date" disabled={!canEdit} value={form.issueDate} onChange={(v) => setForm((f) => ({ ...f, issueDate: v }))} />
      <Field label="Expires" type="date" required disabled={!canEdit} value={form.expiryDate} onChange={(v) => setForm((f) => ({ ...f, expiryDate: v }))} />

      {canEdit ? (
        <div className="md:col-span-2">
          <Button loading={save.isPending} disabled={!form.licenceNo} onClick={() => save.mutate(form)}>
            Save licence
          </Button>
        </div>
      ) : null}
    </Card>
  );
}

// ---------------------------------------------------------------- history

function HistoryTab({ history }: { history: Row[] }) {
  if (history.length === 0)
    return (
      <Card>
        <p className="text-sm text-muted">No recorded changes of status.</p>
      </Card>
    );

  return (
    <Card>
      <ol className="space-y-4 border-l border-border pl-5">
        {history.map((h, i) => (
          <li key={i} className="relative">
            <span className="absolute -left-[23px] top-1.5 size-2 rounded-full bg-primary" />
            <div className="flex items-center gap-2">
              <Status value={h.EventType ?? h.Status} />
              <span className="tabular text-xs text-muted">{date(h.EventDate ?? h.InsertDate)}</span>
            </div>
            {h.Remark ? <p className="mt-1 text-sm text-text">{String(h.Remark)}</p> : null}
          </li>
        ))}
      </ol>
    </Card>
  );
}

// ---------------------------------------------------------------- blacklist

function BlacklistDialog({
  open,
  onOpenChange,
  loading,
  onConfirm,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  loading: boolean;
  onConfirm: (reason: string) => void;
}) {
  const [reason, setReason] = useState("");
  const [typed, setTyped] = useState("");

  return (
    <Modal
      open={open}
      onOpenChange={onOpenChange}
      title="Blacklist this person"
      description="They will be blocked from deployment at every site, across every branch."
      footer={
        <Button
          variant="danger"
          loading={loading}
          disabled={reason.trim().length < 10 || typed !== "BLACKLIST"}
          onClick={() => onConfirm(reason.trim())}
        >
          Blacklist
        </Button>
      }
    >
      <div>
        <Label required>Why</Label>
        <TextArea
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="This is kept permanently and is what a future branch manager will read."
        />
      </div>
      <div>
        <Label required>Type BLACKLIST to confirm</Label>
        <Input value={typed} onChange={(e) => setTyped(e.target.value.toUpperCase())} />
        <p className="mt-1 text-xs text-muted">
          This decision costs someone their livelihood, so it takes more than one click.
        </p>
      </div>
    </Modal>
  );
}

// ---------------------------------------------------------------- shared

function Field({
  label,
  value,
  onChange,
  type = "text",
  required,
  disabled,
  maxLength,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: string;
  required?: boolean;
  disabled?: boolean;
  maxLength?: number;
}) {
  return (
    <div>
      <Label required={required}>{label}</Label>
      <Input
        type={type}
        value={value}
        disabled={disabled}
        maxLength={maxLength}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  );
}
