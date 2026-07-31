"use client";

import { useRef } from "react";
import { Button } from "@diti365/ui";
import { date, dateTime, money } from "@/lib/format";
import {
  Shield,
  ShieldCheck,
  Phone,
  Mail,
  Globe,
  MapPin,
  Calendar,
  Clock,
  User,
  Building,
  IdCard,
  FileText,
  ClipboardList,
  Sun,
  Moon,
  CheckCircle2,
  Lock,
} from "lucide-react";

export type ReportFilterMeta = {
  from?: string;
  to?: string;
  client?: string;
  site?: string;
  branch?: string;
  employee?: string;
  status?: string;
};

export type PrintDocumentProps = {
  title: string;
  subtitle?: string;
  filters?: ReportFilterMeta;
  summaryItems?: { label: string; value: string | number }[];
  columns?: { key: string; label: string; align?: "left" | "center" | "right"; icon?: string }[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  rows?: any[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  totals?: Record<string, any>;
  children?: React.ReactNode;
};

/**
 * Premium A4 Print Preview Modal
 */
export function PrintModal({
  open,
  onClose,
  title,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: React.ReactNode;
}) {
  const contentRef = useRef<HTMLDivElement>(null);

  if (!open) return null;

  const handlePrint = () => {
    window.print();
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4 sm:p-6 backdrop-blur-md print:static print:p-0 print:bg-transparent">
      <div className="flex h-[92vh] w-full max-w-6xl flex-col rounded-2xl border border-slate-700/60 bg-slate-900 shadow-2xl overflow-hidden print:static print:h-auto print:max-w-none print:border-none print:shadow-none print:bg-transparent print:rounded-none">
        {/* Modal Top Action Bar (Hidden during Print) */}
        <div className="flex items-center justify-between border-b border-slate-800 px-6 py-4 bg-slate-900/90 text-white shrink-0 no-print print:hidden">
          <div className="flex items-center gap-3">
            <div className="flex size-9 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-600 to-blue-600 text-white shadow-md">
              <Shield className="size-5" />
            </div>
            <div>
              <h2 className="text-sm font-extrabold text-white tracking-tight">{title}</h2>
              <p className="text-xs text-slate-400 font-medium">Executive A4 Print & PDF Document Preview</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" size="sm" onClick={onClose} className="text-slate-200 border-slate-700 hover:bg-slate-800">
              Close
            </Button>
            <Button variant="primary" size="sm" onClick={handlePrint} className="bg-indigo-600 hover:bg-indigo-700 text-white shadow-md shadow-indigo-600/30">
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print / Save as PDF
            </Button>
          </div>
        </div>

        {/* Scrollable Document Container (Unconstrained during Print) */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-8 bg-slate-950 flex justify-center print:static print:p-0 print:bg-white print:overflow-visible">
          <div
            ref={contentRef}
            className="w-full max-w-[210mm] min-h-[297mm] bg-white text-slate-900 p-8 shadow-2xl rounded-xl font-sans text-xs print:static print:p-0 print:shadow-none print:w-full print:max-w-none print:min-h-0 print:rounded-none print:bg-white relative"
          >
            {children}
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * DITI365 Ultra-Premium Corporate Letterhead Header
 */
export function ReportCorporateHeader() {
  return (
    <div className="relative mb-7 pb-5 select-none no-break">
      {/* Top-Left Architectural Folded Geometric Artwork */}
      <div className="absolute -top-8 -left-8 w-28 h-28 pointer-events-none overflow-hidden z-10">
        <svg className="size-full" viewBox="0 0 120 120" fill="none">
          <path d="M0 0 H120 L0 120 Z" fill="url(#cornerGradMain)" />
          <path d="M0 0 H85 L0 85 Z" fill="url(#cornerGradAccent)" opacity="0.85" />
          <path d="M0 80 L80 0 L84 0 L0 84 Z" fill="#fbbf24" opacity="0.9" />
          <defs>
            <linearGradient id="cornerGradMain" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#0f172a" />
              <stop offset="40%" stopColor="#1e1b4b" />
              <stop offset="80%" stopColor="#312e81" />
              <stop offset="100%" stopColor="#4338ca" />
            </linearGradient>
            <linearGradient id="cornerGradAccent" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#1e1b4b" />
              <stop offset="100%" stopColor="#2563eb" />
            </linearGradient>
          </defs>
        </svg>
      </div>

      {/* Top-Right Pinned Gold-Edged Bookmark Ribbon Badge */}
      <div
        className="absolute -top-8 right-5 w-16 h-28 bg-gradient-to-b from-[#0f172a] via-[#1e1b4b] to-[#312e81] text-white shadow-2xl z-20 flex flex-col items-center justify-between pt-3.5 pb-4 rounded-b-sm border-x-2 border-amber-400/80"
        style={{ clipPath: "polygon(0 0, 100% 0, 100% 100%, 50% 88%, 0 100%)" }}
      >
        <div className="flex size-8 items-center justify-center rounded-full bg-gradient-to-br from-amber-300 via-amber-400 to-amber-500 text-[#0f172a] shadow-md border border-white">
          <ShieldCheck className="size-4 text-[#0f172a] stroke-[2.5]" />
        </div>
        <div className="text-[8px] font-black uppercase tracking-widest text-center leading-tight space-y-0.5 text-amber-200">
          <div>TRUST</div>
          <div className="text-white">SECURITY</div>
          <div>EXCELLENCE</div>
        </div>
      </div>

      {/* Main Header Row */}
      <div className="flex items-start justify-between pr-24 pt-1">
        {/* Left Company Branding & Emblem */}
        <div className="flex items-center gap-4">
          <div className="relative flex size-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-[#0f172a] via-[#1e1b4b] to-[#312e81] text-white shadow-xl border-2 border-amber-400/70 p-1">
            <div className="flex size-full flex-col items-center justify-center rounded-xl bg-gradient-to-br from-[#1e1b4b] to-[#4338ca] text-center">
              <Shield className="size-4 text-amber-400 mb-0.5" />
              <div className="text-[12px] font-black tracking-tighter text-white leading-none">D365</div>
            </div>
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-2xl font-black tracking-tight text-[#0f172a] uppercase leading-none">
                DITI365 SECURITY OPERATIONS
              </h1>
            </div>
            <div className="h-0.5 w-24 bg-gradient-to-r from-amber-400 via-indigo-600 to-transparent my-1.5 rounded-full" />
            <p className="text-[11px] font-extrabold text-slate-600 uppercase tracking-widest">
              Enterprise Security & Facility Management OS
            </p>
          </div>
        </div>

        {/* Right Contact Info Block */}
        <div className="text-right space-y-1 text-[10.5px] text-slate-700 font-semibold">
          <div className="inline-flex items-center gap-1.5 rounded-md bg-slate-100/90 px-2 py-0.5">
            <Phone className="size-3 text-indigo-600 shrink-0" />
            <span className="tabular-nums">+91 12345 67890</span>
          </div>
          <div className="flex items-center justify-end gap-1.5">
            <Mail className="size-3 text-indigo-600 shrink-0" />
            <span>info@diti365.com</span>
          </div>
          <div className="flex items-center justify-end gap-1.5">
            <Globe className="size-3 text-indigo-600 shrink-0" />
            <span>www.diti365.com</span>
          </div>
          <div className="inline-flex items-center gap-1.5 rounded-md bg-amber-50 px-2.5 py-0.5 text-amber-900 font-extrabold border border-amber-300/60 shadow-2xs">
            <MapPin className="size-3 text-amber-600 shrink-0" />
            <span>Secure Today, Safer Tomorrow</span>
          </div>
        </div>
      </div>

      {/* Double Premium Divider Rule Line */}
      <div className="mt-4 space-y-0.5">
        <div className="h-1 w-full rounded-full bg-gradient-to-r from-[#0f172a] via-amber-400 to-[#312e81]" />
        <div className="h-0.5 w-full bg-slate-200" />
      </div>
    </div>
  );
}

/**
 * Dynamic Report Title & Metadata Block
 */
export function ReportTitleBlock({
  title,
  subtitle = "Executive A4 Print & PDF Document",
  filters,
}: {
  title: string;
  subtitle?: string;
  filters?: ReportFilterMeta;
}) {
  const generatedAt = dateTime(new Date());

  return (
    <div className="mb-5 space-y-3">
      <div className="flex items-center justify-between gap-4">
        {/* Title + Icon */}
        <div className="flex items-center gap-3">
          <div className="flex size-10 shrink-0 items-center justify-center rounded-xl bg-indigo-50 dark:bg-indigo-950 text-indigo-700 border border-indigo-200/80 shadow-2xs">
            <ClipboardList className="size-5" />
          </div>
          <div>
            <h2 className="text-base sm:text-lg font-black tracking-tight text-[#1e1b4b] uppercase leading-tight">
              {title}
            </h2>
            <p className="text-[11px] font-medium text-slate-500">{subtitle}</p>
          </div>
        </div>

        {/* Right Metadata Card */}
        <div className="rounded-xl border border-slate-200 bg-slate-50/80 px-3.5 py-2 text-right shadow-2xs shrink-0">
          <div className="flex items-center justify-end gap-1.5 text-[10px] font-bold uppercase tracking-wider text-slate-500">
            <Calendar className="size-3 text-indigo-600" />
            <span>Generated On</span>
          </div>
          <div className="mt-0.5 text-xs font-extrabold text-slate-900 tabular-nums">
            {generatedAt}
          </div>
        </div>
      </div>

      {/* Active Filters Metadata Bar */}
      {filters && Object.keys(filters).some((k) => !!filters[k as keyof ReportFilterMeta]) ? (
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5 rounded-lg border border-slate-200 bg-slate-50/60 px-3.5 py-2 text-[11px] text-slate-700">
          {filters.from || filters.to ? (
            <div>
              <span className="font-semibold text-slate-500">Period: </span>
              <strong className="font-bold text-slate-900">{date(filters.from)} to {date(filters.to)}</strong>
            </div>
          ) : null}
          {filters.branch ? (
            <div>
              <span className="font-semibold text-slate-500">Branch: </span>
              <strong className="font-bold text-slate-900">{filters.branch}</strong>
            </div>
          ) : null}
          {filters.client ? (
            <div>
              <span className="font-semibold text-slate-500">Client: </span>
              <strong className="font-bold text-slate-900">{filters.client}</strong>
            </div>
          ) : null}
          {filters.site ? (
            <div>
              <span className="font-semibold text-slate-500">Site: </span>
              <strong className="font-bold text-slate-900">{filters.site}</strong>
            </div>
          ) : null}
          {filters.status ? (
            <div>
              <span className="font-semibold text-slate-500">Status: </span>
              <strong className="font-bold text-slate-900">{filters.status}</strong>
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

/**
 * 3-Column Corporate Footer & Bottom Banner Ribbon
 */
export function ReportCorporateFooter() {
  return (
    <div className="mt-8 pt-4 border-t border-slate-200 select-none space-y-4 no-break">
      {/* 3-Column Signatory & System Grid */}
      <div className="grid grid-cols-3 gap-6 text-[10.5px]">
        {/* Left Column: Prepared By */}
        <div className="flex items-start gap-2.5">
          <div className="flex size-7 items-center justify-center rounded-lg bg-indigo-50 text-indigo-700 border border-indigo-200 shrink-0">
            <Shield className="size-4" />
          </div>
          <div>
            <div className="font-bold text-slate-900">Prepared By</div>
            <div className="text-slate-600 font-medium">Diti365 Security Operations</div>
            <div className="text-slate-500 text-[9.5px]">Operations Management Team</div>
          </div>
        </div>

        {/* Center Column: System Generated Document Notice */}
        <div className="flex items-start gap-2.5">
          <div className="flex size-7 items-center justify-center rounded-lg bg-indigo-50 text-indigo-700 border border-indigo-200 shrink-0">
            <CheckCircle2 className="size-4" />
          </div>
          <div>
            <div className="font-bold text-slate-900">System Generated Document</div>
            <div className="text-slate-600 font-medium">This report is system generated</div>
            <div className="text-slate-500 text-[9.5px]">Not for manual use</div>
          </div>
        </div>

        {/* Right Column: Authorised Signatory */}
        <div className="text-right space-y-1">
          <div className="font-bold text-slate-900">Authorised Signatory</div>
          <div className="text-slate-600 font-medium">Diti365 Security Operations</div>
          <div className="text-slate-500 text-[9.5px]">Operations Manager</div>
          {/* Handwritten Signature Asset */}
          <div className="flex justify-end pt-1">
            <svg className="h-7 w-28 text-indigo-900" viewBox="0 0 150 40" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M10 25 C 25 10, 35 35, 50 20 C 65 5, 80 30, 95 15 C 110 35, 120 10, 140 25 M 30 28 L 120 28" />
            </svg>
          </div>
        </div>
      </div>

      {/* Bottom Full-Width Deep Navy/Violet Ribbon Banner */}
      <div className="relative h-9 rounded-lg bg-gradient-to-r from-[#0f172a] via-[#1e1b4b] to-[#312e81] text-white flex items-center justify-between px-8 text-[10px] font-black uppercase tracking-widest shadow-md">
        <span className="text-indigo-200">SECURE TODAY</span>

        {/* Centered Gold Shield Badge */}
        <div className="flex size-7 items-center justify-center rounded-full bg-gradient-to-b from-amber-300 to-amber-500 text-[#1e1b4b] shadow-md border-2 border-white">
          <ShieldCheck className="size-4" />
        </div>

        <span className="text-indigo-200">SAFER TOMORROW</span>
      </div>
    </div>
  );
}

/**
 * Executive Payslip / Salary Statement Layout
 */
export function PayslipPrintTemplate({
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  payslip,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  payslip: any;
}) {
  const basic = Number(payslip.BasicPay ?? payslip.BasicSalary ?? 0);
  const hra = Number(payslip.HRA ?? 0);
  const conveyance = Number(payslip.Conveyance ?? payslip.Allowances ?? 0);
  const otAmount = Number(payslip.OvertimeAmount ?? payslip.OTAmount ?? 0);
  const gross = Number(payslip.GrossSalary ?? payslip.GrossPay ?? basic + hra + conveyance + otAmount);

  const pf = Number(payslip.PFDeduction ?? payslip.PF ?? 0);
  const esi = Number(payslip.ESIDeduction ?? payslip.ESI ?? 0);
  const advance = Number(payslip.AdvanceDeduction ?? payslip.Advance ?? 0);
  const totalDeduction = Number(payslip.TotalDeduction ?? payslip.Deductions ?? pf + esi + advance);

  const netPay = Number(payslip.NetPayable ?? payslip.NetSalary ?? gross - totalDeduction);

  return (
    <div className="print-area space-y-4">
      <ReportCorporateHeader />
      <ReportTitleBlock
        title="PAYSLIP / SALARY STATEMENT"
        subtitle={`For the Period: ${payslip.Month ?? payslip.Period ?? "Current Month"}`}
      />

      {/* Employee Details Header Card */}
      <div className="grid grid-cols-2 gap-4 rounded-xl border border-slate-200 p-4 bg-slate-50/80 shadow-2xs">
        <div className="space-y-1">
          <div className="text-[10px] uppercase font-bold text-slate-400">Employee Profile:</div>
          <div className="text-sm font-extrabold text-slate-900">{payslip.GuardName ?? payslip.EmployeeName ?? "Staff Member"}</div>
          <div className="text-xs text-slate-600 font-medium">Employee ID: <strong className="font-bold text-slate-900 tabular-nums">{payslip.EmpCode ?? payslip.GuardCode ?? "EMP-001"}</strong></div>
          <div className="text-xs text-slate-600 font-medium">Designation: <strong className="font-bold text-slate-900">{payslip.Designation ?? "Security Guard"}</strong></div>
        </div>
        <div className="space-y-1 text-right">
          <div className="text-xs text-slate-600 font-medium">Branch: <strong className="font-bold text-slate-900">{payslip.BranchName ?? "Head Office"}</strong></div>
          <div className="text-xs text-slate-600 font-medium">Bank Account: <strong className="font-bold text-slate-900 tabular-nums">{payslip.BankAccountNo ?? "XXXXXXXX1234"}</strong></div>
          <div className="text-xs text-slate-600 font-medium">PF Number: <strong className="font-bold text-slate-900 tabular-nums">{payslip.PFNumber ?? "PF-98745"}</strong></div>
          <div className="text-xs text-slate-600 font-medium">Present Days: <strong className="font-extrabold text-indigo-700 tabular-nums">{payslip.PresentDays ?? payslip.DaysWorked ?? 30} Days</strong></div>
        </div>
      </div>

      {/* Earnings vs Deductions Table */}
      <div className="grid grid-cols-2 gap-4">
        {/* Earnings Column */}
        <div className="rounded-xl border border-slate-200 overflow-hidden shadow-2xs">
          <div className="bg-gradient-to-r from-[#1e1b4b] to-[#312e81] px-4 py-2.5 text-xs font-bold text-white uppercase tracking-wider">
            Earnings Breakdown
          </div>
          <table className="w-full text-xs">
            <tbody className="divide-y divide-slate-200">
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">Basic Pay</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(basic)}</td>
              </tr>
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">House Rent Allowance (HRA)</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(hra)}</td>
              </tr>
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">Conveyance & Allowances</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(conveyance)}</td>
              </tr>
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">Overtime Pay</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(otAmount)}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr className="bg-slate-50 font-bold border-t border-slate-300">
                <td className="px-4 py-2.5 text-slate-900">Gross Earnings</td>
                <td className="px-4 py-2.5 text-right text-emerald-700 font-extrabold tabular-nums">{money(gross)}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        {/* Deductions Column */}
        <div className="rounded-xl border border-slate-200 overflow-hidden shadow-2xs">
          <div className="bg-gradient-to-r from-red-900 to-red-700 px-4 py-2.5 text-xs font-bold text-white uppercase tracking-wider">
            Deductions Breakdown
          </div>
          <table className="w-full text-xs">
            <tbody className="divide-y divide-slate-200">
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">Provident Fund (PF)</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(pf)}</td>
              </tr>
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">ESI Contribution</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(esi)}</td>
              </tr>
              <tr>
                <td className="px-4 py-2.5 text-slate-600 font-medium">Salary Advance Repayment</td>
                <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(advance)}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr className="bg-slate-50 font-bold border-t border-slate-300">
                <td className="px-4 py-2.5 text-slate-900">Total Deductions</td>
                <td className="px-4 py-2.5 text-right text-red-700 font-extrabold tabular-nums">{money(totalDeduction)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {/* Net Payable Highlight Card */}
      <div className="rounded-xl border-2 border-indigo-600 bg-gradient-to-r from-indigo-50 to-blue-50 p-4 text-center shadow-md">
        <div className="text-xs font-bold uppercase tracking-wider text-indigo-950">Net Salary Payable</div>
        <div className="mt-1 text-3xl font-black text-indigo-700 tabular-nums">{money(netPay)}</div>
        <div className="mt-1 text-[11px] font-semibold text-slate-600 italic">Transferred directly to registered bank account</div>
      </div>

      <ReportCorporateFooter />
    </div>
  );
}

/**
 * Executive Tax Invoice Printable Layout
 */
export function TaxInvoicePrintTemplate({
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  invoice,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  invoice: any;
}) {
  return (
    <div className="print-area space-y-4">
      <ReportCorporateHeader />
      <ReportTitleBlock
        title="TAX INVOICE"
        subtitle={`Invoice No: ${invoice.InvoiceNo ?? "INV-001"}`}
      />

      {/* Client & Billing Info */}
      <div className="grid grid-cols-2 gap-4 rounded-xl border border-slate-200 p-4 bg-slate-50/80 shadow-2xs">
        <div>
          <div className="text-[10px] uppercase font-bold text-slate-400">Billed To:</div>
          <div className="text-sm font-extrabold text-slate-900 mt-0.5">{invoice.ClientName ?? "Client Company"}</div>
          <div className="text-xs text-slate-600 font-medium">{invoice.ClientAddress ?? "Corporate Office Address"}</div>
          <div className="text-xs text-slate-600 font-medium mt-1">GSTIN: <strong className="font-bold text-slate-900 tabular-nums">{invoice.GSTIN ?? "27AAACD1234F1Z5"}</strong></div>
        </div>
        <div className="text-right space-y-1">
          <div className="text-xs text-slate-600 font-medium">Invoice Date: <strong className="font-bold text-slate-900 tabular-nums">{date(invoice.InvoiceDate)}</strong></div>
          <div className="text-xs text-slate-600 font-medium">Due Date: <strong className="font-bold text-red-600 tabular-nums">{date(invoice.DueDate)}</strong></div>
          <div className="text-xs text-slate-600 font-medium">Billing Period: <strong className="font-bold text-slate-900">{invoice.BillingMonth ?? "Current Month"}</strong></div>
        </div>
      </div>

      {/* Particulars Table */}
      <div className="rounded-xl border border-slate-200 overflow-hidden shadow-2xs">
        <table className="w-full text-xs text-left border-collapse">
          <thead className="bg-gradient-to-r from-[#1e1b4b] via-[#3730a3] to-[#4338ca] text-white font-bold uppercase text-[10.5px] tracking-wider">
            <tr>
              <th className="px-4 py-3">Service Description</th>
              <th className="px-4 py-3 text-right">Guards</th>
              <th className="px-4 py-3 text-right">Rate / Shift</th>
              <th className="px-4 py-3 text-right">Total (₹)</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200">
            <tr>
              <td className="px-4 py-3 font-semibold text-slate-900">
                Security Guard Deployment & Facilities Management
                <div className="text-[11px] text-slate-500 font-medium">Site: {invoice.SiteName ?? "Main Campus"}</div>
              </td>
              <td className="px-4 py-3 text-right font-bold text-slate-900 tabular-nums">{invoice.GuardCount ?? 12}</td>
              <td className="px-4 py-3 text-right font-bold text-slate-900 tabular-nums">{money(invoice.RatePerGuard ?? 18000)}</td>
              <td className="px-4 py-3 text-right font-extrabold text-slate-900 tabular-nums">{money(invoice.SubTotal ?? 216000)}</td>
            </tr>
          </tbody>
          <tfoot className="border-t-2 border-slate-300 bg-slate-50 font-bold">
            <tr>
              <td colSpan={3} className="px-4 py-2.5 text-right font-semibold text-slate-600">Subtotal:</td>
              <td className="px-4 py-2.5 text-right font-bold text-slate-900 tabular-nums">{money(invoice.SubTotal ?? 216000)}</td>
            </tr>
            <tr>
              <td colSpan={3} className="px-4 py-2.5 text-right font-semibold text-slate-600">GST (18%):</td>
              <td className="px-4 py-2.5 text-right font-semibold text-slate-900 tabular-nums">{money(invoice.TaxAmount ?? (Number(invoice.SubTotal ?? 216000) * 0.18))}</td>
            </tr>
            <tr className="border-t border-slate-300 bg-indigo-50 text-sm font-black">
              <td colSpan={3} className="px-4 py-3 text-right text-indigo-950 uppercase tracking-wider">Grand Total Payable:</td>
              <td className="px-4 py-3 text-right text-indigo-700 tabular-nums">{money(invoice.GrandTotal ?? (Number(invoice.SubTotal ?? 216000) * 1.18))}</td>
            </tr>
          </tfoot>
        </table>
      </div>

      <ReportCorporateFooter />
    </div>
  );
}

/**
 * Generic Printable Table Layout matching Reference Design
 */
export function GenericReportPrintTemplate({
  title,
  subtitle = "Executive A4 Print & PDF Document",
  filters,
  columns,
  rows,
}: PrintDocumentProps) {
  const safeColumns = columns ?? [];
  const safeRows = rows ?? [];

  return (
    <div className="print-area space-y-4 relative">
      {/* Background Watermark */}
      <div className="absolute inset-0 pointer-events-none flex items-center justify-center opacity-[0.03] select-none z-0">
        <div className="text-center">
          <Shield className="size-96 text-indigo-900 mx-auto" />
          <div className="text-7xl font-black tracking-tighter text-indigo-900 -mt-24">D365</div>
        </div>
      </div>

      <div className="relative z-10 space-y-4">
        <ReportCorporateHeader />
        <ReportTitleBlock title={title} subtitle={subtitle} filters={filters} />

        {safeRows.length > 0 ? (
          <div className="rounded-xl border border-slate-200 overflow-hidden shadow-2xs">
            <table className="w-full text-xs text-left border-collapse">
              <thead className="bg-gradient-to-r from-[#1e1b4b] via-[#3730a3] to-[#4338ca] text-white font-bold uppercase text-[10.5px] tracking-wider">
                <tr>
                  {safeColumns.map((col) => {
                    const isShift = /shift/i.test(col.key);
                    const isGuard = /guard|employee|staff|name/i.test(col.key);
                    const isCode = /code|empcode|id/i.test(col.key);
                    const isSite = /unit|site|client|location/i.test(col.key);
                    const isDate = /date|since|at$/i.test(col.key);

                    return (
                      <th
                        key={col.key}
                        className={`px-3.5 py-3 ${col.align === "right" ? "text-right" : col.align === "center" ? "text-center" : "text-left"}`}
                      >
                        <div className={`inline-flex items-center gap-1.5 ${col.align === "right" ? "justify-end" : col.align === "center" ? "justify-center" : "justify-start"}`}>
                          {isGuard ? <User className="size-3.5 text-indigo-200" /> : null}
                          {isCode ? <IdCard className="size-3.5 text-indigo-200" /> : null}
                          {isSite ? <Building className="size-3.5 text-indigo-200" /> : null}
                          {isShift ? <Clock className="size-3.5 text-indigo-200" /> : null}
                          {isDate ? <Calendar className="size-3.5 text-indigo-200" /> : null}
                          <span>{col.label}</span>
                        </div>
                      </th>
                    );
                  })}
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200/80">
                {safeRows.map((row, idx) => (
                  <tr key={idx} className="transition-colors duration-150 odd:bg-white even:bg-slate-50/60 hover:bg-indigo-50/40">
                    {safeColumns.map((col) => {
                      const val = row[col.key];
                      const isMoney = /amount|total|salary|wage|rate|payable|balance|price/i.test(col.key);
                      const isDate = /date|time|since|at$/i.test(col.key);
                      const isShift = /shift/i.test(col.key);

                      // Semantic Shift Badges
                      if (isShift && val) {
                        const strVal = String(val).toLowerCase();
                        const isDay = strVal.includes("day");
                        return (
                          <td key={col.key} className="px-3.5 py-2.5 text-left align-middle">
                            <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-bold ring-1 ring-inset ${isDay ? "bg-emerald-50 text-emerald-700 ring-emerald-600/30" : "bg-indigo-50 text-indigo-700 ring-indigo-600/30"}`}>
                              {isDay ? <Sun className="size-3 text-emerald-600" /> : <Moon className="size-3 text-indigo-600" />}
                              {String(val)}
                            </span>
                          </td>
                        );
                      }

                      return (
                        <td
                          key={col.key}
                          className={`px-3.5 py-2.5 align-middle text-slate-900 font-semibold ${col.align === "right" ? "text-right tabular-nums" : col.align === "center" ? "text-center" : "text-left"}`}
                        >
                          {val === null || val === undefined || val === ""
                            ? "—"
                            : isMoney
                            ? <span className="tabular-nums font-bold text-slate-900">{money(val)}</span>
                            : isDate
                            ? <span className="inline-flex items-center gap-1 tabular-nums font-medium text-slate-700"><Calendar className="size-3 text-indigo-500 shrink-0" />{date(val)}</span>
                            : String(val)}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="p-8 text-center text-slate-500 font-medium rounded-xl border border-dashed border-slate-300">
            No records found for the selected report filters.
          </div>
        )}

        <ReportCorporateFooter />
      </div>
    </div>
  );
}
