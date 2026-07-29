namespace Diti365.Contracts.Auth;

public sealed record LoginRequest(
    string LoginId,
    string Password,
    string? DeviceId = null,
    string? DeviceModel = null,
    string? AppVersion = null,
    string? Platform = null,
    string? FcmToken = null);

public sealed record LoginResponse(
    string AccessToken,
    string RefreshToken,
    DateTime AccessTokenExpiresAt,
    AuthUser User,
    IReadOnlyList<string> Permissions);

public sealed record AuthUser(
    int UserId,
    int? CompanyId,
    int? BranchId,
    int? EmpId,
    int? ClientId,
    string UserName,
    string Name,
    string? EmpCode,
    string? MobileNo,
    string? Designation,
    string? Unit,
    string RoleCode,
    int? LoginType,
    string? PhotoUrl,
    bool MustChangePassword,
    DateOnly? ExpiresOn,
    int AttendanceCount);

public sealed record RefreshRequest(string RefreshToken, string? DeviceId = null);
public sealed record LogoutRequest(string RefreshToken);

public sealed record OtpRequest(string MobileNo, string Purpose = "Login");
public sealed record OtpVerifyRequest(string MobileNo, string Otp, string Purpose = "Login");

public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);
public sealed record ResetPasswordRequest(string ResetToken, string NewPassword);

/// <summary>
/// Deliberately carries a token, not a user id: the caller is still anonymous
/// at this point and must not be told which account the code belonged to.
/// </summary>
public sealed record OtpVerifyResponse(string ResetToken);
public sealed record ForgotPasswordRequest(string MobileNo);
public sealed record DeviceVerifyRequest(string DeviceId);
public sealed record UpdateTokenRequest(string FcmToken, string? Platform = null);

/// <summary>Row returned by usp_User_GetForAuthentication. Never leaves the infrastructure layer.</summary>
public sealed record AuthCandidate(
    int UserId,
    int? CompanyId,
    int? BranchId,
    int? EmpId,
    int? ClientId,
    string UserName,
    string MobileNo,
    string? PasswordHash,
    string? PasswordSalt,
    string? LegacyPasswordHash,
    bool MustChangePassword,
    int RoleId,
    string RoleCode,
    int? LoginType,
    string? DeviceId,
    bool IsActive,
    bool IsLocked,
    int FailedLoginCount,
    DateTime? LockedUntil,
    DateOnly? ExpiresOn,
    bool CompanyIsActive,
    bool CompanyIsExpired,
    DateOnly? CompanyExpiryDate,
    int CompanyMaxUsers,
    int CompanyUserCount);

public sealed record PermissionGrant(
    string Module, string Code, string Name,
    bool CanView, bool CanCreate, bool CanEdit, bool CanDelete, bool CanApprove, bool CanExport);
