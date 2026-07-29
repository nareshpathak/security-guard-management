using System.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Data;

/// <summary>
/// Typed SqlParameter factories.
///
/// AddWithValue is deliberately absent. It infers the type from the CLR value, so a
/// string parameter arrives as NVARCHAR(4000) rather than NVARCHAR(50), which forces
/// an implicit conversion, discards the index and produces a different cached plan for
/// every distinct string length. Always state the type and the size.
/// </summary>
public static class P
{
    public static SqlParameter Int(string name, int? value) =>
        new(name, SqlDbType.Int) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter BigInt(string name, long? value) =>
        new(name, SqlDbType.BigInt) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter TinyInt(string name, byte? value) =>
        new(name, SqlDbType.TinyInt) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter SmallInt(string name, short? value) =>
        new(name, SqlDbType.SmallInt) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter NVar(string name, string? value, int size) =>
        new(name, SqlDbType.NVarChar, size) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter NVarMax(string name, string? value) =>
        new(name, SqlDbType.NVarChar, -1) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Char(string name, string? value, int size) =>
        new(name, SqlDbType.Char, size) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Bit(string name, bool? value) =>
        new(name, SqlDbType.Bit) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Date(string name, DateOnly? value) =>
        new(name, SqlDbType.Date) { Value = value.HasValue ? value.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value };

    public static SqlParameter DateTime2(string name, DateTime? value) =>
        new(name, SqlDbType.DateTime2) { Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Time(string name, TimeOnly? value) =>
        new(name, SqlDbType.Time) { Value = value.HasValue ? value.Value.ToTimeSpan() : DBNull.Value };

    /// <summary>Money. Always 18,2 - see docs/prd/01-database.md §1.</summary>
    public static SqlParameter Money(string name, decimal? value) =>
        new(name, SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = (object?)value ?? DBNull.Value };

    /// <summary>Latitude or longitude. Always 10,7.</summary>
    public static SqlParameter Coord(string name, decimal? value) =>
        new(name, SqlDbType.Decimal) { Precision = 10, Scale = 7, Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Dec(string name, decimal? value, byte precision, byte scale) =>
        new(name, SqlDbType.Decimal) { Precision = precision, Scale = scale, Value = (object?)value ?? DBNull.Value };

    public static SqlParameter Guid(string name, Guid? value) =>
        new(name, SqlDbType.UniqueIdentifier) { Value = (object?)value ?? DBNull.Value };

    /// <summary>Table-valued parameter. The type name must match the SQL type exactly.</summary>
    public static SqlParameter Tvp(string name, string typeName, DataTable rows) =>
        new(name, SqlDbType.Structured) { TypeName = typeName, Value = rows };

    public static SqlParameter OutInt(string name) =>
        new(name, SqlDbType.Int) { Direction = ParameterDirection.Output };

    public static SqlParameter OutNVar(string name, int size) =>
        new(name, SqlDbType.NVarChar, size) { Direction = ParameterDirection.Output };
}
