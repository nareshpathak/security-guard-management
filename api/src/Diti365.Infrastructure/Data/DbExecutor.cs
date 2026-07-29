using System.Collections.Concurrent;
using System.Data;
using System.Diagnostics;
using Diti365.Application.Abstractions;
using Diti365.Contracts.Common;
using Diti365.Domain;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Diti365.Infrastructure.Data;

/// <inheritdoc />
public sealed class DbExecutor(
    IOptions<DbOptions> options,
    ICurrentUser currentUser,
    ILogger<DbExecutor> logger) : IDbExecutor
{
    private readonly DbOptions _o = options.Value;

    /// <summary>
    /// Parameter names each procedure actually declares, asked of SQL Server once per
    /// procedure per process.
    ///
    /// This exists because 27 of the 150 procedures do not take @UserID, and blindly
    /// appending it produced "Procedure has too many arguments specified" - a 500 on
    /// perfectly good calls. Deriving the real signature is self-maintaining: add a
    /// parameter to a procedure later and the executor picks it up without a code change.
    /// </summary>
    private static readonly ConcurrentDictionary<string, HashSet<string>> ParameterCache = new(StringComparer.OrdinalIgnoreCase);

    // ---------------------------------------------------------------- public API

    public async Task<IReadOnlyList<T>> QueryAsync<T>(
        string procedure, Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory, CancellationToken ct)
        => await RunAsync(procedure, parameters, async (cmd, token) =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(token).ConfigureAwait(false);
            return await ReadAllAsync(reader, mapperFactory, token).ConfigureAwait(false);
        }, ct).ConfigureAwait(false);

    public async Task<T?> QuerySingleAsync<T>(
        string procedure, Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory, CancellationToken ct)
    {
        var rows = await QueryAsync(procedure, parameters, mapperFactory, ct).ConfigureAwait(false);
        return rows.Count == 0 ? default : rows[0];
    }

    public async Task<PagedResult<T>> QueryPagedAsync<T>(
        string procedure, Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory, CancellationToken ct)
        => await RunAsync(procedure, parameters, async (cmd, token) =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(token).ConfigureAwait(false);
            var items = await ReadAllAsync(reader, mapperFactory, token).ConfigureAwait(false);

            var total = items.Count;
            if (await reader.NextResultAsync(token).ConfigureAwait(false)
                && await reader.ReadAsync(token).ConfigureAwait(false))
            {
                total = reader.IsDBNull(0) ? items.Count : reader.GetInt32(0);
            }

            return new PagedResult<T>(items, total);
        }, ct).ConfigureAwait(false);

    public async Task<T> QueryMultipleAsync<T>(
        string procedure, Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, CancellationToken, Task<T>> read, CancellationToken ct)
        => await RunAsync(procedure, parameters, async (cmd, token) =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(token).ConfigureAwait(false);
            return await read(reader, token).ConfigureAwait(false);
        }, ct).ConfigureAwait(false);

    public async Task<SpResult> ExecuteAsync(
        string procedure, Action<SqlParameterCollection>? parameters, CancellationToken ct)
        => await RunAsync(procedure, parameters, async (cmd, token) =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(token).ConfigureAwait(false);
            if (!await reader.ReadAsync(token).ConfigureAwait(false))
                return new SpResult(true, 200, 0, "OK");

            var oSuccess = reader.OrdinalOrDefault("Success");
            var oStatus  = reader.OrdinalOrDefault("Status");
            var oId      = reader.OrdinalOrDefault("Id");
            var oMessage = reader.OrdinalOrDefault("Message");

            return new SpResult(
                oSuccess < 0 || reader.Bool(oSuccess),
                oStatus  < 0 ? 200 : reader.Int(oStatus),
                oId      < 0 ? 0   : reader.IntN(oId) ?? 0,
                oMessage < 0 ? "OK" : reader.Str(oMessage));
        }, ct).ConfigureAwait(false);

    public async Task<int> ExecuteNonQueryAsync(
        string procedure, Action<SqlParameterCollection>? parameters, CancellationToken ct)
        => await RunAsync(procedure, parameters,
            async (cmd, token) => await cmd.ExecuteNonQueryAsync(token).ConfigureAwait(false),
            ct).ConfigureAwait(false);

    public async Task<T?> ExecuteScalarAsync<T>(
        string procedure, Action<SqlParameterCollection>? parameters, CancellationToken ct)
        => await RunAsync(procedure, parameters, async (cmd, token) =>
        {
            var value = await cmd.ExecuteScalarAsync(token).ConfigureAwait(false);
            return value is null or DBNull ? default : (T)Convert.ChangeType(value, typeof(T));
        }, ct).ConfigureAwait(false);

    public async Task<IReadOnlyList<T>> ExecuteTvpAsync<T>(
        string procedure, string tvpParameterName, string tvpTypeName, DataTable rows,
        Action<SqlParameterCollection>? parameters,
        Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory, CancellationToken ct)
        => await RunAsync(procedure, p =>
        {
            parameters?.Invoke(p);
            p.Add(P.Tvp(tvpParameterName, tvpTypeName, rows));
        }, async (cmd, token) =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(token).ConfigureAwait(false);
            return await ReadAllAsync(reader, mapperFactory, token).ConfigureAwait(false);
        }, ct).ConfigureAwait(false);

    // ---------------------------------------------------------------- internals

    private static async Task<IReadOnlyList<T>> ReadAllAsync<T>(
        SqlDataReader reader, Func<SqlDataReader, Func<SqlDataReader, T>> mapperFactory, CancellationToken ct)
    {
        var results = new List<T>();
        if (!reader.HasRows) return results;

        // The factory resolves every ordinal exactly once, before the loop.
        var map = mapperFactory(reader);
        while (await reader.ReadAsync(ct).ConfigureAwait(false))
            results.Add(map(reader));

        return results;
    }

    private async Task<TResult> RunAsync<TResult>(
        string procedure,
        Action<SqlParameterCollection>? parameters,
        Func<SqlCommand, CancellationToken, Task<TResult>> body,
        CancellationToken ct)
    {
        var attempt = 0;
        var sw = Stopwatch.StartNew();

        while (true)
        {
            attempt++;
            try
            {
                await using var conn = new SqlConnection(_o.ConnectionString);
                await conn.OpenAsync(ct).ConfigureAwait(false);

                await using var cmd = new SqlCommand(procedure, conn)
                {
                    CommandType = CommandType.StoredProcedure,
                    CommandTimeout = _o.LongRunningProcedures.Contains(procedure)
                        ? _o.LongCommandTimeoutSeconds
                        : _o.CommandTimeoutSeconds
                };

                parameters?.Invoke(cmd.Parameters);
                InjectContext(cmd, procedure);

                var result = await body(cmd, ct).ConfigureAwait(false);

                sw.Stop();
                if (sw.ElapsedMilliseconds > _o.SlowQueryWarnMs)
                {
                    logger.LogWarning(
                        "Slow procedure {Procedure} took {ElapsedMs} ms (company {CompanyId}, user {UserId})",
                        procedure, sw.ElapsedMilliseconds, currentUser.CompanyId, currentUser.UserId);
                }
                else
                {
                    logger.LogDebug("{Procedure} took {ElapsedMs} ms", procedure, sw.ElapsedMilliseconds);
                }

                return result;
            }
            catch (SqlException ex)
            {
                // A procedure THROW is a business rule, never retry it.
                var domain = SqlErrorTranslator.Translate(ex);
                if (domain is not null)
                {
                    logger.LogInformation(
                        "{Procedure} rejected the request: {Code} {Message}",
                        procedure, domain.Code, domain.Message);
                    throw domain;
                }

                if (SqlErrorTranslator.IsTransient(ex) && attempt <= _o.RetryCount)
                {
                    var delay = _o.RetryBaseDelayMs * (int)Math.Pow(2, attempt - 1)
                                + Random.Shared.Next(0, 100);   // jitter, so retries do not converge
                    logger.LogWarning(ex,
                        "Transient SQL error on {Procedure}, attempt {Attempt} of {Max}, retrying in {Delay} ms",
                        procedure, attempt, _o.RetryCount, delay);
                    await Task.Delay(delay, ct).ConfigureAwait(false);
                    continue;
                }

                logger.LogError(ex, "SQL error on {Procedure}", procedure);
                throw new DomainException(ErrorCodes.Internal,
                    "A database error occurred. The trace id identifies this request in the logs.",
                    500, inner: ex);
            }
        }
    }

    /// <summary>
    /// Reads the procedure's real parameter list from SQL Server, once, and caches it.
    /// </summary>
    private static HashSet<string> GetDeclaredParameters(SqlConnection conn, string procedure)
    {
        return ParameterCache.GetOrAdd(procedure, name =>
        {
            using var probe = new SqlCommand(name, conn) { CommandType = CommandType.StoredProcedure };
            SqlCommandBuilder.DeriveParameters(probe);

            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (SqlParameter p in probe.Parameters)
                if (p.Direction != ParameterDirection.ReturnValue)
                    set.Add(p.ParameterName);

            return set;
        });
    }

    /// <summary>
    /// Appends @CompanyID and @UserID from the authenticated principal, and drops any
    /// parameter the procedure does not declare.
    ///
    /// Dropping is logged at Warning rather than being silent: a dropped parameter is
    /// usually a typo (@UnitId for @UnitID), and a filter that quietly stops applying
    /// is worse than one that fails loudly.
    /// </summary>
    private void InjectContext(SqlCommand cmd, string procedure)
    {
        var declared = GetDeclaredParameters(cmd.Connection!, procedure);

        if (!_o.TenantlessProcedures.Contains(procedure))
        {
            if (declared.Contains("@CompanyID") && !cmd.Parameters.Contains("@CompanyID"))
                cmd.Parameters.Add(P.Int("@CompanyID", currentUser.IsAuthenticated ? currentUser.CompanyId : null));

            if (declared.Contains("@UserID") && !cmd.Parameters.Contains("@UserID"))
                cmd.Parameters.Add(P.Int("@UserID", currentUser.IsAuthenticated ? currentUser.UserId : null));
        }

        for (var i = cmd.Parameters.Count - 1; i >= 0; i--)
        {
            var name = cmd.Parameters[i].ParameterName;
            if (declared.Contains(name)) continue;

            logger.LogWarning(
                "{Procedure} does not declare {Parameter}; it was dropped. Check for a typo in the repository.",
                procedure, name);
            cmd.Parameters.RemoveAt(i);
        }
    }
}
