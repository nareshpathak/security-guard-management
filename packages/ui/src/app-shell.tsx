"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import {
  Building2,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
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
  permission?: string;
  children?: NavItem[];
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
      { href: "/approvals", label: "Approvals Queue", icon: CheckCheck },
      { href: "/client-portal", label: "Client Portal", icon: ShieldCheck, permission: "M1.Profile.View" },
    ],
  },
  {
    label: "Workforce Management",
    items: [
      {
        href: "/people/employees",
        label: "Guards & Staff",
        icon: Users,
        permission: "M6.Employee.View",
        children: [
          { href: "/people/employees", label: "Guard Directory", icon: Users },
          { href: "/people/recruits", label: "Recruit Candidates", icon: UserPlus, permission: "M5.Recruit.View" },
          { href: "/people/documents", label: "Document Vault", icon: FileText, permission: "M6.Employee.View" },
        ],
      },
      { href: "/people/recruits", label: "Recruit Intake", icon: UserPlus, permission: "M5.Recruit.View" },
      { href: "/people/training", label: "Training Modules", icon: GraduationCap, permission: "M16.Hr.View" },
      { href: "/people/lifecycle", label: "Joins & Exits", icon: LogIn, permission: "M16.Hr.View" },
      { href: "/people/requests", label: "Guard Requests", icon: ClipboardList },
    ],
  },
  {
    label: "Clients & Contracts",
    items: [
      {
        href: "/clients",
        label: "Client Accounts",
        icon: Building2,
        permission: "M4.Client.View",
        children: [
          { href: "/clients", label: "Client Directory", icon: Building2 },
          { href: "/clients/units", label: "Deployment Sites", icon: MapPin, permission: "M4.Client.View" },
          { href: "/clients/contracts", label: "Contract Agreements", icon: ScrollText, permission: "M4.Client.View" },
        ],
      },
      { href: "/clients/units", label: "Client Sites", icon: MapPin, permission: "M4.Client.View" },
      { href: "/clients/contracts", label: "Contracts & Rates", icon: ScrollText, permission: "M4.Client.View" },
      { href: "/clients/complaints", label: "Client Complaints", icon: MessageSquareWarning, permission: "M12.Complaint.View" },
      { href: "/clients/client-relations", label: "Relation Visits", icon: Handshake, permission: "M13.Sales.View" },
    ],
  },
  {
    label: "Security Operations",
    items: [
      {
        href: "/operations/deployment",
        label: "Deployments",
        icon: Shield,
        permission: "M7.Deployment.View",
        children: [
          { href: "/operations/deployment", label: "Active Deployments", icon: Shield },
          { href: "/operations/turnout", label: "Live Turnout", icon: CalendarCheck2 },
          { href: "/operations/deployment/new", label: "Site Transfers", icon: ArrowLeftRight },
        ],
      },
      { href: "/operations/turnout", label: "Turnout Board", icon: CalendarCheck2, permission: "M7.Deployment.View" },
      { href: "/operations/attendance", label: "Daily Attendance", icon: CalendarClock, permission: "M8.Attendance.View" },
      { href: "/operations/attendance/summary", label: "Monthly Summary", icon: CalendarCheck2, permission: "M8.Attendance.View" },
      {
        href: "/operations/patrol",
        label: "Patrol Management",
        icon: QrCode,
        permission: "M9.Patrol.View",
        children: [
          { href: "/operations/patrol", label: "Scan History Logs", icon: QrCode },
          { href: "/operations/patrol/rounds", label: "Patrol Rounds Config", icon: RouteIcon },
          { href: "/operations/qr-codes", label: "QR Checkpoints", icon: QrCode },
        ],
      },
      { href: "/operations/tracking", label: "Live GPS Tracking", icon: Radar, permission: "M10.Tracking.View" },
      { href: "/operations/incidents", label: "Incident Escalation", icon: AlertTriangle, permission: "M12.Incident.View" },
      { href: "/operations/field-reports", label: "Field Audit Reports", icon: NotebookPen, permission: "M12.Incident.View" },
      { href: "/operations/gate-pass", label: "Gate Passes", icon: DoorOpen, permission: "M16.GatePass.Edit" },
      { href: "/operations/events", label: "Special Events", icon: CalendarCheck2, permission: "M7.Deployment.View" },
      { href: "/tasks", label: "Tasks & Checklists", icon: ListTodo, permission: "M11.Task.View" },
    ],
  },
  {
    label: "Stores & Uniforms",
    items: [
      { href: "/inventory/stock", label: "Uniform Stock", icon: Package, permission: "M14.Inventory.View" },
      { href: "/inventory/ledger", label: "Kit Issue Ledger", icon: ScrollText, permission: "M14.Inventory.View" },
      { href: "/inventory/issues", label: "Outstanding Kit", icon: PackageOpen, permission: "M14.Inventory.View" },
      { href: "/inventory/movements", label: "Stock Movement", icon: Truck, permission: "M14.Inventory.Edit" },
    ],
  },
  {
    label: "Finance & Payroll",
    items: [
      { href: "/finance/payroll", label: "Payroll Processing", icon: Wallet, permission: "M15.Payroll.View" },
      { href: "/finance/invoices", label: "Client Invoices", icon: Receipt, permission: "M15.Invoice.View" },
      { href: "/finance/receipts", label: "Payment Receipts", icon: HandCoins, permission: "M15.Invoice.View" },
      { href: "/finance/ageing", label: "Outstanding Ageing", icon: Hourglass, permission: "M15.Invoice.View" },
      { href: "/finance/advances", label: "Salary Advances", icon: Wallet },
      { href: "/finance/salary-slips", label: "Salary Slips PDF", icon: ScrollText },
    ],
  },
  {
    label: "Sales & Growth",
    items: [
      { href: "/sales/visits", label: "Sales Visits", icon: Briefcase, permission: "M13.Sales.View" },
      { href: "/sales/follow-ups", label: "Client Follow-ups", icon: CalendarClock, permission: "M13.Sales.View" },
      { href: "/sales/pipeline", label: "Deals Pipeline", icon: TrendingUp, permission: "M13.Sales.View" },
    ],
  },
  {
    label: "System Settings",
    items: [
      { href: "/reports", label: "Reports Hub", icon: FileText, permission: "RPT.Report.View" },
      { href: "/settings/users", label: "User Accounts", icon: ShieldCheck, permission: "SET.Settings.Edit" },
      { href: "/settings/masters", label: "Reference Masters", icon: Database, permission: "M3.Master.View" },
      { href: "/settings/company", label: "Company Profile", icon: Building, permission: "SET.Settings.Edit" },
      { href: "/settings/branches", label: "Branch Offices", icon: MapPin, permission: "M3.Master.View" },
      { href: "/settings/roles", label: "My Permissions", icon: KeyRound },
      { href: "/settings/session", label: "Active Session", icon: IdCard },
      { href: "/settings/password", label: "Change Password", icon: Lock },
      { href: "/settings/audit", label: "Audit Logs", icon: ScrollText, permission: "SET.Audit.View" },
      { href: "/chat", label: "Team Chat", icon: MessageCircle },
      { href: "/tenants", label: "Tenants", icon: Building2, permission: "M2.Tenant.Manage" },
      { href: "/platform-analytics", label: "Platform Metrics", icon: LineChart, permission: "M2.Tenant.Manage" },
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
  const [mobileOpen, setMobileOpen] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [expandedSubmenus, setExpandedSubmenus] = useState<Record<string, boolean>>({});

  const toggleSubmenu = (href: string) => {
    setExpandedSubmenus((prev) => ({ ...prev, [href]: !prev[href] }));
  };

  const isItemActive = (href: string) => {
    if (href === "/dashboard") return pathname === "/dashboard";
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  const renderNavItem = (item: NavItem, isChild = false) => {
    const Icon = item.icon;
    const active = isItemActive(item.href);
    const hasChildren = item.children && item.children.length > 0;
    const isExpanded = !!expandedSubmenus[item.href];

    if (hasChildren && !collapsed) {
      return (
        <li key={item.href}>
          <button
            type="button"
            onClick={() => toggleSubmenu(item.href)}
            className={cn(
              "flex w-full items-center justify-between rounded-lg px-2.5 py-2 text-xs font-semibold transition-all duration-150 select-none",
              active
                ? "bg-indigo-50 dark:bg-indigo-950/80 font-bold text-indigo-700 dark:text-indigo-300 border border-indigo-200/50 dark:border-indigo-800/50"
                : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 hover:text-slate-900 dark:hover:bg-slate-800 dark:hover:text-slate-100",
            )}
          >
            <div className="flex items-center gap-2.5 truncate">
              <Icon className="size-4 shrink-0" />
              <span className="truncate">{item.label}</span>
            </div>
            <ChevronDown
              className={cn("size-3.5 shrink-0 transition-transform duration-200", isExpanded && "rotate-180")}
            />
          </button>
          {isExpanded && (
            <ul className="mt-1 space-y-1 border-l-2 border-indigo-200/80 dark:border-indigo-800/80 ml-3.5 pl-2.5">
              {item.children?.map((child) => renderNavItem(child, true))}
            </ul>
          )}
        </li>
      );
    }

    return (
      <li key={item.href} className="relative group">
        <Link
          href={item.href}
          onClick={() => setMobileOpen(false)}
          className={cn(
            "flex items-center gap-2.5 rounded-lg px-2.5 py-2 text-xs transition-all duration-150 relative select-none",
            isChild && "py-1.5 text-[11px]",
            active
              ? "bg-gradient-to-r from-indigo-600 to-blue-600 font-bold text-white shadow-sm shadow-indigo-500/25 border border-indigo-500/30"
              : "text-slate-600 dark:text-slate-400 hover:bg-slate-100 hover:text-slate-900 dark:hover:bg-slate-800 dark:hover:text-slate-100",
            collapsed && "justify-center px-0 py-2.5",
          )}
        >
          <Icon className={cn("size-4 shrink-0", active ? "text-white" : "text-current")} />
          {!collapsed && <span className="truncate font-medium">{item.label}</span>}

          {/* Floating Tooltip in Collapsed Mode */}
          {collapsed && (
            <div className="absolute left-full top-1/2 ml-3 -translate-y-1/2 z-50 hidden group-hover:flex flex-col rounded-lg border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-2.5 text-xs text-slate-900 dark:text-slate-100 shadow-xl whitespace-nowrap">
              <span className="font-bold text-indigo-600 dark:text-indigo-400">{item.label}</span>
              {hasChildren && (
                <div className="mt-1 pt-1 border-t border-slate-200 dark:border-slate-800 flex flex-col gap-1 text-[11px] text-slate-500">
                  {item.children?.map((child) => (
                    <span key={child.href} className="hover:text-indigo-600">
                      • {child.label}
                    </span>
                  ))}
                </div>
              )}
            </div>
          )}
        </Link>
      </li>
    );
  };

  const NavContent = (
    <nav className="flex h-full flex-col select-none">
      {/* Sidebar Header */}
      <div className="flex h-14 items-center justify-between border-b border-slate-200/90 dark:border-slate-800/90 px-4">
        <div className="flex items-center gap-2.5 truncate">
          <div className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-gradient-to-br from-indigo-600 to-blue-600 text-xs font-black text-white shadow-sm shadow-indigo-500/25">
            D
          </div>
          {!collapsed && (
            <div className="truncate">
              <div className="text-xs font-black tracking-tight text-slate-900 dark:text-slate-100">Diti365 ERP</div>
              <div className="text-[10px] font-semibold text-slate-500">Enterprise Operations</div>
            </div>
          )}
        </div>
        <button
          type="button"
          onClick={() => setCollapsed(!collapsed)}
          className="hidden lg:flex size-7 items-center justify-center rounded-md border border-slate-200 dark:border-slate-800 text-slate-500 hover:bg-slate-100 hover:text-slate-900 dark:hover:bg-slate-800"
          title={collapsed ? "Expand Sidebar" : "Collapse Sidebar"}
        >
          {collapsed ? <ChevronRight className="size-4" /> : <ChevronLeft className="size-4" />}
        </button>
      </div>

      {/* Nav Groups & Items */}
      <div className="flex-1 overflow-y-auto px-3 py-3 space-y-4">
        {nav.map((group) => (
          <div key={group.label}>
            {!collapsed ? (
              <div className="mb-1.5 px-2 text-[10px] font-extrabold uppercase tracking-wider text-slate-400 dark:text-slate-500">
                {group.label}
              </div>
            ) : (
              <div className="my-2 border-t border-slate-200 dark:border-slate-800" />
            )}
            <ul className="space-y-0.5">{group.items.map((item) => renderNavItem(item))}</ul>
          </div>
        ))}
      </div>

      {/* User Footer Profile */}
      <div className="border-t border-slate-200/90 dark:border-slate-800/90 p-3 bg-slate-50/50 dark:bg-slate-900/50">
        {!collapsed ? (
          <>
            <div className="mb-0.5 truncate text-xs font-bold text-slate-900 dark:text-slate-100">
              {userName ?? "Signed in"}
            </div>
            <div className="mb-3 truncate text-[11px] font-semibold text-slate-500">
              Role: {roleCode ?? "Administrator"}
            </div>
          </>
        ) : null}
        <div className="flex items-center gap-1.5">
          <Button
            variant="outline"
            size="sm"
            className={cn("flex-1 text-xs font-semibold", collapsed && "px-0 justify-center")}
            onClick={onToggleDark}
            type="button"
            title="Toggle Dark / Light Theme"
          >
            {dark ? <Sun className="size-4" /> : <Moon className="size-4" />}
            {!collapsed && <span className="ml-1.5">{dark ? "Light" : "Dark"}</span>}
          </Button>
          <Button
            variant="outline"
            size="sm"
            className={cn("flex-1 text-xs font-semibold", collapsed && "px-0 justify-center")}
            onClick={onLogout}
            type="button"
            title="Logout of session"
          >
            <LogOut className="size-4 text-red-600" />
            {!collapsed && <span className="ml-1.5">Logout</span>}
          </Button>
        </div>
      </div>
    </nav>
  );

  return (
    <div className="flex min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100">
      {/* Desktop Sidebar */}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-30 hidden shrink-0 border-r border-slate-200/90 dark:border-slate-800/90 bg-white dark:bg-slate-900 transition-all duration-300 ease-in-out lg:block shadow-2xs",
          collapsed ? "w-[68px]" : "w-[260px]",
        )}
      >
        {NavContent}
      </aside>

      {/* Mobile Drawer */}
      {mobileOpen ? (
        <div className="fixed inset-0 z-50 lg:hidden">
          <button
            type="button"
            aria-label="Close menu"
            className="absolute inset-0 bg-slate-950/40 backdrop-blur-xs"
            onClick={() => setMobileOpen(false)}
          />
          <aside className="absolute inset-y-0 left-0 w-72 bg-white dark:bg-slate-900 shadow-2xl">
            {NavContent}
          </aside>
        </div>
      ) : null}

      {/* Main Body Layout */}
      <div
        className={cn(
          "flex-1 min-w-0 transition-all duration-300 ease-in-out",
          collapsed ? "lg:pl-[68px]" : "lg:pl-[260px]",
        )}
      >
        {/* Mobile Header Bar */}
        <header className="sticky top-0 z-20 flex h-14 items-center justify-between border-b border-slate-200/90 dark:border-slate-800/90 bg-white/90 dark:bg-slate-900/90 px-4 backdrop-blur lg:hidden">
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => setMobileOpen(true)}
              aria-label="Open menu"
              className="p-1 rounded-md hover:bg-slate-100 dark:hover:bg-slate-800"
            >
              {mobileOpen ? <X className="size-5" /> : <Menu className="size-5" />}
            </button>
            <span className="font-extrabold text-sm">Diti365 ERP</span>
          </div>
          <Button variant="outline" size="sm" onClick={onToggleDark}>
            {dark ? <Sun className="size-4" /> : <Moon className="size-4" />}
          </Button>
        </header>

        <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">{children}</main>
      </div>
    </div>
  );
}
