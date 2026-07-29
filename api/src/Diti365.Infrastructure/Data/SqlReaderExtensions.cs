using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Data;

/// <summary>
/// Null-safe readers. Every mapper caches its ordinals outside the row loop and then
/// calls these - reading by column name inside a loop is the single most common
/// performance mistake in ADO.NET code.
/// </summary>
public static class SqlReaderExtensions
{
    public static int      Int(this SqlDataReader r, int i)        => r.GetInt32(i);
    public static int?     IntN(this SqlDataReader r, int i)       => r.IsDBNull(i) ? null : r.GetInt32(i);
    public static long     Long(this SqlDataReader r, int i)       => r.GetInt64(i);
    public static long?    LongN(this SqlDataReader r, int i)      => r.IsDBNull(i) ? null : r.GetInt64(i);
    public static byte?    ByteN(this SqlDataReader r, int i)      => r.IsDBNull(i) ? null : r.GetByte(i);
    public static string   Str(this SqlDataReader r, int i)        => r.IsDBNull(i) ? string.Empty : r.GetString(i);
    public static string?  StrN(this SqlDataReader r, int i)       => r.IsDBNull(i) ? null : r.GetString(i);
    public static bool     Bool(this SqlDataReader r, int i)       => !r.IsDBNull(i) && r.GetBoolean(i);
    public static bool?    BoolN(this SqlDataReader r, int i)      => r.IsDBNull(i) ? null : r.GetBoolean(i);
    public static decimal  Dec(this SqlDataReader r, int i)        => r.IsDBNull(i) ? 0m : r.GetDecimal(i);
    public static decimal? DecN(this SqlDataReader r, int i)       => r.IsDBNull(i) ? null : r.GetDecimal(i);
    public static DateTime? DateTimeN(this SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetDateTime(i);

    public static DateOnly? DateN(this SqlDataReader r, int i) =>
        r.IsDBNull(i) ? null : DateOnly.FromDateTime(r.GetDateTime(i));

    public static TimeOnly? TimeN(this SqlDataReader r, int i) =>
        r.IsDBNull(i) ? null : TimeOnly.FromTimeSpan(r.GetTimeSpan(i));

    public static Guid? GuidN(this SqlDataReader r, int i) =>
        r.IsDBNull(i) ? null : r.GetGuid(i);

    /// <summary>
    /// Trim a CHAR(n) status. Attendance statuses are stored space padded ('P ', 'A '),
    /// so anything surfaced to the API must be trimmed exactly once, here.
    /// </summary>
    public static string Code(this SqlDataReader r, int i) =>
        r.IsDBNull(i) ? string.Empty : r.GetString(i).TrimEnd();

    /// <summary>Ordinal lookup that returns -1 instead of throwing when a column is absent.</summary>
    public static int OrdinalOrDefault(this SqlDataReader r, string name)
    {
        try { return r.GetOrdinal(name); }
        catch (IndexOutOfRangeException) { return -1; }
    }
}
