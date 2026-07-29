using Diti365.Contracts.Attendance;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V1;

using Row = IReadOnlyDictionary<string, object?>;

/// <summary>Legacy OperationController — field operations surface for Diti365.apk v4.8.</summary>
[Route("api/Operation")]
public sealed class OperationController(
    IPeopleRepository people,
    IAttendanceRepository attendance,
    IOpsRepository ops,
    IWorkflowRepository workflow,
    IFinanceRepository finance) : LegacyControllerBase
{
    // ---- recruitment ----
    [HttpPost("addrecruits")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddRecruits([FromBody] V1RecruitBody b) =>
        FromSp(await people.SaveRecruitAsync(b.Name ?? "", b.Mobile, b.Aadhaar ?? b.AdharCardNo, b.OldEmpCode,
            b.BranchId, b.DesignationId, b.SourceBy, b.Dated, b.Remark, null, Ct));

    [HttpPost("updaterecruits")]
    public async Task<ActionResult<LegacyEnvelope<object>>> UpdateRecruits([FromBody] V1RecruitBody b) =>
        FromSp(await people.SaveRecruitAsync(b.Name ?? "", b.Mobile, b.Aadhaar ?? b.AdharCardNo, b.OldEmpCode,
            b.BranchId, b.DesignationId, b.SourceBy, b.Dated, b.Remark, b.RecruitId, Ct));

    [HttpGet("getrecruits")]
    [HttpGet("getpendingrecruit")]
    [HttpGet("getrecruitdata")]
    [HttpGet("getNewRecruits")]
    [HttpGet("getRecruitedEmployee")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetRecruits(
        [FromQuery] string? status, [FromQuery] int? branchId, [FromQuery] string? search,
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var sets = await people.GetRecruitsAsync(status, branchId, search, from, to, page, pageSize, Ct);
        return OkData(sets.Count > 0 ? sets[0] : Array.Empty<Row>());
    }

    // ---- employees ----
    [HttpGet("getemp")]
    [HttpGet("getemployee")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetEmp([FromQuery] int empId)
    {
        var sets = await people.GetEmployee360Async(empId, Ct);
        return OkData(sets.Count > 0 ? sets[0] : Array.Empty<Row>());
    }

    [HttpGet("getstafflist")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetStaffList(
        [FromQuery] int? branchId, [FromQuery] int? unitId, [FromQuery] string? search,
        [FromQuery] string? status, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await people.GetEmployeesAsync(new EmployeeFilter(
            branchId, unitId, null, null, status, null, null, null, search, page, pageSize), Ct);
        return OkData(result.Items);
    }

    [HttpGet("getunitemployee")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetUnitEmployee(
        [FromQuery] int unitId, [FromQuery] int? shiftId) =>
        OkData(await ops.GetUnitEmployeesAsync(unitId, shiftId, Ct));

    [HttpPost("addfamily")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddFamily([FromBody] V1FamilyBody b) =>
        FromSp(await people.SaveFamilyAsync(b.EmpId, b.Relation ?? "", b.Name ?? "", b.Dob, b.Occupation,
            b.Dependent, b.SharePercent, b.Aadhaar, b.FamilyId, Ct));

    [HttpPost("bankdetails")]
    public async Task<ActionResult<LegacyEnvelope<object>>> BankDetails([FromBody] V1BankBody b) =>
        FromSp(await people.SaveBankAsync(b.EmpId, b.BankId, b.BankName, b.BranchName, b.AccountNo ?? b.AcNo,
            b.Ifsc, b.IfscId, b.AccountType, b.NameInPassbook, null, null, Ct));

    [HttpPost("addgunman")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddGunman([FromBody] V1GunBody b) =>
        FromSp(await people.SaveGunLicenceAsync(b.EmpId, b.GunanType, b.TypeArm, b.GunNo, b.Model,
            b.LicenceNo, b.Expiry, b.AreaId, b.IssueDate, Ct));

    [HttpPost("addreliever")]
    [HttpPost("addrelievers")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddReliever([FromBody] V1DeployBody b) =>
        FromSp(await ops.DeployAsync(b.EmpId, b.UnitId, b.PostId, b.ShiftId, b.FromDate,
            true, b.RelieverForEmpId, b.Remark, false, null, Ct));

    [HttpGet("getreliever")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetReliever(
        [FromQuery] int unitId, [FromQuery] DateOnly? onDate, [FromQuery] int? shiftId) =>
        OkData(await ops.GetAvailableRelieversAsync(unitId, onDate, shiftId, Ct));

    // ---- client / unit ----
    [HttpPost("addclient")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddClient([FromBody] V1ClientBody b) =>
        FromSp(await people.SaveClientAsync(new ClientInput(
            b.ClientName ?? "", b.BranchId, b.ClientCode, b.Address, b.CityId, b.StateId, b.Pin,
            b.Gstin, b.Pan, b.ContactPerson, b.ContactNo, b.Email, b.ClientId), Ct));

    [HttpPost("addsite")]
    [HttpPost("updatesite")]
    public async Task<ActionResult<LegacyEnvelope<object>>> SaveSite([FromBody] V1UnitBody b) =>
        FromSp(await people.SaveUnitAsync(new UnitInput(
            b.ClientId, b.UnitName ?? "", b.BranchId, b.UnitCode, b.Address, b.CityId, b.StateId, b.Pin,
            b.Latitude, b.Longitude, b.GeofenceRadiusMeters ?? 150, b.SupervisorEmpId,
            b.AgreementNo, b.AgreementExpDate, b.OrderNo, b.OrderDate, b.OrderExpiryDate,
            b.WorkStartDate, b.UnitId), Ct));

    [HttpGet("getunit")]
    [HttpGet("getuserunit")]
    [HttpGet("getMyClient")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetUnit(
        [FromQuery] int? clientId, [FromQuery] int? branchId, [FromQuery] string? search,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await people.GetUnitsAsync(clientId, branchId, search, page, pageSize, Ct);
        return OkData(result.Items);
    }

    // ---- attendance ----
    [HttpPost("insertattendancein")]
    public async Task<ActionResult<LegacyEnvelope<object>>> PunchIn([FromBody] PunchRequest body)
    {
        var empId = body.EmpId ?? 0;
        return FromSp(await attendance.PunchInAsync(empId, body, Ct));
    }

    [HttpPost("insertattendanceout")]
    public async Task<ActionResult<LegacyEnvelope<object>>> PunchOut([FromBody] PunchRequest body)
    {
        var empId = body.EmpId ?? 0;
        return FromSp(await attendance.PunchOutAsync(empId, body, Ct));
    }

    [HttpPost("insertattendance")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertAttendance([FromBody] V1BulkAttendBody b) =>
        FromSp(await attendance.BulkMarkAsync(b.UnitId, b.Date, b.ShiftId, b.EmpIds ?? [], b.Status ?? "P", b.Remark, Ct));

    [HttpGet("getattendance")]
    public async Task<ActionResult<LegacyEnvelope<AttendanceRow>>> GetAttendance(
        [FromQuery] int? unitId, [FromQuery] int? empId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await attendance.GetAsync(unitId, empId, from, to, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("getselfattendance")]
    public async Task<ActionResult<LegacyEnvelope<object>>> GetSelfAttendance(
        [FromQuery] int empId, [FromQuery] string? monthYear)
    {
        var result = await attendance.GetSelfAsync(empId, monthYear ?? DateTime.Today.ToString("yyyy-MM"), Ct);
        return OkData<object>(new object[] { result });
    }

    [HttpGet("getattendsummary")]
    public async Task<ActionResult<LegacyEnvelope<AttendanceSummaryRow>>> GetAttendSummary(
        [FromQuery] string monthYear, [FromQuery] int? unitId, [FromQuery] int? branchId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await attendance.GetSummaryAsync(monthYear, unitId, branchId, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("getAttendanceCount")]
    public async Task<ActionResult<LegacyEnvelope<AttendanceCounts>>> GetAttendanceCount(
        [FromQuery] int? empId, [FromQuery] DateOnly? onDate)
    {
        var counts = await attendance.GetCountsAsync(empId, onDate, Ct);
        return OkData(new[] { counts });
    }

    [HttpGet("attendforapproval")]
    public async Task<ActionResult<LegacyEnvelope<ApprovalRow>>> AttendForApproval(
        [FromQuery] int? unitId, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await attendance.GetForApprovalAsync(unitId, from, to, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpPost("approve")]
    public async Task<ActionResult<LegacyEnvelope<object>>> Approve([FromBody] ApproveRequest body) =>
        FromSp(await attendance.ApproveAsync(body.AttendanceIds, body.Approve, body.RejectReason, Ct));

    // ---- deployment ----
    [HttpPost("incDecDeployment")]
    public async Task<ActionResult<LegacyEnvelope<object>>> IncDec([FromBody] V1IncDecBody b) =>
        FromSp(await ops.IncDecAsync(b.UnitId, b.ChangeType ?? "INC", b.Dated, b.Nop, b.Timing,
            b.DesignationId, b.ShiftId, b.Remark, Ct));

    [HttpPost("newcontractDeployment")]
    [HttpPost("contractTermination")]
    public async Task<ActionResult<LegacyEnvelope<object>>> Contract([FromBody] V1ContractBody b) =>
        FromSp(await ops.ContractAsync(b.ContractType ?? "NEW", b.ClientId, b.UnitId, b.Dated, b.Nop,
            b.Timing, b.From, b.To, b.Remark, Ct));

    [HttpPost("temporaryEvent")]
    public async Task<ActionResult<LegacyEnvelope<object>>> TemporaryEvent([FromBody] V1TempEventBody b) =>
        FromSp(await ops.TemporaryEventAsync(b.UnitId, b.ClientId, b.TypeOfService, b.ServiceTypeId,
            b.StartDate, b.EndDate, b.StartTime, b.EndTime, b.Nop, b.Rate, b.Remark, Ct));

    [HttpPost("movement")]
    public async Task<ActionResult<LegacyEnvelope<object>>> Movement([FromBody] V1MovementBody b) =>
        FromSp(await ops.MovementAsync(b.EmpId, b.FromUnitId, b.ToUnitId, b.PostName, b.Date, b.Time,
            b.InstructionBy, b.Remark, b.ApplyNow, Ct));

    [HttpPost("insertturnout")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertTurnout([FromBody] V1TurnoutBody b) =>
        FromSp(await ops.SaveTurnoutAsync(b.UnitId, b.TurnoutDate, b.ShiftId, b.RequiredNos, b.PresentNos,
            b.AbsentNos, b.RelieverNos, b.Remark, b.EmpIds, Ct));

    [HttpGet("getturnoutrpt")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetTurnoutRpt(
        [FromQuery] DateOnly? onDate, [FromQuery] int? branchId, [FromQuery] int? clientId, [FromQuery] int? shiftId) =>
        OkData(await ops.GetLiveTurnoutAsync(onDate, branchId, clientId, shiftId, Ct));

    // ---- QR / patrol ----
    [HttpPost("addclientqr")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddClientQr([FromBody] V1QrBody b) =>
        FromSp(await ops.SaveCheckpointAsync(b.UnitId, b.Name ?? "", b.Location, b.LocationId,
            b.Latitude, b.Longitude, b.MaxDistanceMeters ?? 50, b.RequirePhoto, b.Remark, b.QrId, Ct));

    [HttpGet("getqrlist")]
    [HttpGet("getqrlistadmin")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetQrList(
        [FromQuery] int? unitId, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await ops.GetCheckpointsAsync(unitId, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("getqrlistsummary")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetQrSummary(
        [FromQuery] DateOnly? from, [FromQuery] DateOnly? to, [FromQuery] int? unitId) =>
        OkData(await ops.GetPatrolSummaryAsync(from, to, unitId, Ct));

    [HttpGet("getqrdistance")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetQrDistance(
        [FromQuery] string qrCode, [FromQuery] decimal? lat, [FromQuery] decimal? lon) =>
        OkData(await ops.GetCheckpointDistanceAsync(qrCode, lat, lon, Ct));

    [HttpPost("readqr")]
    [HttpPost("readqrwithimage")]
    public async Task<ActionResult<LegacyEnvelope<object>>> ReadQr([FromBody] V1ScanBody b) =>
        FromSp(await ops.ScanAsync(b.QrCode ?? "", b.EmpId, b.Latitude, b.Longitude, b.ImageUrl,
            b.Remark, b.ScanTime, b.IsMock, b.IsOffline, b.ClientRequestId, b.DeviceId, b.AppVersion, Ct));

    // ---- location ----
    [HttpPost("trackLocation")]
    public async Task<ActionResult<LegacyEnvelope<object>>> TrackLocation([FromBody] V1TrackBody b) =>
        FromSp(await ops.TrackAsync(b.Latitude, b.Longitude, b.Accuracy, b.Speed, b.Battery,
            b.LoggedAt, b.Source ?? "mobile", b.IsMock, b.DeviceId, Ct));

    [HttpGet("getlocationlog")]
    [HttpGet("trackRpt")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetLocationLog([FromQuery] int staleMinutes = 30) =>
        OkData(await ops.GetLiveLocationsAsync(staleMinutes, Ct));

    [HttpGet("getuserlocationlog")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetUserLocationLog(
        [FromQuery] int userId, [FromQuery] DateOnly? onDate)
    {
        var sets = await ops.GetTrailAsync(userId, onDate, Ct);
        return OkData(sets.Count > 0 ? sets[0] : Array.Empty<Row>());
    }

    // ---- incidents / complaints ----
    [HttpPost("insertincident")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertIncident([FromBody] V1IncidentBody b) =>
        FromSp(await workflow.CreateIncidentAsync(b.UnitId, b.TypeId, b.Date, b.Time, b.EmpId, b.BeltNo,
            b.FullName, b.Severity, b.Remark, b.ActionTaken, b.PhotoUrl, b.Latitude, b.Longitude,
            b.ClientRequestId, Ct));

    [HttpPost("insertfield")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertField([FromBody] V1FieldBody b) =>
        FromSp(await workflow.CreateFieldReportAsync(b.UnitId, b.ContactPerson, b.Remark, b.Latitude,
            b.Longitude, b.PhotoUrl, b.ClientRequestId, b.EmpRemarksJson, Ct));

    [HttpGet("getrptdetail")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetRptDetail([FromQuery] int reportId)
    {
        var sets = await workflow.GetFieldReportAsync(reportId, Ct);
        return OkData(sets.Count > 0 ? sets[0] : Array.Empty<Row>());
    }

    [HttpGet("getcount")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetCount([FromQuery] DateOnly? onDate) =>
        OkData(await workflow.GetReportCountsAsync(onDate, Ct));

    [HttpPost("insertcomplaint")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertComplaint([FromBody] V1ComplaintBody b) =>
        FromSp(await workflow.CreateComplaintAsync(b.UnitId, b.Description ?? "", b.TypeId, b.ClientId,
            b.PhotoUrl, b.ClientRequestId, Ct));

    [HttpGet("getcomplaint")]
    [HttpGet("getunitcomplaint")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetComplaint(
        [FromQuery] int? unitId, [FromQuery] int? clientId, [FromQuery] string? status,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await workflow.GetComplaintsAsync(unitId, clientId, status, null, false, null, null, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpPost("updatecomplaintstatus")]
    public async Task<ActionResult<LegacyEnvelope<object>>> UpdateComplaintStatus([FromBody] V1ComplaintStatusBody b) =>
        FromSp(await workflow.UpdateComplaintAsync(b.ComplaintId, b.Status ?? "Open", b.Remark, b.AssignedToEmpId, Ct));

    [HttpPost("insertsuggestion")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertSuggestion([FromBody] V1SuggestionBody b) =>
        FromSp(await workflow.CreateSuggestionAsync(b.Subject, b.Description ?? "", Ct));

    [HttpPost("insertrequest")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertRequest([FromBody] V1RequestBody b) =>
        FromSp(await workflow.CreateRequestAsync(b.RequestType ?? "Leave", b.From, b.To, b.Amount, b.Reason, Ct));

    // ---- HR ----
    [HttpPost("resign")]
    [HttpPost("insertleft")]
    [HttpPost("insertrejoin")]
    public async Task<ActionResult<LegacyEnvelope<object>>> Lifecycle([FromBody] V1LifecycleBody b) =>
        FromSp(await workflow.LifecycleEventAsync(b.EmpId, b.EventType ?? "Resign", b.EventDate, b.Timing,
            b.Remark, b.DocUrl, Ct));

    [HttpPost("training")]
    public async Task<ActionResult<LegacyEnvelope<object>>> Training([FromBody] V1TrainingBody b) =>
        FromSp(await workflow.SaveTrainingAsync(b.UnitId, b.Dated, b.Timing, b.Topic, b.Remark,
            b.PhotoUrl, b.Attendees, b.TrainingId, Ct));

    [HttpPost("insertgatepass")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertGatePass([FromBody] V1GatePassBody b) =>
        FromSp(await workflow.CreateGatePassAsync(b.UnitId, b.Name ?? "", b.Mobile, b.Purpose, b.WhomToMeet,
            b.VehicleNo, b.Materials, b.ImageUrl, b.ClientRequestId, Ct));

    // ---- uniform ----
    [HttpPost("issueitem")]
    [HttpPost("issueemployee")]
    public async Task<ActionResult<LegacyEnvelope<object>>> IssueItem([FromBody] V1UniformIssueBody b) =>
        FromSp(await workflow.IssueUniformAsync(b.EmpId, b.ItemId, b.Qty, b.Rate, b.RecoverInSalary, b.Remark, Ct));

    [HttpPost("returnitem")]
    [HttpPost("returnemployee")]
    public async Task<ActionResult<LegacyEnvelope<object>>> ReturnItem([FromBody] V1UniformReturnBody b) =>
        FromSp(await workflow.ReturnUniformAsync(b.IssueId, b.Qty, b.Remark, Ct));

    [HttpGet("getstock")]
    [HttpGet("getbranchstock")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetStock([FromQuery] int? branchId) =>
        OkData(await workflow.GetStockAsync(branchId, Ct));

    [HttpGet("GetUniformLedger")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetUniformLedger(
        [FromQuery] int? empId, [FromQuery] int? branchId, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await workflow.GetUniformLedgerAsync(empId, branchId, page, pageSize, Ct);
        return OkData(result.Items);
    }

    // ---- finance ----
    [HttpPost("insertadvance")]
    public async Task<ActionResult<LegacyEnvelope<object>>> InsertAdvance([FromBody] V1AdvanceBody b) =>
        FromSp(await workflow.CreateAdvanceAsync(b.EmpId, b.Amount, b.Installment, b.Reason, b.IssueDate, Ct));

    [HttpGet("getsalary")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetSalary([FromQuery] int empId, [FromQuery] string monthYear)
    {
        var row = await finance.GetSalarySlipAsync(empId, monthYear, Ct);
        return row is null ? Ok(LegacyEnvelope<Row>.Fail("Not found", 404)) : OkData(new[] { row });
    }

    [HttpGet("getbill")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetBill(
        [FromQuery] int? clientId, [FromQuery] string? status, [FromQuery] short? year,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await finance.GetInvoicesAsync(clientId, status, year, false, page, pageSize, Ct);
        return OkData(result.Items);
    }

    // ---- docs ----
    [HttpPost("uploaddoc")]
    public async Task<ActionResult<LegacyEnvelope<object>>> UploadDoc([FromBody] V1DocBody b) =>
        FromSp(await workflow.SaveDocumentAsync(b.OwnerType ?? "Employee", b.OwnerId, b.BlobUrl ?? b.Url ?? "",
            b.DocTypeId, b.FileName, b.MimeType, b.SizeBytes, b.IssueDate, b.ExpiryDate, b.Remark, Ct));

    [HttpGet("docdetail")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> DocDetail(
        [FromQuery] int withinDays = 365, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await workflow.GetExpiringDocumentsAsync(withinDays, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpPost("updateFlag")]
    public ActionResult<LegacyEnvelope<object>> UpdateFlag() => OkEmpty("OK");

    [HttpGet("getuserchecklists")]
    [HttpGet("getuserlists")]
    public ActionResult<LegacyEnvelope<object>> GetUserChecklists() => OkEmpty("OK");

    [HttpPost("active")]
    public ActionResult<LegacyEnvelope<object>> Active() => OkEmpty("OK");
}

#region V1 request bodies
public sealed record V1RecruitBody(string? Name = null, string? Mobile = null, string? Aadhaar = null, string? AdharCardNo = null,
    string? OldEmpCode = null, int? BranchId = null, int? DesignationId = null, string? SourceBy = null,
    DateOnly? Dated = null, string? Remark = null, int? RecruitId = null);
public sealed record V1FamilyBody(int EmpId, string? Relation = null, string? Name = null, DateOnly? Dob = null,
    string? Occupation = null, bool Dependent = false, decimal? SharePercent = null, string? Aadhaar = null, int? FamilyId = null);
public sealed record V1BankBody(int EmpId, int? BankId = null, string? BankName = null, string? BranchName = null,
    string? AccountNo = null, string? AcNo = null, string? Ifsc = null, int? IfscId = null,
    string? AccountType = null, string? NameInPassbook = null);
public sealed record V1GunBody(int EmpId, string? GunanType = null, string? TypeArm = null, string? GunNo = null,
    string? Model = null, string? LicenceNo = null, DateOnly? Expiry = null, int? AreaId = null, DateOnly? IssueDate = null);
public sealed record V1DeployBody(int EmpId, int UnitId, int? PostId = null, int? ShiftId = null, DateOnly? FromDate = null,
    int? RelieverForEmpId = null, string? Remark = null);
public sealed record V1ClientBody(string? ClientName = null, int? BranchId = null, string? ClientCode = null, string? Address = null,
    int? CityId = null, int? StateId = null, string? Pin = null, string? Gstin = null, string? Pan = null,
    string? ContactPerson = null, string? ContactNo = null, string? Email = null, int? ClientId = null);
public sealed record V1UnitBody(int ClientId, string? UnitName = null, int? BranchId = null, string? UnitCode = null,
    string? Address = null, int? CityId = null, int? StateId = null, string? Pin = null,
    decimal? Latitude = null, decimal? Longitude = null, int? GeofenceRadiusMeters = null,
    int? SupervisorEmpId = null, string? AgreementNo = null, DateOnly? AgreementExpDate = null,
    string? OrderNo = null, DateOnly? OrderDate = null, DateOnly? OrderExpiryDate = null,
    DateOnly? WorkStartDate = null, int? UnitId = null);
public sealed record V1BulkAttendBody(int UnitId, DateOnly Date, int ShiftId, IReadOnlyList<int>? EmpIds = null,
    string? Status = null, string? Remark = null);
public sealed record V1IncDecBody(int UnitId, string? ChangeType = null, DateOnly Dated = default, int Nop = 0,
    string? Timing = null, int? DesignationId = null, int? ShiftId = null, string? Remark = null);
public sealed record V1ContractBody(string? ContractType = null, int? ClientId = null, int? UnitId = null,
    DateOnly? Dated = null, int Nop = 0, string? Timing = null, DateOnly? From = null, DateOnly? To = null, string? Remark = null);
public sealed record V1TempEventBody(int? UnitId = null, int? ClientId = null, string? TypeOfService = null,
    int? ServiceTypeId = null, DateOnly StartDate = default, DateOnly? EndDate = null,
    TimeOnly? StartTime = null, TimeOnly? EndTime = null, int Nop = 0, decimal? Rate = null, string? Remark = null);
public sealed record V1MovementBody(int EmpId, int? FromUnitId = null, int? ToUnitId = null, string? PostName = null,
    DateOnly? Date = null, TimeOnly? Time = null, string? InstructionBy = null, string? Remark = null, bool ApplyNow = true);
public sealed record V1TurnoutBody(int UnitId, DateOnly TurnoutDate, int? ShiftId = null, int RequiredNos = 0,
    int PresentNos = 0, int AbsentNos = 0, int RelieverNos = 0, string? Remark = null, IReadOnlyList<int>? EmpIds = null);
public sealed record V1QrBody(int UnitId, string? Name = null, string? Location = null, int? LocationId = null,
    decimal? Latitude = null, decimal? Longitude = null, int? MaxDistanceMeters = null, bool RequirePhoto = false,
    string? Remark = null, int? QrId = null);
public sealed record V1ScanBody(string? QrCode = null, int? EmpId = null, decimal? Latitude = null, decimal? Longitude = null,
    string? ImageUrl = null, string? Remark = null, DateTime? ScanTime = null, bool IsMock = false, bool IsOffline = false,
    Guid? ClientRequestId = null, string? DeviceId = null, string? AppVersion = null);
public sealed record V1TrackBody(decimal Latitude, decimal Longitude, decimal? Accuracy = null, decimal? Speed = null,
    byte? Battery = null, DateTime? LoggedAt = null, string? Source = null, bool IsMock = false, string? DeviceId = null);
public sealed record V1IncidentBody(int UnitId, int? TypeId = null, DateOnly? Date = null, TimeOnly? Time = null,
    int? EmpId = null, string? BeltNo = null, string? FullName = null, byte? Severity = null, string? Remark = null,
    string? ActionTaken = null, string? PhotoUrl = null, decimal? Latitude = null, decimal? Longitude = null,
    Guid? ClientRequestId = null);
public sealed record V1FieldBody(int UnitId, string? ContactPerson = null, string? Remark = null,
    decimal? Latitude = null, decimal? Longitude = null, string? PhotoUrl = null,
    Guid? ClientRequestId = null, string? EmpRemarksJson = null);
public sealed record V1ComplaintBody(int UnitId, string? Description = null, int? TypeId = null, int? ClientId = null,
    string? PhotoUrl = null, Guid? ClientRequestId = null);
public sealed record V1ComplaintStatusBody(int ComplaintId, string? Status = null, string? Remark = null, int? AssignedToEmpId = null);
public sealed record V1SuggestionBody(string? Subject = null, string? Description = null);
public sealed record V1RequestBody(string? RequestType = null, DateOnly? From = null, DateOnly? To = null,
    decimal? Amount = null, string? Reason = null);
public sealed record V1LifecycleBody(int EmpId, string? EventType = null, DateOnly EventDate = default,
    string? Timing = null, string? Remark = null, string? DocUrl = null);
public sealed record V1TrainingBody(DateOnly Dated, int? UnitId = null, string? Timing = null, string? Topic = null,
    string? Remark = null, string? PhotoUrl = null, IReadOnlyList<int>? Attendees = null, int? TrainingId = null);
public sealed record V1GatePassBody(int UnitId, string? Name = null, string? Mobile = null, string? Purpose = null,
    string? WhomToMeet = null, string? VehicleNo = null, string? Materials = null, string? ImageUrl = null,
    Guid? ClientRequestId = null);
public sealed record V1UniformIssueBody(int EmpId, int ItemId, decimal Qty, decimal? Rate = null,
    bool RecoverInSalary = true, string? Remark = null);
public sealed record V1UniformReturnBody(int IssueId, decimal Qty, string? Remark = null);
public sealed record V1AdvanceBody(int EmpId, decimal Amount, decimal? Installment = null, string? Reason = null, DateOnly? IssueDate = null);
public sealed record V1DocBody(string? OwnerType = null, int OwnerId = 0, string? BlobUrl = null, string? Url = null,
    int? DocTypeId = null, string? FileName = null, string? MimeType = null, long? SizeBytes = null,
    DateOnly? IssueDate = null, DateOnly? ExpiryDate = null, string? Remark = null);
#endregion
