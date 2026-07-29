using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2")]
public sealed class PeopleController(ICurrentUser currentUser, IPeopleRepository repo)
    : ApiControllerBase(currentUser)
{
    // ----------------------------------------------------------- recruitment

    /// <summary>
    /// Aadhaar / mobile / old employee code check, run on field blur in the recruit form.
    /// It searches employees and recruits, and reports whether the person was
    /// blacklisted and why - the case that matters most in this industry.
    /// </summary>
    [HttpGet("recruits/check-duplicate"), HasPermission(Perm.RecruitView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> CheckDuplicate(
        [FromQuery] string? aadhaar, [FromQuery] string? mobile,
        [FromQuery] string? oldEmpCode, [FromQuery] int? excludeEmpId) =>
        Data(await repo.CheckDuplicateAsync(aadhaar, mobile, oldEmpCode, excludeEmpId, Ct));

    [HttpGet("recruits"), HasPermission(Perm.RecruitView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Recruits([FromQuery] PagedQuery q) =>
        Data(await repo.GetRecruitsAsync(q.Status, q.BranchId, q.Search, q.From, q.To, q.Page, q.PageSize, Ct));

    [HttpPost("recruits"), HasPermission(Perm.RecruitEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveRecruit([FromBody] RecruitRequest r) =>
        Command(await repo.SaveRecruitAsync(r.Name, r.Mobile, r.Aadhaar, r.OldEmpCode, r.BranchId,
                                            r.DesignationId, r.SourceBy, r.Dated, r.Remark, r.RecruitId, Ct));

    [HttpPost("recruits/{id:int}/status"), HasPermission(Perm.RecruitApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SetRecruitStatus(int id, [FromBody] StatusRequest r) =>
        Command(await repo.SetRecruitStatusAsync(id, r.Status, r.Remark, Ct));

    /// <summary>Converts an approved recruit into an employee and allocates the code under an applock.</summary>
    [HttpPost("recruits/{id:int}/convert"), HasPermission(Perm.RecruitApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> ConvertRecruit(int id, [FromBody] ConvertRequest r) =>
        Command(await repo.ConvertRecruitAsync(id, r.Doj, Ct));

    // -------------------------------------------------------------- employees

    [HttpGet("employees"), HasPermission(Perm.EmployeeView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Employees(
        [FromQuery] PagedQuery q, [FromQuery] int? clientId, [FromQuery] int? designationId,
        [FromQuery] bool? isGunman, [FromQuery] bool? isReliever, [FromQuery] bool? pvPending)
    {
        var filter = new EmployeeFilter(q.BranchId, q.UnitId, clientId, designationId, q.Status,
                                        isGunman, isReliever, pvPending, q.Search, q.Page, q.PageSize,
                                        q.SortBy ?? "EmpFullName", q.SortDir ?? "asc");
        var result = await repo.GetEmployeesAsync(filter, Ct);
        return Paged(result, q);
    }

    /// <summary>Fourteen result sets: one per tab of the employee profile screen.</summary>
    [HttpGet("employees/{empId:int}"), HasPermission(Perm.EmployeeView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Employee360(int empId) =>
        Data(await repo.GetEmployee360Async(empId, Ct));

    /// <summary>
    /// Step one of the six-step biodata wizard. Only the fields this step sent are
    /// applied; anything omitted keeps its stored value, so the wizard can autosave
    /// each step without carrying the whole 196-field payload.
    /// </summary>
    [HttpPatch("employees/{empId:int}"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveCore(
        int empId, [FromBody] Dictionary<string, object?> fields) =>
        Command(await repo.SaveEmployeeCoreAsync(empId, fields, Ct));

    [HttpPut("employees/{empId:int}/addresses/{addressType}"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveAddress(
        int empId, string addressType, [FromBody] AddressRequest r) =>
        Command(await repo.SaveAddressAsync(empId, addressType, r.Address1, r.Address2, r.City,
                                            r.StateId, r.DistrictId, r.Pin, r.Telephone, r.AddressDuration, Ct));

    [HttpPost("employees/{empId:int}/family"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveFamily(int empId, [FromBody] FamilyRequest r) =>
        Command(await repo.SaveFamilyAsync(empId, r.Relation, r.Name, r.Dob, r.Occupation,
                                           r.Dependent, r.SharePercent, r.AadhaarNo, r.FamilyId, Ct));

    [HttpPut("employees/{empId:int}/bank"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveBank(int empId, [FromBody] BankRequest r) =>
        Command(await repo.SaveBankAsync(empId, r.BankId, r.BankName, r.BranchName, r.BankAcNo, r.Ifsc,
                                         r.IfscCodeId, r.AcType, r.NameInBankPassbook, r.PassbookUrl, r.ChequeUrl, Ct));

    [HttpPut("employees/{empId:int}/statutory"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveStatutory(int empId, [FromBody] StatutoryRequest r) =>
        Command(await repo.SaveStatutoryAsync(empId, r.Aadhaar, r.Pan, r.VoterId, r.DlNo,
                                              r.Uan, r.PfNo, r.EsicNo, r.PaymentMode, Ct));

    [HttpPut("employees/{empId:int}/verification"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveVerification(int empId, [FromBody] VerificationRequest r) =>
        Command(await repo.SaveVerificationAsync(empId, r.IsPoliceVerification, r.PvNo, r.PoliceStation,
                                                 r.RemarkByThana, r.SendDate, r.ReturnDate, r.ValidUpTo, r.CertificateUrl, Ct));

    [HttpPut("employees/{empId:int}/gun-licence"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveGunLicence(int empId, [FromBody] GunLicenceRequest r) =>
        Command(await repo.SaveGunLicenceAsync(empId, r.GunanType, r.TypeArm, r.GunNo, r.GunModelNum,
                                               r.LicenceNo, r.Expiry, r.AreaId, r.IssueDate, Ct));

    [HttpPost("employees/{empId:int}/blacklist"), HasPermission(Perm.EmployeeEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Blacklist(int empId, [FromBody] BlacklistRequest r) =>
        Command(await repo.BlacklistAsync(empId, r.Blacklist, r.Reason, Ct));

    // -------------------------------------------------------- clients, units

    [HttpPost("clients"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveClient([FromBody] ClientInput input) =>
        Command(await repo.SaveClientAsync(input, Ct));

    /// <summary>
    /// Clients with the numbers the list screen needs inline: units, guards
    /// deployed, open complaints and what is still owed.
    /// </summary>
    [HttpGet("clients"), HasPermission(Perm.ClientView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Clients([FromQuery] PagedQuery q)
    {
        var result = await repo.GetClientsAsync(q.BranchId, q.Search, q.Status, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("units"), HasPermission(Perm.ClientView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Units(
        [FromQuery] PagedQuery q, [FromQuery] int? clientId)
    {
        var result = await repo.GetUnitsAsync(clientId, q.BranchId, q.Search, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpPost("units"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveUnit([FromBody] UnitInput input) =>
        Command(await repo.SaveUnitAsync(input, Ct));

    [HttpPost("units/{unitId:int}/posts"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SavePost(int unitId, [FromBody] UnitPostRequest r) =>
        Command(await repo.SaveUnitPostAsync(unitId, r.PostName, r.DesignationId, r.ShiftId,
                                             r.RequiredStrength, r.RatePerGuard, r.IsArmed, r.EffectiveFrom, r.PostId, Ct));

    [HttpPost("units/{unitId:int}/locations"), HasPermission(Perm.ClientEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> SaveUnitLocation(int unitId, [FromBody] UnitLocationRequest r) =>
        Command(await repo.SaveUnitLocationAsync(unitId, r.LocationName, r.Latitude, r.Longitude,
                                                 r.Description, r.LocationId, Ct));
}

public sealed record RecruitRequest(string Name, string? Mobile = null, string? Aadhaar = null,
    string? OldEmpCode = null, int? BranchId = null, int? DesignationId = null, string? SourceBy = null,
    DateOnly? Dated = null, string? Remark = null, int? RecruitId = null);
public sealed record StatusRequest(string Status, string? Remark = null);
public sealed record ConvertRequest(DateOnly? Doj = null);
public sealed record AddressRequest(string? Address1, string? Address2, string? City, int? StateId,
    int? DistrictId, string? Pin, string? Telephone, string? AddressDuration);
public sealed record FamilyRequest(string Relation, string Name, DateOnly? Dob = null, string? Occupation = null,
    bool Dependent = false, decimal? SharePercent = null, string? AadhaarNo = null, int? FamilyId = null);
public sealed record BankRequest(int? BankId, string? BankName, string? BranchName, string? BankAcNo,
    string? Ifsc, int? IfscCodeId, string? AcType, string? NameInBankPassbook, string? PassbookUrl, string? ChequeUrl);
public sealed record StatutoryRequest(string? Aadhaar, string? Pan, string? VoterId, string? DlNo,
    string? Uan, string? PfNo, string? EsicNo, string? PaymentMode);
public sealed record VerificationRequest(bool? IsPoliceVerification, string? PvNo, string? PoliceStation,
    string? RemarkByThana, DateOnly? SendDate, DateOnly? ReturnDate, DateOnly? ValidUpTo, string? CertificateUrl);
public sealed record GunLicenceRequest(string? GunanType, string? TypeArm, string? GunNo, string? GunModelNum,
    string? LicenceNo, DateOnly? Expiry, int? AreaId, DateOnly? IssueDate);
public sealed record BlacklistRequest(bool Blacklist, string Reason);
public sealed record UnitPostRequest(string PostName, int? DesignationId, int? ShiftId, int RequiredStrength,
    decimal RatePerGuard, bool IsArmed = false, DateOnly? EffectiveFrom = null, int? PostId = null);
public sealed record UnitLocationRequest(string LocationName, decimal? Latitude, decimal? Longitude,
    string? Description, int? LocationId);
