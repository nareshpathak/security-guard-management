using System.Data;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

/// <summary>
/// Deployment, turnout, movement, patrol and tracking.
///
/// The read shapes here feed grids and map views rather than client-side business
/// logic, so they use the generic row mapper. The write methods stay strongly typed,
/// because those carry the rules that matter.
/// </summary>
public interface IOpsRepository
{
    // deployment
    Task<SpResult> DeployAsync(int empId, int unitId, int? postId, int? shiftId, DateOnly? fromDate,
                               bool isReliever, int? relieverForEmpId, string? remark,
                               bool allowOverStrength, string? overStrengthReason, CancellationToken ct);
    Task<SpResult> EndDeploymentAsync(int deploymentId, DateOnly? toDate, string? remark, CancellationToken ct);
    Task<PagedResult<Row>> GetDeploymentsAsync(int? unitId, int? empId, int? branchId, int? shiftId,
                                               bool onlyActive, string? search, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetUnitEmployeesAsync(int unitId, int? shiftId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetAvailableRelieversAsync(int unitId, DateOnly? onDate, int? shiftId, CancellationToken ct);

    // turnout
    Task<IReadOnlyList<Row>> GetLiveTurnoutAsync(DateOnly? onDate, int? branchId, int? clientId, int? shiftId, CancellationToken ct);
    Task<SpResult> SaveTurnoutAsync(int unitId, DateOnly date, int? shiftId, int required, int present,
                                    int absent, int reliever, string? remark, IEnumerable<int>? empIds, CancellationToken ct);
    Task<IReadOnlyList<Row>> DetectVacantPostsAsync(int minutesAhead, CancellationToken ct);

    // movement, inc/dec, contracts
    Task<SpResult> MovementAsync(int empId, int? fromUnitId, int? toUnitId, string? postName,
                                 DateOnly? date, TimeOnly? time, string? instructionBy, string? remark,
                                 bool applyNow, CancellationToken ct);
    Task<SpResult> IncDecAsync(int unitId, string changeType, DateOnly dated, int nop, string? timing,
                               int? designationId, int? shiftId, string? remark, CancellationToken ct);
    Task<SpResult> IncDecApproveAsync(int changeId, bool approve, string? remark, CancellationToken ct);
    Task<SpResult> ContractAsync(string contractType, int? clientId, int? unitId, DateOnly? dated, int nop,
                                 string? timing, DateOnly? from, DateOnly? to, string? remark, CancellationToken ct);
    Task<SpResult> TemporaryEventAsync(int? unitId, int? clientId, string? typeOfService, int? serviceTypeId,
                                       DateOnly startDate, DateOnly? endDate, TimeOnly? startTime, TimeOnly? endTime,
                                       int nop, decimal? rate, string? remark, CancellationToken ct);

    // patrol
    Task<SpResult> SaveCheckpointAsync(int unitId, string name, string? location, int? locationId,
                                       decimal? lat, decimal? lon, int maxDistance, bool requirePhoto,
                                       string? remark, int? qrId, CancellationToken ct);
    Task<PagedResult<Row>> GetCheckpointsAsync(int? unitId, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetCheckpointDistanceAsync(string qrCode, decimal? lat, decimal? lon, CancellationToken ct);
    Task<SpResult> ScanAsync(string qrCode, int? empId, decimal? lat, decimal? lon, string? imageUrl,
                             string? remark, DateTime? scantime, bool isMock, bool isOffline,
                             Guid? clientRequestId, string? deviceId, string? appVersion, CancellationToken ct);
    Task<PagedResult<Row>> GetScanLogAsync(int? unitId, int? qrId, int? empId, DateOnly? from, DateOnly? to,
                                           bool onlyOutOfRange, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetPatrolSummaryAsync(DateOnly? from, DateOnly? to, int? unitId, CancellationToken ct);
    Task<SpResult> SaveRoundAsync(int unitId, string roundName, TimeOnly start, TimeOnly end, int grace,
                                  string? daysOfWeek, IEnumerable<int>? qrIds, int? roundId, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetMyPatrolProgressAsync(int? unitId, CancellationToken ct);
    Task<IReadOnlyList<Row>> DetectMissedRoundsAsync(DateOnly? onDate, CancellationToken ct);

    // tracking
    Task<SpResult> TrackAsync(decimal lat, decimal lon, decimal? accuracy, decimal? speed, byte? battery,
                              DateTime? loggedAt, string source, bool isMock, string? deviceId, CancellationToken ct);
    Task<SpResult> TrackBatchAsync(IReadOnlyList<LocationPing> pings, string? deviceId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetLiveLocationsAsync(int staleMinutes, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetTrailAsync(int targetUserId, DateOnly? onDate, CancellationToken ct);
}

public sealed class OpsRepository(IDbExecutor db) : IOpsRepository
{
    // ------------------------------------------------------------ deployment

    public Task<SpResult> DeployAsync(int empId, int unitId, int? postId, int? shiftId, DateOnly? fromDate,
                                      bool isReliever, int? relieverForEmpId, string? remark,
                                      bool allowOverStrength, string? overStrengthReason, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Deployment_Insert", p =>
        {
            p.Add(P.Int ("@EmpID",              empId));
            p.Add(P.Int ("@UnitID",             unitId));
            p.Add(P.Int ("@PostID",             postId));
            p.Add(P.Int ("@ShiftID",            shiftId));
            p.Add(P.Date("@FromDate",           fromDate));
            p.Add(P.Bit ("@IsReliever",         isReliever));
            p.Add(P.Int ("@RelieverForEmpID",   relieverForEmpId));
            p.Add(P.NVar("@Remark",             remark, 500));
            p.Add(P.Bit ("@AllowOverStrength",  allowOverStrength));
            p.Add(P.NVar("@OverStrengthReason", overStrengthReason, 300));
        }, ct);

    public Task<SpResult> EndDeploymentAsync(int deploymentId, DateOnly? toDate, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Deployment_End", p =>
        {
            p.Add(P.Int ("@DeploymentID", deploymentId));
            p.Add(P.Date("@ToDate",       toDate));
            p.Add(P.NVar("@Remark",       remark, 500));
        }, ct);

    public Task<PagedResult<Row>> GetDeploymentsAsync(int? unitId, int? empId, int? branchId, int? shiftId,
                                                      bool onlyActive, string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Deployment_GetList", p =>
        {
            p.Add(P.Int ("@UnitID",     unitId));
            p.Add(P.Int ("@EmpID",      empId));
            p.Add(P.Int ("@BranchID",   branchId));
            p.Add(P.Int ("@ShiftID",    shiftId));
            p.Add(P.Bit ("@OnlyActive", onlyActive));
            p.Add(P.NVar("@Search",     search, 200));
            p.Add(P.Int ("@PageNo",     page));
            p.Add(P.Int ("@PageSize",   pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetUnitEmployeesAsync(int unitId, int? shiftId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Deployment_GetUnitEmployees", p =>
        {
            p.Add(P.Int("@UnitID",  unitId));
            p.Add(P.Int("@ShiftID", shiftId));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetAvailableRelieversAsync(int unitId, DateOnly? onDate, int? shiftId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Deployment_GetAvailableRelievers", p =>
        {
            p.Add(P.Int ("@UnitID",  unitId));
            p.Add(P.Date("@OnDate",  onDate));
            p.Add(P.Int ("@ShiftID", shiftId));
        }, Map.Dynamic, ct);

    // --------------------------------------------------------------- turnout

    public Task<IReadOnlyList<Row>> GetLiveTurnoutAsync(DateOnly? onDate, int? branchId, int? clientId, int? shiftId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Turnout_GetLive", p =>
        {
            p.Add(P.Date("@OnDate",   onDate));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.Int ("@ClientID", clientId));
            p.Add(P.Int ("@ShiftID",  shiftId));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveTurnoutAsync(int unitId, DateOnly date, int? shiftId, int required, int present,
                                           int absent, int reliever, string? remark, IEnumerable<int>? empIds, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Turnout_Insert", p =>
        {
            p.Add(P.Int    ("@UnitID",      unitId));
            p.Add(P.Date   ("@TurnoutDate", date));
            p.Add(P.Int    ("@ShiftID",     shiftId));
            p.Add(P.Int    ("@RequiredNos", required));
            p.Add(P.Int    ("@PresentNos",  present));
            p.Add(P.Int    ("@AbsentNos",   absent));
            p.Add(P.Int    ("@RelieverNos", reliever));
            p.Add(P.NVar   ("@Remark",      remark, 500));
            p.Add(P.NVarMax("@EmpIdsCsv",   empIds is null ? null : string.Join(',', empIds)));
        }, ct);

    public Task<IReadOnlyList<Row>> DetectVacantPostsAsync(int minutesAhead, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Turnout_DetectVacantPosts",
            p => p.Add(P.Int("@MinutesAhead", minutesAhead)), Map.Dynamic, ct);

    // ------------------------------------------------- movement and contracts

    public Task<SpResult> MovementAsync(int empId, int? fromUnitId, int? toUnitId, string? postName,
                                        DateOnly? date, TimeOnly? time, string? instructionBy, string? remark,
                                        bool applyNow, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Movement_Insert", p =>
        {
            p.Add(P.Int ("@EmpID",         empId));
            p.Add(P.Int ("@FromUnitID",    fromUnitId));
            p.Add(P.Int ("@ToUnitID",      toUnitId));
            p.Add(P.NVar("@PostName",      postName, 150));
            p.Add(P.Date("@MovementDate",  date));
            p.Add(P.Time("@MovementTime",  time));
            p.Add(P.NVar("@InstructionBy", instructionBy, 150));
            p.Add(P.NVar("@Remark",        remark, 1000));
            p.Add(P.Bit ("@ApplyNow",      applyNow));
        }, ct);

    public Task<SpResult> IncDecAsync(int unitId, string changeType, DateOnly dated, int nop, string? timing,
                                      int? designationId, int? shiftId, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Deployment_IncDec", p =>
        {
            p.Add(P.Int ("@UnitID",        unitId));
            p.Add(P.NVar("@ChangeType",    changeType, 10));
            p.Add(P.Date("@Dated",         dated));
            p.Add(P.Int ("@Nop",           nop));
            p.Add(P.NVar("@Timing",        timing, 50));
            p.Add(P.Int ("@DesignationID", designationId));
            p.Add(P.Int ("@ShiftID",       shiftId));
            p.Add(P.NVar("@Remark",        remark, 1000));
        }, ct);

    public Task<SpResult> IncDecApproveAsync(int changeId, bool approve, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Deployment_IncDecApprove", p =>
        {
            p.Add(P.Int ("@ChangeID", changeId));
            p.Add(P.Bit ("@Approve",  approve));
            p.Add(P.NVar("@Remark",   remark, 500));
        }, ct);

    public Task<SpResult> ContractAsync(string contractType, int? clientId, int? unitId, DateOnly? dated, int nop,
                                        string? timing, DateOnly? from, DateOnly? to, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Contract_Insert", p =>
        {
            p.Add(P.NVar("@ContractType",  contractType, 20));
            p.Add(P.Int ("@ClientID",      clientId));
            p.Add(P.Int ("@UnitID",        unitId));
            p.Add(P.Date("@Dated",         dated));
            p.Add(P.Int ("@Nop",           nop));
            p.Add(P.NVar("@Timing",        timing, 50));
            p.Add(P.Date("@EffectiveFrom", from));
            p.Add(P.Date("@EffectiveTo",   to));
            p.Add(P.NVar("@Remark",        remark, 1000));
        }, ct);

    public Task<SpResult> TemporaryEventAsync(int? unitId, int? clientId, string? typeOfService, int? serviceTypeId,
                                              DateOnly startDate, DateOnly? endDate, TimeOnly? startTime, TimeOnly? endTime,
                                              int nop, decimal? rate, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_TemporaryEvent_Insert", p =>
        {
            p.Add(P.Int  ("@UnitID",        unitId));
            p.Add(P.Int  ("@ClientID",      clientId));
            p.Add(P.NVar ("@TypeOfService", typeOfService, 100));
            p.Add(P.Int  ("@ServiceTypeID", serviceTypeId));
            p.Add(P.Date ("@StartDate",     startDate));
            p.Add(P.Date ("@EndDate",       endDate));
            p.Add(P.Time ("@StartTime",     startTime));
            p.Add(P.Time ("@EndTime",       endTime));
            p.Add(P.Int  ("@NOP",           nop));
            p.Add(P.Money("@RatePerGuard",  rate));
            p.Add(P.NVar ("@Remark",        remark, 1000));
        }, ct);

    // ---------------------------------------------------------------- patrol

    public Task<SpResult> SaveCheckpointAsync(int unitId, string name, string? location, int? locationId,
                                              decimal? lat, decimal? lon, int maxDistance, bool requirePhoto,
                                              string? remark, int? qrId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Qr_Add", p =>
        {
            p.Add(P.Int  ("@UnitID",            unitId));
            p.Add(P.NVar ("@Name",              name, 150));
            p.Add(P.NVar ("@Location",          location, 300));
            p.Add(P.Int  ("@LocationID",        locationId));
            p.Add(P.Coord("@Latitude",          lat));
            p.Add(P.Coord("@Longitude",         lon));
            p.Add(P.Int  ("@MaxDistanceMeters", maxDistance));
            p.Add(P.Bit  ("@RequirePhoto",      requirePhoto));
            p.Add(P.NVar ("@Remark",            remark, 500));
            p.Add(P.Int  ("@QrID",              qrId));
        }, ct);

    public Task<PagedResult<Row>> GetCheckpointsAsync(int? unitId, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Qr_GetList", p =>
        {
            p.Add(P.Int("@UnitID",   unitId));
            p.Add(P.Int("@PageNo",   page));
            p.Add(P.Int("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetCheckpointDistanceAsync(string qrCode, decimal? lat, decimal? lon, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Qr_GetDistance", p =>
        {
            p.Add(P.NVar ("@QrCode",    qrCode, 64));
            p.Add(P.Coord("@Latitude",  lat));
            p.Add(P.Coord("@Longitude", lon));
        }, Map.Dynamic, ct);

    public Task<SpResult> ScanAsync(string qrCode, int? empId, decimal? lat, decimal? lon, string? imageUrl,
                                    string? remark, DateTime? scantime, bool isMock, bool isOffline,
                                    Guid? clientRequestId, string? deviceId, string? appVersion, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Qr_Scan", p =>
        {
            p.Add(P.NVar     ("@QrCode",          qrCode, 64));
            p.Add(P.Int      ("@EmpID",           empId));
            p.Add(P.Coord    ("@Latitude",        lat));
            p.Add(P.Coord    ("@Longitude",       lon));
            p.Add(P.NVar     ("@ImageUrl",        imageUrl, 500));
            p.Add(P.NVar     ("@Remark",          remark, 500));
            p.Add(P.DateTime2("@Scantime",        scantime));
            p.Add(P.Bit      ("@IsMockLocation",  isMock));
            p.Add(P.Bit      ("@IsOffline",       isOffline));
            p.Add(P.Guid     ("@ClientRequestId", clientRequestId));
            p.Add(P.NVar     ("@DeviceID",        deviceId, 200));
            p.Add(P.NVar     ("@AppVersion",      appVersion, 20));
        }, ct);

    public Task<PagedResult<Row>> GetScanLogAsync(int? unitId, int? qrId, int? empId, DateOnly? from, DateOnly? to,
                                                  bool onlyOutOfRange, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Qr_GetScanLog", p =>
        {
            p.Add(P.Int ("@UnitID",          unitId));
            p.Add(P.Int ("@QrID",            qrId));
            p.Add(P.Int ("@EmpID",           empId));
            p.Add(P.Date("@FromDate",        from));
            p.Add(P.Date("@ToDate",          to));
            p.Add(P.Bit ("@OnlyOutOfRange",  onlyOutOfRange));
            p.Add(P.Int ("@PageNo",          page));
            p.Add(P.Int ("@PageSize",        pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetPatrolSummaryAsync(DateOnly? from, DateOnly? to, int? unitId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Qr_GetSummary", p =>
        {
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.Int ("@UnitID",   unitId));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveRoundAsync(int unitId, string roundName, TimeOnly start, TimeOnly end, int grace,
                                         string? daysOfWeek, IEnumerable<int>? qrIds, int? roundId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_PatrolRound_Save", p =>
        {
            p.Add(P.Int    ("@UnitID",       unitId));
            p.Add(P.NVar   ("@RoundName",    roundName, 100));
            p.Add(P.Time   ("@StartTime",    start));
            p.Add(P.Time   ("@EndTime",      end));
            p.Add(P.Int    ("@GraceMinutes", grace));
            p.Add(P.NVar   ("@DaysOfWeek",   daysOfWeek, 20));
            p.Add(P.NVarMax("@QrIdsCsv",     qrIds is null ? null : string.Join(',', qrIds)));
            p.Add(P.Int    ("@RoundID",      roundId));
        }, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetMyPatrolProgressAsync(int? unitId, CancellationToken ct) =>
        db.QueryMultipleAsync("dbo.usp_PatrolRound_GetMyProgress",
            p => p.Add(P.Int("@UnitID", unitId)),
            async (reader, token) =>
            {
                var sets = new List<IReadOnlyList<Row>>();
                do
                {
                    var rows = new List<Row>();
                    if (reader.HasRows)
                    {
                        var map = Map.Dynamic(reader);
                        while (await reader.ReadAsync(token).ConfigureAwait(false)) rows.Add(map(reader));
                    }
                    sets.Add(rows);
                }
                while (await reader.NextResultAsync(token).ConfigureAwait(false));
                return (IReadOnlyList<IReadOnlyList<Row>>)sets;
            }, ct);

    public Task<IReadOnlyList<Row>> DetectMissedRoundsAsync(DateOnly? onDate, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Patrol_DetectMissedRounds",
            p => p.Add(P.Date("@OnDate", onDate)), Map.Dynamic, ct);

    // -------------------------------------------------------------- tracking

    public Task<SpResult> TrackAsync(decimal lat, decimal lon, decimal? accuracy, decimal? speed, byte? battery,
                                     DateTime? loggedAt, string source, bool isMock, string? deviceId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Location_Track", p =>
        {
            p.Add(P.Coord    ("@Latitude",       lat));
            p.Add(P.Coord    ("@Longitude",      lon));
            p.Add(P.Dec      ("@Accuracy",       accuracy, 7, 2));
            p.Add(P.Dec      ("@Speed",          speed, 7, 2));
            p.Add(P.TinyInt  ("@BatteryLevel",   battery));
            p.Add(P.DateTime2("@LoggedAt",       loggedAt));
            p.Add(P.Char     ("@Source",         source, 2));
            p.Add(P.Bit      ("@IsMockLocation", isMock));
            p.Add(P.NVar     ("@DeviceID",       deviceId, 200));
        }, ct);

    /// <summary>
    /// The phone's location outbox in one round trip.
    ///
    /// Spoofed pings are sent up and stored flagged rather than dropped on the
    /// device, so a supervisor can see that someone tried. They are excluded
    /// from the live board and contribute nothing to distance travelled.
    /// </summary>
    public async Task<SpResult> TrackBatchAsync(IReadOnlyList<LocationPing> pings, string? deviceId, CancellationToken ct)
    {
        var table = new DataTable();
        table.Columns.Add("Latitude",       typeof(decimal));
        table.Columns.Add("Longitude",      typeof(decimal));
        table.Columns.Add("Accuracy",       typeof(decimal));
        table.Columns.Add("Speed",          typeof(decimal));
        table.Columns.Add("BatteryLevel",   typeof(byte));
        table.Columns.Add("LoggedAt",       typeof(DateTime));
        table.Columns.Add("Source",         typeof(string));
        table.Columns.Add("IsMockLocation", typeof(bool));

        foreach (var x in pings)
        {
            table.Rows.Add(
                x.Latitude, x.Longitude,
                (object?)x.Accuracy ?? DBNull.Value,
                (object?)x.Speed ?? DBNull.Value,
                (object?)x.BatteryLevel ?? DBNull.Value,
                x.LoggedAt,
                // CHAR(2): 'FG' foreground, 'BG' background.
                string.Equals(x.Source, "BG", StringComparison.OrdinalIgnoreCase) ? "BG" : "FG",
                x.IsMockLocation);
        }

        var outcome = await db.ExecuteTvpAsync("dbo.usp_Location_TrackBatch",
            "@Pings", "ops.LocationPingList", table,
            p => p.Add(P.NVar("@DeviceID", deviceId, 200)),
            Map.SpResult, ct).ConfigureAwait(false);

        return outcome.Count > 0 ? outcome[0] : new SpResult(true, 200, 0, "No pings supplied");
    }

    public Task<IReadOnlyList<Row>> GetLiveLocationsAsync(int staleMinutes, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Location_GetLive",
            p => p.Add(P.Int("@StaleMinutes", staleMinutes)), Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetTrailAsync(int targetUserId, DateOnly? onDate, CancellationToken ct) =>
        db.QueryMultipleAsync("dbo.usp_Location_GetTrail", p =>
        {
            p.Add(P.Int ("@TargetUserID", targetUserId));
            p.Add(P.Date("@OnDate",       onDate));
        }, async (reader, token) =>
        {
            var sets = new List<IReadOnlyList<Row>>();
            do
            {
                var rows = new List<Row>();
                if (reader.HasRows)
                {
                    var map = Map.Dynamic(reader);
                    while (await reader.ReadAsync(token).ConfigureAwait(false)) rows.Add(map(reader));
                }
                sets.Add(rows);
            }
            while (await reader.NextResultAsync(token).ConfigureAwait(false));
            return (IReadOnlyList<IReadOnlyList<Row>>)sets;
        }, ct);
}
