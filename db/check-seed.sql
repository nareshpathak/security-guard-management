/*  Why are patrol scans, invoices and salary rows empty?
    Run:  sqlcmd -S localhost -E -I -d Diti365_Dev -i db\check-seed.sql   */
SET NOCOUNT ON;
GO
PRINT '--- row counts ---';
SELECT 'Employee'        AS T, COUNT(*) AS N FROM hr.Employee
UNION ALL SELECT 'Deployment',        COUNT(*) FROM ops.Deployment
UNION ALL SELECT 'Attendance',        COUNT(*) FROM ops.Attendance
UNION ALL SELECT 'Attendance approved',COUNT(*) FROM ops.Attendance WHERE ApprovalStatus = 1
UNION ALL SELECT 'QrCheckpoint',      COUNT(*) FROM ops.QrCheckpoint
UNION ALL SELECT 'PatrolRound',       COUNT(*) FROM ops.PatrolRound
UNION ALL SELECT 'PatrolRoundCheckpt',COUNT(*) FROM ops.PatrolRoundCheckpoint
UNION ALL SELECT 'QrScanLog',         COUNT(*) FROM ops.QrScanLog
UNION ALL SELECT 'LocationLog',       COUNT(*) FROM ops.LocationLog
UNION ALL SELECT 'SalaryStructure',   COUNT(*) FROM fin.SalaryStructure
UNION ALL SELECT 'SalaryRun',         COUNT(*) FROM fin.SalaryRun
UNION ALL SELECT 'Salary',            COUNT(*) FROM fin.Salary
UNION ALL SELECT 'Invoice',           COUNT(*) FROM fin.Invoice
UNION ALL SELECT 'UnitPost',          COUNT(*) FROM crm.UnitPost
UNION ALL SELECT 'Night deployments', COUNT(*) FROM ops.Deployment d
                                      JOIN mst.Shift s ON s.ShiftID = d.ShiftID WHERE s.IsNight = 1;
GO
PRINT '';
PRINT '--- would payroll find anything for last month? ---';
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @M CHAR(7) = CONVERT(CHAR(7), DATEADD(MONTH, -1, SYSDATETIME()), 126);
SELECT MonthYear = @M,
       EmployeesWithApprovedAttendance =
           (SELECT COUNT(DISTINCT EmpID) FROM ops.Attendance
            WHERE CompanyID = @Diti AND ApprovalStatus = 1
              AND CONVERT(CHAR(7), AttendanceDate, 126) = @M),
       EmployeesWithSalaryStructure =
           (SELECT COUNT(*) FROM fin.SalaryStructure WHERE CompanyID = @Diti AND IsCancel = 0),
       EarliestAttendance = (SELECT MIN(AttendanceDate) FROM ops.Attendance WHERE CompanyID = @Diti),
       LatestAttendance   = (SELECT MAX(AttendanceDate) FROM ops.Attendance WHERE CompanyID = @Diti);
GO
PRINT '';
PRINT '--- attendance by month ---';
SELECT MonthYear = CONVERT(CHAR(7), AttendanceDate, 126),
       Rows = COUNT(*),
       Approved = SUM(CASE WHEN ApprovalStatus = 1 THEN 1 ELSE 0 END)
FROM ops.Attendance GROUP BY CONVERT(CHAR(7), AttendanceDate, 126) ORDER BY 1;
GO
