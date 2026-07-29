namespace Diti365.Domain;

/// <summary>Machine-readable error codes returned in the problem+json body. docs/prd/02-api.md §9.</summary>
public static class ErrorCodes
{
    public const string AuthInvalidCredentials  = "AUTH_INVALID_CREDENTIALS";
    public const string AuthAccountLocked       = "AUTH_ACCOUNT_LOCKED";
    public const string AuthAccountInactive     = "AUTH_ACCOUNT_INACTIVE";
    public const string AuthDeviceNotRegistered = "AUTH_DEVICE_NOT_REGISTERED";
    public const string AuthRefreshInvalid      = "AUTH_REFRESH_INVALID";
    public const string LicenceExpired          = "LICENCE_EXPIRED";
    public const string LicenceUserLimit        = "LICENCE_USER_LIMIT";
    public const string TenantParamForbidden    = "TENANT_PARAM_FORBIDDEN";
    public const string PermissionDenied        = "PERMISSION_DENIED";
    public const string GeofenceViolation       = "GEOFENCE_VIOLATION";
    public const string DuplicatePunch          = "DUPLICATE_PUNCH";
    public const string MockLocationDetected    = "MOCK_LOCATION_DETECTED";
    public const string AttendanceLocked        = "ATTENDANCE_LOCKED";
    public const string PayrollRunLocked        = "PAYROLL_RUN_LOCKED";
    public const string DuplicateAadhaar        = "DUPLICATE_AADHAAR";
    public const string ValidationFailed        = "VALIDATION_FAILED";
    public const string NotFound                = "NOT_FOUND";
    public const string Conflict                = "CONFLICT";
    public const string RateLimited             = "RATE_LIMITED";
    public const string Internal                = "INTERNAL_ERROR";
}
