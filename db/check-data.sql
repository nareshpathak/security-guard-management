/*==============================================================================
  check-data.sql
  Two things looked odd after the seed filled in:
    1. the live turnout board reports ALL 12 units short of strength
    2. invoice DTI/2026-27/0006 has a taxable amount of 0.00
  This answers both without changing anything.

  Run:  sqlcmd -S localhost -E -I -d Diti365_Dev -i db\check-data.sql
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

PRINT '--- 1. required vs deployed, per unit ---';
SELECT  u.UnitCode,
        u.UnitName,
        Required = ISNULL(p.Req, 0),
        Deployed = ISNULL(d.Dep, 0),
        Gap      = ISNULL(p.Req, 0) - ISNULL(d.Dep, 0)
FROM crm.Unit AS u
OUTER APPLY (SELECT Req = SUM(up.RequiredStrength) FROM crm.UnitPost AS up
             WHERE up.UnitID = u.UnitID AND up.IsActive = 1) AS p
OUTER APPLY (SELECT Dep = COUNT(*) FROM ops.Deployment AS dp
             WHERE dp.UnitID = u.UnitID AND dp.Status = N'Active' AND dp.IsCancel = 0) AS d
WHERE u.CompanyID = @Diti
ORDER BY Gap DESC;

PRINT '';
PRINT '--- 2. what the turnout board actually sees today ---';
SELECT TOP (20) * FROM dbo.vwDailyTurnout
WHERE CompanyID = @Diti
ORDER BY UnitID;

PRINT '';
PRINT '--- 3. attendance recorded for today, by status ---';
SELECT  a.AttendanceDate,
        Status = a.Status,
        Rows   = COUNT(*),
        Approved = SUM(CAST(a.ApprovalStatus AS INT))
FROM ops.Attendance AS a
WHERE a.CompanyID = @Diti
  AND a.AttendanceDate >= DATEADD(DAY, -2, CAST(SYSDATETIME() AS DATE))
GROUP BY a.AttendanceDate, a.Status
ORDER BY a.AttendanceDate DESC, a.Status;

PRINT '';
PRINT '--- 4. every client: units, deployments, and the invoice raised ---';
SELECT  c.ClientName,
        Units       = (SELECT COUNT(*) FROM crm.Unit AS u WHERE u.ClientID = c.ClientID AND u.IsCancel = 0),
        Deployments = (SELECT COUNT(*) FROM ops.Deployment AS dp
                       INNER JOIN crm.Unit AS u2 ON u2.UnitID = dp.UnitID
                       WHERE u2.ClientID = c.ClientID AND dp.Status = N'Active' AND dp.IsCancel = 0),
        HasContract = (SELECT COUNT(*) FROM crm.Contract AS ct
                       WHERE ct.ClientID = c.ClientID AND ct.IsCancel = 0),
        i.InvoiceNo, i.TaxableAmount, i.GrandTotal, i.Status
FROM crm.Client AS c
LEFT JOIN fin.Invoice AS i ON i.ClientID = c.ClientID AND i.IsCancel = 0
WHERE c.CompanyID = @Diti
ORDER BY i.TaxableAmount;

PRINT '';
PRINT '--- 5. the zero-value invoice, line by line ---';
SELECT i.InvoiceNo, il.*
FROM fin.Invoice AS i
LEFT JOIN fin.InvoiceDetail AS il ON il.Bid = i.Bid
WHERE i.CompanyID = @Diti AND i.TaxableAmount = 0;
GO
