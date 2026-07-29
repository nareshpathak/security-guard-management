using Diti365.Contracts.Auth;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

public interface IAuthRepository
{
    Task<AuthCandidate?> GetForAuthenticationAsync(string loginId, CancellationToken ct);
    Task<AuthUser?> LoginSucceededAsync(int userId, LoginRequest req, string? ip, CancellationToken ct);
    Task LoginFailedAsync(string loginId, string reason, LoginRequest req, string? ip, CancellationToken ct);
    Task LogoutAsync(int userId, CancellationToken ct);
    Task<IReadOnlyList<PermissionGrant>> GetPermissionsAsync(int companyId, int userId, CancellationToken ct);
    Task<SpResult> CheckMobileAsync(string mobileNo, CancellationToken ct);
    Task<SpResult> CheckDeviceAsync(int userId, string deviceId, CancellationToken ct);
    Task<SpResult> CheckExpiryAsync(int companyId, CancellationToken ct);
    Task<SpResult> GenerateOtpAsync(string mobileNo, string otpHash, string purpose, CancellationToken ct);
    Task<SpResult> VerifyOtpAsync(string mobileNo, string otpHash, string purpose, CancellationToken ct);
    Task<SpResult> ChangePasswordAsync(int userId, string hash, string salt, CancellationToken ct);
    Task<SpResult> UpdateFcmTokenAsync(int userId, string token, string? platform, CancellationToken ct);
}

public sealed class AuthRepository(IDbExecutor db) : IAuthRepository
{
    public Task<AuthCandidate?> GetForAuthenticationAsync(string loginId, CancellationToken ct) =>
        db.QuerySingleAsync("dbo.usp_User_GetForAuthentication",
            p => p.Add(P.NVar("@LoginId", loginId, 100)),
            Map.AuthCandidate, ct);

    public Task<AuthUser?> LoginSucceededAsync(int userId, LoginRequest req, string? ip, CancellationToken ct) =>
        db.QuerySingleAsync("dbo.usp_User_LoginSucceeded", p =>
        {
            p.Add(P.Int ("@UserID",      userId));
            p.Add(P.NVar("@DeviceID",    req.DeviceId, 200));
            p.Add(P.NVar("@DeviceModel", req.DeviceModel, 120));
            p.Add(P.NVar("@FcmToken",    req.FcmToken, 500));
            p.Add(P.NVar("@AppVersion",  req.AppVersion, 20));
            p.Add(P.NVar("@Platform",    req.Platform, 20));
            p.Add(P.NVar("@IpAddress",   ip, 45));
        }, Map.AuthUser, ct);

    public Task LoginFailedAsync(string loginId, string reason, LoginRequest req, string? ip, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_LoginFailed", p =>
        {
            p.Add(P.NVar("@LoginId",    loginId, 100));
            p.Add(P.NVar("@Reason",     reason, 200));
            p.Add(P.NVar("@IpAddress",  ip, 45));
            p.Add(P.NVar("@DeviceID",   req.DeviceId, 200));
            p.Add(P.NVar("@AppVersion", req.AppVersion, 20));
            p.Add(P.NVar("@Platform",   req.Platform, 20));
        }, ct);

    public Task LogoutAsync(int userId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_Logout", p => p.Add(P.Int("@UserID", userId)), ct);

    public Task<IReadOnlyList<PermissionGrant>> GetPermissionsAsync(int companyId, int userId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_User_GetRights", p =>
        {
            p.Add(P.Int("@CompanyID", companyId));
            p.Add(P.Int("@UserID",    userId));
        }, Map.PermissionGrant, ct);

    public Task<SpResult> CheckMobileAsync(string mobileNo, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_CheckMobile", p => p.Add(P.NVar("@MobileNo", mobileNo, 15)), ct);

    public Task<SpResult> CheckDeviceAsync(int userId, string deviceId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_CheckDeviceId", p =>
        {
            p.Add(P.Int ("@UserID",   userId));
            p.Add(P.NVar("@DeviceID", deviceId, 200));
        }, ct);

    public Task<SpResult> CheckExpiryAsync(int companyId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Company_CheckExpiry", p => p.Add(P.Int("@CompanyID", companyId)), ct);

    public Task<SpResult> GenerateOtpAsync(string mobileNo, string otpHash, string purpose, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_GenerateOtp", p =>
        {
            p.Add(P.NVar("@MobileNo", mobileNo, 15));
            p.Add(P.NVar("@OtpHash",  otpHash, 200));
            p.Add(P.NVar("@Purpose",  purpose, 30));
        }, ct);

    public Task<SpResult> VerifyOtpAsync(string mobileNo, string otpHash, string purpose, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_VerifyOtp", p =>
        {
            p.Add(P.NVar("@MobileNo", mobileNo, 15));
            p.Add(P.NVar("@OtpHash",  otpHash, 200));
            p.Add(P.NVar("@Purpose",  purpose, 30));
        }, ct);

    public Task<SpResult> ChangePasswordAsync(int userId, string hash, string salt, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_ChangePassword", p =>
        {
            p.Add(P.Int ("@UserID",       userId));
            p.Add(P.NVar("@PasswordHash", hash, 500));
            p.Add(P.NVar("@PasswordSalt", salt, 200));
        }, ct);

    public Task<SpResult> UpdateFcmTokenAsync(int userId, string token, string? platform, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_User_UpdateFcmToken", p =>
        {
            p.Add(P.Int ("@UserID",   userId));
            p.Add(P.NVar("@FcmToken", token, 500));
            p.Add(P.NVar("@Platform", platform, 20));
        }, ct);
}
