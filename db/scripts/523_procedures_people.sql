/*==============================================================================
  523_procedures_people.sql
  Recruitment, employee 360, clients and units.
  Spec: docs/prd/01-database.md §7.2 ; docs/prd/02-api.md §4.2
  Split rationale: DECISIONS.md #21

  The employee record is spread across hr.Employee plus ten satellite tables.
  Each satellite has its own save procedure so the six-step biodata wizard can
  autosave one step at a time without holding a 196-column payload.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  DUPLICATE DETECTION - runs on Aadhaar / mobile / old employee code
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_People_CheckDuplicate
    @CompanyID   INT,
    @AdharCardNo NVARCHAR(12) = NULL,
    @Mobile      NVARCHAR(15) = NULL,
    @OldEmpCode  NVARCHAR(30) = NULL,
    @ExcludeEmpID INT         = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Source      = N'Employee',
        EmpID       = e.EmpID,
        RecruitID   = CAST(NULL AS INT),
        Name        = e.EmpFullName,
        EmpCode     = e.EmpCode,
        Mobile      = e.Mobile1,
        AdharCardNo = st.AdharCardNo,
        EmpStatus   = e.EmpStatus,
        IsBlackListed = e.IsBlackListed,
        BlackListedReason = e.BlackListedReason,
        MatchedOn   = CASE
                        WHEN @AdharCardNo IS NOT NULL AND st.AdharCardNo = @AdharCardNo THEN N'Aadhaar'
                        WHEN @Mobile      IS NOT NULL AND e.Mobile1      = @Mobile      THEN N'Mobile'
                        ELSE N'OldEmpCode'
                      END
    FROM hr.Employee AS e
    LEFT JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
    WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
      AND (@ExcludeEmpID IS NULL OR e.EmpID <> @ExcludeEmpID)
      AND ( (@AdharCardNo IS NOT NULL AND st.AdharCardNo = @AdharCardNo)
         OR (@Mobile      IS NOT NULL AND e.Mobile1      = @Mobile)
         OR (@OldEmpCode  IS NOT NULL AND e.OldEmpCode   = @OldEmpCode) )

    UNION ALL

    SELECT
        N'Recruit', NULL, r.RecruitID, r.Name, NULL, r.Mobile, r.AdharCardNo,
        r.Status, CAST(0 AS BIT), NULL,
        CASE WHEN @AdharCardNo IS NOT NULL AND r.AdharCardNo = @AdharCardNo THEN N'Aadhaar'
             WHEN @Mobile      IS NOT NULL AND r.Mobile      = @Mobile      THEN N'Mobile'
             ELSE N'OldEmpCode' END
    FROM hr.Recruit AS r
    WHERE r.CompanyID = @CompanyID AND r.IsCancel = 0 AND r.Status <> N'Converted'
      AND ( (@AdharCardNo IS NOT NULL AND r.AdharCardNo = @AdharCardNo)
         OR (@Mobile      IS NOT NULL AND r.Mobile      = @Mobile)
         OR (@OldEmpCode  IS NOT NULL AND r.OldEmpCode  = @OldEmpCode) );
END;
GO

/*==============================================================================
  RECRUITMENT
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Recruit_Save
    @CompanyID     INT,
    @UserID        INT,
    @Name          NVARCHAR(200),
    @Mobile        NVARCHAR(15)  = NULL,
    @AdharCardNo   NVARCHAR(12)  = NULL,
    @OldEmpCode    NVARCHAR(30)  = NULL,
    @BranchID      INT           = NULL,
    @DesignationID INT           = NULL,
    @SourceBy      NVARCHAR(100) = NULL,
    @Dated         DATE          = NULL,
    @Remark        NVARCHAR(500) = NULL,
    @RecruitID     INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Dated IS NULL SET @Dated = CAST(SYSDATETIME() AS DATE);

    /* a blacklisted person must never re-enter the pipeline silently */
    IF @AdharCardNo IS NOT NULL AND EXISTS (
        SELECT 1 FROM hr.Employee AS e
        INNER JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
        WHERE e.CompanyID = @CompanyID AND e.IsBlackListed = 1 AND st.AdharCardNo = @AdharCardNo)
        THROW 51400, 'This person is blacklisted and cannot be recruited.', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF @RecruitID IS NULL
        BEGIN
            INSERT INTO hr.Recruit (CompanyID, BranchID, Name, Mobile, AdharCardNo, OldEmpCode,
                                    Dated, SourceBy, DesignationID, Status, Remark,
                                    InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @Name, @Mobile, @AdharCardNo, @OldEmpCode,
                    @Dated, @SourceBy, @DesignationID, N'New', @Remark,
                    SYSDATETIME(), @UserID);
            SET @RecruitID = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE hr.Recruit
            SET Name = @Name, Mobile = @Mobile, AdharCardNo = @AdharCardNo,
                OldEmpCode = @OldEmpCode, BranchID = @BranchID,
                DesignationID = @DesignationID, SourceBy = @SourceBy, Remark = @Remark,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE RecruitID = @RecruitID AND CompanyID = @CompanyID AND IsCancel = 0;

            IF @@ROWCOUNT = 0 THROW 51401, 'Recruit not found.', 1;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @RecruitID, Message = N'Recruit saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Recruit_SetStatus
    @CompanyID INT,
    @UserID    INT,
    @RecruitID INT,
    @Status    NVARCHAR(20),
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (N'New', N'Screened', N'Verified', N'Approved', N'Waitlist', N'Rejected')
        THROW 51402, 'Invalid recruit status.', 1;

    UPDATE hr.Recruit
    SET Status     = @Status,
        IsApproved = CASE WHEN @Status = N'Approved' THEN 1 ELSE 0 END,
        IsReject   = CASE WHEN @Status = N'Rejected' THEN 1 ELSE 0 END,
        Remark     = ISNULL(@Remark, Remark),
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE RecruitID = @RecruitID AND CompanyID = @CompanyID AND IsCancel = 0
      AND Status <> N'Converted';

    IF @@ROWCOUNT = 0 THROW 51403, 'Recruit not found, or already converted.', 1;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @RecruitID,
           Message = CONCAT(N'Moved to ', @Status);
END;
GO

/*  Approved recruit becomes an employee. Employee code is allocated under an
    applock by usp_Code_NextEmpCode, so two HR users converting at the same
    moment cannot produce the same code.  */
CREATE OR ALTER PROCEDURE dbo.usp_Recruit_Convert
    @CompanyID INT,
    @UserID    INT,
    @RecruitID INT,
    @Doj       DATE = NULL,
    @EmpID     INT  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Name NVARCHAR(200), @Mobile NVARCHAR(15), @Aadhaar NVARCHAR(12),
            @BranchID INT, @DesignationID INT, @OldEmpCode NVARCHAR(30),
            @EmpCode NVARCHAR(30), @First NVARCHAR(100), @Last NVARCHAR(100);

    IF @Doj IS NULL SET @Doj = CAST(SYSDATETIME() AS DATE);

    SELECT @Name = r.Name, @Mobile = r.Mobile, @Aadhaar = r.AdharCardNo,
           @BranchID = r.BranchID, @DesignationID = r.DesignationID, @OldEmpCode = r.OldEmpCode
    FROM hr.Recruit AS r
    WHERE r.RecruitID = @RecruitID AND r.CompanyID = @CompanyID
      AND r.Status = N'Approved' AND r.IsCancel = 0;

    IF @Name IS NULL
        THROW 51404, 'Recruit not found or not approved.', 1;

    SET @First = LTRIM(RTRIM(LEFT(@Name, CASE WHEN CHARINDEX(N' ', @Name) > 0
                                              THEN CHARINDEX(N' ', @Name) ELSE LEN(@Name) END)));
    SET @Last  = LTRIM(RTRIM(CASE WHEN CHARINDEX(N' ', @Name) > 0
                                  THEN SUBSTRING(@Name, CHARINDEX(N' ', @Name) + 1, 200) ELSE N'' END));

    EXEC dbo.usp_Code_NextEmpCode @CompanyID = @CompanyID, @BranchID = @BranchID, @EmpCode = @EmpCode OUTPUT;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO hr.Employee (CompanyID, BranchID, EmpCode, OldEmpCode, FirstName, LastName,
                                 Mobile1, DesignationID, Doj, EmpStatus, IsApproved,
                                 InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @EmpCode, @OldEmpCode, @First,
                NULLIF(@Last, N''), @Mobile, @DesignationID, @Doj, N'Active', 1,
                SYSDATETIME(), @UserID);

        SET @EmpID = SCOPE_IDENTITY();

        IF @Aadhaar IS NOT NULL
            INSERT INTO hr.EmployeeStatutory (EmpID, CompanyID, AdharCardNo, InsertDate, InsertUserID)
            VALUES (@EmpID, @CompanyID, @Aadhaar, SYSDATETIME(), @UserID);

        INSERT INTO hr.EmployeeStatusHistory (CompanyID, EmpID, EventType, EventDate,
                                              Remark, IsApproved, InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID, N'Join', @Doj, N'Converted from recruitment', 1, SYSDATETIME(), @UserID);

        UPDATE hr.Recruit
        SET Status = N'Converted', EmpID = @EmpID,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE RecruitID = @RecruitID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID,
           Message = CONCAT(N'Employee created with code ', @EmpCode), EmpCode = @EmpCode;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Recruit_GetList
    @CompanyID INT,
    @UserID    INT,
    @Status    NVARCHAR(20)  = NULL,
    @BranchID  INT           = NULL,
    @Search    NVARCHAR(200) = NULL,
    @FromDate  DATE          = NULL,
    @ToDate    DATE          = NULL,
    @PageNo    INT           = 1,
    @PageSize  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        r.RecruitID, r.Name, r.Mobile, r.AdharCardNo, r.OldEmpCode, r.Dated,
        r.SourceBy, r.Status, r.Remark, r.EmpID,
        r.DesignationID, d.DesignationName, r.BranchID, b.BranchName,
        AgeInPipelineDays = DATEDIFF(DAY, r.Dated, CAST(SYSDATETIME() AS DATE)),
        HasDuplicate = CASE WHEN EXISTS (
                            SELECT 1 FROM hr.Employee AS e
                            LEFT JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
                            WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
                              AND ((r.AdharCardNo IS NOT NULL AND st.AdharCardNo = r.AdharCardNo)
                                OR (r.Mobile IS NOT NULL AND e.Mobile1 = r.Mobile)))
                            THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END
    FROM hr.Recruit AS r
    LEFT JOIN mst.Designation AS d ON d.DesignationID = r.DesignationID
    LEFT JOIN org.Branch      AS b ON b.BranchID = r.BranchID
    WHERE r.CompanyID = @CompanyID AND r.IsCancel = 0
      AND (@Status   IS NULL OR r.Status = @Status)
      AND (@BranchID IS NULL OR r.BranchID = @BranchID)
      AND (@FromDate IS NULL OR r.Dated >= @FromDate)
      AND (@ToDate   IS NULL OR r.Dated <= @ToDate)
      AND (@Search   IS NULL OR r.Name LIKE N'%' + @Search + N'%'
                             OR r.Mobile LIKE N'%' + @Search + N'%')
      AND (r.BranchID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleBranches(@CompanyID, @UserID) AS ab
                      WHERE ab.BranchID = r.BranchID))
    ORDER BY r.Dated DESC, r.Name
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM hr.Recruit AS r
    WHERE r.CompanyID = @CompanyID AND r.IsCancel = 0
      AND (@Status   IS NULL OR r.Status = @Status)
      AND (@BranchID IS NULL OR r.BranchID = @BranchID)
      AND (@FromDate IS NULL OR r.Dated >= @FromDate)
      AND (@ToDate   IS NULL OR r.Dated <= @ToDate)
      AND (@Search   IS NULL OR r.Name LIKE N'%' + @Search + N'%'
                             OR r.Mobile LIKE N'%' + @Search + N'%');

    /* pipeline counts for the kanban header */
    SELECT Status, Cnt = COUNT(*)
    FROM hr.Recruit
    WHERE CompanyID = @CompanyID AND IsCancel = 0
    GROUP BY Status;
END;
GO

/*==============================================================================
  EMPLOYEE - LIST AND 360
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Employee_GetList
    @CompanyID     INT,
    @UserID        INT,
    @BranchID      INT           = NULL,
    @UnitID        INT           = NULL,
    @ClientID      INT           = NULL,
    @DesignationID INT           = NULL,
    @EmpStatus     NVARCHAR(20)  = NULL,
    @IsGunman      BIT           = NULL,
    @IsReliever    BIT           = NULL,
    @PvPending     BIT           = NULL,
    @Search        NVARCHAR(200) = NULL,
    @PageNo        INT           = 1,
    @PageSize      INT           = 50,
    @SortBy        NVARCHAR(50)  = N'EmpFullName',
    @SortDir       NVARCHAR(4)   = N'asc'
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        v.EmpID, v.EmpCode, v.EmpFullName, v.Photo, v.Mobile1, v.Gender, v.Age,
        v.DesignationName, v.UnitID, v.UnitName, v.ClientName, v.BranchName,
        v.EmpStatus, v.Doj, v.BeltNo, v.IsGunman, v.IsReliever, v.IsBlackListed,
        v.PoliceVerified, v.PVValidUpTo, v.IdCardExpireDate,
        v.MedicalCertificateValidUpto, v.GunLicenceExpiry
    FROM dbo.vwEmployeeFull AS v
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND (v.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au WHERE au.UnitID = v.UnitID))
      AND (@BranchID      IS NULL OR v.BranchID      = @BranchID)
      AND (@UnitID        IS NULL OR v.UnitID        = @UnitID)
      AND (@ClientID      IS NULL OR v.Clientid      = @ClientID)
      AND (@DesignationID IS NULL OR v.DesignationID = @DesignationID)
      AND (@EmpStatus     IS NULL OR v.EmpStatus     = @EmpStatus)
      AND (@IsGunman      IS NULL OR v.IsGunman      = @IsGunman)
      AND (@IsReliever    IS NULL OR v.IsReliever    = @IsReliever)
      AND (@PvPending     IS NULL OR v.PoliceVerified = CASE WHEN @PvPending = 1 THEN 0 ELSE 1 END)
      AND (@Search        IS NULL OR v.EmpFullName LIKE N'%' + @Search + N'%'
                                  OR v.EmpCode     LIKE N'%' + @Search + N'%'
                                  OR v.Mobile1     LIKE N'%' + @Search + N'%'
                                  OR v.BeltNo      LIKE N'%' + @Search + N'%')
    ORDER BY
        CASE WHEN @SortDir = N'asc'  AND @SortBy = N'EmpFullName' THEN v.EmpFullName END ASC,
        CASE WHEN @SortDir = N'desc' AND @SortBy = N'EmpFullName' THEN v.EmpFullName END DESC,
        CASE WHEN @SortDir = N'asc'  AND @SortBy = N'EmpCode'     THEN v.EmpCode END ASC,
        CASE WHEN @SortDir = N'desc' AND @SortBy = N'EmpCode'     THEN v.EmpCode END DESC,
        CASE WHEN @SortDir = N'asc'  AND @SortBy = N'Doj'         THEN v.Doj END ASC,
        CASE WHEN @SortDir = N'desc' AND @SortBy = N'Doj'         THEN v.Doj END DESC,
        v.EmpID
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM dbo.vwEmployeeFull AS v
    WHERE v.CompanyID = @CompanyID AND v.IsCancel = 0
      AND (v.UnitID IS NULL
           OR EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au WHERE au.UnitID = v.UnitID))
      AND (@BranchID      IS NULL OR v.BranchID      = @BranchID)
      AND (@UnitID        IS NULL OR v.UnitID        = @UnitID)
      AND (@ClientID      IS NULL OR v.Clientid      = @ClientID)
      AND (@DesignationID IS NULL OR v.DesignationID = @DesignationID)
      AND (@EmpStatus     IS NULL OR v.EmpStatus     = @EmpStatus)
      AND (@IsGunman      IS NULL OR v.IsGunman      = @IsGunman)
      AND (@IsReliever    IS NULL OR v.IsReliever    = @IsReliever)
      AND (@Search        IS NULL OR v.EmpFullName LIKE N'%' + @Search + N'%'
                                  OR v.EmpCode     LIKE N'%' + @Search + N'%'
                                  OR v.Mobile1     LIKE N'%' + @Search + N'%'
                                  OR v.BeltNo      LIKE N'%' + @Search + N'%');
END;
GO

/*  Employee 360 - eleven result sets, one per tab of the profile screen  */
CREATE OR ALTER PROCEDURE dbo.usp_Employee_Get360
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM hr.Employee WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0)
        THROW 51405, 'Employee not found.', 1;

    /* 1 core */
    SELECT e.EmpID, e.CompanyID, e.BranchID, e.EmpCode, e.OldEmpCode, e.Salutation,
           e.FirstName, e.Middlename, e.LastName, e.EmpFullName, e.Gender, e.Dob,
           Age = dbo.fnAgeInYears(e.Dob, CAST(SYSDATETIME() AS DATE)),
           e.BirthPlace, e.Bloodgroup, e.Nationality, e.Married, e.SpouseName,
           e.Mobile1, e.Mobile2, e.EmailId1, e.EmailId2,
           e.DesignationID, d.DesignationName, e.GradeID, e.CategoryID, e.ShiftID, s.ShiftName,
           e.UnitID, u.UnitName, e.Clientid, cl.ClientName, e.RegionID, e.AreaID,
           e.Employeetype, e.EmpStatus, e.Doj, e.Dol, e.DateofLeft, e.LeftReason, e.DoDeployment,
           e.BeltNo, e.CardNo, e.SwipeNo, e.IdCardNo, e.IdCardIssueDate, e.IdCardExpireDate,
           e.Photo, e.Selfie, e.EmpSign, e.IsPermanent, e.IsGunman, e.IsReliever,
           e.IsExService, e.IsNotBilling, e.IsBlackListed, e.BlackListedDate, e.BlackListedReason,
           e.Isform11pf, e.Isformfullfinal, e.Comments, e.IsApproved
    FROM hr.Employee AS e
    LEFT JOIN mst.Designation AS d  ON d.DesignationID = e.DesignationID
    LEFT JOIN mst.Shift       AS s  ON s.ShiftID = e.ShiftID
    LEFT JOIN crm.Unit        AS u  ON u.UnitID = e.UnitID
    LEFT JOIN crm.Client      AS cl ON cl.ClientID = e.Clientid
    WHERE e.EmpID = @EmpID;

    /* 2 addresses */
    SELECT AddressID, AddressType, Address1, Address2, City, StateID, DistrictID,
           Pin, Telephone, AddressDuration, ForeignAddress
    FROM hr.EmployeeAddress WHERE EmpID = @EmpID;

    /* 3 family */
    SELECT FamilyID, Relation, Name, Dob, Occupation, Dependent, SharePercent, AadhaarNo
    FROM hr.EmployeeFamily WHERE EmpID = @EmpID AND IsCancel = 0;

    /* 4 physical */
    SELECT Height, Weight, Chest, Waist, Shoesize, Trousersize, TshirtSize,
           EmployeeEyes, IdentificationMark
    FROM hr.EmployeePhysical WHERE EmpID = @EmpID;

    /* 5 statutory */
    SELECT AdharCardNo, PanCardNo, Pan, VoterId, DlNo, UANNo, PFNo, ESICNo,
           [Percent], PaymentMode, BankForSalary
    FROM hr.EmployeeStatutory WHERE EmpID = @EmpID;

    /* 6 bank */
    SELECT BankAccountID, IsJoint, BankID, BankName, BranchName, BankAcNo, IFSCcode,
           IfscCodeId, AcType, NameInBankPassbook, JointAcName, JointAcNo,
           JointBankName, BankPassbook, Cheque, IsBankAdded
    FROM hr.EmployeeBank WHERE EmpID = @EmpID AND IsCancel = 0;

    /* 7 qualification */
    SELECT q.EmpQualID, q.QualificationID, m.QualificationName, q.AddQualificationID,
           q.InstituteName, q.HigestEducationInstitue, q.ProfessionalQualification,
           q.PassingYear, q.[Percent]
    FROM hr.EmployeeQualification AS q
    LEFT JOIN mst.Qualification AS m ON m.QualificationID = q.QualificationID
    WHERE q.EmpID = @EmpID AND q.IsCancel = 0;

    /* 8 ex-service */
    SELECT ServiceSno, [Rank], Regiment, Dateofdischarge, Criminology, CharacterAssessed
    FROM hr.EmployeeExService WHERE EmpID = @EmpID;

    /* 9 police verification */
    SELECT IsPoliceVerification, PoliceVerificationNo, PoliceStationName, RemarkByThana,
           Pvsenddate, Pvreturndate, PVValidUpTo, VerificationDate, PoliceCertificateImg,
           NotaryStampPadNo
    FROM hr.EmployeeVerification WHERE EmpID = @EmpID;

    /* 10 medical */
    SELECT MedicalDate, MedicalCertificateIssue, MedicalCertificateIssueDate,
           MedicalCertificateValidUpto, MedicalCertificateImg, Hospital, Doctorname,
           DoctorRegNo, DoctorQualification, DoctorDesignation, DoctorAddress, DoctorPhoneNo
    FROM hr.EmployeeMedical WHERE EmpID = @EmpID;

    /* 11 gun licence */
    SELECT GunanType, TypeArm, GunNo, GunModelNum, LicenseNo, Licenseexpire,
           LicenseProduce, AreaID, AreainLicensevalid, IssueDate, Wcpno, Wcpamount, Wcpexpdate
    FROM hr.EmployeeGunLicence WHERE EmpID = @EmpID;

    /* 12 documents */
    SELECT d.DocumentID, d.DocTypeID, dt.DocTypeName, d.DocumentFilename, d.BlobUrl,
           d.IssueDate, d.ExpiryDate, d.IsVerified, d.VerifiedOn,
           DaysToExpiry = DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), d.ExpiryDate)
    FROM doc.Document AS d
    LEFT JOIN mst.DocumentType AS dt ON dt.DocTypeID = d.DocTypeID
    WHERE d.CompanyID = @CompanyID AND d.OwnerType = N'Employee' AND d.OwnerID = @EmpID AND d.IsCancel = 0;

    /* 13 deployment history */
    SELECT dp.DeploymentID, dp.UnitID, u.UnitName, dp.PostID, p.PostName,
           dp.ShiftID, s.ShiftName, dp.FromDate, dp.ToDate, dp.IsReliever, dp.Status
    FROM ops.Deployment AS dp
    LEFT JOIN crm.Unit     AS u ON u.UnitID = dp.UnitID
    LEFT JOIN crm.UnitPost AS p ON p.PostID = dp.PostID
    LEFT JOIN mst.Shift    AS s ON s.ShiftID = dp.ShiftID
    WHERE dp.EmpID = @EmpID AND dp.IsCancel = 0
    ORDER BY dp.FromDate DESC;

    /* 14 status history */
    SELECT HistoryID, EventType, EventDate, FromUnitID, ToUnitID, Remark, DocUrl, IsApproved
    FROM hr.EmployeeStatusHistory WHERE EmpID = @EmpID AND IsCancel = 0
    ORDER BY EventDate DESC;
END;
GO

/*==============================================================================
  EMPLOYEE - SATELLITE SAVES (one per wizard step)
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveCore
    @CompanyID     INT,
    @UserID        INT,
    @EmpID         INT,
    @Salutation    NVARCHAR(10)  = NULL,
    @FirstName     NVARCHAR(100) = NULL,
    @Middlename    NVARCHAR(100) = NULL,
    @LastName      NVARCHAR(100) = NULL,
    @Gender        NVARCHAR(10)  = NULL,
    @Dob           DATE          = NULL,
    @BirthPlace    NVARCHAR(100) = NULL,
    @Bloodgroup    NVARCHAR(5)   = NULL,
    @Nationality   NVARCHAR(50)  = NULL,
    @Married       BIT           = NULL,
    @SpouseName    NVARCHAR(150) = NULL,
    @Mobile1       NVARCHAR(15)  = NULL,
    @Mobile2       NVARCHAR(15)  = NULL,
    @EmailId1      NVARCHAR(150) = NULL,
    @DesignationID INT           = NULL,
    @CategoryID    INT           = NULL,
    @GradeID       INT           = NULL,
    @ShiftID       INT           = NULL,
    @Employeetype  NVARCHAR(50)  = NULL,
    @Doj           DATE          = NULL,
    @BeltNo        NVARCHAR(30)  = NULL,
    @IdCardNo      NVARCHAR(30)  = NULL,
    @IdCardIssueDate  DATE       = NULL,
    @IdCardExpireDate DATE       = NULL,
    @Photo         NVARCHAR(500) = NULL,
    @IsGunman      BIT           = NULL,
    @IsReliever    BIT           = NULL,
    @IsExService   BIT           = NULL,
    @Comments      NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Dob IS NOT NULL AND dbo.fnAgeInYears(@Dob, CAST(SYSDATETIME() AS DATE)) NOT BETWEEN 18 AND 60
        THROW 51406, 'Employee age must be between 18 and 60.', 1;

    UPDATE hr.Employee
    SET Salutation   = ISNULL(@Salutation, Salutation),
        FirstName    = ISNULL(@FirstName, FirstName),
        Middlename   = ISNULL(@Middlename, Middlename),
        LastName     = ISNULL(@LastName, LastName),
        Gender       = ISNULL(@Gender, Gender),
        Dob          = ISNULL(@Dob, Dob),
        BirthPlace   = ISNULL(@BirthPlace, BirthPlace),
        Bloodgroup   = ISNULL(@Bloodgroup, Bloodgroup),
        Nationality  = ISNULL(@Nationality, Nationality),
        Married      = ISNULL(@Married, Married),
        SpouseName   = ISNULL(@SpouseName, SpouseName),
        Mobile1      = ISNULL(@Mobile1, Mobile1),
        Mobile2      = ISNULL(@Mobile2, Mobile2),
        EmailId1     = ISNULL(@EmailId1, EmailId1),
        DesignationID = ISNULL(@DesignationID, DesignationID),
        CategoryID   = ISNULL(@CategoryID, CategoryID),
        GradeID      = ISNULL(@GradeID, GradeID),
        ShiftID      = ISNULL(@ShiftID, ShiftID),
        Employeetype = ISNULL(@Employeetype, Employeetype),
        Doj          = ISNULL(@Doj, Doj),
        BeltNo       = ISNULL(@BeltNo, BeltNo),
        IdCardNo     = ISNULL(@IdCardNo, IdCardNo),
        IdCardIssueDate  = ISNULL(@IdCardIssueDate, IdCardIssueDate),
        IdCardExpireDate = ISNULL(@IdCardExpireDate, IdCardExpireDate),
        Photo        = ISNULL(@Photo, Photo),
        IsGunman     = ISNULL(@IsGunman, IsGunman),
        IsReliever   = ISNULL(@IsReliever, IsReliever),
        IsExService  = ISNULL(@IsExService, IsExService),
        Comments     = ISNULL(@Comments, Comments),
        UpdateDate   = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0;

    IF @@ROWCOUNT = 0 THROW 51405, 'Employee not found.', 1;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveAddress
    @CompanyID   INT,
    @UserID      INT,
    @EmpID       INT,
    @AddressType CHAR(1),
    @Address1    NVARCHAR(300) = NULL,
    @Address2    NVARCHAR(300) = NULL,
    @City        NVARCHAR(100) = NULL,
    @StateID     INT           = NULL,
    @DistrictID  INT           = NULL,
    @Pin         NVARCHAR(10)  = NULL,
    @Telephone   NVARCHAR(20)  = NULL,
    @AddressDuration NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @AddressType NOT IN ('P','R') THROW 51407, 'AddressType must be P or R.', 1;

    UPDATE hr.EmployeeAddress
    SET Address1 = @Address1, Address2 = @Address2, City = @City, StateID = @StateID,
        DistrictID = @DistrictID, Pin = @Pin, Telephone = @Telephone,
        AddressDuration = @AddressDuration, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID AND AddressType = @AddressType;

    IF @@ROWCOUNT = 0
        INSERT INTO hr.EmployeeAddress (CompanyID, EmpID, AddressType, Address1, Address2, City,
                                        StateID, DistrictID, Pin, Telephone, AddressDuration,
                                        InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID, @AddressType, @Address1, @Address2, @City,
                @StateID, @DistrictID, @Pin, @Telephone, @AddressDuration, SYSDATETIME(), @UserID);

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Address saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveFamily
    @CompanyID    INT,
    @UserID       INT,
    @EmpID        INT,
    @Relation     NVARCHAR(30),
    @Name         NVARCHAR(200),
    @Dob          DATE          = NULL,
    @Occupation   NVARCHAR(100) = NULL,
    @Dependent    BIT           = 0,
    @SharePercent DECIMAL(5,2)  = NULL,
    @AadhaarNo    NVARCHAR(12)  = NULL,
    @FamilyID     INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @FamilyID IS NULL
    BEGIN
        INSERT INTO hr.EmployeeFamily (CompanyID, EmpID, Relation, Name, Dob, Occupation,
                                       Dependent, SharePercent, AadhaarNo, InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID, @Relation, @Name, @Dob, @Occupation,
                @Dependent, @SharePercent, @AadhaarNo, SYSDATETIME(), @UserID);
        SET @FamilyID = SCOPE_IDENTITY();
    END
    ELSE
        UPDATE hr.EmployeeFamily
        SET Relation = @Relation, Name = @Name, Dob = @Dob, Occupation = @Occupation,
            Dependent = @Dependent, SharePercent = @SharePercent, AadhaarNo = @AadhaarNo,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE FamilyID = @FamilyID AND EmpID = @EmpID;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @FamilyID, Message = N'Family member saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveBank
    @CompanyID   INT,
    @UserID      INT,
    @EmpID       INT,
    @BankID      INT           = NULL,
    @BankName    NVARCHAR(150) = NULL,
    @BranchName  NVARCHAR(150) = NULL,
    @BankAcNo    NVARCHAR(30)  = NULL,
    @IFSCcode    NVARCHAR(11)  = NULL,
    @IfscCodeId  INT           = NULL,
    @AcType      NVARCHAR(30)  = NULL,
    @NameInBankPassbook NVARCHAR(150) = NULL,
    @BankPassbook NVARCHAR(500) = NULL,
    @Cheque      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE hr.EmployeeBank
    SET BankID = @BankID, BankName = @BankName, BranchName = @BranchName,
        BankAcNo = @BankAcNo, IFSCcode = @IFSCcode, IfscCodeId = @IfscCodeId,
        AcType = @AcType, NameInBankPassbook = @NameInBankPassbook,
        BankPassbook = @BankPassbook, Cheque = @Cheque,
        IsBankAdded = 1, BankAddedDate = SYSDATETIME(), BankAddedUserId = @UserID,
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID AND IsJoint = 0 AND IsCancel = 0;

    IF @@ROWCOUNT = 0
        INSERT INTO hr.EmployeeBank (CompanyID, EmpID, IsJoint, BankID, BankName, BranchName,
                                     BankAcNo, IFSCcode, IfscCodeId, AcType, NameInBankPassbook,
                                     BankPassbook, Cheque, IsBankAdded, BankAddedDate,
                                     BankAddedUserId, InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID, 0, @BankID, @BankName, @BranchName,
                @BankAcNo, @IFSCcode, @IfscCodeId, @AcType, @NameInBankPassbook,
                @BankPassbook, @Cheque, 1, SYSDATETIME(), @UserID, SYSDATETIME(), @UserID);

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Bank details saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveStatutory
    @CompanyID   INT,
    @UserID      INT,
    @EmpID       INT,
    @AdharCardNo NVARCHAR(12) = NULL,
    @PanCardNo   NVARCHAR(10) = NULL,
    @VoterId     NVARCHAR(30) = NULL,
    @DlNo        NVARCHAR(30) = NULL,
    @UANNo       NVARCHAR(12) = NULL,
    @PFNo        NVARCHAR(30) = NULL,
    @ESICNo      NVARCHAR(20) = NULL,
    @PaymentMode NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /* Aadhaar must be unique within the tenant */
    IF @AdharCardNo IS NOT NULL AND EXISTS (
        SELECT 1 FROM hr.EmployeeStatutory
        WHERE CompanyID = @CompanyID AND AdharCardNo = @AdharCardNo AND EmpID <> @EmpID)
        THROW 51408, 'This Aadhaar number is already registered to another employee.', 1;

    UPDATE hr.EmployeeStatutory
    SET AdharCardNo = @AdharCardNo, PanCardNo = @PanCardNo, VoterId = @VoterId,
        DlNo = @DlNo, UANNo = @UANNo, PFNo = @PFNo, ESICNo = @ESICNo,
        PaymentMode = @PaymentMode, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID;

    IF @@ROWCOUNT = 0
        INSERT INTO hr.EmployeeStatutory (EmpID, CompanyID, AdharCardNo, PanCardNo, VoterId,
                                          DlNo, UANNo, PFNo, ESICNo, PaymentMode,
                                          InsertDate, InsertUserID)
        VALUES (@EmpID, @CompanyID, @AdharCardNo, @PanCardNo, @VoterId,
                @DlNo, @UANNo, @PFNo, @ESICNo, @PaymentMode, SYSDATETIME(), @UserID);

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Statutory details saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveVerification
    @CompanyID            INT,
    @UserID               INT,
    @EmpID                INT,
    @IsPoliceVerification BIT           = NULL,
    @PoliceVerificationNo NVARCHAR(50)  = NULL,
    @PoliceStationName    NVARCHAR(150) = NULL,
    @RemarkByThana        NVARCHAR(500) = NULL,
    @Pvsenddate           DATE          = NULL,
    @Pvreturndate         DATE          = NULL,
    @PVValidUpTo          DATE          = NULL,
    @PoliceCertificateImg NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE hr.EmployeeVerification
    SET IsPoliceVerification = ISNULL(@IsPoliceVerification, IsPoliceVerification),
        PoliceVerificationNo = @PoliceVerificationNo, PoliceStationName = @PoliceStationName,
        RemarkByThana = @RemarkByThana, Pvsenddate = @Pvsenddate, Pvreturndate = @Pvreturndate,
        PVValidUpTo = @PVValidUpTo, PoliceCertificateImg = @PoliceCertificateImg,
        VerificationDate = CASE WHEN @IsPoliceVerification = 1 THEN CAST(SYSDATETIME() AS DATE) ELSE VerificationDate END,
        UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID;

    IF @@ROWCOUNT = 0
        INSERT INTO hr.EmployeeVerification (EmpID, CompanyID, IsPoliceVerification, PoliceVerificationNo,
                                             PoliceStationName, RemarkByThana, Pvsenddate, Pvreturndate,
                                             PVValidUpTo, PoliceCertificateImg, InsertDate, InsertUserID)
        VALUES (@EmpID, @CompanyID, ISNULL(@IsPoliceVerification, 0), @PoliceVerificationNo,
                @PoliceStationName, @RemarkByThana, @Pvsenddate, @Pvreturndate,
                @PVValidUpTo, @PoliceCertificateImg, SYSDATETIME(), @UserID);

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Verification saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_SaveGunLicence
    @CompanyID     INT,
    @UserID        INT,
    @EmpID         INT,
    @GunanType     NVARCHAR(50)  = NULL,
    @TypeArm       NVARCHAR(50)  = NULL,
    @GunNo         NVARCHAR(50)  = NULL,
    @GunModelNum   NVARCHAR(50)  = NULL,
    @LicenseNo     NVARCHAR(50)  = NULL,
    @Licenseexpire DATE          = NULL,
    @AreaID        INT           = NULL,
    @IssueDate     DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE hr.EmployeeGunLicence
    SET GunanType = @GunanType, TypeArm = @TypeArm, GunNo = @GunNo, GunModelNum = @GunModelNum,
        LicenseNo = @LicenseNo, Licenseexpire = @Licenseexpire, AreaID = @AreaID,
        IssueDate = @IssueDate, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID;

    IF @@ROWCOUNT = 0
        INSERT INTO hr.EmployeeGunLicence (EmpID, CompanyID, GunanType, TypeArm, GunNo, GunModelNum,
                                           LicenseNo, Licenseexpire, AreaID, IssueDate,
                                           InsertDate, InsertUserID)
        VALUES (@EmpID, @CompanyID, @GunanType, @TypeArm, @GunNo, @GunModelNum,
                @LicenseNo, @Licenseexpire, @AreaID, @IssueDate, SYSDATETIME(), @UserID);

    UPDATE hr.Employee SET IsGunman = 1, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
    WHERE EmpID = @EmpID AND CompanyID = @CompanyID;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID, Message = N'Gun licence saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Employee_Blacklist
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT,
    @Blacklist BIT,
    @Reason    NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Blacklist = 1 AND (@Reason IS NULL OR LTRIM(RTRIM(@Reason)) = N'')
        THROW 51409, 'A reason is required to blacklist an employee.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE hr.Employee
        SET IsBlackListed     = @Blacklist,
            BlackListedDate   = CASE WHEN @Blacklist = 1 THEN CAST(SYSDATETIME() AS DATE) ELSE NULL END,
            BlackListedReason = CASE WHEN @Blacklist = 1 THEN @Reason ELSE NULL END,
            EmpStatus         = CASE WHEN @Blacklist = 1 THEN N'Blacklisted' ELSE N'Active' END,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE EmpID = @EmpID AND CompanyID = @CompanyID AND IsCancel = 0;

        IF @@ROWCOUNT = 0 THROW 51405, 'Employee not found.', 1;

        IF @Blacklist = 1
            UPDATE ops.Deployment
            SET Status = N'Ended', ToDate = CAST(SYSDATETIME() AS DATE),
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE CompanyID = @CompanyID AND EmpID = @EmpID AND Status = N'Active';

        INSERT INTO hr.EmployeeStatusHistory (CompanyID, EmpID, EventType, EventDate, Remark,
                                              IsApproved, InsertDate, InsertUserID)
        VALUES (@CompanyID, @EmpID,
                CASE WHEN @Blacklist = 1 THEN N'Blacklist' ELSE N'Unblacklist' END,
                CAST(SYSDATETIME() AS DATE), @Reason, 1, SYSDATETIME(), @UserID);

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @EmpID,
           Message = CASE WHEN @Blacklist = 1 THEN N'Employee blacklisted' ELSE N'Blacklist removed' END;
END;
GO

/*==============================================================================
  CLIENTS AND UNITS
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Client_Save
    @CompanyID      INT,
    @UserID         INT,
    @ClientName     NVARCHAR(200),
    @BranchID       INT           = NULL,
    @ClientCode     NVARCHAR(30)  = NULL,
    @CompanyAddress NVARCHAR(500) = NULL,
    @CityID         INT           = NULL,
    @StateID        INT           = NULL,
    @Pin            NVARCHAR(10)  = NULL,
    @GSTIN          NVARCHAR(15)  = NULL,
    @PAN            NVARCHAR(10)  = NULL,
    @ContactPerson  NVARCHAR(150) = NULL,
    @ContactNo      NVARCHAR(15)  = NULL,
    @Email          NVARCHAR(150) = NULL,
    @ClientID       INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @ClientID IS NULL
    BEGIN
        INSERT INTO crm.Client (CompanyID, BranchID, ClientName, ClientCode, CompanyAddress,
                                CityID, StateID, Pin, GSTIN, PAN, ContactPerson, ContactNo,
                                Email, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ClientName, @ClientCode, @CompanyAddress,
                @CityID, @StateID, @Pin, @GSTIN, @PAN, @ContactPerson, @ContactNo,
                @Email, SYSDATETIME(), @UserID);
        SET @ClientID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        UPDATE crm.Client
        SET ClientName = @ClientName, ClientCode = @ClientCode, BranchID = @BranchID,
            CompanyAddress = @CompanyAddress, CityID = @CityID, StateID = @StateID, Pin = @Pin,
            GSTIN = @GSTIN, PAN = @PAN, ContactPerson = @ContactPerson, ContactNo = @ContactNo,
            Email = @Email, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE ClientID = @ClientID AND CompanyID = @CompanyID AND IsCancel = 0;

        IF @@ROWCOUNT = 0 THROW 51410, 'Client not found.', 1;
    END

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ClientID, Message = N'Client saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Unit_Save
    @CompanyID            INT,
    @UserID               INT,
    @ClientID             INT,
    @UnitName             NVARCHAR(200),
    @BranchID             INT           = NULL,
    @UnitCode             NVARCHAR(30)  = NULL,
    @Address              NVARCHAR(500) = NULL,
    @CityID               INT           = NULL,
    @StateID              INT           = NULL,
    @Pin                  NVARCHAR(10)  = NULL,
    @Latitude             DECIMAL(10,7) = NULL,
    @Longitude            DECIMAL(10,7) = NULL,
    @GeofenceRadiusMeters INT           = 150,
    @SupervisorEmpID      INT           = NULL,
    @AgreementNo          NVARCHAR(50)  = NULL,
    @AgreementExpDate     DATE          = NULL,
    @OrderNo              NVARCHAR(50)  = NULL,
    @OrderDate            DATE          = NULL,
    @OrderExpiryDate      DATE          = NULL,
    @WorkStartDate        DATE          = NULL,
    @UnitID               INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @UnitID IS NULL
    BEGIN
        INSERT INTO crm.Unit (CompanyID, BranchID, ClientID, UnitName, UnitCode, Address,
                              CityID, StateID, Pin, Latitude, Longitude, GeofenceRadiusMeters,
                              SupervisorEmpID, AgreementNo, AgreementExpDate, OrderNo, OrderDate,
                              OrderExpiryDate, WorkStartDate, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ClientID, @UnitName, @UnitCode, @Address,
                @CityID, @StateID, @Pin, @Latitude, @Longitude, @GeofenceRadiusMeters,
                @SupervisorEmpID, @AgreementNo, @AgreementExpDate, @OrderNo, @OrderDate,
                @OrderExpiryDate, @WorkStartDate, SYSDATETIME(), @UserID);
        SET @UnitID = SCOPE_IDENTITY();
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
            THROW 51411, 'You do not have access to this unit.', 1;

        UPDATE crm.Unit
        SET UnitName = @UnitName, UnitCode = @UnitCode, BranchID = @BranchID, ClientID = @ClientID,
            Address = @Address, CityID = @CityID, StateID = @StateID, Pin = @Pin,
            Latitude = @Latitude, Longitude = @Longitude,
            GeofenceRadiusMeters = @GeofenceRadiusMeters, SupervisorEmpID = @SupervisorEmpID,
            AgreementNo = @AgreementNo, AgreementExpDate = @AgreementExpDate,
            OrderNo = @OrderNo, OrderDate = @OrderDate, OrderExpiryDate = @OrderExpiryDate,
            WorkStartDate = @WorkStartDate, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE UnitID = @UnitID AND CompanyID = @CompanyID AND IsCancel = 0;

        IF @@ROWCOUNT = 0 THROW 51412, 'Unit not found.', 1;
    END

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @UnitID, Message = N'Unit saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UnitPost_Save
    @CompanyID        INT,
    @UserID           INT,
    @UnitID           INT,
    @PostName         NVARCHAR(150),
    @DesignationID    INT           = NULL,
    @ShiftID          INT           = NULL,
    @RequiredStrength INT           = 1,
    @RatePerGuard     DECIMAL(18,2) = 0,
    @IsArmed          BIT           = 0,
    @EffectiveFrom    DATE          = NULL,
    @PostID           INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51411, 'You do not have access to this unit.', 1;

    IF @PostID IS NULL
    BEGIN
        INSERT INTO crm.UnitPost (CompanyID, UnitID, PostName, DesignationID, ShiftID,
                                  RequiredStrength, RatePerGuard, IsArmed, EffectiveFrom,
                                  InsertDate, InsertUserID)
        VALUES (@CompanyID, @UnitID, @PostName, @DesignationID, @ShiftID,
                @RequiredStrength, @RatePerGuard, @IsArmed, @EffectiveFrom, SYSDATETIME(), @UserID);
        SET @PostID = SCOPE_IDENTITY();
    END
    ELSE
        UPDATE crm.UnitPost
        SET PostName = @PostName, DesignationID = @DesignationID, ShiftID = @ShiftID,
            RequiredStrength = @RequiredStrength, RatePerGuard = @RatePerGuard,
            IsArmed = @IsArmed, EffectiveFrom = @EffectiveFrom,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE PostID = @PostID AND CompanyID = @CompanyID;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @PostID, Message = N'Post saved';
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Unit_GetList
    @CompanyID INT,
    @UserID    INT,
    @ClientID  INT           = NULL,
    @BranchID  INT           = NULL,
    @Search    NVARCHAR(200) = NULL,
    @PageNo    INT           = 1,
    @PageSize  INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT
        u.UnitID, u.UnitName, u.UnitCode, u.Address, u.ClientID, cl.ClientName,
        u.BranchID, b.BranchName, u.Latitude, u.Longitude, u.GeofenceRadiusMeters,
        u.AgreementNo, u.AgreementExpDate, u.OrderNo, u.OrderDate, u.OrderExpiryDate,
        u.WorkStartDate, u.IsActive,
        SupervisorName = sup.EmpFullName,
        RequiredStrength = ISNULL(rq.RequiredStrength, 0),
        DeployedNos = ISNULL(dp.Cnt, 0),
        CheckpointCount = ISNULL(qr.Cnt, 0),
        OpenComplaints = ISNULL(cp.Cnt, 0),
        AgreementDaysLeft = DATEDIFF(DAY, CAST(SYSDATETIME() AS DATE), u.AgreementExpDate)
    FROM crm.Unit AS u
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
    INNER JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    LEFT  JOIN org.Branch AS b  ON b.BranchID = u.BranchID
    LEFT  JOIN hr.Employee AS sup ON sup.EmpID = u.SupervisorEmpID
    OUTER APPLY dbo.fnUnitRequiredStrength(@CompanyID, u.UnitID, CAST(SYSDATETIME() AS DATE), NULL) AS rq
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.Deployment AS d
                 WHERE d.UnitID = u.UnitID AND d.Status = N'Active' AND d.IsCancel = 0) AS dp
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.QrCheckpoint AS q
                 WHERE q.UnitID = u.UnitID AND q.IsActive = 1 AND q.IsCancel = 0) AS qr
    OUTER APPLY (SELECT Cnt = COUNT(*) FROM ops.Complaint AS c
                 WHERE c.UnitID = u.UnitID AND c.IsClosed = 0 AND c.IsCancel = 0) AS cp
    WHERE u.CompanyID = @CompanyID AND u.IsCancel = 0
      AND (@ClientID IS NULL OR u.ClientID = @ClientID)
      AND (@BranchID IS NULL OR u.BranchID = @BranchID)
      AND (@Search   IS NULL OR u.UnitName LIKE N'%' + @Search + N'%'
                             OR cl.ClientName LIKE N'%' + @Search + N'%')
    ORDER BY cl.ClientName, u.UnitName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*)
    FROM crm.Unit AS u
    INNER JOIN dbo.fnUserAccessibleUnits(@CompanyID, @UserID) AS au ON au.UnitID = u.UnitID
    INNER JOIN crm.Client AS cl ON cl.ClientID = u.ClientID
    WHERE u.CompanyID = @CompanyID AND u.IsCancel = 0
      AND (@ClientID IS NULL OR u.ClientID = @ClientID)
      AND (@BranchID IS NULL OR u.BranchID = @BranchID)
      AND (@Search   IS NULL OR u.UnitName LIKE N'%' + @Search + N'%'
                             OR cl.ClientName LIKE N'%' + @Search + N'%');
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UnitLocation_Save
    @CompanyID    INT,
    @UserID       INT,
    @UnitID       INT,
    @LocationName NVARCHAR(150),
    @Latitude     DECIMAL(10,7) = NULL,
    @Longitude    DECIMAL(10,7) = NULL,
    @Description  NVARCHAR(500) = NULL,
    @LocationID   INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.fnUserAccessibleUnits(@CompanyID, @UserID) WHERE UnitID = @UnitID)
        THROW 51411, 'You do not have access to this unit.', 1;

    IF @LocationID IS NULL
    BEGIN
        INSERT INTO crm.UnitLocation (CompanyID, UnitID, LocationName, Latitude, Longitude,
                                      Description, InsertDate, InsertUserID)
        VALUES (@CompanyID, @UnitID, @LocationName, @Latitude, @Longitude,
                @Description, SYSDATETIME(), @UserID);
        SET @LocationID = SCOPE_IDENTITY();
    END
    ELSE
        UPDATE crm.UnitLocation
        SET LocationName = @LocationName, Latitude = @Latitude, Longitude = @Longitude,
            Description = @Description, UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE LocationID = @LocationID AND CompanyID = @CompanyID;

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @LocationID, Message = N'Location saved';
END;
GO

PRINT '523_procedures_people.sql  ->  OK  (20 procedures)';
GO
