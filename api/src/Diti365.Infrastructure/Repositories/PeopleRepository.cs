using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

public interface IPeopleRepository
{
    // recruitment
    Task<IReadOnlyList<Row>> CheckDuplicateAsync(string? aadhaar, string? mobile, string? oldEmpCode, int? excludeEmpId, CancellationToken ct);
    Task<SpResult> SaveRecruitAsync(string name, string? mobile, string? aadhaar, string? oldEmpCode, int? branchId,
                                    int? designationId, string? sourceBy, DateOnly? dated, string? remark, int? recruitId, CancellationToken ct);
    Task<SpResult> SetRecruitStatusAsync(int recruitId, string status, string? remark, CancellationToken ct);
    Task<SpResult> ConvertRecruitAsync(int recruitId, DateOnly? doj, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetRecruitsAsync(string? status, int? branchId, string? search,
                                                             DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);

    // employees
    Task<PagedResult<Row>> GetEmployeesAsync(EmployeeFilter f, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetEmployee360Async(int empId, CancellationToken ct);
    Task<SpResult> SaveEmployeeCoreAsync(int empId, IDictionary<string, object?> fields, CancellationToken ct);
    Task<SpResult> SaveAddressAsync(int empId, string addressType, string? a1, string? a2, string? city,
                                    int? stateId, int? districtId, string? pin, string? phone, string? duration, CancellationToken ct);
    Task<SpResult> SaveFamilyAsync(int empId, string relation, string name, DateOnly? dob, string? occupation,
                                   bool dependent, decimal? sharePercent, string? aadhaar, int? familyId, CancellationToken ct);
    Task<SpResult> SaveBankAsync(int empId, int? bankId, string? bankName, string? branchName, string? acNo,
                                 string? ifsc, int? ifscId, string? acType, string? nameInPassbook,
                                 string? passbookUrl, string? chequeUrl, CancellationToken ct);
    Task<SpResult> SaveStatutoryAsync(int empId, string? aadhaar, string? pan, string? voter, string? dl,
                                      string? uan, string? pf, string? esic, string? paymentMode, CancellationToken ct);
    Task<SpResult> SaveVerificationAsync(int empId, bool? verified, string? pvNo, string? station, string? thanaRemark,
                                         DateOnly? sendDate, DateOnly? returnDate, DateOnly? validUpTo, string? certUrl, CancellationToken ct);
    Task<SpResult> SaveGunLicenceAsync(int empId, string? gunanType, string? typeArm, string? gunNo, string? model,
                                       string? licenceNo, DateOnly? expiry, int? areaId, DateOnly? issueDate, CancellationToken ct);
    Task<SpResult> BlacklistAsync(int empId, bool blacklist, string reason, CancellationToken ct);

    // clients and units
    Task<SpResult> SaveClientAsync(ClientInput input, CancellationToken ct);
    Task<SpResult> SaveUnitAsync(UnitInput input, CancellationToken ct);
    Task<SpResult> SaveUnitPostAsync(int unitId, string postName, int? designationId, int? shiftId,
                                     int requiredStrength, decimal ratePerGuard, bool isArmed,
                                     DateOnly? effectiveFrom, int? postId, CancellationToken ct);
    Task<PagedResult<Row>> GetClientsAsync(int? branchId, string? search, string? status, int page, int pageSize, CancellationToken ct);
    Task<PagedResult<Row>> GetUnitsAsync(int? clientId, int? branchId, string? search, int page, int pageSize, CancellationToken ct);
    Task<SpResult> SaveUnitLocationAsync(int unitId, string name, decimal? lat, decimal? lon, string? description, int? locationId, CancellationToken ct);
}

public sealed record EmployeeFilter(
    int? BranchId = null, int? UnitId = null, int? ClientId = null, int? DesignationId = null,
    string? EmpStatus = null, bool? IsGunman = null, bool? IsReliever = null, bool? PvPending = null,
    string? Search = null, int Page = 1, int PageSize = 50, string SortBy = "EmpFullName", string SortDir = "asc");

public sealed record ClientInput(string ClientName, int? BranchId, string? ClientCode, string? Address,
    int? CityId, int? StateId, string? Pin, string? Gstin, string? Pan,
    string? ContactPerson, string? ContactNo, string? Email, int? ClientId);

public sealed record UnitInput(int ClientId, string UnitName, int? BranchId, string? UnitCode, string? Address,
    int? CityId, int? StateId, string? Pin, decimal? Latitude, decimal? Longitude, int GeofenceRadiusMeters,
    int? SupervisorEmpId, string? AgreementNo, DateOnly? AgreementExpDate, string? OrderNo, DateOnly? OrderDate,
    DateOnly? OrderExpiryDate, DateOnly? WorkStartDate, int? UnitId);

public sealed class PeopleRepository(IDbExecutor db) : IPeopleRepository
{
    public Task<IReadOnlyList<Row>> CheckDuplicateAsync(string? aadhaar, string? mobile, string? oldEmpCode, int? excludeEmpId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_People_CheckDuplicate", p =>
        {
            p.Add(P.NVar("@AdharCardNo",  aadhaar, 12));
            p.Add(P.NVar("@Mobile",       mobile, 15));
            p.Add(P.NVar("@OldEmpCode",   oldEmpCode, 30));
            p.Add(P.Int ("@ExcludeEmpID", excludeEmpId));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveRecruitAsync(string name, string? mobile, string? aadhaar, string? oldEmpCode, int? branchId,
                                           int? designationId, string? sourceBy, DateOnly? dated, string? remark, int? recruitId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Recruit_Save", p =>
        {
            p.Add(P.NVar("@Name",          name, 200));
            p.Add(P.NVar("@Mobile",        mobile, 15));
            p.Add(P.NVar("@AdharCardNo",   aadhaar, 12));
            p.Add(P.NVar("@OldEmpCode",    oldEmpCode, 30));
            p.Add(P.Int ("@BranchID",      branchId));
            p.Add(P.Int ("@DesignationID", designationId));
            p.Add(P.NVar("@SourceBy",      sourceBy, 100));
            p.Add(P.Date("@Dated",         dated));
            p.Add(P.NVar("@Remark",        remark, 500));
            p.Add(P.Int ("@RecruitID",     recruitId));
        }, ct);

    public Task<SpResult> SetRecruitStatusAsync(int recruitId, string status, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Recruit_SetStatus", p =>
        {
            p.Add(P.Int ("@RecruitID", recruitId));
            p.Add(P.NVar("@Status",    status, 20));
            p.Add(P.NVar("@Remark",    remark, 500));
        }, ct);

    public Task<SpResult> ConvertRecruitAsync(int recruitId, DateOnly? doj, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Recruit_Convert", p =>
        {
            p.Add(P.Int ("@RecruitID", recruitId));
            p.Add(P.Date("@Doj",       doj));
        }, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetRecruitsAsync(string? status, int? branchId, string? search,
                                                                    DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct) =>
        MultiAsync("dbo.usp_Recruit_GetList", p =>
        {
            p.Add(P.NVar("@Status",   status, 20));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Date("@FromDate", from));
            p.Add(P.Date("@ToDate",   to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, ct);

    public Task<PagedResult<Row>> GetEmployeesAsync(EmployeeFilter f, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Employee_GetList", p =>
        {
            p.Add(P.Int ("@BranchID",      f.BranchId));
            p.Add(P.Int ("@UnitID",        f.UnitId));
            p.Add(P.Int ("@ClientID",      f.ClientId));
            p.Add(P.Int ("@DesignationID", f.DesignationId));
            p.Add(P.NVar("@EmpStatus",     f.EmpStatus, 20));
            p.Add(P.Bit ("@IsGunman",      f.IsGunman));
            p.Add(P.Bit ("@IsReliever",    f.IsReliever));
            p.Add(P.Bit ("@PvPending",     f.PvPending));
            p.Add(P.NVar("@Search",        f.Search, 200));
            p.Add(P.Int ("@PageNo",        f.Page));
            p.Add(P.Int ("@PageSize",      f.PageSize));
            p.Add(P.NVar("@SortBy",        f.SortBy, 50));
            p.Add(P.NVar("@SortDir",       f.SortDir, 4));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetEmployee360Async(int empId, CancellationToken ct) =>
        MultiAsync("dbo.usp_Employee_Get360", p => p.Add(P.Int("@EmpID", empId)), ct);

    /// <summary>
    /// The six-step biodata wizard autosaves one step at a time. Only the fields the
    /// step actually sent are passed; the procedure keeps the existing value for
    /// anything omitted (ISNULL(@param, column)).
    /// </summary>
    public Task<SpResult> SaveEmployeeCoreAsync(int empId, IDictionary<string, object?> f, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveCore", p =>
        {
            p.Add(P.Int ("@EmpID",            empId));
            p.Add(P.NVar("@Salutation",       Str(f, "salutation"), 10));
            p.Add(P.NVar("@FirstName",        Str(f, "firstName"), 100));
            p.Add(P.NVar("@Middlename",       Str(f, "middlename"), 100));
            p.Add(P.NVar("@LastName",         Str(f, "lastName"), 100));
            p.Add(P.NVar("@Gender",           Str(f, "gender"), 10));
            p.Add(P.Date("@Dob",              Date(f, "dob")));
            p.Add(P.NVar("@BirthPlace",       Str(f, "birthPlace"), 100));
            p.Add(P.NVar("@Bloodgroup",       Str(f, "bloodgroup"), 5));
            p.Add(P.NVar("@Nationality",      Str(f, "nationality"), 50));
            p.Add(P.Bit ("@Married",          Bool(f, "married")));
            p.Add(P.NVar("@SpouseName",       Str(f, "spouseName"), 150));
            p.Add(P.NVar("@Mobile1",          Str(f, "mobile1"), 15));
            p.Add(P.NVar("@Mobile2",          Str(f, "mobile2"), 15));
            p.Add(P.NVar("@EmailId1",         Str(f, "emailId1"), 150));
            p.Add(P.Int ("@DesignationID",    Int(f, "designationId")));
            p.Add(P.Int ("@CategoryID",       Int(f, "categoryId")));
            p.Add(P.Int ("@GradeID",          Int(f, "gradeId")));
            p.Add(P.Int ("@ShiftID",          Int(f, "shiftId")));
            p.Add(P.NVar("@Employeetype",     Str(f, "employeetype"), 50));
            p.Add(P.Date("@Doj",              Date(f, "doj")));
            p.Add(P.NVar("@BeltNo",           Str(f, "beltNo"), 30));
            p.Add(P.NVar("@IdCardNo",         Str(f, "idCardNo"), 30));
            p.Add(P.Date("@IdCardIssueDate",  Date(f, "idCardIssueDate")));
            p.Add(P.Date("@IdCardExpireDate", Date(f, "idCardExpireDate")));
            p.Add(P.NVar("@Photo",            Str(f, "photo"), 500));
            p.Add(P.Bit ("@IsGunman",         Bool(f, "isGunman")));
            p.Add(P.Bit ("@IsReliever",       Bool(f, "isReliever")));
            p.Add(P.Bit ("@IsExService",      Bool(f, "isExService")));
            p.Add(P.NVar("@Comments",         Str(f, "comments"), 1000));
        }, ct);

    public Task<SpResult> SaveAddressAsync(int empId, string addressType, string? a1, string? a2, string? city,
                                           int? stateId, int? districtId, string? pin, string? phone, string? duration, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveAddress", p =>
        {
            p.Add(P.Int ("@EmpID",           empId));
            p.Add(P.Char("@AddressType",     addressType, 1));
            p.Add(P.NVar("@Address1",        a1, 300));
            p.Add(P.NVar("@Address2",        a2, 300));
            p.Add(P.NVar("@City",            city, 100));
            p.Add(P.Int ("@StateID",         stateId));
            p.Add(P.Int ("@DistrictID",      districtId));
            p.Add(P.NVar("@Pin",             pin, 10));
            p.Add(P.NVar("@Telephone",       phone, 20));
            p.Add(P.NVar("@AddressDuration", duration, 50));
        }, ct);

    public Task<SpResult> SaveFamilyAsync(int empId, string relation, string name, DateOnly? dob, string? occupation,
                                          bool dependent, decimal? sharePercent, string? aadhaar, int? familyId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveFamily", p =>
        {
            p.Add(P.Int ("@EmpID",        empId));
            p.Add(P.NVar("@Relation",     relation, 30));
            p.Add(P.NVar("@Name",         name, 200));
            p.Add(P.Date("@Dob",          dob));
            p.Add(P.NVar("@Occupation",   occupation, 100));
            p.Add(P.Bit ("@Dependent",    dependent));
            p.Add(P.Dec ("@SharePercent", sharePercent, 5, 2));
            p.Add(P.NVar("@AadhaarNo",    aadhaar, 12));
            p.Add(P.Int ("@FamilyID",     familyId));
        }, ct);

    public Task<SpResult> SaveBankAsync(int empId, int? bankId, string? bankName, string? branchName, string? acNo,
                                        string? ifsc, int? ifscId, string? acType, string? nameInPassbook,
                                        string? passbookUrl, string? chequeUrl, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveBank", p =>
        {
            p.Add(P.Int ("@EmpID",              empId));
            p.Add(P.Int ("@BankID",             bankId));
            p.Add(P.NVar("@BankName",           bankName, 150));
            p.Add(P.NVar("@BranchName",         branchName, 150));
            p.Add(P.NVar("@BankAcNo",           acNo, 30));
            p.Add(P.NVar("@IFSCcode",           ifsc, 11));
            p.Add(P.Int ("@IfscCodeId",         ifscId));
            p.Add(P.NVar("@AcType",             acType, 30));
            p.Add(P.NVar("@NameInBankPassbook", nameInPassbook, 150));
            p.Add(P.NVar("@BankPassbook",       passbookUrl, 500));
            p.Add(P.NVar("@Cheque",             chequeUrl, 500));
        }, ct);

    public Task<SpResult> SaveStatutoryAsync(int empId, string? aadhaar, string? pan, string? voter, string? dl,
                                             string? uan, string? pf, string? esic, string? paymentMode, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveStatutory", p =>
        {
            p.Add(P.Int ("@EmpID",       empId));
            p.Add(P.NVar("@AdharCardNo", aadhaar, 12));
            p.Add(P.NVar("@PanCardNo",   pan, 10));
            p.Add(P.NVar("@VoterId",     voter, 30));
            p.Add(P.NVar("@DlNo",        dl, 30));
            p.Add(P.NVar("@UANNo",       uan, 12));
            p.Add(P.NVar("@PFNo",        pf, 30));
            p.Add(P.NVar("@ESICNo",      esic, 20));
            p.Add(P.NVar("@PaymentMode", paymentMode, 30));
        }, ct);

    public Task<SpResult> SaveVerificationAsync(int empId, bool? verified, string? pvNo, string? station, string? thanaRemark,
                                                DateOnly? sendDate, DateOnly? returnDate, DateOnly? validUpTo, string? certUrl, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveVerification", p =>
        {
            p.Add(P.Int ("@EmpID",                empId));
            p.Add(P.Bit ("@IsPoliceVerification", verified));
            p.Add(P.NVar("@PoliceVerificationNo", pvNo, 50));
            p.Add(P.NVar("@PoliceStationName",    station, 150));
            p.Add(P.NVar("@RemarkByThana",        thanaRemark, 500));
            p.Add(P.Date("@Pvsenddate",           sendDate));
            p.Add(P.Date("@Pvreturndate",         returnDate));
            p.Add(P.Date("@PVValidUpTo",          validUpTo));
            p.Add(P.NVar("@PoliceCertificateImg", certUrl, 500));
        }, ct);

    public Task<SpResult> SaveGunLicenceAsync(int empId, string? gunanType, string? typeArm, string? gunNo, string? model,
                                              string? licenceNo, DateOnly? expiry, int? areaId, DateOnly? issueDate, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_SaveGunLicence", p =>
        {
            p.Add(P.Int ("@EmpID",         empId));
            p.Add(P.NVar("@GunanType",     gunanType, 50));
            p.Add(P.NVar("@TypeArm",       typeArm, 50));
            p.Add(P.NVar("@GunNo",         gunNo, 50));
            p.Add(P.NVar("@GunModelNum",   model, 50));
            p.Add(P.NVar("@LicenseNo",     licenceNo, 50));
            p.Add(P.Date("@Licenseexpire", expiry));
            p.Add(P.Int ("@AreaID",        areaId));
            p.Add(P.Date("@IssueDate",     issueDate));
        }, ct);

    public Task<SpResult> BlacklistAsync(int empId, bool blacklist, string reason, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Employee_Blacklist", p =>
        {
            p.Add(P.Int ("@EmpID",     empId));
            p.Add(P.Bit ("@Blacklist", blacklist));
            p.Add(P.NVar("@Reason",    reason, 500));
        }, ct);

    public Task<SpResult> SaveClientAsync(ClientInput i, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Client_Save", p =>
        {
            p.Add(P.NVar("@ClientName",     i.ClientName, 200));
            p.Add(P.Int ("@BranchID",       i.BranchId));
            p.Add(P.NVar("@ClientCode",     i.ClientCode, 30));
            p.Add(P.NVar("@CompanyAddress", i.Address, 500));
            p.Add(P.Int ("@CityID",         i.CityId));
            p.Add(P.Int ("@StateID",        i.StateId));
            p.Add(P.NVar("@Pin",            i.Pin, 10));
            p.Add(P.NVar("@GSTIN",          i.Gstin, 15));
            p.Add(P.NVar("@PAN",            i.Pan, 10));
            p.Add(P.NVar("@ContactPerson",  i.ContactPerson, 150));
            p.Add(P.NVar("@ContactNo",      i.ContactNo, 15));
            p.Add(P.NVar("@Email",          i.Email, 150));
            p.Add(P.Int ("@ClientID",       i.ClientId));
        }, ct);

    public Task<SpResult> SaveUnitAsync(UnitInput i, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Unit_Save", p =>
        {
            p.Add(P.Int  ("@ClientID",             i.ClientId));
            p.Add(P.NVar ("@UnitName",             i.UnitName, 200));
            p.Add(P.Int  ("@BranchID",             i.BranchId));
            p.Add(P.NVar ("@UnitCode",             i.UnitCode, 30));
            p.Add(P.NVar ("@Address",              i.Address, 500));
            p.Add(P.Int  ("@CityID",               i.CityId));
            p.Add(P.Int  ("@StateID",              i.StateId));
            p.Add(P.NVar ("@Pin",                  i.Pin, 10));
            p.Add(P.Coord("@Latitude",             i.Latitude));
            p.Add(P.Coord("@Longitude",            i.Longitude));
            p.Add(P.Int  ("@GeofenceRadiusMeters", i.GeofenceRadiusMeters));
            p.Add(P.Int  ("@SupervisorEmpID",      i.SupervisorEmpId));
            p.Add(P.NVar ("@AgreementNo",          i.AgreementNo, 50));
            p.Add(P.Date ("@AgreementExpDate",     i.AgreementExpDate));
            p.Add(P.NVar ("@OrderNo",              i.OrderNo, 50));
            p.Add(P.Date ("@OrderDate",            i.OrderDate));
            p.Add(P.Date ("@OrderExpiryDate",      i.OrderExpiryDate));
            p.Add(P.Date ("@WorkStartDate",        i.WorkStartDate));
            p.Add(P.Int  ("@UnitID",               i.UnitId));
        }, ct);

    public Task<SpResult> SaveUnitPostAsync(int unitId, string postName, int? designationId, int? shiftId,
                                            int requiredStrength, decimal ratePerGuard, bool isArmed,
                                            DateOnly? effectiveFrom, int? postId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_UnitPost_Save", p =>
        {
            p.Add(P.Int  ("@UnitID",           unitId));
            p.Add(P.NVar ("@PostName",         postName, 150));
            p.Add(P.Int  ("@DesignationID",    designationId));
            p.Add(P.Int  ("@ShiftID",          shiftId));
            p.Add(P.Int  ("@RequiredStrength", requiredStrength));
            p.Add(P.Money("@RatePerGuard",     ratePerGuard));
            p.Add(P.Bit  ("@IsArmed",          isArmed));
            p.Add(P.Date ("@EffectiveFrom",    effectiveFrom));
            p.Add(P.Int  ("@PostID",           postId));
        }, ct);

    public Task<PagedResult<Row>> GetClientsAsync(int? branchId, string? search, string? status, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Client_GetList", p =>
        {
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.NVar("@Status",   status, 20));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetUnitsAsync(int? clientId, int? branchId, string? search, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Unit_GetList", p =>
        {
            p.Add(P.Int ("@ClientID", clientId));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<SpResult> SaveUnitLocationAsync(int unitId, string name, decimal? lat, decimal? lon,
                                                string? description, int? locationId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_UnitLocation_Save", p =>
        {
            p.Add(P.Int  ("@UnitID",       unitId));
            p.Add(P.NVar ("@LocationName", name, 150));
            p.Add(P.Coord("@Latitude",     lat));
            p.Add(P.Coord("@Longitude",    lon));
            p.Add(P.NVar ("@Description",  description, 500));
            p.Add(P.Int  ("@LocationID",   locationId));
        }, ct);

    // ------------------------------------------------------------- helpers

    private Task<IReadOnlyList<IReadOnlyList<Row>>> MultiAsync(
        string procedure, Action<Microsoft.Data.SqlClient.SqlParameterCollection>? parameters, CancellationToken ct) =>
        db.QueryMultipleAsync(procedure, parameters, async (reader, token) =>
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

    private static string?  Str (IDictionary<string, object?> f, string k) => f.TryGetValue(k, out var v) ? v?.ToString() : null;
    private static int?     Int (IDictionary<string, object?> f, string k) => f.TryGetValue(k, out var v) && v is not null && int.TryParse(v.ToString(), out var i) ? i : null;
    private static bool?    Bool(IDictionary<string, object?> f, string k) => f.TryGetValue(k, out var v) && v is not null && bool.TryParse(v.ToString(), out var b) ? b : null;
    private static DateOnly? Date(IDictionary<string, object?> f, string k) => f.TryGetValue(k, out var v) && v is not null && DateOnly.TryParse(v.ToString(), out var d) ? d : null;
}
