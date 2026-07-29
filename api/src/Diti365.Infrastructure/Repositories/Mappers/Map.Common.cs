using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

public static partial class Map
{
    /// <summary>
    /// The standard command envelope: Success, Status, Id, Message.
    ///
    /// IDbExecutor.ExecuteAsync already reads this shape directly, so this factory
    /// exists for the paths that cannot use it - ExecuteTvpAsync, which is generic
    /// over its result type because some batch procedures return per-row outcomes
    /// instead of a single envelope.
    ///
    /// Every ordinal is resolved with OrdinalOrDefault so a procedure that omits a
    /// column (several return no Id) maps to a sensible default rather than throwing.
    /// </summary>
    public static Func<SqlDataReader, SpResult> SpResult(SqlDataReader r)
    {
        var oSuccess = r.OrdinalOrDefault("Success");
        var oStatus  = r.OrdinalOrDefault("Status");
        var oId      = r.OrdinalOrDefault("Id");
        var oMessage = r.OrdinalOrDefault("Message");

        return row => new SpResult(
            oSuccess < 0 || row.Bool(oSuccess),
            oStatus  < 0 ? 200 : row.Int(oStatus),
            oId      < 0 ? 0   : row.IntN(oId) ?? 0,
            oMessage < 0 ? "OK" : row.Str(oMessage));
    }
}
