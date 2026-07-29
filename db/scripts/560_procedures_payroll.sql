/*==============================================================================
  560_procedures_payroll.sql
  Payroll generation and client billing.
  Spec: docs/prd/01-database.md §7.6

  Payroll is the highest-consequence code in the system: an error here is money
  taken from a guard who earns near minimum wage. Three rules are enforced:
    1. Only APPROVED attendance counts towards payable days.
    2. A run must pass validation before it can be generated.
    3. Once locked, nothing about the month can change - not the salary rows,
       not the attendance behind them (fnIsAttendanceMonthLocked in 520).
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  VALIDATION - run this before generating; it is the blocking list on the wizard
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Payroll_Validate
    @CompanyID INT,
    @UserID    INT,
    @MonthYear CHAR(7),
    @BranchID  INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @From DATE = CAST(@MonthYear + '-01' AS DATE);
    DECLARE @To   DATE = EOMONTH(@From);

    ;WITH emp AS (
        SELECT e.EmpID, e.EmpCode, e.EmpFullName, e.BranchID, e.UnitID
        FROM hr.Employee AS e
        WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
          AND e.EmpStatus IN (N'Active', N'Resigned', N'Left')
          AND (@BranchID IS NULL OR e.BranchID = @BranchID)
          AND (e.Doj IS NULL OR e.Doj <= @To)
          AND (e.Dol IS NULL OR e.Dol >= @From)
    )
    SELECT Issue = N'Unapproved attendance', e.EmpID, e.EmpCode, e.EmpFullName,
           Detail = CONCAT(x.Cnt, N' day(s) still pending approval')
    FROM emp AS e
    CROSS APPLY (SELECT Cnt = COUNT(*) FROM ops.Attendance AS a
                 WHERE a.EmpID = e.EmpID AND a.IsCancel = 0 AND a.ApprovalStatus = 0
                   AND a.AttendanceDate BETWEEN @From AND @To) AS x
    WHERE x.Cnt > 0

    UNION ALL
    SELECT N'No salary structure', e.EmpID, e.EmpCode, e.EmpFullName,
           N'No effective salary structure for this month'
    FROM emp AS e
    WHERE NOT EXISTS (SELECT 1 FROM fin.SalaryStructure AS s
                      WHERE s.EmpID = e.EmpID AND s.IsCancel = 0 AND s.EffectiveFrom <= @To)

    UNION ALL
    SELECT N'Missing bank details', e.EmpID, e.EmpCode, e.EmpFullName,
           N'No account number or IFSC on record'
    FROM emp AS e
    WHERE NOT EXISTS (SELECT 1 FROM hr.EmployeeBank AS b
                      WHERE b.EmpID = e.EmpID AND b.IsJoint = 0 AND b.IsCancel = 0
                        AND b.BankAcNo IS NOT NULL AND b.IFSCcode IS NOT NULL)

    UNION ALL
    SELECT N'No attendance', e.EmpID, e.EmpCode, e.EmpFullName,
           N'No attendance recorded for the month'
    FROM emp AS e
    WHERE NOT EXISTS (SELECT 1 FROM ops.Attendance AS a
                      WHERE a.EmpID = e.EmpID AND a.IsCancel = 0
                        AND a.AttendanceDate BETWEEN @From AND @To)
    ORDER BY Issue, EmpFullName;

    SELECT AlreadyLocked = CASE WHEN EXISTS (
        SELECT 1 FROM fin.SalaryRun
        WHERE CompanyID = @CompanyID AND MonthYear = @MonthYear
          AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0)
          AND Status IN (N'Locked', N'Paid') AND IsCancel = 0)
        THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
END;
GO

/*==============================================================================
  GENERATE
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Payroll_Generate
    @CompanyID INT,
    @UserID    INT,
    @MonthYear CHAR(7),
    @BranchID  INT = NULL,
    @RunID     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @From DATE = CAST(@MonthYear + '-01' AS DATE);
    DECLARE @To   DATE = EOMONTH(@From);
    DECLARE @lock NVARCHAR(200) = CONCAT(N'payroll:', @CompanyID, N':', @MonthYear, N':', ISNULL(@BranchID, 0));
    DECLARE @rc INT, @Count INT = 0, @Total DECIMAL(18,2) = 0;

    BEGIN TRY
        BEGIN TRAN;

        EXEC @rc = sp_getapplock @Resource = @lock, @LockMode = 'Exclusive',
                                 @LockOwner = 'Transaction', @LockTimeout = 10000;
        IF @rc < 0 THROW 51900, 'A payroll run for this month is already in progress.', 1;

        SELECT @RunID = RunID FROM fin.SalaryRun
        WHERE CompanyID = @CompanyID AND MonthYear = @MonthYear
          AND ISNULL(BranchID, 0) = ISNULL(@BranchID, 0) AND IsCancel = 0;

        IF @RunID IS NOT NULL
           AND EXISTS (SELECT 1 FROM fin.SalaryRun WHERE RunID = @RunID AND Status IN (N'Locked', N'Paid'))
            THROW 51901, 'This month is already locked. Unlock is not permitted.', 1;

        IF @RunID IS NULL
        BEGIN
            INSERT INTO fin.SalaryRun (CompanyID, BranchID, MonthYear, Status, GeneratedBy,
                                       GeneratedOn, InsertDate, InsertUserID)
            VALUES (@CompanyID, @BranchID, @MonthYear, N'Draft', @UserID,
                    SYSDATETIME(), SYSDATETIME(), @UserID);
            SET @RunID = SCOPE_IDENTITY();
        END
        ELSE
            DELETE FROM fin.Salary WHERE RunID = @RunID;   -- regenerate a draft from scratch

        ;WITH emp AS (
            SELECT e.EmpID, e.BranchID, e.UnitID, e.Clientid,
                   StateID = ISNULL(u.StateID, co.StateID)
            FROM hr.Employee AS e
            LEFT JOIN crm.Unit   AS u  ON u.UnitID = e.UnitID
            LEFT JOIN org.Company AS co ON co.CompanyID = e.CompanyID
            WHERE e.CompanyID = @CompanyID AND e.IsCancel = 0
              AND e.EmpStatus IN (N'Active', N'Resigned', N'Left')
              AND (@BranchID IS NULL OR e.BranchID = @BranchID)
              AND (e.Doj IS NULL OR e.Doj <= @To)
              AND (e.Dol IS NULL OR e.Dol >= @From)
              AND EXISTS (SELECT 1 FROM ops.Attendance AS a
                          WHERE a.EmpID = e.EmpID AND a.IsCancel = 0 AND a.ApprovalStatus = 1
                            AND a.AttendanceDate BETWEEN @From AND @To)
        ),
        strct AS (
            SELECT s.EmpID, s.BasicWages, s.HRAAmt, s.FoodAllow, s.LeaveAllow, s.ReliverAllow,
                   s.SpAllowance, s.MixOther, s.OtRatePerHour,
                   s.IsPfApplicable, s.IsEsicApplicable, s.IsPtApplicable, s.IsLwfApplicable
            FROM fin.SalaryStructure AS s
            INNER JOIN (SELECT EmpID, MaxEff = MAX(EffectiveFrom)
                        FROM fin.SalaryStructure
                        WHERE IsCancel = 0 AND EffectiveFrom <= @To
                        GROUP BY EmpID) AS m
                    ON m.EmpID = s.EmpID AND m.MaxEff = s.EffectiveFrom
            WHERE s.IsCancel = 0
        ),
        att AS (
            SELECT a.EmpID,
                   PresentDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0 WHEN a.Status = 'DS' THEN 2.0 ELSE 0 END),
                   OtHours     = SUM(ISNULL(a.OtHours, 0))
            FROM ops.Attendance AS a
            WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0 AND a.ApprovalStatus = 1
              AND a.AttendanceDate BETWEEN @From AND @To
            GROUP BY a.EmpID
        ),
        calc AS (
            SELECT
                e.EmpID, e.BranchID, e.UnitID, e.StateID,
                ClientName  = cl.ClientName,
                PresentDays = ISNULL(a.PresentDays, 0),
                PayableDays = dbo.fnPayableDays(@CompanyID, e.EmpID, @MonthYear),
                DaysInMonth = CAST(DAY(@To) AS DECIMAL(5,1)),
                st.BasicWages, st.HRAAmt, st.FoodAllow, st.LeaveAllow, st.ReliverAllow,
                st.SpAllowance, st.MixOther, st.OtRatePerHour,
                st.IsPfApplicable, st.IsEsicApplicable, st.IsPtApplicable, st.IsLwfApplicable,
                OtHours = ISNULL(a.OtHours, 0)
            FROM emp AS e
            INNER JOIN strct AS st ON st.EmpID = e.EmpID
            LEFT  JOIN att   AS a  ON a.EmpID  = e.EmpID
            LEFT  JOIN crm.Client AS cl ON cl.ClientID = e.Clientid
        ),
        prorated AS (
            SELECT c.*,
                   Ratio = CASE WHEN c.DaysInMonth = 0 THEN 0 ELSE c.PayableDays / c.DaysInMonth END
            FROM calc AS c
        ),
        earnings AS (
            SELECT p.*,
                   eBasic   = ROUND(p.BasicWages   * p.Ratio, 0),
                   eHra     = ROUND(p.HRAAmt       * p.Ratio, 0),
                   eFood    = ROUND(p.FoodAllow    * p.Ratio, 0),
                   eLeave   = ROUND(p.LeaveAllow   * p.Ratio, 0),
                   eReliver = ROUND(p.ReliverAllow * p.Ratio, 0),
                   eSpecial = ROUND(p.SpAllowance  * p.Ratio, 0),
                   eOther   = ROUND(p.MixOther     * p.Ratio, 0),
                   eOt      = ROUND(p.OtHours * ISNULL(p.OtRatePerHour, 0), 0)
            FROM prorated AS p
        ),
        totals AS (
            SELECT e.*,
                   Gross = e.eBasic + e.eHra + e.eFood + e.eLeave + e.eReliver + e.eSpecial + e.eOther + e.eOt
            FROM earnings AS e
        ),
        deductions AS (
            SELECT t.*,
                   dPf   = CASE WHEN t.IsPfApplicable   = 1 THEN dbo.fnPfAmount(t.eBasic, @To) ELSE 0 END,
                   dEsic = CASE WHEN t.IsEsicApplicable = 1 THEN dbo.fnEsicAmount(t.Gross, @To) ELSE 0 END,
                   dPt   = CASE WHEN t.IsPtApplicable   = 1 THEN dbo.fnPtAmount(t.Gross, t.StateID, @To) ELSE 0 END,
                   dLwf  = CASE WHEN t.IsLwfApplicable  = 1 THEN dbo.fnLwfAmount(t.StateID, t.Gross, @To) ELSE 0 END,
                   dAdv  = ISNULL((SELECT MIN(CASE WHEN adv.InstallmentAmount > adv.BalanceAmount
                                                   THEN adv.BalanceAmount ELSE adv.InstallmentAmount END)
                                   FROM fin.Advance AS adv
                                   WHERE adv.EmpID = t.EmpID AND adv.CompanyID = @CompanyID
                                     AND adv.IsCancel = 0 AND adv.BalanceAmount > 0
                                     AND adv.Status IN (N'Approved', N'Recovering')), 0),
                   dUnif = ISNULL((SELECT SUM(i.OutstandingQty * i.Rate) - SUM(i.RecoveredAmount)
                                   FROM inv.EmployeeIssue AS i
                                   WHERE i.EmpID = t.EmpID AND i.CompanyID = @CompanyID
                                     AND i.IsCancel = 0 AND i.RecoverInSalary = 1), 0)
            FROM totals AS t
        )
        INSERT INTO fin.Salary (RunID, CompanyID, BranchID, EmpID, UnitID, ClientName, MonthYear,
                                PresentDays, PayableDays, BasicWages, HRAAmt, FoodAllow, LeaveAllow,
                                ReliverAllow, SpAllowance, BonusAmt, MixOther, OtAmount, TotalEarnings,
                                PFAmt, ESICAmt, PtEmp, LwfEmp, AdvanceDeduction, UniformDeduction,
                                OtherDeduction, DeductionAmt, NetPayble, InsertDate, InsertUserID)
        SELECT @RunID, @CompanyID, d.BranchID, d.EmpID, d.UnitID, d.ClientName, @MonthYear,
               d.PresentDays, d.PayableDays, d.eBasic, d.eHra, d.eFood, d.eLeave,
               d.eReliver, d.eSpecial, 0, d.eOther, d.eOt, d.Gross,
               d.dPf, d.dEsic, d.dPt, d.dLwf, d.dAdv,
               CASE WHEN d.dUnif > 0 THEN d.dUnif ELSE 0 END,
               0,
               d.dPf + d.dEsic + d.dPt + d.dLwf + d.dAdv + CASE WHEN d.dUnif > 0 THEN d.dUnif ELSE 0 END,
               d.Gross - (d.dPf + d.dEsic + d.dPt + d.dLwf + d.dAdv + CASE WHEN d.dUnif > 0 THEN d.dUnif ELSE 0 END),
               SYSDATETIME(), @UserID
        FROM deductions AS d;

        SELECT @Count = COUNT(*), @Total = ISNULL(SUM(NetPayble), 0) FROM fin.Salary WHERE RunID = @RunID;

        UPDATE fin.SalaryRun
        SET EmployeeCount = @Count, TotalNetPayable = @Total,
            GeneratedOn = SYSDATETIME(), GeneratedBy = @UserID,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE RunID = @RunID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @RunID,
           Message = CONCAT(@Count, N' salary rows generated'),
           EmployeeCount = @Count, TotalNetPayable = @Total;
END;
GO

/*==============================================================================
  LOCK - also recovers advances and uniform amounts, once and only once
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Payroll_Lock
    @CompanyID INT,
    @UserID    INT,
    @RunID     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM fin.SalaryRun
                   WHERE RunID = @RunID AND CompanyID = @CompanyID AND Status = N'Draft' AND IsCancel = 0)
        THROW 51902, 'Run not found, or it is not in Draft status.', 1;

    BEGIN TRY
        BEGIN TRAN;

        /* advances: reduce the balance by what this run deducted */
        UPDATE adv
        SET adv.BalanceAmount = adv.BalanceAmount - s.AdvanceDeduction,
            adv.Status = CASE WHEN adv.BalanceAmount - s.AdvanceDeduction <= 0
                              THEN N'Closed' ELSE N'Recovering' END,
            adv.UpdateDate = SYSDATETIME(), adv.UpdateUserID = @UserID
        FROM fin.Advance AS adv
        INNER JOIN fin.Salary AS s ON s.EmpID = adv.EmpID AND s.RunID = @RunID
        WHERE adv.CompanyID = @CompanyID AND adv.BalanceAmount > 0
          AND adv.Status IN (N'Approved', N'Recovering') AND s.AdvanceDeduction > 0;

        /* uniform: mark the recovered amount so it is not deducted again next month */
        UPDATE i
        SET i.RecoveredAmount = i.RecoveredAmount + (i.OutstandingQty * i.Rate),
            i.UpdateDate = SYSDATETIME(), i.UpdateUserID = @UserID
        FROM inv.EmployeeIssue AS i
        INNER JOIN fin.Salary AS s ON s.EmpID = i.EmpID AND s.RunID = @RunID
        WHERE i.CompanyID = @CompanyID AND i.RecoverInSalary = 1 AND i.IsCancel = 0
          AND s.UniformDeduction > 0;

        UPDATE fin.SalaryRun
        SET Status = N'Locked', LockedOn = SYSDATETIME(), LockedBy = @UserID,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE RunID = @RunID;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @RunID,
           Message = N'Payroll locked. The month is now closed for attendance edits.';
END;
GO

/*==============================================================================
  SLIP AND REGISTER
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Payroll_GetSlip
    @CompanyID INT,
    @UserID    INT,
    @EmpID     INT,
    @MonthYear CHAR(7)
AS
BEGIN
    SET NOCOUNT ON;

    /* exact Salaryslipmodel$Datum shape */
    SELECT TOP (1)
        s.WcsSalaryID, s.MonthYear, s.ClientName,
        s.BasicWages, s.HRAAmt, s.FoodAllow, s.LeaveAllow, s.ReliverAllow,
        s.SpAllowance, s.BonusAmt, s.MixOther, s.TotalEarnings,
        s.PFAmt, s.ESICAmt, s.PtEmp, s.LwfEmp, s.DeductionAmt, s.NetPayble,
        s.PresentDays, s.PayableDays, s.OtAmount,
        s.AdvanceDeduction, s.UniformDeduction, s.PaymentMode, s.PaidOn, s.UtrNo,
        EmpCode = e.EmpCode, EmpName = e.EmpFullName,
        DesignationName = d.DesignationName, UnitName = u.UnitName,
        BankAcNo = b.BankAcNo, IFSCcode = b.IFSCcode, BankName = b.BankName,
        UANNo = st.UANNo, ESICNo = st.ESICNo, PanCardNo = st.PanCardNo,
        RunStatus = r.Status,
        CompanyName = co.CompanyName, CompanyAddress = co.CompanyAddress, LogoUrl = co.LogoUrl
    FROM fin.Salary AS s
    INNER JOIN fin.SalaryRun AS r ON r.RunID = s.RunID
    INNER JOIN hr.Employee   AS e ON e.EmpID = s.EmpID
    INNER JOIN org.Company   AS co ON co.CompanyID = s.CompanyID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit      AS u ON u.UnitID = s.UnitID
    LEFT  JOIN hr.EmployeeBank AS b ON b.EmpID = e.EmpID AND b.IsJoint = 0 AND b.IsCancel = 0
    LEFT  JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
    WHERE s.CompanyID = @CompanyID AND s.EmpID = @EmpID
      AND s.MonthYear = @MonthYear AND s.IsCancel = 0
    ORDER BY s.WcsSalaryID DESC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Payroll_GetRegister
    @CompanyID INT,
    @UserID    INT,
    @RunID     INT,
    @PageNo    INT = 1,
    @PageSize  INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 100;
    IF @PageSize > 500 SET @PageSize = 500;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT r.RunID, r.MonthYear, r.Status, r.EmployeeCount, r.TotalNetPayable,
           r.GeneratedOn, r.LockedOn, b.BranchName
    FROM fin.SalaryRun AS r
    LEFT JOIN org.Branch AS b ON b.BranchID = r.BranchID
    WHERE r.RunID = @RunID AND r.CompanyID = @CompanyID;

    SELECT s.WcsSalaryID, s.EmpID, e.EmpCode, e.EmpFullName, d.DesignationName,
           u.UnitName, s.ClientName, s.PresentDays, s.PayableDays,
           s.BasicWages, s.HRAAmt, s.FoodAllow, s.LeaveAllow, s.ReliverAllow,
           s.SpAllowance, s.BonusAmt, s.MixOther, s.OtAmount, s.TotalEarnings,
           s.PFAmt, s.ESICAmt, s.PtEmp, s.LwfEmp, s.AdvanceDeduction,
           s.UniformDeduction, s.OtherDeduction, s.DeductionAmt, s.NetPayble,
           s.EditReason,
           PrevNetPayble = pv.NetPayble,
           VariancePercent = CASE WHEN ISNULL(pv.NetPayble, 0) = 0 THEN NULL
                                  ELSE CAST((s.NetPayble - pv.NetPayble) * 100.0 / pv.NetPayble AS DECIMAL(6,1)) END
    FROM fin.Salary AS s
    INNER JOIN hr.Employee AS e ON e.EmpID = s.EmpID
    LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    LEFT  JOIN crm.Unit AS u ON u.UnitID = s.UnitID
    OUTER APPLY (SELECT TOP (1) NetPayble FROM fin.Salary AS p
                 WHERE p.EmpID = s.EmpID AND p.CompanyID = @CompanyID
                   AND p.MonthYear < s.MonthYear AND p.IsCancel = 0
                 ORDER BY p.MonthYear DESC) AS pv
    WHERE s.RunID = @RunID AND s.CompanyID = @CompanyID AND s.IsCancel = 0
    ORDER BY e.EmpFullName
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*) FROM fin.Salary WHERE RunID = @RunID AND IsCancel = 0;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Payroll_GetBankAdvice
    @CompanyID INT, @UserID INT, @RunID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT e.EmpCode, BeneficiaryName = ISNULL(b.NameInBankPassbook, e.EmpFullName),
           b.BankAcNo, b.IFSCcode, b.BankName, Amount = s.NetPayble,
           Narration = CONCAT(N'SALARY ', s.MonthYear, N' ', e.EmpCode)
    FROM fin.Salary AS s
    INNER JOIN hr.Employee AS e ON e.EmpID = s.EmpID
    LEFT  JOIN hr.EmployeeBank AS b ON b.EmpID = e.EmpID AND b.IsJoint = 0 AND b.IsCancel = 0
    WHERE s.RunID = @RunID AND s.CompanyID = @CompanyID AND s.IsCancel = 0 AND s.NetPayble > 0
    ORDER BY e.EmpCode;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Payroll_GetStatutoryReturn
    @CompanyID INT, @UserID INT, @RunID INT, @ReturnType NVARCHAR(10)   -- PF / ESIC
AS
BEGIN
    SET NOCOUNT ON;

    IF @ReturnType = N'PF'
        SELECT st.UANNo, e.EmpFullName, GrossWages = s.TotalEarnings, EpfWages = s.BasicWages,
               EpsWages = s.BasicWages, EdliWages = s.BasicWages,
               EpfContribution = s.PFAmt, EpsContribution = 0, EpfEpsDiff = 0,
               NcpDays = CAST(DAY(EOMONTH(CAST(s.MonthYear + '-01' AS DATE))) - s.PayableDays AS INT),
               RefundOfAdvances = 0
        FROM fin.Salary AS s
        INNER JOIN hr.Employee AS e ON e.EmpID = s.EmpID
        LEFT  JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
        WHERE s.RunID = @RunID AND s.CompanyID = @CompanyID AND s.IsCancel = 0 AND s.PFAmt > 0
        ORDER BY st.UANNo;
    ELSE IF @ReturnType = N'ESIC'
        SELECT st.ESICNo, e.EmpFullName, NoOfDays = s.PayableDays,
               TotalWages = s.TotalEarnings, EmployeeContribution = s.ESICAmt,
               Reason = NULL, LastWorkingDay = e.Dol
        FROM fin.Salary AS s
        INNER JOIN hr.Employee AS e ON e.EmpID = s.EmpID
        LEFT  JOIN hr.EmployeeStatutory AS st ON st.EmpID = e.EmpID
        WHERE s.RunID = @RunID AND s.CompanyID = @CompanyID AND s.IsCancel = 0 AND s.ESICAmt > 0
        ORDER BY st.ESICNo;
    ELSE
        THROW 51903, 'ReturnType must be PF or ESIC.', 1;
END;
GO

/*==============================================================================
  CLIENT BILLING
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Invoice_Generate
    @CompanyID INT,
    @UserID    INT,
    @ClientID  INT,
    @Month     TINYINT,
    @Year      SMALLINT,
    @UnitID    INT = NULL,
    @GstPercent DECIMAL(5,2) = 18.00,
    @Bid       INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @From DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @To   DATE = EOMONTH(@From);
    DECLARE @InvoiceNo NVARCHAR(50), @Fy NVARCHAR(20), @BranchID INT,
            @Taxable DECIMAL(18,2) = 0, @IsInterState BIT = 0,
            @CompanyStateID INT, @ClientStateID INT;

    SET @Fy = CASE WHEN @Month >= 4
                   THEN CONCAT(@Year, N'-', RIGHT(CAST(@Year + 1 AS NVARCHAR(4)), 2))
                   ELSE CONCAT(@Year - 1, N'-', RIGHT(CAST(@Year AS NVARCHAR(4)), 2)) END;

    SELECT @CompanyStateID = StateID FROM org.Company WHERE CompanyID = @CompanyID;
    SELECT @ClientStateID = StateID, @BranchID = BranchID FROM crm.Client WHERE ClientID = @ClientID;
    SET @IsInterState = CASE WHEN @ClientStateID IS NOT NULL AND @CompanyStateID IS NOT NULL
                                  AND @ClientStateID <> @CompanyStateID THEN 1 ELSE 0 END;

    /* Guard clause and number allocation happen BEFORE the transaction opens.
       usp_Code_NextInvoiceNo takes sp_getapplock with LockOwner = 'Transaction' and
       rolls back on failure; calling it inside this transaction would let it destroy
       the caller's transaction. Same pattern as usp_Recruit_Convert. */
    IF EXISTS (SELECT 1 FROM fin.Invoice
               WHERE CompanyID = @CompanyID AND ClientID = @ClientID
                 AND Month = @Month AND Year = @Year AND IsCancel = 0
                 AND Status <> N'Draft')
        THROW 51904, 'A non-draft invoice already exists for this client and month.', 1;

    EXEC dbo.usp_Code_NextInvoiceNo @CompanyID = @CompanyID, @FinancialYear = @Fy,
                                    @InvoiceNo = @InvoiceNo OUTPUT;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM fin.InvoiceLine
        WHERE Bid IN (SELECT Bid FROM fin.Invoice
                      WHERE CompanyID = @CompanyID AND ClientID = @ClientID
                        AND Month = @Month AND Year = @Year AND Status = N'Draft');
        DELETE FROM fin.Invoice
        WHERE CompanyID = @CompanyID AND ClientID = @ClientID
          AND Month = @Month AND Year = @Year AND Status = N'Draft';

        INSERT INTO fin.Invoice (CompanyID, BranchID, ClientID, UnitID, Month, Year, InvoiceNo,
                                 InvoiceDate, DueDate, Status, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ClientID, @UnitID, @Month, @Year, @InvoiceNo,
                CAST(SYSDATETIME() AS DATE), DATEADD(DAY, 30, CAST(SYSDATETIME() AS DATE)),
                N'Draft', SYSDATETIME(), @UserID);

        SET @Bid = SCOPE_IDENTITY();

        /* man-days actually served, from approved attendance, priced per post */
        INSERT INTO fin.InvoiceLine (Bid, CompanyID, UnitID, PostID, DesignationName,
                                     ManDays, RatePerManDay, Amount, Description, HsnSac,
                                     SequenceNo, InsertDate, InsertUserID)
        SELECT @Bid, @CompanyID, x.UnitID, x.PostID, x.DesignationName,
               x.ManDays, x.Rate, ROUND(x.ManDays * x.Rate, 2),
               CONCAT(x.UnitName, N' - ', x.DesignationName, N' (', x.ManDays, N' man-days)'),
               N'998529',
               ROW_NUMBER() OVER (ORDER BY x.UnitName, x.DesignationName),
               SYSDATETIME(), @UserID
        FROM (
            SELECT a.UnitID, u.UnitName, a.PostID,
                   DesignationName = ISNULL(d.DesignationName, N'Security Guard'),
                   ManDays = SUM(CASE WHEN a.Status = 'P ' THEN 1.0
                                      WHEN a.Status = 'DS' THEN 2.0
                                      WHEN a.Status = 'HD' THEN 0.5 ELSE 0 END),
                   Rate = ISNULL(MAX(p.RatePerGuard), 0)
            FROM ops.Attendance AS a
            INNER JOIN crm.Unit AS u ON u.UnitID = a.UnitID
            LEFT  JOIN crm.UnitPost AS p ON p.PostID = a.PostID
            LEFT  JOIN hr.Employee AS e ON e.EmpID = a.EmpID
            LEFT  JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
            WHERE a.CompanyID = @CompanyID AND a.IsCancel = 0 AND a.ApprovalStatus = 1
              AND a.AttendanceDate BETWEEN @From AND @To
              AND u.ClientID = @ClientID
              AND (@UnitID IS NULL OR a.UnitID = @UnitID)
              AND ISNULL(e.IsNotBilling, 0) = 0
            GROUP BY a.UnitID, u.UnitName, a.PostID, d.DesignationName
        ) AS x
        WHERE x.ManDays > 0;

        SELECT @Taxable = ISNULL(SUM(Amount), 0) FROM fin.InvoiceLine WHERE Bid = @Bid;

        UPDATE fin.Invoice
        SET TaxableAmount = @Taxable,
            CgstAmt = CASE WHEN @IsInterState = 0 THEN ROUND(@Taxable * @GstPercent / 200.0, 2) ELSE 0 END,
            SgstAmt = CASE WHEN @IsInterState = 0 THEN ROUND(@Taxable * @GstPercent / 200.0, 2) ELSE 0 END,
            IgstAmt = CASE WHEN @IsInterState = 1 THEN ROUND(@Taxable * @GstPercent / 100.0, 2) ELSE 0 END,
            GrandTotal = @Taxable + CASE WHEN @IsInterState = 1
                                         THEN ROUND(@Taxable * @GstPercent / 100.0, 2)
                                         ELSE ROUND(@Taxable * @GstPercent / 200.0, 2) * 2 END,
            UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
        WHERE Bid = @Bid;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Bid,
           Message = CONCAT(N'Invoice ', @InvoiceNo, N' generated'),
           InvoiceNo = @InvoiceNo, TaxableAmount = @Taxable;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Invoice_GetList
    @CompanyID INT,
    @UserID    INT,
    @ClientID  INT = NULL,
    @Status    NVARCHAR(20) = NULL,
    @Year      SMALLINT = NULL,
    @OnlyOutstanding BIT = 0,
    @PageNo    INT = 1,
    @PageSize  INT = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 200 SET @PageSize = 200;
    IF @PageNo IS NULL OR @PageNo < 1 SET @PageNo = 1;

    SELECT Bid, InvoiceNo, InvoiceDate, DueDate, ClientID, ClientName, UnitID,
           GrandTotal, ReceivedAmount, OutstandingAmount, Status, DaysOverdue, AgeBucket
    FROM dbo.vwInvoiceAgeing
    WHERE CompanyID = @CompanyID
      AND (@ClientID IS NULL OR ClientID = @ClientID)
      AND (@Status   IS NULL OR Status = @Status)
      AND (@Year     IS NULL OR YEAR(InvoiceDate) = @Year)
      AND (@OnlyOutstanding = 0 OR OutstandingAmount > 0)
    ORDER BY InvoiceDate DESC
    OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;

    SELECT TotalRows = COUNT(*), TotalOutstanding = ISNULL(SUM(OutstandingAmount), 0)
    FROM dbo.vwInvoiceAgeing
    WHERE CompanyID = @CompanyID
      AND (@ClientID IS NULL OR ClientID = @ClientID)
      AND (@Status   IS NULL OR Status = @Status)
      AND (@Year     IS NULL OR YEAR(InvoiceDate) = @Year)
      AND (@OnlyOutstanding = 0 OR OutstandingAmount > 0);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Invoice_GetDetail
    @CompanyID INT, @UserID INT, @Bid INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT i.Bid, i.InvoiceNo, i.InvoiceDate, i.DueDate, i.Month, i.Year,
           i.TaxableAmount, i.CgstAmt, i.SgstAmt, i.IgstAmt, i.GrandTotal,
           i.ReceivedAmount, i.OutstandingAmount, i.Status, i.PdfUrl, i.SentOn,
           c.ClientName, c.CompanyAddress AS ClientAddress, c.GSTIN AS ClientGSTIN,
           co.CompanyName, co.CompanyAddress, co.GSTIN AS CompanyGSTIN, co.LogoUrl
    FROM fin.Invoice AS i
    INNER JOIN crm.Client  AS c  ON c.ClientID = i.ClientID
    INNER JOIN org.Company AS co ON co.CompanyID = i.CompanyID
    WHERE i.Bid = @Bid AND i.CompanyID = @CompanyID AND i.IsCancel = 0;

    SELECT l.LineID, l.SequenceNo, l.UnitID, u.UnitName, l.DesignationName,
           l.ManDays, l.RatePerManDay, l.Amount, l.Description, l.HsnSac
    FROM fin.InvoiceLine AS l
    LEFT JOIN crm.Unit AS u ON u.UnitID = l.UnitID
    WHERE l.Bid = @Bid AND l.CompanyID = @CompanyID
    ORDER BY l.SequenceNo;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Receipt_Insert
    @CompanyID INT,
    @UserID    INT,
    @ClientID  INT,
    @Amount    DECIMAL(18,2),
    @Bid       INT           = NULL,
    @ReceivedOn DATE         = NULL,
    @Mode      NVARCHAR(30)  = NULL,
    @RefNo     NVARCHAR(50)  = NULL,
    @Remark    NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Amount <= 0 THROW 51905, 'Receipt amount must be greater than zero.', 1;
    IF @ReceivedOn IS NULL SET @ReceivedOn = CAST(SYSDATETIME() AS DATE);

    DECLARE @ReceiptID INT, @BranchID INT, @Grand DECIMAL(18,2), @Received DECIMAL(18,2);
    SELECT @BranchID = BranchID FROM crm.Client WHERE ClientID = @ClientID;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO fin.Receipt (CompanyID, BranchID, ClientID, Bid, Amount, ReceivedOn,
                                 Mode, RefNo, Remark, InsertDate, InsertUserID)
        VALUES (@CompanyID, @BranchID, @ClientID, @Bid, @Amount, @ReceivedOn,
                @Mode, @RefNo, @Remark, SYSDATETIME(), @UserID);

        SET @ReceiptID = SCOPE_IDENTITY();

        IF @Bid IS NOT NULL
        BEGIN
            UPDATE fin.Invoice
            SET ReceivedAmount = ReceivedAmount + @Amount,
                UpdateDate = SYSDATETIME(), UpdateUserID = @UserID
            WHERE Bid = @Bid AND CompanyID = @CompanyID;

            SELECT @Grand = GrandTotal, @Received = ReceivedAmount FROM fin.Invoice WHERE Bid = @Bid;

            UPDATE fin.Invoice
            SET Status = CASE WHEN @Received >= @Grand THEN N'Paid' ELSE N'PartPaid' END
            WHERE Bid = @Bid;
        END

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @ReceiptID, Message = N'Receipt recorded';
END;
GO

PRINT '560_procedures_payroll.sql  ->  OK  (11 procedures)';
GO
