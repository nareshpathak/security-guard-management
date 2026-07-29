using Diti365.Contracts.Auth;
using Diti365.Infrastructure.Data;
using Microsoft.Data.SqlClient;

namespace Diti365.Infrastructure.Repositories;

public static partial class Map
{
    public static Func<SqlDataReader, AuthCandidate> AuthCandidate(SqlDataReader r)
    {
        int oUserId   = r.GetOrdinal("UserID"),
            oCompany  = r.GetOrdinal("CompanyID"),
            oBranch   = r.GetOrdinal("BranchID"),
            oEmp      = r.GetOrdinal("EmpID"),
            oClient   = r.GetOrdinal("ClientID"),
            oUserName = r.GetOrdinal("UserName"),
            oMobile   = r.GetOrdinal("MobileNo"),
            oHash     = r.GetOrdinal("PasswordHash"),
            oSalt     = r.GetOrdinal("PasswordSalt"),
            oLegacy   = r.GetOrdinal("LegacyPasswordHash"),
            oMustChg  = r.GetOrdinal("MustChangePassword"),
            oRoleId   = r.GetOrdinal("RoleID"),
            oRoleCode = r.GetOrdinal("RoleCode"),
            oLoginTy  = r.GetOrdinal("LoginType"),
            oDevice   = r.GetOrdinal("DeviceID"),
            oActive   = r.GetOrdinal("IsActive"),
            oLocked   = r.GetOrdinal("IsLocked"),
            oFailed   = r.GetOrdinal("FailedLoginCount"),
            oLockUntil= r.GetOrdinal("LockedUntil"),
            oExpires  = r.GetOrdinal("ExpiresOn"),
            oCoActive = r.GetOrdinal("CompanyIsActive"),
            oCoExpired= r.GetOrdinal("CompanyIsExpired"),
            oCoExpDate= r.GetOrdinal("CompanyExpiryDate"),
            oCoMax    = r.GetOrdinal("CompanyMaxUsers"),
            oCoCount  = r.GetOrdinal("CompanyUserCount");

        return row => new AuthCandidate(
            row.Int(oUserId), row.IntN(oCompany), row.IntN(oBranch), row.IntN(oEmp), row.IntN(oClient),
            row.Str(oUserName), row.Str(oMobile),
            row.StrN(oHash), row.StrN(oSalt), row.StrN(oLegacy),
            row.Bool(oMustChg), row.Int(oRoleId), row.Str(oRoleCode), row.IntN(oLoginTy),
            row.StrN(oDevice), row.Bool(oActive), row.Bool(oLocked), row.Int(oFailed),
            row.DateTimeN(oLockUntil), row.DateN(oExpires),
            row.Bool(oCoActive), row.Bool(oCoExpired), row.DateN(oCoExpDate),
            row.IntN(oCoMax) ?? 0, row.IntN(oCoCount) ?? 0);
    }

    public static Func<SqlDataReader, AuthUser> AuthUser(SqlDataReader r)
    {
        int oId       = r.GetOrdinal("Id"),
            oCompany  = r.GetOrdinal("Companyid"),
            oBranch   = r.GetOrdinal("BranchID"),
            oEmpCode  = r.GetOrdinal("EmpCode"),
            oName     = r.GetOrdinal("Name"),
            oMobile   = r.GetOrdinal("MobileNo"),
            oDesig    = r.GetOrdinal("Designation"),
            oUnit     = r.GetOrdinal("Unit"),
            oLoginTy  = r.GetOrdinal("LoginType"),
            oRoleCode = r.GetOrdinal("RoleCode"),
            oPhoto    = r.GetOrdinal("PhotoUrl"),
            oAttCount = r.GetOrdinal("AttendanceCount"),
            oMustChg  = r.GetOrdinal("MustChangePassword"),
            oExpires  = r.GetOrdinal("ExpiresOn");

        return row => new AuthUser(
            row.Int(oId), row.IntN(oCompany), row.IntN(oBranch),
            EmpId: null, ClientId: null,
            UserName: row.Str(oName), Name: row.Str(oName),
            EmpCode: row.StrN(oEmpCode), MobileNo: row.StrN(oMobile),
            Designation: row.StrN(oDesig), Unit: row.StrN(oUnit),
            RoleCode: row.Str(oRoleCode), LoginType: row.IntN(oLoginTy),
            PhotoUrl: row.StrN(oPhoto), MustChangePassword: row.Bool(oMustChg),
            ExpiresOn: row.DateN(oExpires), AttendanceCount: row.IntN(oAttCount) ?? 0);
    }

    public static Func<SqlDataReader, PermissionGrant> PermissionGrant(SqlDataReader r)
    {
        int oModule = r.GetOrdinal("Module"),
            oCode   = r.GetOrdinal("Code"),
            oName   = r.GetOrdinal("Name"),
            oView   = r.GetOrdinal("CanView"),
            oCreate = r.GetOrdinal("CanCreate"),
            oEdit   = r.GetOrdinal("CanEdit"),
            oDelete = r.GetOrdinal("CanDelete"),
            oApprove= r.GetOrdinal("CanApprove"),
            oExport = r.GetOrdinal("CanExport");

        return row => new PermissionGrant(
            row.Str(oModule), row.Str(oCode), row.Str(oName),
            row.Bool(oView), row.Bool(oCreate), row.Bool(oEdit),
            row.Bool(oDelete), row.Bool(oApprove), row.Bool(oExport));
    }

    /// <summary>Generic (ID, Name) lookup row used by every master dropdown.</summary>
    public static Func<SqlDataReader, LookupItem> Lookup(SqlDataReader r)
    {
        int oId   = r.OrdinalOrDefault("ID");
        if (oId < 0) oId = 0;
        int oName = r.OrdinalOrDefault("Name");
        if (oName < 0) oName = 1;
        return row => new LookupItem(row.Int(oId), row.Str(oName));
    }
}

public sealed record LookupItem(int Id, string Name);
