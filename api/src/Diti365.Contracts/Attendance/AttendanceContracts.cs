namespace Diti365.Contracts.Attendance;

public sealed record PunchRequest(
    int UnitId,
    int? ShiftId = null,
    DateTime? PunchAt = null,
    decimal? Latitude = null,
    decimal? Longitude = null,
    string? SelfieUrl = null,
    bool IsMockLocation = false,
    bool IsOffline = false,
    Guid? ClientRequestId = null,
    string? DeviceId = null,
    string? AppVersion = null,
    string? Remark = null,
    // Set only when a supervisor has approved an out-of-geofence exception.
    bool AllowOutOfGeofence = false,
    // Omitted by a guard punching for himself; supervisors supply it.
    int? EmpId = null);

public sealed record PunchResult(int AttendanceId, string Message, int? DistanceMeters,
                                 decimal? WorkedHours = null, string? AttendanceStatus = null);

/// <summary>One row of the mobile offline outbox batch.</summary>
public sealed record OfflinePunch(
    Guid ClientRequestId,
    int EmpId,
    int UnitId,
    int? ShiftId,
    DateTime PunchAt,
    decimal? Latitude,
    decimal? Longitude,
    string Direction,          // "IN " or "OUT"
    string? SelfieUrl,
    bool IsMockLocation,
    string? DeviceId,
    string? AppVersion);

public sealed record SyncOutcome(Guid ClientRequestId, long? AttendanceId, bool Accepted, string Message);

public sealed record AttendanceRow(
    long AttendanceId, DateOnly AttendanceDate, int EmpId, string EmpCode, string EmpFullName,
    string? DesignationName, int UnitId, string? UnitName, int? ShiftId, string? ShiftName,
    DateTime? InTime, DateTime? OutTime, decimal? WorkedHours, decimal OtHours,
    string Status, int ApprovalStatus, int? InDistanceMeters, int? OutDistanceMeters,
    string? InSelfieUrl, string? OutSelfieUrl, bool OutsideGeofence, bool IsMockLocation, bool IsOffline);

public sealed record ApprovalRow(
    long AttendanceId, DateOnly AttendanceDate, int EmpId, string EmpCode, string EmpFullName,
    string? Photo, string? DesignationName, int UnitId, string UnitName, int? ShiftId, string? ShiftName,
    DateTime? InTime, DateTime? OutTime, decimal? WorkedHours, decimal OtHours, string Status,
    int? InDistanceMeters, int? OutDistanceMeters, string? InSelfieUrl, string? OutSelfieUrl,
    bool IsMockLocation, bool IsOffline, int Source, bool OutsideGeofence, bool MissingOutPunch);

public sealed record ApproveRequest(IReadOnlyList<long> AttendanceIds, bool Approve, string? RejectReason = null);

public sealed record AttendanceSummaryRow(
    int EmpId, string EmpCode, string EmpFullName, string? DesignationName, string? UnitName,
    decimal PresentDays, decimal HalfDays, decimal AbsentDays, decimal WeekOff, decimal Holidays,
    decimal LeaveDays, decimal OtHours, int PendingApproval, decimal PayableDays);

public sealed record SelfAttendanceDay(
    long AttendanceId, DateOnly AttendanceDate, DateTime? InTime, DateTime? OutTime,
    decimal? WorkedHours, decimal OtHours, string Status, int ApprovalStatus,
    string? InSelfieUrl, string? OutSelfieUrl, int? InDistanceMeters, int? OutDistanceMeters,
    bool IsOffline, string? UnitName, string? ShiftName);

public sealed record SelfAttendanceTotals(
    decimal PresentDays, int HalfDays, int AbsentDays, int LeaveDays, decimal OtHours);

public sealed record SelfAttendanceResponse(
    IReadOnlyList<SelfAttendanceDay> Days, SelfAttendanceTotals Totals);

public sealed record AttendanceCounts(int AttendanceCount, int PresentCount, int AbsentCount, int PendingCount);
