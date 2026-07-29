namespace Diti365.Application.Security;

/// <summary>
/// Mirrors sec.Permission.Code seeded by db/scripts/700_seed_reference.sql.
/// Constants rather than strings so a typo is a compile error, not a silent 403.
/// </summary>
public static class Perm
{
    public const string ProfileView          = "M1.Profile.View";
    public const string TenantManage         = "M2.Tenant.Manage";
    public const string MasterView           = "M3.Master.View";
    public const string MasterEdit           = "M3.Master.Edit";
    public const string ClientView           = "M4.Client.View";
    public const string ClientEdit           = "M4.Client.Edit";
    public const string RecruitView          = "M5.Recruit.View";
    public const string RecruitEdit          = "M5.Recruit.Edit";
    public const string RecruitApprove       = "M5.Recruit.Approve";
    public const string EmployeeView         = "M6.Employee.View";
    public const string EmployeeEdit         = "M6.Employee.Edit";
    public const string EmployeeViewSensitive = "M6.Employee.ViewSensitive";
    public const string DeploymentView       = "M7.Deployment.View";
    public const string DeploymentEdit       = "M7.Deployment.Edit";
    public const string DeploymentApprove    = "M7.Deployment.Approve";
    public const string AttendanceView       = "M8.Attendance.View";
    public const string AttendancePunch      = "M8.Attendance.Punch";
    public const string AttendanceEdit       = "M8.Attendance.Edit";
    public const string AttendanceApprove    = "M8.Attendance.Approve";
    public const string PatrolView           = "M9.Patrol.View";
    public const string PatrolScan           = "M9.Patrol.Scan";
    public const string PatrolEdit           = "M9.Patrol.Edit";
    public const string TrackingView         = "M10.Tracking.View";
    public const string TaskView             = "M11.Task.View";
    public const string TaskEdit             = "M11.Task.Edit";
    public const string IncidentView         = "M12.Incident.View";
    public const string IncidentEdit         = "M12.Incident.Edit";
    public const string ComplaintView        = "M12.Complaint.View";
    public const string ComplaintEdit        = "M12.Complaint.Edit";
    public const string ComplaintApprove     = "M12.Complaint.Approve";
    public const string SalesView            = "M13.Sales.View";
    public const string SalesEdit            = "M13.Sales.Edit";
    public const string InventoryView        = "M14.Inventory.View";
    public const string InventoryEdit        = "M14.Inventory.Edit";
    public const string PayrollView          = "M15.Payroll.View";
    public const string PayrollEdit          = "M15.Payroll.Edit";
    public const string PayrollApprove       = "M15.Payroll.Approve";
    public const string InvoiceView          = "M15.Invoice.View";
    public const string InvoiceEdit          = "M15.Invoice.Edit";
    public const string HrView               = "M16.Hr.View";
    public const string HrEdit               = "M16.Hr.Edit";
    public const string GatePassEdit         = "M16.GatePass.Edit";
    public const string RequestApprove       = "M16.Request.Approve";
    public const string ReportView           = "RPT.Report.View";
    public const string ReportExport         = "RPT.Report.Export";
    public const string SettingsEdit         = "SET.Settings.Edit";
    public const string AuditView            = "SET.Audit.View";
}
