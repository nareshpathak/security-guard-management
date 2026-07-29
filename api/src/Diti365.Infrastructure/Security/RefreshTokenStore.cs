using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Options;

namespace Diti365.Infrastructure.Security;

public interface IRefreshTokenStore
{
    Task StoreAsync(int userId, string tokenHash, DateTime expiresAt, string? ip, string? deviceId, CancellationToken ct);
    Task<RefreshLookup?> FindAsync(string tokenHash, CancellationToken ct);
    Task RotateAsync(string oldHash, string newHash, CancellationToken ct);
    Task RevokeAsync(string tokenHash, CancellationToken ct);
    Task RevokeAllForUserAsync(int userId, CancellationToken ct);
}

public sealed record RefreshLookup(long TokenId, int UserId, DateTime ExpiresAt, DateTime? RevokedAt, string? ReplacedBy);

/// <summary>
/// Refresh tokens are the one place the API touches a table directly rather than a
/// business procedure, because they are pure session plumbing with no business rules.
/// Even so the statements are parameterised and confined to this class.
/// </summary>
public sealed class RefreshTokenStore(IOptions<DbOptions> options) : IRefreshTokenStore
{
    private readonly string _cs = options.Value.ConnectionString;

    public async Task StoreAsync(int userId, string tokenHash, DateTime expiresAt, string? ip, string? deviceId, CancellationToken ct)
    {
        const string sql = """
            INSERT INTO sec.RefreshToken (UserID, TokenHash, ExpiresAt, CreatedByIp, DeviceID)
            VALUES (@UserID, @TokenHash, @ExpiresAt, @Ip, @DeviceId);
            """;
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add(P.Int("@UserID", userId));
        cmd.Parameters.Add(P.NVar("@TokenHash", tokenHash, 200));
        cmd.Parameters.Add(P.DateTime2("@ExpiresAt", expiresAt));
        cmd.Parameters.Add(P.NVar("@Ip", ip, 45));
        cmd.Parameters.Add(P.NVar("@DeviceId", deviceId, 200));
        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }

    public async Task<RefreshLookup?> FindAsync(string tokenHash, CancellationToken ct)
    {
        const string sql = """
            SELECT TOP (1) TokenID, UserID, ExpiresAt, RevokedAt, ReplacedByTokenHash
            FROM sec.RefreshToken WHERE TokenHash = @TokenHash;
            """;
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add(P.NVar("@TokenHash", tokenHash, 200));
        await using var r = await cmd.ExecuteReaderAsync(ct).ConfigureAwait(false);
        if (!await r.ReadAsync(ct).ConfigureAwait(false)) return null;

        return new RefreshLookup(
            r.GetInt64(0), r.GetInt32(1), r.GetDateTime(2),
            r.IsDBNull(3) ? null : r.GetDateTime(3),
            r.IsDBNull(4) ? null : r.GetString(4));
    }

    public async Task RotateAsync(string oldHash, string newHash, CancellationToken ct)
    {
        const string sql = """
            UPDATE sec.RefreshToken
            SET RevokedAt = SYSDATETIME(), ReplacedByTokenHash = @NewHash
            WHERE TokenHash = @OldHash AND RevokedAt IS NULL;
            """;
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add(P.NVar("@OldHash", oldHash, 200));
        cmd.Parameters.Add(P.NVar("@NewHash", newHash, 200));
        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }

    public async Task RevokeAsync(string tokenHash, CancellationToken ct)
    {
        const string sql = "UPDATE sec.RefreshToken SET RevokedAt = SYSDATETIME() WHERE TokenHash = @TokenHash AND RevokedAt IS NULL;";
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add(P.NVar("@TokenHash", tokenHash, 200));
        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }

    public async Task RevokeAllForUserAsync(int userId, CancellationToken ct)
    {
        const string sql = "UPDATE sec.RefreshToken SET RevokedAt = SYSDATETIME() WHERE UserID = @UserID AND RevokedAt IS NULL;";
        await using var conn = new SqlConnection(_cs);
        await conn.OpenAsync(ct).ConfigureAwait(false);
        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.Add(P.Int("@UserID", userId));
        await cmd.ExecuteNonQueryAsync(ct).ConfigureAwait(false);
    }
}
