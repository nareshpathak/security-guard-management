namespace Diti365.Infrastructure.Data;

public sealed class DbOptions
{
    public const string SectionName = "Database";

    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>Default command timeout in seconds.</summary>
    public int CommandTimeoutSeconds { get; set; } = 30;

    /// <summary>Timeout for the long procedures: payroll, invoicing, registers, seeds.</summary>
    public int LongCommandTimeoutSeconds { get; set; } = 300;

    /// <summary>Procedures that get the long timeout.</summary>
    public HashSet<string> LongRunningProcedures { get; set; } = new(StringComparer.OrdinalIgnoreCase)
    {
        "dbo.usp_Payroll_Generate",
        "dbo.usp_Payroll_Lock",
        "dbo.usp_Invoice_Generate",
        "dbo.usp_Attendance_RefreshSummary",
        "dbo.usp_Attendance_GetRegister",
        "dbo.usp_Location_Purge"
    };

    /// <summary>
    /// Procedures that legitimately run without a tenant, because the caller has not
    /// authenticated yet. Everything else has @CompanyID injected from the JWT.
    /// </summary>
    public HashSet<string> TenantlessProcedures { get; set; } = new(StringComparer.OrdinalIgnoreCase)
    {
        "dbo.usp_User_GetForAuthentication",
        "dbo.usp_User_LoginSucceeded",
        "dbo.usp_User_LoginFailed",
        "dbo.usp_User_Logout",
        "dbo.usp_User_CheckMobile",
        "dbo.usp_User_CheckDeviceId",
        "dbo.usp_User_GenerateOtp",
        "dbo.usp_User_VerifyOtp",
        "dbo.usp_User_ChangePassword",
        "dbo.usp_User_UpdateFcmToken",
        "dbo.usp_Company_CheckExpiry",
        "dbo.usp_Company_GetLog",
        "dbo.usp_Company_GetLogDetail",
        "dbo.usp_Master_GetStates",
        "dbo.usp_Master_GetCity",
        "dbo.usp_Master_GetDistrict",
        "dbo.usp_Dashboard_Platform",
        "dbo.usp_Attendance_MarkAbsentForNoPunch",
        "dbo.usp_Patrol_DetectMissedRounds",
        "dbo.usp_Turnout_DetectVacantPosts"
    };

    public int RetryCount { get; set; } = 3;
    public int RetryBaseDelayMs { get; set; } = 200;

    /// <summary>Log a warning for any procedure slower than this.</summary>
    public int SlowQueryWarnMs { get; set; } = 500;
}
