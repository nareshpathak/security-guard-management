using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

public static partial class Map
{
    /// <summary>
    /// Maps any result set to an ordered dictionary of column name to value.
    ///
    /// Used only by the report and dashboard endpoints. Those are generic grids: the
    /// web report shell renders whatever columns arrive, and the procedure is the
    /// contract. Writing a DTO per report would produce forty classes with no
    /// behaviour, and every column change would then need edits in three places
    /// instead of one.
    ///
    /// Domain endpoints - attendance, deployment, people, payroll - keep typed DTOs,
    /// because their shapes are consumed by real client logic rather than a grid.
    /// </summary>
    public static Func<SqlDataReader, IReadOnlyDictionary<string, object?>> Dynamic(SqlDataReader r)
    {
        var count = r.FieldCount;
        var names = new string[count];
        for (var i = 0; i < count; i++) names[i] = r.GetName(i);

        return row =>
        {
            var dict = new Dictionary<string, object?>(count, StringComparer.Ordinal);
            for (var i = 0; i < count; i++)
            {
                if (row.IsDBNull(i)) { dict[names[i]] = null; continue; }

                var value = row.GetValue(i);
                dict[names[i]] = value switch
                {
                    // CHAR(n) codes are space padded in the database; trim once, here.
                    string s when s.Length > 0 && s[^1] == ' ' => s.TrimEnd(),
                    DateTime dt when dt.TimeOfDay == TimeSpan.Zero => DateOnly.FromDateTime(dt),
                    TimeSpan ts => TimeOnly.FromTimeSpan(ts),
                    _ => value
                };
            }
            return dict;
        };
    }
}
