using Diti365.Api.Controllers;
using Diti365.Application.Abstractions;
using Diti365.Contracts.Auth;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Diti365.Infrastructure.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Diti365.Api.Controllers.V2;

[Route("api/v2/auth")]
public sealed class AuthController(
    ICurrentUser currentUser,
    IAuthService auth,
    IAuthRepository repo) : ApiControllerBase(currentUser)
{
    /// <summary>Signs in and returns an access token plus a rotating refresh token.</summary>
    [HttpPost("login"), AllowAnonymous, EnableRateLimiting("auth")]
    [ProducesResponseType<ApiResponse<LoginResponse>>(200)]
    [ProducesResponseType(401), ProducesResponseType(402), ProducesResponseType(403), ProducesResponseType(423)]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Login([FromBody] LoginRequest request) =>
        Data(await auth.LoginAsync(request, ClientIp, Ct));

    [HttpPost("refresh"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<ActionResult<ApiResponse<LoginResponse>>> Refresh([FromBody] RefreshRequest request) =>
        Data(await auth.RefreshAsync(request, ClientIp, Ct));

    [HttpPost("logout")]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest request)
    {
        await auth.LogoutAsync(request.RefreshToken, Me.UserId, Ct);
        return NoContent();
    }

    [HttpPost("otp/request"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<IActionResult> RequestOtp([FromBody] OtpRequest request)
    {
        // Always 202, whether or not the number is registered. Telling the caller which
        // numbers exist would turn this into an account-enumeration endpoint.
        await auth.RequestOtpAsync(request.MobileNo, request.Purpose, Ct);
        return Accepted();
    }

    /// <summary>Returns a ten-minute token that authorises a password reset and nothing else.</summary>
    [HttpPost("otp/verify"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<ActionResult<ApiResponse<OtpVerifyResponse>>> VerifyOtp([FromBody] OtpVerifyRequest request) =>
        Data(new OtpVerifyResponse(await auth.VerifyOtpAsync(request.MobileNo, request.Otp, request.Purpose, Ct)));

    [HttpPost("password/reset"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
    {
        await auth.ResetPasswordAsync(request, Ct);
        return NoContent();
    }

    [HttpPost("password/change")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequest request)
    {
        await auth.ChangePasswordAsync(Me.UserId, User.Identity?.Name ?? string.Empty, request, Ct);
        return NoContent();
    }

    [HttpPost("device/verify")]
    public async Task<ActionResult<ApiResponse<SpResult>>> VerifyDevice([FromBody] DeviceVerifyRequest request) =>
        Command(await repo.CheckDeviceAsync(Me.UserId, request.DeviceId, Ct));

    [HttpPost("device/token")]
    public async Task<ActionResult<ApiResponse<SpResult>>> UpdateToken([FromBody] UpdateTokenRequest request) =>
        Command(await repo.UpdateFcmTokenAsync(Me.UserId, request.FcmToken, request.Platform, Ct));

    [HttpGet("mobile/{mobileNo}/exists"), AllowAnonymous, EnableRateLimiting("auth")]
    public async Task<ActionResult<ApiResponse<SpResult>>> CheckMobile(string mobileNo) =>
        Command(await repo.CheckMobileAsync(mobileNo, Ct));
}
