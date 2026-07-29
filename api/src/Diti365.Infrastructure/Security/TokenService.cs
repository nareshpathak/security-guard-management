using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Diti365.Contracts.Auth;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace Diti365.Infrastructure.Security;

public interface ITokenService
{
    (string Token, DateTime ExpiresAt) CreateAccessToken(AuthUser user, IReadOnlyList<string> permissions, string? deviceId);
    string CreateRefreshToken();
    string HashRefreshToken(string token);

    /// <summary>Short-lived, single-purpose token proving an OTP was verified.</summary>
    string CreatePasswordResetToken(int userId);

    /// <summary>Returns the user id the reset token was minted for, or null if it is not valid.</summary>
    int? ReadPasswordResetToken(string token);
}

public sealed class TokenService(IOptions<JwtOptions> options) : ITokenService
{
    private readonly JwtOptions _o = options.Value;

    public (string Token, DateTime ExpiresAt) CreateAccessToken(
        AuthUser user, IReadOnlyList<string> permissions, string? deviceId)
    {
        var expires = DateTime.UtcNow.AddMinutes(_o.AccessTokenMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.UserId.ToString()),
            new(ClaimTypes.NameIdentifier,   user.UserId.ToString()),
            new(ClaimTypes.Name,             user.UserName),
            new(DitiClaims.RoleCode,         user.RoleCode),
            new(ClaimTypes.Role,             user.RoleCode),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N"))
        };

        if (user.CompanyId is not null) claims.Add(new Claim(DitiClaims.CompanyId, user.CompanyId.Value.ToString()));
        if (user.BranchId  is not null) claims.Add(new Claim(DitiClaims.BranchId,  user.BranchId.Value.ToString()));
        if (user.EmpId     is not null) claims.Add(new Claim(DitiClaims.EmpId,     user.EmpId.Value.ToString()));
        if (user.ClientId  is not null) claims.Add(new Claim(DitiClaims.ClientId,  user.ClientId.Value.ToString()));
        if (user.LoginType is not null) claims.Add(new Claim(DitiClaims.LoginType, user.LoginType.Value.ToString()));
        if (!string.IsNullOrWhiteSpace(deviceId)) claims.Add(new Claim(DitiClaims.DeviceId, deviceId));

        claims.AddRange(permissions.Select(p => new Claim(DitiClaims.Perms, p)));

        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.SigningKey));
        var token = new JwtSecurityToken(
            issuer: _o.Issuer,
            audience: _o.Audience,
            claims: claims,
            notBefore: DateTime.UtcNow,
            expires: expires,
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }

    /// <summary>
    /// Proof that an OTP was verified, valid for ten minutes and for nothing else.
    ///
    /// The alternative - handing the caller a user id after OTP verification and
    /// letting them post it back with a new password - would let anyone reset
    /// any account by guessing an integer. The purpose claim means this token
    /// cannot be presented as an access token either: the API's bearer scheme
    /// rejects it because it carries no permissions and the wrong audience.
    /// </summary>
    public string CreatePasswordResetToken(int userId)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.SigningKey));
        var token = new JwtSecurityToken(
            issuer: _o.Issuer,
            audience: ResetAudience,
            claims:
            [
                new Claim(JwtRegisteredClaimNames.Sub, userId.ToString()),
                new Claim(PurposeClaim, ResetPurpose),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N"))
            ],
            notBefore: DateTime.UtcNow,
            expires: DateTime.UtcNow.AddMinutes(10),
            signingCredentials: new SigningCredentials(key, SecurityAlgorithms.HmacSha256));

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public int? ReadPasswordResetToken(string token)
    {
        try
        {
            var principal = new JwtSecurityTokenHandler().ValidateToken(token, new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = _o.Issuer,
                ValidateAudience = true,
                ValidAudience = ResetAudience,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.FromSeconds(30),
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.SigningKey))
            }, out _);

            if (principal.FindFirst(PurposeClaim)?.Value != ResetPurpose) return null;

            return int.TryParse(principal.FindFirst(JwtRegisteredClaimNames.Sub)?.Value, out var id)
                ? id
                : null;
        }
        catch
        {
            // Expired, tampered with, or minted for something else. All the same
            // answer to the caller: this token is no good.
            return null;
        }
    }

    private const string PurposeClaim = "diti:purpose";
    private const string ResetPurpose = "password_reset";
    private const string ResetAudience = "diti365:password-reset";

    /// <summary>An opaque 256-bit random value. Only its hash is stored.</summary>
    public string CreateRefreshToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));

    public string HashRefreshToken(string token) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
