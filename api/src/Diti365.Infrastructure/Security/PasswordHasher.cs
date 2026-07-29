using System.Security.Cryptography;
using Microsoft.AspNetCore.Cryptography.KeyDerivation;

namespace Diti365.Infrastructure.Security;

public interface IPasswordHasher
{
    (string Hash, string Salt) Hash(string password);
    bool Verify(string password, string hash, string salt);
    bool VerifyLegacy(string password, string legacyHash, bool allowDevPlaintext);
}

/// <summary>
/// PBKDF2-SHA256, 210 000 iterations, 128-bit salt. docs/prd/05-rbac-and-nfr.md S2.
///
/// This cannot run in T-SQL, which is why the login flow is split across three
/// procedures rather than one. See DECISIONS.md #19.
/// </summary>
public sealed class PasswordHasher : IPasswordHasher
{
    private const int Iterations = 210_000;
    private const int SaltBytes = 16;
    private const int KeyBytes = 32;

    /// <summary>
    /// Seeded demo users carry 'PLAINTEXT:Admin@123'. Honoured only in Development,
    /// and re-hashed the moment the user logs in. DECISIONS.md #25.
    /// </summary>
    private const string DevPlaintextPrefix = "PLAINTEXT:";

    public (string Hash, string Salt) Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(SaltBytes);
        var key = KeyDerivation.Pbkdf2(password, salt, KeyDerivationPrf.HMACSHA256, Iterations, KeyBytes);
        return (Convert.ToBase64String(key), Convert.ToBase64String(salt));
    }

    public bool Verify(string password, string hash, string salt)
    {
        if (string.IsNullOrEmpty(hash) || string.IsNullOrEmpty(salt)) return false;

        byte[] saltBytes, expected;
        try
        {
            saltBytes = Convert.FromBase64String(salt);
            expected = Convert.FromBase64String(hash);
        }
        catch (FormatException) { return false; }

        var actual = KeyDerivation.Pbkdf2(password, saltBytes, KeyDerivationPrf.HMACSHA256, Iterations, expected.Length);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    public bool VerifyLegacy(string password, string legacyHash, bool allowDevPlaintext)
    {
        if (string.IsNullOrEmpty(legacyHash)) return false;

        if (legacyHash.StartsWith(DevPlaintextPrefix, StringComparison.Ordinal))
        {
            if (!allowDevPlaintext) return false;   // never outside Development
            var expected = legacyHash[DevPlaintextPrefix.Length..];
            return CryptographicOperations.FixedTimeEquals(
                System.Text.Encoding.UTF8.GetBytes(password),
                System.Text.Encoding.UTF8.GetBytes(expected));
        }

        // The legacy ASP.NET application stored an unsalted MD5 hex digest. Verifying it
        // here is the whole point of the migration path: on success the caller
        // immediately re-hashes with PBKDF2 and clears LegacyPasswordHash.
        var digest = Convert.ToHexString(
            System.Security.Cryptography.MD5.HashData(System.Text.Encoding.UTF8.GetBytes(password)));
        return string.Equals(digest, legacyHash.Replace("-", string.Empty), StringComparison.OrdinalIgnoreCase);
    }
}
