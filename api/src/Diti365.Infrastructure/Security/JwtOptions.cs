namespace Diti365.Infrastructure.Security;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; set; } = "diti365";
    public string Audience { get; set; } = "diti365-clients";

    /// <summary>Minimum 32 bytes. Supplied from Key Vault or an environment variable, never committed.</summary>
    public string SigningKey { get; set; } = string.Empty;

    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;
}
