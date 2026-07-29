using System.Data;
using Diti365.Contracts.Common;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Data;

/// <summary>
/// The only abstraction over the database, and the only type in the solution allowed
/// to construct a SqlConnection.
///
/// Every call is a stored procedure. There is no method that accepts SQL text, by
/// design: if a query is needed, a procedure is added to db/scripts/.
///
/// @CompanyID and @UserID are appended from ICurrentUser, never from a caller
/// argument, so a repository cannot accidentally accept a tenant id from the request.
/// </summary>
public interface IDbExecutor
{
    Task<IReadOnlyList<T>> QueryAsync<T>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory,
        CancellationToken ct);

    Task<T?> QuerySingleAsync<T>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory,
        CancellationToken ct);

    /// <summary>Result set 1 = rows, result set 2 = a single TotalRows column.</summary>
    Task<PagedResult<T>> QueryPagedAsync<T>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory,
        CancellationToken ct);

    /// <summary>Reads several result sets from one procedure. Used by the 360 and dashboard calls.</summary>
    Task<T> QueryMultipleAsync<T>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, CancellationToken, Task<T>> read,
        CancellationToken ct);

    /// <summary>A command procedure: returns the single (Success, Status, Id, Message) row.</summary>
    Task<SpResult> ExecuteAsync(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        CancellationToken ct);

    /// <summary>A command procedure that returns no envelope. Yields the affected-row count.</summary>
    Task<int> ExecuteNonQueryAsync(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        CancellationToken ct);

    Task<T?> ExecuteScalarAsync<T>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        CancellationToken ct);

    /// <summary>
    /// Bulk write through a table-valued parameter. Used by the mobile offline sync
    /// batch and the batched location pings - never loop and call a single-row
    /// procedure N times.
    /// </summary>
    Task<IReadOnlyList<T>> ExecuteTvpAsync<T>(
        string procedure,
        string tvpParameterName,
        string tvpTypeName,
        DataTable rows,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory,
        CancellationToken ct);
}
