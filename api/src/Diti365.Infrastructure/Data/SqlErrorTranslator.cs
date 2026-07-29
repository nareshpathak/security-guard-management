using Diti365.Domain;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Data;

/// <summary>
/// Turns SQL Server errors into either a retryable signal or a DomainException.
///
/// The stored procedures THROW in the 51000-51999 range. Each number has a stable
/// meaning, so the mapping lives in one table rather than being re-derived from the
/// message text anywhere.
/// </summary>
internal static class SqlErrorTranslator
{
    /// <summary>Deadlock, timeout and the Azure SQL transient family.</summary>
    private static readonly HashSet<int> Transient =
    [
        1205,   // deadlock victim
        -2,     // command timeout
        4060, 40197, 40501, 40613, 49918, 49919, 49920,
        10928, 10929, 10053, 10054, 10060, 233, 64, 20
    ];

    public static bool IsTransient(SqlException ex) =>
        ex.Errors.Cast<SqlError>().Any(e => Transient.Contains(e.Number));

    /// <summary>
    /// Maps a procedure THROW number to an API error code and HTTP status.
    /// Keep this in step with the THROW numbers in db/scripts/5*.sql and 600_triggers.sql.
    /// </summary>
    public static DomainException? Translate(SqlException ex)
    {
        var e = ex.Errors.Cast<SqlError>().FirstOrDefault(x => x.Number is >= 51000 and <= 51999);
        if (e is null) return null;

        var (code, status) = e.Number switch
        {
            // triggers, 600_triggers.sql
            51001 => (ErrorCodes.LicenceUserLimit,     402),
            51002 => (ErrorCodes.PayrollRunLocked,     409),
            51003 => (ErrorCodes.ValidationFailed,     422),
            51004 => (ErrorCodes.MockLocationDetected, 422),
            51005 => (ErrorCodes.ValidationFailed,     422),

            // code generators, 300_functions.sql
            51010 or 51011 => (ErrorCodes.Conflict,    409),

            // auth and OTP, 510
            51020 => (ErrorCodes.RateLimited,          429),
            51021 => (ErrorCodes.NotFound,             404),
            51030 or 51031 => (ErrorCodes.ValidationFailed, 422),

            // attendance, 520
            51100 => (ErrorCodes.MockLocationDetected, 422),
            51101 => (ErrorCodes.AttendanceLocked,     409),
            51102 => (ErrorCodes.ValidationFailed,     422),
            51103 => (ErrorCodes.NotFound,             404),
            51104 => (ErrorCodes.GeofenceViolation,    422),
            51105 => (ErrorCodes.DuplicatePunch,       409),
            51106 => (ErrorCodes.ValidationFailed,     422),
            51107 => (ErrorCodes.ValidationFailed,     422),
            51108 => (ErrorCodes.PermissionDenied,     403),

            // deployment, 521
            51200 => (ErrorCodes.PermissionDenied,     403),
            51201 or 51202 => (ErrorCodes.NotFound,    404),
            51203 or 51204 => (ErrorCodes.Conflict,    409),
            51205 or 51206 or 51207 => (ErrorCodes.ValidationFailed, 422),

            // patrol, 522
            51300 => (ErrorCodes.PermissionDenied,     403),
            51301 or 51303 or 51305 => (ErrorCodes.NotFound, 404),
            51302 => (ErrorCodes.MockLocationDetected, 422),
            51304 => (ErrorCodes.ValidationFailed,     422),

            // people, 523
            51400 => (ErrorCodes.Conflict,             409),
            51401 or 51403 or 51404 or 51405 or 51410 or 51412 => (ErrorCodes.NotFound, 404),
            51402 or 51406 or 51407 or 51409 => (ErrorCodes.ValidationFailed, 422),
            51408 => (ErrorCodes.DuplicateAadhaar,     409),
            51411 => (ErrorCodes.PermissionDenied,     403),

            // incidents and complaints, 524
            51500 => (ErrorCodes.PermissionDenied,     403),
            51501 or 51502 or 51503 or 51504 => (ErrorCodes.ValidationFailed, 422),
            51505 => (ErrorCodes.NotFound,             404),

            // inventory and HR, 525
            51600 or 51605 or 51606 or 51607 => (ErrorCodes.ValidationFailed, 422),
            51601 or 51603 => (ErrorCodes.NotFound,    404),
            51602 or 51604 or 51608 => (ErrorCodes.Conflict, 409),

            // tasks, 530
            51700 or 51701 or 51703 => (ErrorCodes.ValidationFailed, 422),
            51702 => (ErrorCodes.PermissionDenied,     403),

            // sales, 540
            51800 => (ErrorCodes.ValidationFailed,     422),
            51801 => (ErrorCodes.PermissionDenied,     403),

            // payroll and billing, 560
            51900 => (ErrorCodes.Conflict,             409),
            51901 or 51902 => (ErrorCodes.PayrollRunLocked, 409),
            51903 or 51905 => (ErrorCodes.ValidationFailed, 422),
            51904 => (ErrorCodes.Conflict,             409),
            51950 => (ErrorCodes.PermissionDenied,     403),

            _ => (ErrorCodes.ValidationFailed,         422)
        };

        return new DomainException(code, e.Message, status, inner: ex);
    }
}
