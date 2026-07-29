using Diti365.Application.Abstractions;
using Diti365.Contracts.Auth;
using Diti365.Domain;
using Diti365.Infrastructure.Repositories;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Diti365.Infrastructure.Security;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest req, string? ip, CancellationToken ct);
    Task<LoginResponse> RefreshAsync(RefreshRequest req, string? ip, CancellationToken ct);
    Task LogoutAsync(string refreshToken, int userId, CancellationToken ct);
    Task<IReadOnlyList<string>> GetPermissionCodesAsync(int companyId, int userId, CancellationToken ct);
    Task ChangePasswordAsync(int userId, string loginId, ChangePasswordRequest req, CancellationToken ct);
    Task RequestOtpAsync(string mobileNo, string purpose, CancellationToken ct);
    Task<string> VerifyOtpAsync(string mobileNo, string otp, string purpose, CancellationToken ct);
    Task ResetPasswordAsync(ResetPasswordRequest req, CancellationToken ct);
}

/// <summary>
/// The three-step login described in DECISIONS.md #19:
///   1. usp_User_GetForAuthentication returns the hash, salt and lock state
///   2. PBKDF2 verification happens here, in C#
///   3. usp_User_LoginSucceeded or usp_User_LoginFailed records the outcome
///
/// Every failure path returns the same message and takes a comparable amount of work,
/// so the response does not reveal whether an account exists.
/// </summary>
public sealed class AuthService(
    IAuthRepository repo,
    IPasswordHasher hasher,
    ITokenService tokens,
    IRefreshTokenStore refreshStore,
    IOtpService otp,
    IOptions<JwtOptions> jwtOptions,
    IHostEnvironment env,
    ILogger<AuthService> logger) : IAuthService
{
    private readonly JwtOptions _jwt = jwtOptions.Value;
    private const string GenericFailure = "The login id or password is incorrect.";

    public async Task<LoginResponse> LoginAsync(LoginRequest req, string? ip, CancellationToken ct)
    {
        var candidate = await repo.GetForAuthenticationAsync(req.LoginId, ct).ConfigureAwait(false);

        if (candidate is null)
        {
            // Spend comparable time so a missing account is not distinguishable by timing.
            hasher.Hash(req.Password);
            await repo.LoginFailedAsync(req.LoginId, "No such user", req, ip, ct).ConfigureAwait(false);
            throw new DomainException(ErrorCodes.AuthInvalidCredentials, GenericFailure, 401);
        }

        if (candidate.IsLocked && candidate.LockedUntil > DateTime.UtcNow)
        {
            throw new DomainException(ErrorCodes.AuthAccountLocked,
                "This account is locked after too many failed attempts. Try again in a few minutes.", 423);
        }

        if (!candidate.IsActive)
            throw new DomainException(ErrorCodes.AuthAccountInactive, "This account is inactive.", 403);

        var verified = false;
        var needsRehash = false;

        if (!string.IsNullOrEmpty(candidate.PasswordHash) && !string.IsNullOrEmpty(candidate.PasswordSalt))
        {
            verified = hasher.Verify(req.Password, candidate.PasswordHash, candidate.PasswordSalt);
        }
        else if (!string.IsNullOrEmpty(candidate.LegacyPasswordHash))
        {
            verified = hasher.VerifyLegacy(req.Password, candidate.LegacyPasswordHash, env.IsDevelopment());
            needsRehash = verified;
        }

        if (!verified)
        {
            await repo.LoginFailedAsync(req.LoginId, "Bad password", req, ip, ct).ConfigureAwait(false);
            throw new DomainException(ErrorCodes.AuthInvalidCredentials, GenericFailure, 401);
        }

        // Licence checks happen after the password is proven, so an expired tenant does
        // not become an account-enumeration oracle.
        if (candidate.CompanyId is not null)
        {
            if (!candidate.CompanyIsActive || candidate.CompanyIsExpired ||
                (candidate.CompanyExpiryDate is { } exp && exp < DateOnly.FromDateTime(DateTime.UtcNow)))
            {
                throw new DomainException(ErrorCodes.LicenceExpired,
                    "This company's subscription has expired. Please contact your administrator.", 402);
            }
        }

        if (candidate.ExpiresOn is { } userExp && userExp < DateOnly.FromDateTime(DateTime.UtcNow))
            throw new DomainException(ErrorCodes.LicenceExpired, "This login has expired.", 402);

        // Device binding. A first login claims the device; a different device is refused.
        if (!string.IsNullOrWhiteSpace(req.DeviceId))
        {
            var device = await repo.CheckDeviceAsync(candidate.UserId, req.DeviceId!, ct).ConfigureAwait(false);
            if (!device.Success)
            {
                await repo.LoginFailedAsync(req.LoginId, "Device mismatch", req, ip, ct).ConfigureAwait(false);
                throw new DomainException(ErrorCodes.AuthDeviceNotRegistered,
                    "This account is registered on another device. Ask your administrator to reset it.", 403);
            }
        }

        if (needsRehash)
        {
            var (hash, salt) = hasher.Hash(req.Password);
            await repo.ChangePasswordAsync(candidate.UserId, hash, salt, ct).ConfigureAwait(false);
            logger.LogInformation("Upgraded the stored password for user {UserId} to PBKDF2.", candidate.UserId);
        }

        var user = await repo.LoginSucceededAsync(candidate.UserId, req, ip, ct).ConfigureAwait(false)
                   ?? throw new DomainException(ErrorCodes.Internal, "Login could not be completed.", 500);

        // The procedure returns the legacy payload; fill in the ids it does not carry.
        user = user with
        {
            EmpId = candidate.EmpId,
            ClientId = candidate.ClientId,
            UserName = candidate.UserName,
            BranchId = candidate.BranchId
        };

        var permissions = candidate.CompanyId is null
            ? Array.Empty<string>()
            : (await GetPermissionCodesAsync(candidate.CompanyId.Value, candidate.UserId, ct).ConfigureAwait(false)).ToArray();

        return await IssueAsync(user, permissions, req.DeviceId, ip, ct).ConfigureAwait(false);
    }

    public async Task<LoginResponse> RefreshAsync(RefreshRequest req, string? ip, CancellationToken ct)
    {
        var hash = tokens.HashRefreshToken(req.RefreshToken);
        var found = await refreshStore.FindAsync(hash, ct).ConfigureAwait(false)
                    ?? throw new DomainException(ErrorCodes.AuthRefreshInvalid, "The refresh token is not valid.", 401);

        // Reuse detection: a token that was already rotated means the family is
        // compromised, so every session for that user is revoked.
        if (found.RevokedAt is not null)
        {
            await refreshStore.RevokeAllForUserAsync(found.UserId, ct).ConfigureAwait(false);
            logger.LogWarning("Refresh token reuse detected for user {UserId}; all sessions revoked.", found.UserId);
            throw new DomainException(ErrorCodes.AuthRefreshInvalid, "This session is no longer valid. Please sign in again.", 401);
        }

        if (found.ExpiresAt < DateTime.UtcNow)
            throw new DomainException(ErrorCodes.AuthRefreshInvalid, "This session has expired. Please sign in again.", 401);

        var candidate = await repo.GetForAuthenticationAsync(found.UserId.ToString(), ct).ConfigureAwait(false);
        var user = await repo.LoginSucceededAsync(found.UserId,
                        new LoginRequest(string.Empty, string.Empty, req.DeviceId), ip, ct).ConfigureAwait(false)
                   ?? throw new DomainException(ErrorCodes.AuthRefreshInvalid, "This session is no longer valid.", 401);

        if (candidate is not null)
            user = user with { EmpId = candidate.EmpId, ClientId = candidate.ClientId, UserName = candidate.UserName };

        var permissions = user.CompanyId is null
            ? Array.Empty<string>()
            : (await GetPermissionCodesAsync(user.CompanyId.Value, found.UserId, ct).ConfigureAwait(false)).ToArray();

        var issued = await IssueAsync(user, permissions, req.DeviceId, ip, ct).ConfigureAwait(false);
        await refreshStore.RotateAsync(hash, tokens.HashRefreshToken(issued.RefreshToken), ct).ConfigureAwait(false);
        return issued;
    }

    public async Task LogoutAsync(string refreshToken, int userId, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(refreshToken))
            await refreshStore.RevokeAsync(tokens.HashRefreshToken(refreshToken), ct).ConfigureAwait(false);

        await repo.LogoutAsync(userId, ct).ConfigureAwait(false);
    }

    public async Task<IReadOnlyList<string>> GetPermissionCodesAsync(int companyId, int userId, CancellationToken ct)
    {
        var grants = await repo.GetPermissionsAsync(companyId, userId, ct).ConfigureAwait(false);
        return grants.Where(g => g.CanView || g.CanCreate || g.CanEdit || g.CanDelete || g.CanApprove || g.CanExport)
                     .Select(g => g.Code)
                     .Distinct(StringComparer.Ordinal)
                     .ToArray();
    }

    public async Task ChangePasswordAsync(int userId, string loginId, ChangePasswordRequest req, CancellationToken ct)
    {
        var candidate = await repo.GetForAuthenticationAsync(loginId, ct).ConfigureAwait(false)
                        ?? throw DomainException.NotFound("User");

        var ok = !string.IsNullOrEmpty(candidate.PasswordHash)
            ? hasher.Verify(req.CurrentPassword, candidate.PasswordHash!, candidate.PasswordSalt ?? string.Empty)
            : hasher.VerifyLegacy(req.CurrentPassword, candidate.LegacyPasswordHash ?? string.Empty, env.IsDevelopment());

        if (!ok)
            throw new DomainException(ErrorCodes.AuthInvalidCredentials, "The current password is incorrect.", 401);

        var (hash, salt) = hasher.Hash(req.NewPassword);
        await repo.ChangePasswordAsync(userId, hash, salt, ct).ConfigureAwait(false);

        // The procedure already revokes refresh tokens; this keeps the API side in step.
        await refreshStore.RevokeAllForUserAsync(userId, ct).ConfigureAwait(false);
    }

    public async Task RequestOtpAsync(string mobileNo, string purpose, CancellationToken ct)
    {
        var code = otp.Generate();
        await repo.GenerateOtpAsync(mobileNo, otp.Hash(mobileNo, code), purpose, ct).ConfigureAwait(false);
        await otp.SendAsync(mobileNo, code, ct).ConfigureAwait(false);
    }

    /// <summary>
    /// Verifies the code and returns a ten-minute token that authorises exactly
    /// one thing: setting this user's password.
    ///
    /// It deliberately does NOT return the user id. Handing an anonymous caller
    /// an integer and then accepting that integer on the reset endpoint would
    /// let anyone reset any account by counting upwards.
    /// </summary>
    public async Task<string> VerifyOtpAsync(string mobileNo, string code, string purpose, CancellationToken ct)
    {
        var result = await repo.VerifyOtpAsync(mobileNo, otp.Hash(mobileNo, code), purpose, ct).ConfigureAwait(false);
        if (!result.Success)
            throw new DomainException(ErrorCodes.ValidationFailed, result.Message, 422);

        return tokens.CreatePasswordResetToken(result.Id);
    }

    /// <summary>
    /// Sets a new password from a verified reset token.
    ///
    /// The OTP behind the token is already consumed by usp_User_VerifyOtp, so a
    /// second reset needs a second code. Every existing session is revoked:
    /// whoever asked for the reset may well be locking someone else out on
    /// purpose, and the old sessions must not survive that.
    /// </summary>
    public async Task ResetPasswordAsync(ResetPasswordRequest req, CancellationToken ct)
    {
        var userId = tokens.ReadPasswordResetToken(req.ResetToken)
                     ?? throw new DomainException(ErrorCodes.ValidationFailed,
                            "This reset link has expired. Request a new code.", 400);

        if (req.NewPassword.Length < 8)
            throw new DomainException(ErrorCodes.ValidationFailed,
                "Choose a password of at least 8 characters.", 400);

        var (hash, salt) = hasher.Hash(req.NewPassword);
        await repo.ChangePasswordAsync(userId, hash, salt, ct).ConfigureAwait(false);
        await refreshStore.RevokeAllForUserAsync(userId, ct).ConfigureAwait(false);
    }

    private async Task<LoginResponse> IssueAsync(
        AuthUser user, IReadOnlyList<string> permissions, string? deviceId, string? ip, CancellationToken ct)
    {
        var (access, expiresAt) = tokens.CreateAccessToken(user, permissions, deviceId);
        var refresh = tokens.CreateRefreshToken();

        await refreshStore.StoreAsync(
            user.UserId, tokens.HashRefreshToken(refresh),
            DateTime.UtcNow.AddDays(_jwt.RefreshTokenDays), ip, deviceId, ct).ConfigureAwait(false);

        return new LoginResponse(access, refresh, expiresAt, user, permissions);
    }
}
