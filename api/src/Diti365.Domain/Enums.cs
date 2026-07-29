namespace Diti365.Domain;

public static class RoleCodes
{
    public const string SuperAdmin   = "SUPER_ADMIN";
    public const string CompanyAdmin = "COMPANY_ADMIN";
    public const string BranchAdmin  = "BRANCH_ADMIN";
    public const string Operations   = "OPERATIONS";
    public const string Hr           = "HR";
    public const string Accounts     = "ACCOUNTS";
    public const string Supervisor   = "SUPERVISOR";
    public const string Gatekeeper   = "GATEKEEPER";
    public const string NightPatrol  = "NIGHT_PATROL";
    public const string Sales        = "SALES";
    public const string Employee     = "EMPLOYEE";
    public const string Client       = "CLIENT";
}

/// <summary>Attendance status, stored as CHAR(2) so the values are space padded.</summary>
public static class AttendanceStatus
{
    public const string Present     = "P ";
    public const string Absent      = "A ";
    public const string HalfDay     = "HD";
    public const string WeekOff     = "WO";
    public const string Holiday     = "HO";
    public const string Leave       = "LV";
    public const string DoubleShift = "DS";
}

public enum PunchDirection { In, Out }

public enum ApprovalStatus { Pending = 0, Approved = 1, Rejected = 2 }

public enum AttendanceSource { SelfPunch = 1, Supervisor = 2, Biometric = 3, Import = 4 }
