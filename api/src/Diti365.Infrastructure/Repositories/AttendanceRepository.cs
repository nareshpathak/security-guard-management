using System.Data;
using Diti365.Contracts.Attendance;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

public interface IAttendanceRepository
{
    Task<SpResult> PunchInAsync(int empId, PunchRequest req, CancellationToken ct);
    Task<SpResult> PunchOutAsync(int empId, PunchRequest req, CancellationToken ct);
    Task<IReadOnlyList<SyncOutcome>> SyncBatchAsync(IReadOnlyList<OfflinePunch> punches, CancellationToken ct);
    Task<SpResult> BulkMarkAsync(int unitId, DateOnly date, int shiftId, IEnumerable<int> empIds, string status, string? remark, CancellationToken ct);
    Task<PagedResult<ApprovalRow>> GetForApprovalAsync(int? unitId, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);
    Task<SpResult> ApproveAsync(IEnumerable<long> ids, bool approve, string? reason, CancellationToken ct);
    Task<PagedResult<AttendanceRow>> GetAsync(int? unitId, int? empId, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);
    Task<SelfAttendanceResponse> GetSelfAsync(int empId, string monthYear, CancellationToken ct);
    Task<PagedResult<AttendanceSummaryRow>> GetSummaryAsync(string monthYear, int? unitId, int? branchId, int page, int pageSize, CancellationToken ct);
    Task<AttendanceCounts> GetCountsAsync(int? empId, DateOnly? onDate, CancellationToken ct);
}

public sealed class AttendanceRepository(IDbExecutor db) : IAttendanceRepository
{
    public Task<SpResult> PunchInAsync(int empId, PunchRequest q, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Attendance_InsertPunchIn", p =>
        {
            p.Add(P.Int  ("@EmpID",              empId));
            p.Add(P.Int  ("@UnitID",             q.UnitId));
            p.Add(P.Int  ("@ShiftID",            q.ShiftId));
            p.Add(P.DateTime2("@PunchAt",        q.PunchAt));
            p.Add(P.Coord("@Latitude",           q.Latitude));
            p.Add(P.Coord("@Longitude",          q.Longitude));
            p.Add(P.NVar ("@SelfieUrl",          q.SelfieUrl, 500));
            p.Add(P.Bit  ("@IsMockLocation",     q.IsMockLocation));
            p.Add(P.Bit  ("@IsOffline",          q.IsOffline));
            p.Add(P.Guid ("@ClientRequestId",    q.ClientRequestId));
            p.Add(P.NVar ("@DeviceID",           q.DeviceId, 200));
            p.Add(P.NVar ("@AppVersion",         q.AppVersion, 20));
            p.Add(P.Bit  ("@AllowOutOfGeofence", q.AllowOutOfGeofence));
            p.Add(P.NVar ("@Remark",             q.Remark, 500));
        }, ct);

    public Task<SpResult> PunchOutAsync(int empId, PunchRequest q, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Attendance_InsertPunchOut", p =>
        {
            p.Add(P.Int  ("@EmpID",              empId));
            p.Add(P.Int  ("@UnitID",             q.UnitId));
            p.Add(P.Int  ("@ShiftID",            q.ShiftId));
            p.Add(P.DateTime2("@PunchAt",        q.PunchAt));
            p.Add(P.Coord("@Latitude",           q.Latitude));
            p.Add(P.Coord("@Longitude",          q.Longitude));
            p.Add(P.NVar ("@SelfieUrl",          q.SelfieUrl, 500));
            p.Add(P.Bit  ("@IsMockLocation",     q.IsMockLocation));
            p.Add(P.Bit  ("@IsOffline",          q.IsOffline));
            p.Add(P.Guid ("@ClientRequestId",    q.ClientRequestId));
            p.Add(P.NVar ("@DeviceID",           q.DeviceId, 200));
            p.Add(P.NVar ("@AppVersion",         q.AppVersion, 20));
            p.Add(P.Bit  ("@AllowOutOfGeofence", q.AllowOutOfGeofence));
        }, ct);

    /// <summary>
    /// One round trip for the whole outbox. A rejected punch does not abort the batch:
    /// the procedure returns a per-row outcome so the phone can clear what was accepted
    /// and surface only the genuine failures.
    /// </summary>
    public Task<IReadOnlyList<SyncOutcome>> SyncBatchAsync(IReadOnlyList<OfflinePunch> punches, CancellationToken ct)
    {
        var table = new DataTable();
        table.Columns.Add("ClientRequestId", typeof(Guid));
        table.Columns.Add("EmpID",           typeof(int));
        table.Columns.Add("UnitID",          typeof(int));
        table.Columns.Add("ShiftID",         typeof(int));
        table.Columns.Add("PunchAt",         typeof(DateTime));
        table.Columns.Add("Latitude",        typeof(decimal));
        table.Columns.Add("Longitude",       typeof(decimal));
        table.Columns.Add("Direction",       typeof(string));
        table.Columns.Add("SelfieUrl",       typeof(string));
        table.Columns.Add("IsMockLocation",  typeof(bool));
        table.Columns.Add("DeviceID",        typeof(string));
        table.Columns.Add("AppVersion",      typeof(string));

        foreach (var x in punches)
        {
            table.Rows.Add(
                x.ClientRequestId, x.EmpId, x.UnitId, (object?)x.ShiftId ?? DBNull.Value, x.PunchAt,
                (object?)x.Latitude ?? DBNull.Value, (object?)x.Longitude ?? DBNull.Value,
                // CHAR(3): 'IN ' is padded, 'OUT' is not.
                x.Direction.Trim().Equals("IN", StringComparison.OrdinalIgnoreCase) ? "IN " : "OUT",
                (object?)x.SelfieUrl ?? DBNull.Value, x.IsMockLocation,
                (object?)x.DeviceId ?? DBNull.Value, (object?)x.AppVersion ?? DBNull.Value);
        }

        return db.ExecuteTvpAsync("dbo.usp_Attendance_SyncBatch",
            "@Punches", "ops.AttendancePunchList", table, null, Map.SyncOutcome, ct);
    }

    public Task<SpResult> BulkMarkAsync(int unitId, DateOnly date, int shiftId, IEnumerable<int> empIds,
                                        string status, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Attendance_Insert", p =>
        {
            p.Add(P.Int ("@UnitID",         unitId));
            p.Add(P.Date("@AttendanceDate", date));
            p.Add(P.Int ("@ShiftID",        shiftId));
            p.Add(P.NVarMax("@EmpIdsCsv",   string.Join(',', empIds)));
            p.Add(P.Char("@Status",         status.PadRight(2), 2));
            p.Add(P.NVar("@Remark",         remark, 500));
        }, ct);

    public Task<PagedResult<ApprovalRow>> GetForApprovalAsync(
        int? unitId, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Attendance_GetForApproval", p =>
        {
            p.Add(P.Int ("@UnitID",   unitId));
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.ApprovalRow, ct);

    public Task<SpResult> ApproveAsync(IEnumerable<long> ids, bool approve, string? reason, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Attendance_Approve", p =>
        {
            p.Add(P.NVarMax("@AttendanceIdsCsv", string.Join(',', ids)));
            p.Add(P.Bit    ("@Approve",          approve));
            p.Add(P.NVar   ("@RejectReason",     reason, 300));
        }, ct);

    public Task<PagedResult<AttendanceRow>> GetAsync(
        int? unitId, int? empId, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Attendance_Get", p =>
        {
            p.Add(P.Int ("@UnitID",   unitId));
            p.Add(P.Int ("@EmpID",    empId));
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.AttendanceRow, ct);

    public Task<SelfAttendanceResponse> GetSelfAsync(int empId, string monthYear, CancellationToken ct) =>
        db.QueryMultipleAsync("dbo.usp_Attendance_GetSelf", p =>
        {
            p.Add(P.Int ("@EmpID",     empId));
            p.Add(P.Char("@MonthYear", monthYear, 7));
        }, async (reader, token) =>
        {
            var days = new List<SelfAttendanceDay>();
            if (reader.HasRows)
            {
                var map = Map.SelfAttendanceDay(reader);
                while (await reader.ReadAsync(token).ConfigureAwait(false)) days.Add(map(reader));
            }

            var totals = new SelfAttendanceTotals(0, 0, 0, 0, 0);
            if (await reader.NextResultAsync(token).ConfigureAwait(false)
                && await reader.ReadAsync(token).ConfigureAwait(false))
            {
                totals = new SelfAttendanceTotals(
                    reader.Dec(reader.GetOrdinal("PresentDays")),
                    reader.IntN(reader.GetOrdinal("HalfDays")) ?? 0,
                    reader.IntN(reader.GetOrdinal("AbsentDays")) ?? 0,
                    reader.IntN(reader.GetOrdinal("LeaveDays")) ?? 0,
                    reader.Dec(reader.GetOrdinal("OtHours")));
            }

            return new SelfAttendanceResponse(days, totals);
        }, ct);

    public Task<PagedResult<AttendanceSummaryRow>> GetSummaryAsync(
        string monthYear, int? unitId, int? branchId, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Attendance_GetSummary", p =>
        {
            p.Add(P.Char("@MonthYear", monthYear, 7));
            p.Add(P.Int ("@UnitID",    unitId));
            p.Add(P.Int ("@BranchID",  branchId));
            p.Add(P.Int ("@PageNo",    page));
            p.Add(P.Int ("@PageSize",  pageSize));
        }, Map.AttendanceSummaryRow, ct);

    public async Task<AttendanceCounts> GetCountsAsync(int? empId, DateOnly? onDate, CancellationToken ct)
    {
        var row = await db.QuerySingleAsync<AttendanceCounts>("dbo.usp_Attendance_GetCount", p =>
        {
            p.Add(P.Int ("@EmpID",  empId));
            p.Add(P.Date("@OnDate", onDate));
        }, r =>
        {
            int a = r.GetOrdinal("AttendanceCount"), pr = r.GetOrdinal("PresentCount"),
                ab = r.GetOrdinal("AbsentCount"), pe = r.GetOrdinal("PendingCount");
            return reader => new AttendanceCounts(
                reader.IntN(a) ?? 0, reader.IntN(pr) ?? 0, reader.IntN(ab) ?? 0, reader.IntN(pe) ?? 0);
        }, ct).ConfigureAwait(false);

        return row ?? new AttendanceCounts(0, 0, 0, 0);
    }
}
