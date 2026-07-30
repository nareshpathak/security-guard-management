"use client";

import { useRef } from "react";
import { Button } from "@diti365/ui";
import { date, dateTime, money } from "@/lib/format";

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
  columns?: { key: string; label: string; align?: "left" | "center" | "right" }[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  rows?: any[];
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  totals?: Record<string, any>;
  children?: React.ReactNode;
};

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
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 sm:p-6 backdrop-blur-xs">
      <div className="flex h-[90vh] w-full max-w-5xl flex-col rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] shadow-2xl overflow-hidden">
        {/* Modal Header */}
        <div className="flex items-center justify-between border-b border-[var(--diti-border)] px-6 py-4 bg-[var(--diti-surface-sunken)] print:hidden">
          <div>
            <h2 className="text-base font-bold text-[var(--diti-text)]">{title}</h2>
            <p className="text-xs text-[var(--diti-muted)]">Executive A4 Print & PDF Document Preview</p>
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" size="sm" onClick={onClose}>
              Close
            </Button>
            <Button variant="primary" size="sm" onClick={handlePrint}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print / Save as PDF
            </Button>
          </div>
        </div>

        {/* Scrollable Document Container */}
        <div className="flex-1 overflow-y-auto p-6 bg-zinc-100 dark:bg-zinc-950 flex justify-center">
          <div
            ref={contentRef}
            className="w-full max-w-[210mm] min-h-[297mm] bg-white text-zinc-900 p-8 shadow-md rounded-sm font-sans text-xs print:p-0 print:shadow-none print:w-full print:max-w-none print:min-h-0"
          >
            {children}
          </div>
        </div>
      </div>

      {/* Print Specific CSS Stylesheet */}
      <style jsx global>{`
        @media print {
          body * {
            visibility: hidden !important;
          }
          .print-area, .print-area * {
            visibility: visible !important;
          }
          .print-area {
            position: absolute !important;
            left: 0 !important;
            top: 0 !important;
            width: 100% !important;
            margin: 0 !important;
            padding: 15mm !important;
            background: white !important;
            color: black !important;
          }
          @page {
            size: A4 portrait;
            margin: 10mm;
          }
        }
      `}</style>
    </div>
  );
}

/**
 * Standard Corporate Header for Reports & Invoices
 */
export function ReportCorporateHeader({
  title,
  subtitle,
  filters,
}: {
  title: string;
  subtitle?: string;
  filters?: ReportFilterMeta;
}) {
  const generatedAt = dateTime(new Date());

  return (
    <div className="border-b-2 border-zinc-900 pb-4 mb-5">
      <div className="flex items-start justify-between">
        <div>
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 font-extrabold text-white text-base tracking-tighter">
              D365
            </div>
            <div>
              <h1 className="text-lg font-black tracking-tight text-zinc-900 uppercase">Diti365 Security Operations</h1>
              <p className="text-[10px] text-zinc-500 font-medium">Enterprise Security & Facility Management OS</p>
            </div>
          </div>
        </div>
        <div className="text-right">
          <h2 className="text-base font-bold text-blue-700 uppercase tracking-wide">{title}</h2>
          {subtitle ? <p className="text-[11px] text-zinc-600 font-normal">{subtitle}</p> : null}
          <div className="mt-1 text-[10px] text-zinc-500">
            Generated: <strong className="font-semibold text-zinc-800">{generatedAt}</strong>
          </div>
        </div>
      </div>

      {/* Active Filters Metadata Bar */}
      {filters && Object.keys(filters).length > 0 ? (
        <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 rounded bg-zinc-100 px-3 py-1.5 text-[11px] text-zinc-700">
          {filters.from || filters.to ? (
            <div>
              <span className="font-semibold text-zinc-500">Period: </span>
              <span className="font-medium text-zinc-900">{date(filters.from)} to {date(filters.to)}</span>
            </div>
          ) : null}
          {filters.branch ? (
            <div>
              <span className="font-semibold text-zinc-500">Branch: </span>
              <span className="font-medium text-zinc-900">{filters.branch}</span>
            </div>
          ) : null}
          {filters.client ? (
            <div>
              <span className="font-semibold text-zinc-500">Client: </span>
              <span className="font-medium text-zinc-900">{filters.client}</span>
            </div>
          ) : null}
          {filters.site ? (
            <div>
              <span className="font-semibold text-zinc-500">Site: </span>
              <span className="font-medium text-zinc-900">{filters.site}</span>
            </div>
          ) : null}
          {filters.status ? (
            <div>
              <span className="font-semibold text-zinc-500">Status: </span>
              <span className="font-medium text-zinc-900">{filters.status}</span>
            </div>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}

/**
 * Standard Corporate Footer for Reports & Invoices
 */
export function ReportCorporateFooter() {
  return (
    <div className="mt-8 border-t border-zinc-300 pt-3 text-[10px] text-zinc-500 flex items-center justify-between print:fixed print:bottom-4 print:left-8 print:right-8">
      <div>
        <span>Diti365 Security Systems · Strictly Confidential Internal Business Document</span>
      </div>
      <div>
        <span>System Generated Report</span>
      </div>
    </div>
  );
}

/**
 * Executive Salary Slip / Payslip Printable Layout
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
      <ReportCorporateHeader
        title="PAYSLIP / SALARY STATEMENT"
        subtitle={`For the Period: ${payslip.Month ?? payslip.Period ?? "Current Month"}`}
      />

      {/* Employee Details Header Card */}
      <div className="grid grid-cols-2 gap-4 rounded-lg border border-zinc-300 p-3.5 bg-zinc-50">
        <div className="space-y-1">
          <div className="text-[11px] text-zinc-500 font-medium">Employee Name:</div>
          <div className="text-sm font-bold text-zinc-900">{payslip.GuardName ?? payslip.EmployeeName ?? "Staff Member"}</div>
          <div className="text-[11px] text-zinc-600">Employee ID: <strong className="font-semibold">{payslip.EmpCode ?? payslip.GuardCode ?? "EMP-001"}</strong></div>
          <div className="text-[11px] text-zinc-600">Designation: <strong className="font-semibold">{payslip.Designation ?? "Security Guard"}</strong></div>
        </div>
        <div className="space-y-1 text-right">
          <div className="text-[11px] text-zinc-600">Branch: <strong className="font-semibold">{payslip.BranchName ?? "Head Office"}</strong></div>
          <div className="text-[11px] text-zinc-600">Bank Account: <strong className="font-semibold">{payslip.BankAccountNo ?? "XXXXXXXX1234"}</strong></div>
          <div className="text-[11px] text-zinc-600">PF Number: <strong className="font-semibold">{payslip.PFNumber ?? "PF-98745"}</strong></div>
          <div className="text-[11px] text-zinc-600">Present Days: <strong className="font-bold text-zinc-900">{payslip.PresentDays ?? payslip.DaysWorked ?? 30} Days</strong></div>
        </div>
      </div>

      {/* Earnings vs Deductions Table */}
      <div className="grid grid-cols-2 gap-4">
        {/* Earnings Column */}
        <div className="rounded-lg border border-zinc-300 overflow-hidden">
          <div className="bg-emerald-50 border-b border-zinc-300 px-3 py-2 text-xs font-bold text-emerald-800 uppercase">
            Earnings
          </div>
          <table className="w-full text-xs">
            <tbody className="divide-y divide-zinc-200">
              <tr>
                <td className="px-3 py-2 text-zinc-600">Basic Pay</td>
                <td className="px-3 py-2 text-right font-medium">{money(basic)}</td>
              </tr>
              <tr>
                <td className="px-3 py-2 text-zinc-600">House Rent Allowance (HRA)</td>
                <td className="px-3 py-2 text-right font-medium">{money(hra)}</td>
              </tr>
              <tr>
                <td className="px-3 py-2 text-zinc-600">Conveyance & Special Allowance</td>
                <td className="px-3 py-2 text-right font-medium">{money(conveyance)}</td>
              </tr>
              <tr>
                <td className="px-3 py-2 text-zinc-600">Overtime Earnings</td>
                <td className="px-3 py-2 text-right font-medium">{money(otAmount)}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr className="bg-zinc-50 font-bold border-t border-zinc-300">
                <td className="px-3 py-2 text-zinc-900">Gross Earnings</td>
                <td className="px-3 py-2 text-right text-emerald-700">{money(gross)}</td>
              </tr>
            </tfoot>
          </table>
        </div>

        {/* Deductions Column */}
        <div className="rounded-lg border border-zinc-300 overflow-hidden">
          <div className="bg-red-50 border-b border-zinc-300 px-3 py-2 text-xs font-bold text-red-800 uppercase">
            Deductions
          </div>
          <table className="w-full text-xs">
            <tbody className="divide-y divide-zinc-200">
              <tr>
                <td className="px-3 py-2 text-zinc-600">Provident Fund (PF)</td>
                <td className="px-3 py-2 text-right font-medium">{money(pf)}</td>
              </tr>
              <tr>
                <td className="px-3 py-2 text-zinc-600">Employee State Insurance (ESI)</td>
                <td className="px-3 py-2 text-right font-medium">{money(esi)}</td>
              </tr>
              <tr>
                <td className="px-3 py-2 text-zinc-600">Salary Advance Repayment</td>
                <td className="px-3 py-2 text-right font-medium">{money(advance)}</td>
              </tr>
            </tbody>
            <tfoot>
              <tr className="bg-zinc-50 font-bold border-t border-zinc-300">
                <td className="px-3 py-2 text-zinc-900">Total Deductions</td>
                <td className="px-3 py-2 text-right text-red-700">{money(totalDeduction)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      {/* Net Payable Highlight Card */}
      <div className="rounded-lg border-2 border-blue-600 bg-blue-50/50 p-4 text-center">
        <div className="text-xs font-bold uppercase tracking-wider text-blue-900">Net Salary Payable</div>
        <div className="mt-1 text-3xl font-black text-blue-700">{money(netPay)}</div>
        <div className="mt-1 text-[11px] font-medium text-zinc-600 italic">Transferred directly to registered bank account</div>
      </div>

      {/* Signatures */}
      <div className="mt-12 grid grid-cols-2 gap-8 pt-8">
        <div className="text-center border-t border-zinc-400 pt-2 text-[11px] text-zinc-600 font-medium">
          Employee Signature
        </div>
        <div className="text-center border-t border-zinc-400 pt-2 text-[11px] text-zinc-600 font-medium">
          Authorized Accounts Signatory
        </div>
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
      <ReportCorporateHeader
        title="TAX INVOICE"
        subtitle={`Invoice No: ${invoice.InvoiceNo ?? "INV-001"}`}
      />

      {/* Client & Billing Info */}
      <div className="grid grid-cols-2 gap-4 rounded-lg border border-zinc-300 p-3.5 bg-zinc-50">
        <div>
          <div className="text-[10px] uppercase font-bold text-zinc-400">Billed To:</div>
          <div className="text-sm font-bold text-zinc-900 mt-1">{invoice.ClientName ?? "Client Company"}</div>
          <div className="text-[11px] text-zinc-600">{invoice.ClientAddress ?? "Corporate Office Address"}</div>
          <div className="text-[11px] text-zinc-600 mt-1">GSTIN: <strong className="font-semibold">{invoice.GSTIN ?? "27AAACD1234F1Z5"}</strong></div>
        </div>
        <div className="text-right space-y-1">
          <div className="text-[11px] text-zinc-600">Invoice Date: <strong className="font-semibold">{date(invoice.InvoiceDate)}</strong></div>
          <div className="text-[11px] text-zinc-600">Due Date: <strong className="font-semibold text-red-600">{date(invoice.DueDate)}</strong></div>
          <div className="text-[11px] text-zinc-600">Billing Period: <strong className="font-semibold">{invoice.BillingMonth ?? "Current Month"}</strong></div>
        </div>
      </div>

      {/* Particulars Table */}
      <div className="rounded-lg border border-zinc-300 overflow-hidden">
        <table className="w-full text-xs text-left border-collapse">
          <thead className="bg-zinc-100 border-b border-zinc-300 font-bold uppercase text-[10px] text-zinc-700">
            <tr>
              <th className="px-3 py-2">Service Description</th>
              <th className="px-3 py-2 text-right">Guards</th>
              <th className="px-3 py-2 text-right">Rate / Shift</th>
              <th className="px-3 py-2 text-right">Total (₹)</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-zinc-200">
            <tr>
              <td className="px-3 py-2.5 font-medium text-zinc-900">
                Security Guard Deployment & Facilities Management
                <div className="text-[10px] text-zinc-500 font-normal">Site: {invoice.SiteName ?? "Main Campus"}</div>
              </td>
              <td className="px-3 py-2.5 text-right font-medium">{invoice.GuardCount ?? 12}</td>
              <td className="px-3 py-2.5 text-right font-medium">{money(invoice.RatePerGuard ?? 18000)}</td>
              <td className="px-3 py-2.5 text-right font-bold text-zinc-900">{money(invoice.SubTotal ?? 216000)}</td>
            </tr>
          </tbody>
          <tfoot className="border-t-2 border-zinc-300 bg-zinc-50">
            <tr>
              <td colSpan={3} className="px-3 py-2 text-right font-semibold text-zinc-600">Subtotal:</td>
              <td className="px-3 py-2 text-right font-bold text-zinc-900">{money(invoice.SubTotal ?? 216000)}</td>
            </tr>
            <tr>
              <td colSpan={3} className="px-3 py-2 text-right font-semibold text-zinc-600">GST (18%):</td>
              <td className="px-3 py-2 text-right font-semibold text-zinc-900">{money(invoice.TaxAmount ?? (Number(invoice.SubTotal ?? 216000) * 0.18))}</td>
            </tr>
            <tr className="border-t border-zinc-300 bg-blue-50 text-sm font-black">
              <td colSpan={3} className="px-3 py-2.5 text-right text-blue-900 uppercase">Grand Total Payable:</td>
              <td className="px-3 py-2.5 text-right text-blue-700">{money(invoice.GrandTotal ?? (Number(invoice.SubTotal ?? 216000) * 1.18))}</td>
            </tr>
          </tfoot>
        </table>
      </div>

      <ReportCorporateFooter />
    </div>
  );
}

/**
 * Generic Printable Table Layout for Operational Reports
 */
export function GenericReportPrintTemplate({
  title,
  subtitle,
  filters,
  columns,
  rows,
}: PrintDocumentProps) {
  const safeColumns = columns ?? [];
  const safeRows = rows ?? [];

  return (
    <div className="print-area space-y-4">
      <ReportCorporateHeader title={title} subtitle={subtitle} filters={filters} />

      {safeRows.length > 0 ? (
        <div className="rounded border border-zinc-300 overflow-hidden">
          <table className="w-full text-[11px] text-left border-collapse">
            <thead className="bg-zinc-100 border-b border-zinc-300 font-bold uppercase text-[10px] text-zinc-700">
              <tr>
                {safeColumns.map((col) => (
                  <th
                    key={col.key}
                    className={`px-3 py-2 ${col.align === "right" ? "text-right" : col.align === "center" ? "text-center" : "text-left"}`}
                  >
                    {col.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-zinc-200">
              {safeRows.map((row, idx) => (
                <tr key={idx} className="hover:bg-zinc-50">
                  {safeColumns.map((col) => {
                    const val = row[col.key];
                    const isMoney = /amount|total|salary|wage|rate|payable|balance|price/i.test(col.key);
                    const isDate = /date|time|at$/i.test(col.key);
                    return (
                      <td
                        key={col.key}
                        className={`px-3 py-2 ${col.align === "right" ? "text-right" : col.align === "center" ? "text-center" : "text-left"}`}
                      >
                        {val === null || val === undefined
                          ? "—"
                          : isMoney
                          ? money(val)
                          : isDate
                          ? date(val)
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
        <div className="p-8 text-center text-zinc-500 font-medium">No records found for the selected period.</div>
      )}

      <ReportCorporateFooter />
    </div>
  );
}
