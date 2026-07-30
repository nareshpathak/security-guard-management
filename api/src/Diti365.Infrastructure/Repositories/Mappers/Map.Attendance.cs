using Diti365.Contracts.Attendance;
using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

public static partial class Map
{
    public static Func<SqlDataReader, AttendanceRow> AttendanceRow(SqlDataReader r)
    {
        int oId=r.GetOrdinal("AttendanceID"), oDate=r.GetOrdinal("AttendanceDate"),
            oEmp=r.GetOrdinal("EmpID"), oCode=r.GetOrdinal("EmpCode"), oName=r.GetOrdinal("EmpFullName"),
            oDesig=r.GetOrdinal("DesignationName"), oUnit=r.GetOrdinal("UnitID"), oUnitName=r.GetOrdinal("UnitName"),
            oShift=r.GetOrdinal("ShiftID"), oShiftName=r.GetOrdinal("ShiftName"),
            oIn=r.GetOrdinal("InTime"), oOut=r.GetOrdinal("OutTime"),
            oWorked=r.GetOrdinal("WorkedHours"), oOt=r.GetOrdinal("OtHours"),
            oStatus=r.GetOrdinal("Status"), oApproval=r.GetOrdinal("ApprovalStatus"),
            oInDist=r.GetOrdinal("InDistanceMeters"), oOutDist=r.GetOrdinal("OutDistanceMeters"),
            oInSelfie=r.GetOrdinal("InSelfieUrl"), oOutSelfie=r.GetOrdinal("OutSelfieUrl"),
            oOutside=r.GetOrdinal("OutsideGeofence"), oMock=r.GetOrdinal("IsMockLocation"),
            oOffline=r.GetOrdinal("IsOffline");

        return row => new AttendanceRow(
            row.Long(oId), row.DateN(oDate) ?? default, row.Int(oEmp), row.Str(oCode), row.Str(oName),
            row.StrN(oDesig), row.Int(oUnit), row.StrN(oUnitName), row.IntN(oShift), row.StrN(oShiftName),
            row.DateTimeN(oIn), row.DateTimeN(oOut), row.DecN(oWorked), row.Dec(oOt),
            row.Code(oStatus), (row.ByteN(oApproval) ?? 0), row.IntN(oInDist), row.IntN(oOutDist),
            row.StrN(oInSelfie), row.StrN(oOutSelfie), row.Bool(oOutside), row.Bool(oMock), row.Bool(oOffline));
    }

    public static Func<SqlDataReader, ApprovalRow> ApprovalRow(SqlDataReader r)
    {
        int oId=r.GetOrdinal("AttendanceID"), oDate=r.GetOrdinal("AttendanceDate"),
            oEmp=r.GetOrdinal("EmpID"), oCode=r.GetOrdinal("EmpCode"), oName=r.GetOrdinal("EmpFullName"),
            oPhoto=r.GetOrdinal("Photo"), oDesig=r.GetOrdinal("DesignationName"),
            oUnit=r.GetOrdinal("UnitID"), oUnitName=r.GetOrdinal("UnitName"),
            oShift=r.GetOrdinal("ShiftID"), oShiftName=r.GetOrdinal("ShiftName"),
            oIn=r.GetOrdinal("InTime"), oOut=r.GetOrdinal("OutTime"),
            oWorked=r.GetOrdinal("WorkedHours"), oOt=r.GetOrdinal("OtHours"), oStatus=r.GetOrdinal("Status"),
            oInDist=r.GetOrdinal("InDistanceMeters"), oOutDist=r.GetOrdinal("OutDistanceMeters"),
            oInSelfie=r.GetOrdinal("InSelfieUrl"), oOutSelfie=r.GetOrdinal("OutSelfieUrl"),
            oMock=r.GetOrdinal("IsMockLocation"), oOffline=r.GetOrdinal("IsOffline"),
            oSource=r.GetOrdinal("Source"), oOutside=r.GetOrdinal("OutsideGeofence"),
            oMissing=r.GetOrdinal("MissingOutPunch");

        return row => new ApprovalRow(
            row.Long(oId), row.DateN(oDate) ?? default, row.Int(oEmp), row.Str(oCode), row.Str(oName),
            row.StrN(oPhoto), row.StrN(oDesig), row.Int(oUnit), row.Str(oUnitName),
            row.IntN(oShift), row.StrN(oShiftName), row.DateTimeN(oIn), row.DateTimeN(oOut),
            row.DecN(oWorked), row.Dec(oOt), row.Code(oStatus),
            row.IntN(oInDist), row.IntN(oOutDist), row.StrN(oInSelfie), row.StrN(oOutSelfie),
            row.Bool(oMock), row.Bool(oOffline), row.ByteN(oSource) ?? 1,
            row.Bool(oOutside), row.Bool(oMissing));
    }

    public static Func<SqlDataReader, AttendanceSummaryRow> AttendanceSummaryRow(SqlDataReader r)
    {
        int oEmp=r.GetOrdinal("EmpID"), oCode=r.GetOrdinal("EmpCode"), oName=r.GetOrdinal("EmpFullName"),
            oDesig=r.GetOrdinal("DesignationName"), oUnit=r.GetOrdinal("UnitName"),
            oPresent=r.GetOrdinal("PresentDays"), oHalf=r.GetOrdinal("HalfDays"), oAbsent=r.GetOrdinal("AbsentDays"),
            oWo=r.GetOrdinal("WeekOff"), oHo=r.GetOrdinal("Holidays"), oLeave=r.GetOrdinal("LeaveDays"),
            oOt=r.GetOrdinal("OtHours"), oPending=r.GetOrdinal("PendingApproval"), oPayable=r.GetOrdinal("PayableDays");

        return row => new AttendanceSummaryRow(
            row.Int(oEmp), row.Str(oCode), row.Str(oName), row.StrN(oDesig), row.StrN(oUnit),
            row.Dec(oPresent), row.Dec(oHalf), row.Dec(oAbsent), row.Dec(oWo), row.Dec(oHo),
            row.Dec(oLeave), row.Dec(oOt), row.IntN(oPending) ?? 0, row.Dec(oPayable));
    }

    public static Func<SqlDataReader, SelfAttendanceDay> SelfAttendanceDay(SqlDataReader r)
    {
        int oId=r.GetOrdinal("AttendanceID"), oDate=r.GetOrdinal("AttendanceDate"),
            oIn=r.GetOrdinal("InTime"), oOut=r.GetOrdinal("OutTime"),
            oWorked=r.GetOrdinal("WorkedHours"), oOt=r.GetOrdinal("OtHours"),
            oStatus=r.GetOrdinal("Status"), oApproval=r.GetOrdinal("ApprovalStatus"),
            oInSelfie=r.GetOrdinal("InSelfieUrl"), oOutSelfie=r.GetOrdinal("OutSelfieUrl"),
            oInDist=r.GetOrdinal("InDistanceMeters"), oOutDist=r.GetOrdinal("OutDistanceMeters"),
            oOffline=r.GetOrdinal("IsOffline"), oUnit=r.GetOrdinal("UnitName"), oShift=r.GetOrdinal("ShiftName");

        return row => new SelfAttendanceDay(
            row.Long(oId), row.DateN(oDate) ?? default, row.DateTimeN(oIn), row.DateTimeN(oOut),
            row.DecN(oWorked), row.Dec(oOt), row.Code(oStatus), (row.ByteN(oApproval) ?? 0),
            row.StrN(oInSelfie), row.StrN(oOutSelfie), row.IntN(oInDist), row.IntN(oOutDist),
            row.Bool(oOffline), row.StrN(oUnit), row.StrN(oShift));
    }

    public static Func<SqlDataReader, SyncOutcome> SyncOutcome(SqlDataReader r)
    {
        int oId=r.GetOrdinal("ClientRequestId"), oAtt=r.GetOrdinal("AttendanceID"),
            oOk=r.GetOrdinal("Accepted"), oMsg=r.GetOrdinal("Message");
        return row => new SyncOutcome(
            row.GuidN(oId) ?? Guid.Empty, row.LongN(oAtt), row.Bool(oOk), row.Str(oMsg));
    }
}
