"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  Building2,
  FileText,
  LayoutDashboard,
  LogOut,
  Menu,
  Moon,
  Receipt,
  Shield,
  Sun,
  Users,
  Wallet,
  X,
  MapPin,
  UserPlus,
  CalendarCheck2,
  DoorOpen,
  ListTodo,
  QrCode,
  MessageSquareWarning,
  HandCoins,
  Briefcase,
  Radar,
  AlertTriangle,
  GraduationCap,
  LogIn,
  Package,
  ScrollText,
  ShieldCheck,
  Database,
  TrendingUp,
  CalendarClock,
  Hourglass,
  ClipboardList,
  NotebookPen,
  Handshake,
  PackageOpen,
  Building,
  KeyRound,
  LineChart,
  MessageCircle,
  CheckCheck,
  ArrowLeftRight,
  Truck,
  Lock,
  IdCard,
  Route as RouteIcon,
} from "lucide-react";
import { cn } from "./cn";
import { Button } from "./button";

export type NavItem = {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  /**
   * Permission code required to see this entry. The API checks the same code,
   * so hiding the link is a courtesy rather than the control.
   */
  permission?: string;
};

export type NavGroup = {
  label: string;
  items: NavItem[];
};

export const defaultNav: NavGroup[] = [
  {
    label: "Overview",
    items: [
      { href: "/dashboard", label: "Dashboard", icon: LayoutDashboard },
      { href: "/approvals", label: "Approvals", icon: CheckCheck },
      { href: "/client-portal", label: "Your service", icon: ShieldCheck, permission: "M1.Profile.View" },
    ],
  },
  {
    label: "Workforce",
    items: [
      { href: "/people/employees", label: "Guards", icon: Users, permission: "M6.Employee.View" },
      { href: "/people/recruits", label: "Recruits", icon: UserPlus, permission: "M5.Recruit.View" },
      { href: "/people/documents", label: "Documents", icon: FileText, permission: "M6.Employee.View" },
      { href: "/people/training", label: "Training", icon: GraduationCap, permission: "M16.Hr.View" },
      { href: "/people/lifecycle", label: "Joins & exits", icon: LogIn, permission: "M16.Hr.View" },
      { href: "/people/requests", label: "Requests", icon: ClipboardList },
    ],
  },
  {
    label: "Clients",
    items: [
      { href: "/clients", label: "Clients", icon: Building2, permission: "M4.Client.View" },
      { href: "/clients/units", label: "Sites", icon: MapPin, permission: "M4.Client.View" },
      { href: "/clients/contracts", label: "Contracts", icon: ScrollText, permission: "M4.Client.View" },
      { href: "/clients/complaints", label: "Complaints", icon: MessageSquareWarning, permission: "M12.Complaint.View" },
      { href: "/clients/client-relations", label: "Relation visits", icon: Handshake, permission: "M13.Sales.View" },
    ],
  },
  {
    label: "Operations",
    items: [
      { href: "/operations/deployment", label: "Deployments", icon: Shield, permission: "M7.Deployment.View" },
      { href: "/operations/turnout", label: "Turnout", icon: CalendarCheck2, permission: "M7.Deployment.View" },
      { href: "/operations/attendance", label: "Attendance", icon: CalendarClock, permission: "M8.Attendance.View" },
      { href: "/operations/attendance/summary", label: "Monthly summary", icon: CalendarCheck2, permission: "M8.Attendance.View" },
      { href: "/operations/deployment/new", label: "Move guards", icon: ArrowLeftRight, permission: "M7.Deployment.Edit" },
      { href: "/operations/patrol", label: "Patrol", icon: QrCode, permission: "M9.Patrol.View" },
      { href: "/operations/patrol/rounds", label: "Patrol rounds", icon: RouteIcon, permission: "M9.Patrol.View" },
      { href: "/operations/tracking", label: "Live tracking", icon: Radar, permission: "M10.Tracking.View" },
      { href: "/operations/incidents", label: "Incidents", icon: AlertTriangle, permission: "M12.Incident.View" },
      { href: "/operations/field-reports", label: "Field reports", icon: NotebookPen, permission: "M12.Incident.View" },
      { href: "/operations/gate-pass", label: "Gate passes", icon: DoorOpen, permission: "M16.GatePass.Edit" },
      { href: "/operations/qr-codes", label: "QR Codes", icon: QrCode, permission: "M9.Patrol.View" },
      { href: "/operations/events", label: "Events", icon: CalendarCheck2, permission: "M7.Deployment.View" },
      { href: "/tasks", label: "Tasks", icon: ListTodo, permission: "M11.Task.View" },
    ],
  },
  {
    label: "Stores",
    items: [
      { href: "/inventory/stock", label: "Uniform stock", icon: Package, permission: "M14.Inventory.View" },
      { href: "/inventory/ledger", label: "Issue ledger", icon: ScrollText, permission: "M14.Inventory.View" },
      { href: "/inventory/issues", label: "Outstanding kit", icon: PackageOpen, permission: "M14.Inventory.View" },
      { href: "/inventory/movements", label: "Stock movement", icon: Truck, permission: "M14.Inventory.Edit" },
    ],
  },
  {
    label: "Finance",
    items: [
      { href: "/finance/payroll", label: "Payroll", icon: Wallet, permission: "M15.Payroll.View" },
      { href: "/finance/invoices", label: "Invoices", icon: Receipt, permission: "M15.Invoice.View" },
      { href: "/finance/receipts", label: "Receipts", icon: HandCoins, permission: "M15.Invoice.View" },
      { href: "/finance/ageing", label: "Ageing", icon: Hourglass, permission: "M15.Invoice.View" },
      { href: "/finance/advances", label: "Advances", icon: Wallet },
      { href: "/finance/salary-slips", label: "Salary slips", icon: ScrollText },
    ],
  },
  {
    label: "Growth",
    items: [
      { href: "/sales/visits", label: "Visits", icon: Briefcase, permission: "M13.Sales.View" },
      { href: "/sales/follow-ups", label: "Follow-ups", icon: CalendarClock, permission: "M13.Sales.View" },
      { href: "/sales/pipeline", label: "Pipeline", icon: TrendingUp, permission: "M13.Sales.View" },
    ],
  },
  {
    label: "System",
    items: [
      { href: "/reports", label: "Reports", icon: FileText, permission: "RPT.Report.View" },
      { href: "/settings/users", label: "Users", icon: ShieldCheck, permission: "SET.Settings.Edit" },
      { href: "/settings/masters", label: "Reference data", icon: Database, permission: "M3.Master.View" },
      { href: "/settings/company", label: "Company", icon: Building, permission: "SET.Settings.Edit" },
      { href: "/settings/branches", label: "Branches", icon: MapPin, permission: "M3.Master.View" },
      { href: "/settings/roles", label: "My permissions", icon: KeyRound },
      { href: "/settings/session", label: "This session", icon: IdCard },
      { href: "/settings/password", label: "Change password", icon: Lock },
      { href: "/settings/audit", label: "Sign-in log", icon: ScrollText, permission: "SET.Audit.View" },
      { href: "/chat", label: "Chat", icon: MessageCircle },
      { href: "/tenants", label: "Tenants", icon: Building2, permission: "M2.Tenant.Manage" },
      { href: "/platform-analytics", label: "Platform", icon: LineChart, permission: "M2.Tenant.Manage" },
    ],
  },
];

export function AppShell({
  children,
  userName,
  roleCode,
  onLogout,
  dark,
  onToggleDark,
  nav = defaultNav,
}: {
  children: React.ReactNode;
  userName?: string;
  roleCode?: string;
  onLogout?: () => void;
  dark?: boolean;
  onToggleDark?: () => void;
  nav?: NavGroup[];
}) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  const Nav = (
    <nav className="flex h-full flex-col">
      <div className="flex items-center gap-2 border-b border-[var(--diti-border)] px-4 py-4">
        <div className="flex h-8 w-8 items-center justify-center rounded-[var(--diti-radius-md)] bg-[var(--diti-primary)] text-sm font-bold text-white">
          D
        </div>
        <div>
          <div className="text-sm font-semibold text-[var(--diti-text)]">Diti365</div>
          <div className="text-[11px] text-[var(--diti-muted)]">Security operations</div>
        </div>
      </div>
      <div className="flex-1 overflow-y-auto px-3 py-4">
        {nav.map((group) => (
          <div key={group.label} className="mb-5">
            <div className="mb-2 px-2 text-[11px] font-semibold uppercase tracking-wider text-[var(--diti-muted)]">
              {group.label}
            </div>
            <ul className="space-y-1">
              {group.items.map((item) => {
                const Icon = item.icon;
                const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      onClick={() => setOpen(false)}
                      className={cn(
                        "flex items-center gap-2 rounded-[var(--diti-radius-md)] px-2.5 py-2 text-sm transition",
                        active
                          ? "bg-[var(--diti-primary-subtle)] font-medium text-[var(--diti-primary)]"
                          : "text-[var(--diti-muted)] hover:bg-zinc-100 hover:text-[var(--diti-text)] dark:hover:bg-zinc-800",
                      )}
                    >
                      <Icon className="h-4 w-4 shrink-0" />
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-[var(--diti-border)] p-3">
        <div className="mb-2 truncate px-1 text-sm font-medium text-[var(--diti-text)]">
          {userName ?? "Signed in"}
        </div>
        <div className="mb-3 px-1 text-xs text-[var(--diti-muted)]">{roleCode}</div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" className="flex-1" onClick={onToggleDark} type="button">
            {dark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
          </Button>
          <Button variant="outline" size="sm" className="flex-1" onClick={onLogout} type="button">
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </div>
    </nav>
  );

  return (
    <div className="min-h-screen bg-[var(--diti-bg)] text-[var(--diti-text)]">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-[var(--diti-border)] bg-[var(--diti-surface)] lg:block">
        {Nav}
      </aside>
      {open ? (
        <div className="fixed inset-0 z-40 lg:hidden">
          <button
            type="button"
            aria-label="Close menu"
            className="absolute inset-0 bg-black/40"
            onClick={() => setOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-72 bg-[var(--diti-surface)] shadow-xl">{Nav}</aside>
        </div>
      ) : null}
      <div className="lg:pl-64">
        <header className="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-[var(--diti-border)] bg-[var(--diti-surface)]/90 px-4 backdrop-blur lg:hidden">
          <button type="button" onClick={() => setOpen(true)} aria-label="Open menu">
            {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
          <span className="font-semibold">Diti365</span>
        </header>
        <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">{children}</main>
      </div>
    </div>
  );
}
