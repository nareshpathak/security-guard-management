/*==============================================================================
  510_procedures_users.sql
  Authentication, profile and master-data procedures.
  Spec: docs/prd/01-database.md §7.1 ; docs/prd/02-api.md §4.1

  RESULT-SET CONTRACT (matches IDbExecutor in docs/prd/02-api.md §3.1)
  --------------------------------------------------------------------
  Command procedures  : one result set - (Success BIT, Status INT, Id INT, Message NVARCHAR(500))
  Read procedures     : result set 1 = data
  Paged read procs    : result set 1 = data, result set 2 = (TotalRows INT)

  PASSWORDS ARE NOT VERIFIED IN SQL
  ---------------------------------
  PBKDF2 with 210 000 iterations cannot run in T-SQL. The login flow is:
      1. usp_User_GetForAuthentication  -> API receives hash + salt + lock state
      2. API verifies the password in C# (Microsoft.AspNetCore.Cryptography.KeyDerivation)
      3. usp_User_LoginSucceeded  or  usp_User_LoginFailed
  usp_User_LoginSucceeded returns the legacy Loginmodel$Datum payload.
  See DECISIONS.md #19.

  Error numbers thrown here are 51000-51999 and are mapped to API error codes
  by the middleware (docs/prd/02-api.md §9).
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  AUTHENTICATION
==============================================================================*/

-- Step 1 of login. Tenant-less by design: the caller does not know CompanyID yet.
CREATE OR ALTER PROCEDURE dbo.usp_User_GetForAuthentication
    @LoginId NVARCHAR(100)          -- mobile number or user name
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        u.UserID,
        u.CompanyID,
        u.BranchID,
        u.EmpID,
        u.ClientID,
        u.UserName,
        u.MobileNo,
        u.PasswordHash,
        u.PasswordSalt,
        u.LegacyPasswordHash,
        u.MustChangePassword,
        u.RoleID,
        RoleCode        = r.RoleCode,
        u.LoginType,
        u.DeviceID,
        u.IsActive,
        u.IsLocked,
        u.FailedLoginCount,
        u.LockedUntil,
        u.ExpiresOn,
        CompanyIsActive  = ISNULL(c.IsActive, CAST(1 AS BIT)),
        CompanyIsExpired = ISNULL(c.IsExpired, CAST(0 AS BIT)),
        CompanyExpiryDate = c.ExpiryDate,
        CompanyMaxUsers  = c.MaxUsers,
        CompanyUserCount = c.UserCount
    FROM sec.Users AS u
    INNER JOIN sec.Role   AS r ON r.RoleID = u.RoleID
    LEFT  JOIN org.Company AS c ON c.CompanyID = u.CompanyID
    WHERE u.IsCancel = 0
      AND (u.MobileNo = @LoginId OR u.UserName = @LoginId);
END;
GO

-- Step 3a. Called only after the API has verified the password.
CREATE OR ALTER PROCEDURE dbo.usp_User_LoginSucceeded
    @UserID      INT,
    @DeviceID    NVARCHAR(200) = NULL,
    @DeviceModel NVARCHAR(120) = NULL,
    @FcmToken    NVARCHAR(500) = NULL,
    @AppVersion  NVARCHAR(20)  = NULL,
    @Platform    NVARCHAR(20)  = NULL,
    @IpAddress   NVARCHAR(45)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE sec.Users
        SET FailedLoginCount = 0,
            IsLocked         = 0,
            LockedUntil      = NULL,
            LastLoginAt      = SYSDATETIME(),
            DeviceID         = ISNULL(@DeviceID,    DeviceID),
            DeviceModel      = ISNULL(@DeviceModel, DeviceModel),
            FcmToken         = ISNULL(@FcmToken,    FcmToken),
            UpdateDate       = SYSDATETIME(),
            UpdateUserID     = @UserID
        WHERE UserID = @UserID;

        INSERT INTO sec.LoginLog (CompanyID, UserID, LoginAt, IpAddress, DeviceID, AppVersion, Platform, IsSuccess)
        SELECT u.CompanyID, u.UserID, SYSDATETIME(), @IpAddress, @DeviceID, @AppVersion, @Platform, 1
        FROM sec.Users AS u WHERE u.UserID = @UserID;

        UPDATE c
        SET c.LoginCount = c.LoginCount + 1
        FROM org.Company AS c
        INNER JOIN sec.Users AS u ON u.CompanyID = c.CompanyID
        WHERE u.UserID = @UserID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    -- Legacy Loginmodel$Datum payload
    SELECT
        Id              = u.UserID,
        Companyid       = u.CompanyID,
        BranchID        = u.BranchID,
        EmpCode         = e.EmpCode,
        Firstname       = ISNULL(e.FirstName, u.UserName),
        Lastname        = e.LastName,
        Name            = ISNULL(e.EmpFullName, u.UserName),
        MobileNo        = u.MobileNo,
        Designation     = d.DesignationName,
        Employeetype    = e.Employeetype,
        Unit            = un.UnitName,
        LoginType       = u.LoginType,
        RoleCode        = r.RoleCode,
        Deviceid        = u.DeviceID,
        TokenNo         = u.FcmToken,
        PhotoUrl        = ISNULL(u.PhotoUrl, e.Photo),
        AttendanceCount = ISNULL((SELECT COUNT(*)
                                  FROM ops.Attendance AS a
                                  WHERE a.EmpID = u.EmpID
                                    AND a.AttendanceDate = CAST(SYSDATETIME() AS DATE)
                                    AND a.IsCancel = 0), 0),
        MustChangePassword = u.MustChangePassword,
        ExpiresOn       = u.ExpiresOn
    FROM sec.Users AS u
    INNER JOIN sec.Role      AS r  ON r.RoleID = u.RoleID
    LEFT  JOIN hr.Employee   AS e  ON e.EmpID  = u.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit      AS un ON un.UnitID = e.UnitID
    WHERE u.UserID = @UserID;
END;
GO

-- Step 3b. Lockout after 5 consecutive failures for 15 minutes.
CREATE OR ALTER PROCEDURE dbo.usp_User_LoginFailed
    @LoginId    NVARCHAR(100),
    @Reason     NVARCHAR(200) = NULL,
    @IpAddress  NVARCHAR(45)  = NULL,
    @DeviceID   NVARCHAR(200) = NULL,
    @AppVersion NVARCHAR(20)  = NULL,
    @Platform   NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @UserID INT, @CompanyID INT;

    SELECT TOP (1) @UserID = u.UserID, @CompanyID = u.CompanyID
    FROM sec.Users AS u
    WHERE u.IsCancel = 0 AND (u.MobileNo = @LoginId OR u.UserName = @LoginId);

    BEGIN TRY
        BEGIN TRAN;

        IF @UserID IS NOT NULL
            UPDATE sec.Users
            SET FailedLoginCount = FailedLoginCount + 1,
                IsLocked    = CASE WHEN FailedLoginCount + 1 >= 5 THEN 1 ELSE IsLocked END,
                LockedUntil = CASE WHEN FailedLoginCount + 1 >= 5
                                   THEN DATEADD(MINUTE, 15, SYSDATETIME()) ELSE LockedUntil END,
                UpdateDate  = SYSDATETIME()
            WHERE UserID = @UserID;

        INSERT INTO sec.LoginLog (CompanyID, UserID, LoginAt, IpAddress, DeviceID, AppVersion, Platform, IsSuccess, FailReason)
        VALUES (@CompanyID, @UserID, SYSDATETIME(), @IpAddress, @DeviceID, @AppVersion, @Platform, 0, @Reason);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = ISNULL(@UserID, 0),
           Message = N'Recorded';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_Logout
    @UserID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- close the most recent open session, not an arbitrary one
    ;WITH latest AS (
        SELECT TOP (1) LogoutAt
        FROM sec.LoginLog
        WHERE UserID = @UserID AND LogoutAt IS NULL
        ORDER BY LoginAt DESC
    )
    UPDATE latest SET LogoutAt = SYSDATETIME();

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @UserID, Message = N'Logged out';
END;
GO

/*  api/Users/checknum - does this mobile exist, and is it usable  */
CREATE OR ALTER PROCEDURE dbo.usp_User_CheckMobile
    @MobileNo NVARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @UserID INT, @Exists BIT = 0, @Active BIT = 0;

    SELECT TOP (1) @UserID = UserID, @Exists = 1, @Active = IsActive
    FROM sec.Users
    WHERE MobileNo = @MobileNo AND IsCancel = 0;

    SELECT Success = CAST(@Exists AS BIT),
           Status  = CASE WHEN @Exists = 1 THEN 200 ELSE 404 END,
           Id      = ISNULL(@UserID, 0),
           Message = CASE WHEN @Exists = 0 THEN N'Mobile number not registered'
                          WHEN @Active = 0 THEN N'Account is inactive'
                          ELSE N'OK' END;
END;
GO

/*  api/Users/checkdeviceid - Deviceidmodel  */
CREATE OR ALTER PROCEDURE dbo.usp_User_CheckDeviceId
    @UserID   INT,
    @DeviceID NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Registered NVARCHAR(200), @Match BIT = 0;

    SELECT @Registered = DeviceID FROM sec.Users WHERE UserID = @UserID AND IsCancel = 0;

    IF @Registered IS NULL
    BEGIN
        UPDATE sec.Users SET DeviceID = @DeviceID, UpdateDate = SYSDATETIME() WHERE UserID = @UserID;
        SET @Registered = @DeviceID;
        SET @Match = 1;
    END
    ELSE IF @Registered = @DeviceID
        SET @Match = 1;

    SELECT Success = CAST(@Match AS BIT),
           Status  = CASE WHEN @Match = 1 THEN 200 ELSE 403 END,
           Id      = @UserID,
           Message = CASE WHEN @Match = 1 THEN N'Device recognised'
                          ELSE N'This account is registered on another device' END,
           DeviceId = @Registered;
END;
GO

/*  api/Users/checkexpire - Expirymodel  */
CREATE OR ALTER PROCEDURE dbo.usp_Company_CheckExpiry
    @CompanyID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        Success    = CAST(CASE WHEN c.IsExpired = 1 OR (c.ExpiryDate IS NOT NULL AND c.ExpiryDate < CAST(SYSDATETIME() AS DATE))
                               THEN 0 ELSE 1 END AS BIT),
        Status     = CASE WHEN c.IsExpired = 1 OR (c.ExpiryDate IS NOT NULL AND c.ExpiryDate < CAST(SYSDATETIME() AS DATE))
                          THEN 402 ELSE 200 END,
        Id         = c.CompanyID,
        Message    = CASE WHEN c.IsExpired = 1 OR (c.ExpiryDate IS NOT NULL AND c.ExpiryDate < CAST(SYSDATETIME() AS DATE))
                          THEN N'Subscription has expired. Please contact your administrator.'
                          ELSE N'Active' END,
        Expires    = c.ExpiryDate,
        DaysLeft   = DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), c.ExpiryDate),
        UserCount  = c.UserCount,
        MaxUsers   = c.MaxUsers
    FROM org.Company AS c
    WHERE c.CompanyID = @CompanyID;
END;
GO

/*  OTP  */
CREATE OR ALTER PROCEDURE dbo.usp_User_GenerateOtp
    @MobileNo  NVARCHAR(15),
    @OtpHash   NVARCHAR(200),
    @Purpose   NVARCHAR(30),
    @ValidMins INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- throttle: at most 5 OTPs per mobile per 15 minutes
    IF (SELECT COUNT(*) FROM sec.Otp
        WHERE MobileNo = @MobileNo AND InsertDate > DATEADD(MINUTE, -15, SYSDATETIME())) >= 5
        THROW 51020, 'Too many OTP requests. Please try again after 15 minutes.', 1;

    -- invalidate any live OTP for the same purpose
    UPDATE sec.Otp SET ConsumedAt = SYSDATETIME()
    WHERE MobileNo = @MobileNo AND Purpose = @Purpose AND ConsumedAt IS NULL;

    INSERT INTO sec.Otp (MobileNo, OtpHash, Purpose, ExpiresAt)
    VALUES (@MobileNo, @OtpHash, @Purpose, DATEADD(MINUTE, @ValidMins, SYSDATETIME()));

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = CAST(SCOPE_IDENTITY() AS INT),
           Message = N'OTP generated';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_User_VerifyOtp
    @MobileNo NVARCHAR(15),
    @OtpHash  NVARCHAR(200),
    @Purpose  NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @OtpID BIGINT, @Ok BIT = 0;

    SELECT TOP (1) @OtpID = OtpID
    FROM sec.Otp
    WHERE MobileNo = @MobileNo AND Purpose = @Purpose AND ConsumedAt IS NULL
    ORDER BY OtpID DESC;

    IF @OtpID IS NULL
    BEGIN
        SELECT Success = CAST(0 AS BIT), Status = 404, Id = 0, Message = N'No OTP was requested';
        RETURN;
    END

    UPDATE sec.Otp SET AttemptCount = AttemptCount + 1 WHERE OtpID = @OtpID;

    IF EXISTS (SELECT 1 FROM sec.Otp
               WHERE OtpID = @OtpID AND OtpHash = @OtpHash
                 AND ExpiresAt >= SYSDATETIME() AND AttemptCount <= 5)
    BEGIN
        UPDATE sec.Otp SET ConsumedAt = SYSDATETIME() WHERE OtpID = @OtpID;
        SET @Ok = 1;
    END

    SELECT Success = CAST(@Ok AS BIT),
           Status  = CASE WHEN @Ok = 1 THEN 200 ELSE 422 END,
           Id      = ISNULL((SELECT TOP (1) UserID FROM sec.Users WHERE MobileNo = @MobileNo AND IsCancel = 0), 0),
           Message = CASE WHEN @Ok = 1 THEN N'Verified' ELSE N'Invalid or expired OTP' END;
END;
GO

/*  api/Users/changepass  - the API supplies the already-hashed new password  */
CREATE OR ALTER PROCEDURE dbo.usp_User_ChangePassword
    @UserID       INT,
    @PasswordHash NVARCHAR(500),
    @PasswordSalt NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE sec.Users
        SET PasswordHash       = @PasswordHash,
            PasswordSalt       = @PasswordSalt,
            LegacyPasswordHash = NULL,
            MustChangePassword = 0,
            FailedLoginCount   = 0,
            IsLocked           = 0,
            LockedUntil        = NULL,
            UpdateDate         = SYSDATETIME(),
            UpdateUserID       = @UserID
        WHERE UserID = @UserID AND IsCancel = 0;

        IF @@ROWCOUNT = 0 THROW 51021, 'User not found.', 1;

        -- every refresh token of this user is revoked on a password change
        UPDATE sec.RefreshToken
        SET RevokedAt = SYSDATETIME()
        WHERE UserID = @UserID AND RevokedAt IS NULL;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @UserID, Message = N'Password changed';
END;
GO

/*  api/Users/updatetoken  */
CREATE OR ALTER PROCEDURE dbo.usp_User_UpdateFcmToken
    @UserID   INT,
    @FcmToken NVARCHAR(500),
    @Platform NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE sec.Users
    SET FcmToken = @FcmToken, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE UserID = @UserID AND IsCancel = 0;

    SELECT Success = CAST(CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END AS BIT),
           Status  = CASE WHEN @@ROWCOUNT > 0 THEN 200 ELSE 404 END,
           Id      = @UserID,
           Message = N'Token updated';
END;
GO

/*==============================================================================
  RIGHTS AND PROFILE
==============================================================================*/

/*  api/Users/getrights  */
CREATE OR ALTER PROCEDURE dbo.usp_User_GetRights
    @CompanyID INT,
    @UserID    INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PermissionID,
        p.Module,
        p.Code,
        p.Name,
        p.Entity,
        p.[Action],
        rp.CanView,
        rp.CanCreate,
        rp.CanEdit,
        rp.CanDelete,
        rp.CanApprove,
        rp.CanExport
    FROM sec.Users          AS u
    INNER JOIN sec.RolePermission AS rp ON rp.RoleID = u.RoleID
    INNER JOIN sec.Permission     AS p  ON p.PermissionID = rp.PermissionID
    WHERE u.UserID = @UserID
      AND (u.CompanyID = @CompanyID OR u.CompanyID IS NULL)
      AND u.IsCancel = 0
    ORDER BY p.Module, p.SortOrder, p.Code;
END;
GO

/*  api/Users/getprofile - Profilemodel$Datum  */
CREATE OR ALTER PROCEDURE dbo.usp_User_GetProfile
    @CompanyID INT,
    @UserID    INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        Rownum              = 1,
        Name                = ISNULL(e.EmpFullName, u.UserName),
        EmpCode             = e.EmpCode,
        Mobile1             = ISNULL(e.Mobile1, u.MobileNo),
        Photo               = ISNULL(u.PhotoUrl, e.Photo),
        DesignationName     = d.DesignationName,
        UnitName            = un.UnitName,
        Shiftname           = s.ShiftName,
        BeltNo              = e.BeltNo,
        BloodGroup          = e.Bloodgroup,
        Maritalstatus       = CASE WHEN e.Married = 1 THEN N'Married' ELSE N'Single' END,
        Dated               = e.Doj,
        Address             = ra.Address1,
        Paddress1           = pa.Address1,
        BankName            = bk.BankName,
        BankAcNo            = bk.BankAcNo,
        IFSCcode            = bk.IFSCcode,
        DrivingLicenceNo    = st.DlNo,
        IsPoliceVerification = ISNULL(v.IsPoliceVerification, CAST(0 AS BIT)),
        IsReliever          = e.IsReliever,
        TrainingDate        = (SELECT MAX(t.Dated) FROM hr.Training AS t
                               INNER JOIN hr.TrainingAttendee AS ta ON ta.TrainingID = t.TrainingID
                               WHERE ta.EmpID = e.EmpID AND ta.IsPresent = 1),
        ReportingSuperwiser = sup.EmpFullName
    FROM sec.Users AS u
    LEFT JOIN hr.Employee   AS e   ON e.EmpID = u.EmpID
    LEFT JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT JOIN crm.Unit      AS un  ON un.UnitID = e.UnitID
    LEFT JOIN hr.Employee   AS sup ON sup.EmpID = un.SupervisorEmpID
    LEFT JOIN mst.Shift     AS s   ON s.ShiftID = e.ShiftID
    LEFT JOIN hr.EmployeeAddress AS pa ON pa.EmpID = e.EmpID AND pa.AddressType = 'P'
    LEFT JOIN hr.EmployeeAddress AS ra ON ra.EmpID = e.EmpID AND ra.AddressType = 'R'
    LEFT JOIN hr.EmployeeBank    AS bk ON bk.EmpID = e.EmpID AND bk.IsJoint = 0 AND bk.IsCancel = 0
    LEFT JOIN hr.EmployeeStatutory    AS st ON st.EmpID = e.EmpID
    LEFT JOIN hr.EmployeeVerification AS v  ON v.EmpID  = e.EmpID
    WHERE u.UserID = @UserID AND (u.CompanyID = @CompanyID OR u.CompanyID IS NULL);
END;
GO

/*  api/Users/getuserlists  */
CREATE OR ALTER PROCEDURE dbo.usp_User_GetList
    @CompanyID INT,
    @UserID    INT,
    @BranchID  INT           = NULL,
    @RoleID    INT           = NULL,
    @Search    NVARCHAR(200) = NULL,
    @PageNo    INT           = 1,
    @PageSize  INT           = 50,
    @SortBy    NVARCHAR(50)  = N'UserName',
    @SortDir   NVARCHAR(4)   = N'asc'
AS
BEGIN
    SET NOCOUNT ON;

    IF @PageSize IS NULL OR @PageSize < 1   SET @PageSize = 50;
    IF @PageSize > 200                      SET @PageSize = 200;
    IF @PageNo   IS NULL OR @PageNo   < 1   SET @PageNo   = 1;

    ;WITH src AS (
        SELECT
            u.UserID, u.UserName, u.MobileNo, u.EmailID, u.PhotoUrl,
            u.BranchID, b.BranchName, u.RoleID, r.RoleName, r.RoleCode,
            u.LoginType, u.IsActive, u.IsLocked, u.LastLoginAt, u.ExpiresOn,
            u.EmpID, EmpFullName = e.EmpFullName, e.EmpCode
        FROM sec.Users AS u
        INNER JOIN sec.Role  AS r ON r.RoleID  = u.RoleID
        LEFT  JOIN org.Branch AS b ON b.BranchID = u.BranchID
        LEFT  JOIN hr.Employee AS e ON e.EmpID  = u.EmpID
        WHERE u.CompanyID = @CompanyID
          AND u.IsCancel  = 0
          AND (@BranchID IS NULL OR u.BranchID = @BranchID)
          AND (@RoleID   IS NULL OR u.RoleID   = @RoleID)
          AND (@Search   IS NULL OR u.UserName LIKE N'%' + @Search + N'%'
                                 OR u.MobileNo LIKE N'%' + @Search + N'%'
                                 OR e.EmpFullName LIKE N'%' + @Search + N'%')
          AND (u.BranchID IS NULL
               OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleBranches(@CompanyID, @UserID) AS ab
                          WHERE ab.BranchID = u.BranchID))
    )
    SELECT UserID, UserName, MobileNo, EmailID, PhotoUrl, BranchID, BranchName,
           RoleID, RoleName, RoleCode, LoginType, IsActive, IsLocked,
           LastLoginAt, ExpiresOn, EmpID, EmpFullName, EmpCode
    FROM src
    ORDER BY
        CASE WHEN @SortDir = N'asc'  AND @SortBy = N'UserName' THEN UserName END ASC,
        CASE WHEN @SortDir = N'desc' AND @SortBy = N'UserName' THEN UserName END DESC,
        CASE WHEN @SortDir = N'asc'  AND @SortBy = N'LastLoginAt' THEN LastLoginAt END ASC,
        CASE WHEN @SortDir = N'desc' AND @SortBy = N'LastLoginAt' THEN LastLoginAt END DESC,
        UserID
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM sec.Users AS u
    LEFT JOIN hr.Employee AS e ON e.EmpID = u.EmpID
    WHERE u.CompanyID = @CompanyID
      AND u.IsCancel  = 0
      AND (@BranchID IS NULL OR u.BranchID = @BranchID)
      AND (@RoleID   IS NULL OR u.RoleID   = @RoleID)
      AND (@Search   IS NULL OR u.UserName LIKE N'%' + @Search + N'%'
                             OR u.MobileNo LIKE N'%' + @Search + N'%'
                             OR e.EmpFullName LIKE N'%' + @Search + N'%');
END;
GO

/*==============================================================================
  LOGIN AND COMPANY LOGS
==============================================================================*/

CREATE OR ALTER PROCEDURE dbo.usp_User_GetLoginLog
    @CompanyID  INT,
    @UserID     INT,
    @FromDate   DATE = NULL,
    @ToDate     DATE = NULL,
    @TargetUserID INT = NULL,
    @PageNo     INT  = 1,
    @PageSize   INT  = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        l.LoginLogID, l.UserID, UserName = u.UserName,
        Name = ISNULL(e.EmpFullName, u.UserName),
        l.LoginAt, l.LogoutAt, l.IpAddress, l.DeviceID,
        l.AppVersion, l.Platform, l.IsSuccess, l.FailReason
    FROM sec.LoginLog AS l
    LEFT JOIN sec.Users  AS u ON u.UserID = l.UserID
    LEFT JOIN hr.Employee AS e ON e.EmpID = u.EmpID
    WHERE l.CompanyID = @CompanyID
      AND CAST(l.LoginAt AS DATE) BETWEEN @FromDate AND @ToDate
      AND (@TargetUserID IS NULL OR l.UserID = @TargetUserID)
    ORDER BY l.LoginAt DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM sec.LoginLog AS l
    WHERE l.CompanyID = @CompanyID
      AND CAST(l.LoginAt AS DATE) BETWEEN @FromDate AND @ToDate
      AND (@TargetUserID IS NULL OR l.UserID = @TargetUserID);
END;
GO

/*  SUPER_ADMIN: tenant list with usage - Companymodel$Datum  */
CREATE OR ALTER PROCEDURE dbo.usp_Company_GetLog
    @Search   NVARCHAR(200) = NULL,
    @PageNo   INT = 1,
    @PageSize INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        Sno            = ROW_NUMBER() OVER (ORDER BY c.CompanyName),
        Id             = c.CompanyID,
        c.CompanyID,
        c.CompanyName,
        c.CompanyAddress,
        Mobile         = c.Mobile,
        Name           = c.CompanyName,
        c.UserCount,
        c.MaxUsers,
        c.LoginCount,
        c.IsExpired,
        c.ExpiryDate,
        c.IsActive,
        ClientId       = NULL,
        LoginsToday    = (SELECT COUNT(*) FROM sec.LoginLog AS l
                          WHERE l.CompanyID = c.CompanyID AND l.IsSuccess = 1
                            AND CAST(l.LoginAt AS DATE) = CAST(SYSDATETIME() AS DATE))
    FROM org.Company AS c
    WHERE c.IsCancel = 0
      AND (@Search IS NULL OR c.CompanyName LIKE N'%' + @Search + N'%'
                           OR c.CompanyCode LIKE N'%' + @Search + N'%')
    ORDER BY c.CompanyName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM org.Company AS c
    WHERE c.IsCancel = 0
      AND (@Search IS NULL OR c.CompanyName LIKE N'%' + @Search + N'%'
                           OR c.CompanyCode LIKE N'%' + @Search + N'%');
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Company_GetLogDetail
    @CompanyID INT,
    @FromDate  DATE = NULL,
    @ToDate    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @FromDate IS NULL SET @FromDate = DATEADD(DAY, -30, CAST(SYSDATETIME() AS DATE));
    IF @ToDate   IS NULL SET @ToDate   = CAST(SYSDATETIME() AS DATE);

    SELECT
        LogDate     = CAST(l.LoginAt AS DATE),
        TotalLogins = COUNT(*),
        Successful  = SUM(CASE WHEN l.IsSuccess = 1 THEN 1 ELSE 0 END),
        Failed      = SUM(CASE WHEN l.IsSuccess = 0 THEN 1 ELSE 0 END),
        UniqueUsers = COUNT(DISTINCT l.UserID)
    FROM sec.LoginLog AS l
    WHERE l.CompanyID = @CompanyID
      AND CAST(l.LoginAt AS DATE) BETWEEN @FromDate AND @ToDate
    GROUP BY CAST(l.LoginAt AS DATE)
    ORDER BY LogDate DESC;
END;
GO

/*==============================================================================
  MASTER DATA
  All accept @CompanyID and return global rows (CompanyID IS NULL) plus the
  tenant's own overrides.
==============================================================================*/

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetStates
    @CountryID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT StateID, StateName, StateCode, GstStateCode, CountryID,
           CmpAddress, GSTIN, IsApproved, IsCancel, IsReject
    FROM mst.State
    WHERE IsCancel = 0 AND (@CountryID IS NULL OR CountryID = @CountryID)
    ORDER BY StateName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetCity
    @StateID    INT = NULL,
    @DistrictID INT = NULL,
    @Search     NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID = CityID, Name = CityName, PhotoUrl, StateID, DistrictID
    FROM mst.City
    WHERE IsCancel = 0
      AND (@StateID    IS NULL OR StateID    = @StateID)
      AND (@DistrictID IS NULL OR DistrictID = @DistrictID)
      AND (@Search     IS NULL OR CityName LIKE N'%' + @Search + N'%')
    ORDER BY CityName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetDistrict
    @StateID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ID = DistrictID, Name = DistrictName, StateID
    FROM mst.District WHERE IsCancel = 0 AND StateID = @StateID ORDER BY DistrictName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetDesignation
    @CompanyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DesignationID, DesignationName, GradeID, CategoryID, IsGunmanRole
    FROM mst.Designation
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID)
    ORDER BY SortOrder, DesignationName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetQualification
    @CompanyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT QualificationID, QualificationName, InsertDate, IsApproved, IsCancel, IsReject
    FROM mst.Qualification
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID)
    ORDER BY SortOrder, QualificationName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Master_GetComplaintType
    @CompanyID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ComplaintTypeID, ComplaintTypeName, DefaultSlaHours
    FROM mst.ComplaintType
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID)
    ORDER BY ComplaintTypeName;
END;
GO

/*  api/Users/gettype - generic lookup dispatcher used by the legacy app.
    @TypeName decides which master is returned; the shape is always (ID, Name).  */
CREATE OR ALTER PROCEDURE dbo.usp_Master_GetType
    @CompanyID INT,
    @TypeName  NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @TypeName = N'incidenttype'
        SELECT ID = IncidentTypeID, Name = IncidentTypeName FROM mst.IncidentType
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY IncidentTypeName;
    ELSE IF @TypeName = N'servicetype'
        SELECT ID = ServiceTypeID, Name = ServiceName FROM mst.ServiceType
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY ServiceName;
    ELSE IF @TypeName = N'shift'
        SELECT ID = ShiftID, Name = ShiftName FROM mst.Shift
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY StartTime;
    ELSE IF @TypeName = N'grade'
        SELECT ID = GradeID, Name = GradeName FROM mst.Grade
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;
    ELSE IF @TypeName = N'category'
        SELECT ID = CategoryID, Name = CategoryName FROM mst.Category
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;
    ELSE IF @TypeName = N'uniformitem'
        SELECT ID = ItemID, Name = ItemName FROM mst.UniformItem
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY ItemName;
    ELSE IF @TypeName = N'priority'
        SELECT ID = PriorityID, Name = Name FROM mst.Priority WHERE IsCancel = 0 ORDER BY SortOrder;
    ELSE IF @TypeName = N'taskstatus'
        SELECT ID = TaskStatusID, Name = Name FROM mst.TaskStatus WHERE IsCancel = 0 ORDER BY SortOrder;
    ELSE IF @TypeName = N'repetition'
        SELECT ID = RepetitionID, Name = Name FROM mst.TaskRepetition WHERE IsCancel = 0 ORDER BY SortOrder;
    ELSE IF @TypeName = N'documenttype'
        SELECT ID = DocTypeID, Name = DocTypeName FROM mst.DocumentType
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;
    ELSE IF @TypeName = N'bank'
        SELECT ID = BankID, Name = BankName FROM mst.Bank WHERE IsCancel = 0 ORDER BY BankName;
    ELSE IF @TypeName = N'branch'
        SELECT ID = BranchID, Name = BranchName FROM org.Branch
        WHERE IsCancel = 0 AND CompanyID = @CompanyID ORDER BY BranchName;
    ELSE IF @TypeName = N'region'
        SELECT ID = RegionID, Name = RegionName FROM mst.Region
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY RegionName;
    ELSE IF @TypeName = N'area'
        SELECT ID = AreaID, Name = AreaName FROM mst.Area
        WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY AreaName;
    ELSE
        THROW 51030, 'Unknown master type requested.', 1;
END;
GO

/*  api/Users/getsubdropdown - dependent lookups (parent id -> children)  */
CREATE OR ALTER PROCEDURE dbo.usp_Master_GetSubDropdown
    @CompanyID INT,
    @TypeName  NVARCHAR(50),
    @ParentID  INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @TypeName = N'district'
        SELECT ID = DistrictID, Name = DistrictName FROM mst.District
        WHERE IsCancel = 0 AND StateID = @ParentID ORDER BY DistrictName;
    ELSE IF @TypeName = N'city'
        SELECT ID = CityID, Name = CityName FROM mst.City
        WHERE IsCancel = 0 AND StateID = @ParentID ORDER BY CityName;
    ELSE IF @TypeName = N'area'
        SELECT ID = AreaID, Name = AreaName FROM mst.Area
        WHERE IsCancel = 0 AND RegionID = @ParentID ORDER BY AreaName;
    ELSE IF @TypeName = N'ifsc'
        SELECT ID = IfscCodeID, Name = IFSCcode + N' - ' + ISNULL(BranchName, N'')
        FROM mst.IfscCode WHERE IsCancel = 0 AND BankID = @ParentID ORDER BY BranchName;
    ELSE IF @TypeName = N'unit'
        SELECT ID = UnitID, Name = UnitName FROM crm.Unit
        WHERE IsCancel = 0 AND CompanyID = @CompanyID AND ClientID = @ParentID ORDER BY UnitName;
    ELSE IF @TypeName = N'post'
        SELECT ID = PostID, Name = PostName FROM crm.UnitPost
        WHERE IsCancel = 0 AND CompanyID = @CompanyID AND UnitID = @ParentID ORDER BY PostName;
    ELSE
        THROW 51031, 'Unknown sub-dropdown type requested.', 1;
END;
GO

/*  api/Users/getlist - one call that returns every lookup the app needs at
    cold start. Multiple result sets, consumed by GET /api/v2/masters/bootstrap. */
CREATE OR ALTER PROCEDURE dbo.usp_Master_GetBootstrap
    @CompanyID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT StateID, StateName, StateCode, GstStateCode, CountryID FROM mst.State WHERE IsCancel = 0 ORDER BY StateName;

    SELECT DesignationID, DesignationName, GradeID, CategoryID, IsGunmanRole
    FROM mst.Designation WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;

    SELECT ShiftID, ShiftName, StartTime, EndTime, IsNight, GraceInMinutes, GraceOutMinutes, HalfDayHours, FullDayHours
    FROM mst.Shift WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY StartTime;

    SELECT QualificationID, QualificationName FROM mst.Qualification
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;

    SELECT ComplaintTypeID, ComplaintTypeName, DefaultSlaHours FROM mst.ComplaintType
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY ComplaintTypeName;

    SELECT IncidentTypeID, IncidentTypeName, Severity FROM mst.IncidentType
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY IncidentTypeName;

    SELECT ItemID, ItemName, Rate, Uom, IsReturnable FROM mst.UniformItem
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY ItemName;

    SELECT TaskStatusID, Name, ColorHex, IsTerminal FROM mst.TaskStatus WHERE IsCancel = 0 ORDER BY SortOrder;

    SELECT PriorityID, Name, ColorHex FROM mst.Priority WHERE IsCancel = 0 ORDER BY SortOrder;

    SELECT RepetitionID, Name, IntervalDays FROM mst.TaskRepetition WHERE IsCancel = 0 ORDER BY SortOrder;

    SELECT DocTypeID, DocTypeName, OwnerType, IsMandatory, HasExpiry FROM mst.DocumentType
    WHERE IsCancel = 0 AND (CompanyID IS NULL OR CompanyID = @CompanyID) ORDER BY SortOrder;

    SELECT BranchID, BranchName, BranchCode, IsHeadOffice FROM org.Branch
    WHERE IsCancel = 0 AND CompanyID = @CompanyID ORDER BY BranchName;

    SELECT SettingKey, SettingValue, DataType FROM org.CompanySetting WHERE CompanyID = @CompanyID;
END;
GO

PRINT '510_procedures_users.sql  ->  OK  (26 procedures)';
GO
