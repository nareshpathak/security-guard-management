/*==============================================================================
  710_seed_demo_tenant.sql
  Two demo agencies with branches, users, clients, units, posts, employees,
  salary structures, QR checkpoints, patrol rounds and opening uniform stock.
  Spec: docs/prd/01-database.md §8.2

  PASSWORDS
  ---------
  PBKDF2 cannot be computed in T-SQL, so seeded users carry
      LegacyPasswordHash = 'PLAINTEXT:<password>'
  The API's legacy-migration path accepts this prefix ONLY when
  ASPNETCORE_ENVIRONMENT = Development, and immediately re-hashes with PBKDF2 on
  first successful login. It must never be enabled in staging or production.
  See DECISIONS.md #25.

  Demo logins - password Admin@123 for all:
      superadmin            SUPER_ADMIN (platform)
      diti.admin            COMPANY_ADMIN  (Diti Security Services)
      diti.ops / diti.hr / diti.accounts
      diti.sup1 / diti.sup2 / diti.sup3
      diti.sales1 / diti.gate1 / diti.patrol1
      shield.admin          COMPANY_ADMIN  (Shield Force - isolation test tenant)

  Idempotent: keyed on CompanyCode / UserName / natural keys.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @DelhiState INT = (SELECT StateID FROM mst.State WHERE StateName = N'Delhi');
DECLARE @MahaState  INT = (SELECT StateID FROM mst.State WHERE StateName = N'Maharashtra');
DECLARE @NewDelhi   INT = (SELECT CityID  FROM mst.City  WHERE CityName  = N'New Delhi');
DECLARE @Pune       INT = (SELECT CityID  FROM mst.City  WHERE CityName  = N'Pune');
DECLARE @Noida      INT = (SELECT CityID  FROM mst.City  WHERE CityName  = N'Noida');
DECLARE @Gurugram   INT = (SELECT CityID  FROM mst.City  WHERE CityName  = N'Gurugram');

/*==============================================================================
  PLANS
==============================================================================*/
MERGE org.[Plan] AS t
USING (VALUES
    (N'Starter',      25,  10,  99.00),
    (N'Professional',100,  60, 149.00),
    (N'Enterprise',  500, 300, 199.00)
) AS s(PlanName, MaxUsers, MaxUnits, PricePerUserMonth)
   ON t.PlanName = s.PlanName
WHEN NOT MATCHED BY TARGET THEN
    INSERT (PlanName, MaxUsers, MaxUnits, PricePerUserMonth)
    VALUES (s.PlanName, s.MaxUsers, s.MaxUnits, s.PricePerUserMonth);
GO

/*==============================================================================
  COMPANIES
==============================================================================*/
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @ProPlan INT = (SELECT PlanID FROM org.[Plan] WHERE PlanName = N'Professional');
DECLARE @StartPlan INT = (SELECT PlanID FROM org.[Plan] WHERE PlanName = N'Starter');

IF NOT EXISTS (SELECT 1 FROM org.Company WHERE CompanyCode = N'DTI')
    INSERT INTO org.Company (CompanyName, CompanyCode, CompanyAddress, CityID, StateID, Pin,
                             Mobile, Email, GSTIN, PAN, PFCode, ESICCode, LicenceNo, LicenceExpiry,
                             ThemeColor, PlanID, MaxUsers, ExpiryDate, IsActive)
    SELECT N'Diti Security Services Pvt Ltd', N'DTI',
           N'B-42, Okhla Industrial Area Phase II, New Delhi', c.CityID, s.StateID, N'110020',
           N'9811000001', N'ops@ditisecurity.example', N'07AABCD1234E1Z5', N'AABCD1234E',
           N'DLCPM0012345000', N'11000123450000199', N'PSARA/DL/2019/0456',
           DATEADD(YEAR, 2, @Today), N'#0B5FFF', @ProPlan, 100, DATEADD(YEAR, 1, @Today), 1
    FROM mst.City AS c CROSS JOIN mst.State AS s
    WHERE c.CityName = N'New Delhi' AND s.StateName = N'Delhi';

IF NOT EXISTS (SELECT 1 FROM org.Company WHERE CompanyCode = N'SFS')
    INSERT INTO org.Company (CompanyName, CompanyCode, CompanyAddress, CityID, StateID, Pin,
                             Mobile, Email, GSTIN, PAN, ThemeColor, PlanID, MaxUsers, ExpiryDate, IsActive)
    SELECT N'Shield Force Security', N'SFS',
           N'12, Baner Road, Pune', c.CityID, s.StateID, N'411045',
           N'9822000002', N'admin@shieldforce.example', N'27AABCS5678F1Z2', N'AABCS5678F',
           N'#00C2A8', @StartPlan, 25, DATEADD(YEAR, 1, @Today), 1
    FROM mst.City AS c CROSS JOIN mst.State AS s
    WHERE c.CityName = N'Pune' AND s.StateName = N'Maharashtra';
GO

/*==============================================================================
  BRANCHES
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Shield INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'SFS');

MERGE org.Branch AS t
USING (VALUES
    (@Diti,   N'Head Office - Delhi', N'DTI-HO',  N'B-42, Okhla Phase II, New Delhi', N'110020', 1),
    (@Diti,   N'Noida Branch',        N'DTI-NOI', N'A-15, Sector 63, Noida',          N'201301', 0),
    (@Diti,   N'Gurugram Branch',     N'DTI-GGN', N'Plot 9, Udyog Vihar Phase IV',    N'122015', 0),
    (@Shield, N'Pune Head Office',    N'SFS-HO',  N'12, Baner Road, Pune',            N'411045', 1)
) AS s(CompanyID, BranchName, BranchCode, Address, Pin, IsHeadOffice)
   ON t.CompanyID = s.CompanyID AND t.BranchName = s.BranchName
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, BranchName, BranchCode, Address, Pin, IsHeadOffice)
    VALUES (s.CompanyID, s.BranchName, s.BranchCode, s.Address, s.Pin, s.IsHeadOffice);
GO

/*==============================================================================
  COMPANY SETTINGS
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Shield INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'SFS');

MERGE org.CompanySetting AS t
USING (
    SELECT c.CompanyID, v.SettingKey, v.SettingValue, v.DataType, v.Description
    FROM org.Company AS c
    CROSS JOIN (VALUES
        (N'GeofenceRadiusMeters', N'150',   N'int',  N'Default punch radius for a new unit'),
        (N'SelfieMandatory',      N'true',  N'bool', N'Require a selfie on punch in and out'),
        (N'AutoAbsentEnabled',    N'true',  N'bool', N'Auto-mark absent after shift end plus grace'),
        (N'PatrolGraceMinutes',   N'15',    N'int',  N'Grace after a round window closes'),
        (N'ComplaintDefaultSla',  N'24',    N'int',  N'Default SLA hours for a complaint'),
        (N'OtEnabled',            N'true',  N'bool', N'Pay overtime beyond full-day hours'),
        (N'BackgroundTrackingMinutes', N'2', N'int', N'Location ping interval while on duty'),
        (N'MockLocationBlock',    N'true',  N'bool', N'Reject punches and scans from mocked GPS')
    ) AS v(SettingKey, SettingValue, DataType, Description)
    WHERE c.CompanyCode IN (N'DTI', N'SFS')
) AS s
   ON t.CompanyID = s.CompanyID AND t.SettingKey = s.SettingKey
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, SettingKey, SettingValue, DataType, Description)
    VALUES (s.CompanyID, s.SettingKey, s.SettingValue, s.DataType, s.Description);

MERGE org.CompanyModule AS t
USING (
    SELECT c.CompanyID, m.ModuleCode
    FROM org.Company AS c
    CROSS JOIN (VALUES (N'M1'),(N'M2'),(N'M3'),(N'M4'),(N'M5'),(N'M6'),(N'M7'),(N'M8'),
                       (N'M9'),(N'M10'),(N'M11'),(N'M12'),(N'M13'),(N'M14'),(N'M15'),(N'M16')) AS m(ModuleCode)
    WHERE c.CompanyCode IN (N'DTI', N'SFS')
) AS s
   ON t.CompanyID = s.CompanyID AND t.ModuleCode = s.ModuleCode
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, ModuleCode, IsEnabled) VALUES (s.CompanyID, s.ModuleCode, 1);
GO

/*==============================================================================
  CLIENTS AND UNITS  (real Delhi-NCR coordinates)
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @HO   INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-HO');
DECLARE @NOI  INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-NOI');
DECLARE @GGN  INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-GGN');
DECLARE @DL   INT = (SELECT StateID FROM mst.State WHERE StateName = N'Delhi');

MERGE crm.Client AS t
USING (VALUES
    (@Diti, @HO,  N'Meridian Hotels Ltd',        N'CL001', N'Sardar Patel Marg, New Delhi',  N'9811100011'),
    (@Diti, @HO,  N'Apex Corporate Towers',      N'CL002', N'Nehru Place, New Delhi',        N'9811100012'),
    (@Diti, @NOI, N'Sunrise Manufacturing Pvt',  N'CL003', N'Sector 63, Noida',              N'9811100013'),
    (@Diti, @NOI, N'Greenfield Residency AOA',   N'CL004', N'Sector 137, Noida',             N'9811100014'),
    (@Diti, @GGN, N'Nexus Retail Mall',          N'CL005', N'MG Road, Gurugram',             N'9811100015'),
    (@Diti, @GGN, N'Orbit Data Centre',          N'CL006', N'Udyog Vihar, Gurugram',         N'9811100016')
) AS s(CompanyID, BranchID, ClientName, ClientCode, CompanyAddress, ContactNo)
   ON t.CompanyID = s.CompanyID AND t.ClientCode = s.ClientCode
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, BranchID, ClientName, ClientCode, CompanyAddress, ContactNo, StateID)
    VALUES (s.CompanyID, s.BranchID, s.ClientName, s.ClientCode, s.CompanyAddress, s.ContactNo, @DL);
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

MERGE crm.Unit AS t
USING (
    SELECT c.CompanyID, c.BranchID, c.ClientID, v.UnitName, v.UnitCode,
           v.Address, v.Latitude, v.Longitude, v.Radius
    FROM (VALUES
        (N'CL001', N'Meridian Hotel - Main Gate',   N'U001', N'Sardar Patel Marg, New Delhi', 28.5946000, 77.1795000, 120),
        (N'CL001', N'Meridian Hotel - Back Gate',   N'U002', N'Sardar Patel Marg, New Delhi', 28.5951000, 77.1802000, 100),
        (N'CL002', N'Apex Towers - Tower A',        N'U003', N'Nehru Place, New Delhi',       28.5494000, 77.2501000, 150),
        (N'CL002', N'Apex Towers - Tower B',        N'U004', N'Nehru Place, New Delhi',       28.5499000, 77.2510000, 150),
        (N'CL003', N'Sunrise Plant - Gate 1',       N'U005', N'Sector 63, Noida',             28.6270000, 77.3810000, 200),
        (N'CL003', N'Sunrise Plant - Gate 2',       N'U006', N'Sector 63, Noida',             28.6281000, 77.3825000, 200),
        (N'CL003', N'Sunrise Warehouse',            N'U007', N'Sector 63, Noida',             28.6295000, 77.3840000, 180),
        (N'CL004', N'Greenfield Residency',         N'U008', N'Sector 137, Noida',            28.5045000, 77.4020000, 250),
        (N'CL005', N'Nexus Mall - Main Entrance',   N'U009', N'MG Road, Gurugram',            28.4801000, 77.0805000, 150),
        (N'CL005', N'Nexus Mall - Parking',         N'U010', N'MG Road, Gurugram',            28.4795000, 77.0815000, 200),
        (N'CL006', N'Orbit DC - Perimeter',         N'U011', N'Udyog Vihar, Gurugram',        28.5010000, 77.0870000, 180),
        (N'CL006', N'Orbit DC - Server Floor',      N'U012', N'Udyog Vihar, Gurugram',        28.5012000, 77.0873000,  80)
    ) AS v(ClientCode, UnitName, UnitCode, Address, Latitude, Longitude, Radius)
    INNER JOIN crm.Client AS c ON c.ClientCode = v.ClientCode AND c.CompanyID = @Diti
) AS s
   ON t.CompanyID = s.CompanyID AND t.UnitCode = s.UnitCode
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, BranchID, ClientID, UnitName, UnitCode, Address, Latitude, Longitude,
            GeofenceRadiusMeters, AgreementNo, AgreementExpDate, OrderNo, OrderDate,
            OrderExpiryDate, WorkStartDate)
    VALUES (s.CompanyID, s.BranchID, s.ClientID, s.UnitName, s.UnitCode, s.Address,
            s.Latitude, s.Longitude, s.Radius,
            CONCAT(N'AGR/', s.UnitCode), DATEADD(MONTH, 8, @Today),
            CONCAT(N'WO/', s.UnitCode),  DATEADD(MONTH, -10, @Today),
            DATEADD(MONTH, 14, @Today),  DATEADD(MONTH, -10, @Today));
GO

/*  posts: what the client contracted for, per shift  */
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

MERGE crm.UnitPost AS t
USING (
    SELECT u.CompanyID, u.UnitID, v.PostName, d.DesignationID, sh.ShiftID, v.Strength, v.Rate, v.IsArmed
    FROM (VALUES
        (N'U001', N'Main Gate - Day',    N'Security Guard', N'Day',     3, 1100.00, 0),
        (N'U001', N'Main Gate - Night',  N'Security Guard', N'Night',   2, 1200.00, 0),
        (N'U002', N'Back Gate - Day',    N'Security Guard', N'Day',     2, 1100.00, 0),
        (N'U003', N'Lobby - Day',        N'Security Guard', N'Day',     4, 1050.00, 0),
        (N'U003', N'Lobby - Night',      N'Security Guard', N'Night',   2, 1150.00, 0),
        (N'U004', N'Lobby - Day',        N'Security Guard', N'Day',     3, 1050.00, 0),
        (N'U005', N'Gate 1 - Day',       N'Security Guard', N'Day',     4, 1000.00, 0),
        (N'U005', N'Gate 1 - Night',     N'Security Guard', N'Night',   3, 1100.00, 0),
        (N'U006', N'Gate 2 - Day',       N'Security Guard', N'Day',     2, 1000.00, 0),
        (N'U007', N'Warehouse - Night',  N'Gunman',         N'Night',   2, 1800.00, 1),
        (N'U008', N'Society Gate - Day', N'Security Guard', N'Day',     3,  950.00, 0),
        (N'U008', N'Society Gate - Night',N'Security Guard',N'Night',   2, 1050.00, 0),
        (N'U009', N'Entrance - Day',     N'Security Guard', N'Day',     5, 1150.00, 0),
        (N'U010', N'Parking - Day',      N'Security Guard', N'Day',     3, 1000.00, 0),
        (N'U011', N'Perimeter - Day',    N'Security Guard', N'Day',     3, 1250.00, 0),
        (N'U011', N'Perimeter - Night',  N'Gunman',         N'Night',   2, 1900.00, 1),
        (N'U012', N'Server Floor - Day', N'Security Officer',N'General',1, 2200.00, 0)
    ) AS v(UnitCode, PostName, DesignationName, ShiftName, Strength, Rate, IsArmed)
    INNER JOIN crm.Unit AS u ON u.UnitCode = v.UnitCode AND u.CompanyID = @Diti
    INNER JOIN mst.Designation AS d ON d.DesignationName = v.DesignationName AND d.CompanyID IS NULL
    INNER JOIN mst.Shift AS sh ON sh.ShiftName = v.ShiftName AND sh.CompanyID IS NULL
) AS s
   ON t.UnitID = s.UnitID AND t.PostName = s.PostName
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, UnitID, PostName, DesignationID, ShiftID, RequiredStrength, RatePerGuard, IsArmed)
    VALUES (s.CompanyID, s.UnitID, s.PostName, s.DesignationID, s.ShiftID, s.Strength, s.Rate, s.IsArmed);
GO

/*==============================================================================
  EMPLOYEES  (40 for Diti, deterministic)
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @HO INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-HO');

IF (SELECT COUNT(*) FROM hr.Employee WHERE CompanyID = @Diti) < 40
BEGIN
    ;WITH nums AS (
        SELECT TOP (40) n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
        FROM sys.all_objects
    ),
    firsts AS (SELECT i, v FROM (VALUES
        (1,N'Ramesh'),(2,N'Suresh'),(3,N'Mahesh'),(4,N'Rajesh'),(5,N'Dinesh'),
        (6,N'Mukesh'),(7,N'Naresh'),(8,N'Ganesh'),(9,N'Jitendra'),(10,N'Vijay'),
        (11,N'Ajay'),(12,N'Sanjay'),(13,N'Amit'),(14,N'Sumit'),(15,N'Rohit'),
        (16,N'Mohit'),(17,N'Deepak'),(18,N'Pankaj'),(19,N'Manoj'),(20,N'Anil')
    ) AS x(i, v)),
    lasts AS (SELECT i, v FROM (VALUES
        (1,N'Kumar'),(2,N'Singh'),(3,N'Yadav'),(4,N'Sharma'),(5,N'Verma'),
        (6,N'Gupta'),(7,N'Pandey'),(8,N'Mishra'),(9,N'Tiwari'),(10,N'Chauhan')
    ) AS x(i, v))
    INSERT INTO hr.Employee (CompanyID, BranchID, EmpCode, FirstName, LastName, Gender, Dob,
                             Bloodgroup, Nationality, Married, Mobile1, DesignationID, CategoryID,
                             ShiftID, Doj, BeltNo, IdCardNo, IdCardIssueDate, IdCardExpireDate,
                             EmpStatus, IsGunman, IsReliever, IsExService, IsApproved)
    SELECT
        @Diti, @HO,
        N'DTI' + RIGHT(N'00000' + CAST(n.n AS NVARCHAR(10)), 5),
        f.v, l.v,
        CASE WHEN n.n % 10 = 0 THEN N'Female' ELSE N'Male' END,
        DATEADD(YEAR, -(22 + (n.n % 20)), DATEADD(DAY, -(n.n * 7), @Today)),
        CASE n.n % 8 WHEN 0 THEN N'O+' WHEN 1 THEN N'A+' WHEN 2 THEN N'B+' WHEN 3 THEN N'AB+'
                     WHEN 4 THEN N'O-' WHEN 5 THEN N'A-' WHEN 6 THEN N'B-' ELSE N'AB-' END,
        N'Indian',
        CASE WHEN n.n % 3 = 0 THEN 1 ELSE 0 END,
        N'98' + RIGHT(N'00000000' + CAST(11000000 + n.n * 137 AS NVARCHAR(10)), 8),
        d.DesignationID,
        (SELECT CategoryID FROM mst.Category WHERE CategoryName = N'Semi-skilled' AND CompanyID IS NULL),
        sh.ShiftID,
        DATEADD(DAY, -(90 + n.n * 11), @Today),
        N'BLT' + RIGHT(N'000' + CAST(n.n AS NVARCHAR(10)), 3),
        N'IDC' + RIGHT(N'000' + CAST(n.n AS NVARCHAR(10)), 3),
        DATEADD(DAY, -(90 + n.n * 11), @Today),
        DATEADD(YEAR, 3, DATEADD(DAY, -(90 + n.n * 11), @Today)),
        N'Active',
        CASE WHEN n.n % 10 = 7 THEN 1 ELSE 0 END,    -- 4 gunmen
        CASE WHEN n.n % 9  = 0 THEN 1 ELSE 0 END,    -- 4 relievers
        CASE WHEN n.n % 7  = 0 THEN 1 ELSE 0 END,
        1
    FROM nums AS n
    INNER JOIN firsts AS f ON f.i = ((n.n - 1) % 20) + 1
    INNER JOIN lasts  AS l ON l.i = ((n.n - 1) % 10) + 1
    INNER JOIN mst.Designation AS d
            ON d.CompanyID IS NULL
           AND d.DesignationName = CASE WHEN n.n % 10 = 7 THEN N'Gunman'
                                        WHEN n.n % 12 = 0 THEN N'Supervisor'
                                        WHEN n.n % 15 = 0 THEN N'Head Guard'
                                        ELSE N'Security Guard' END
    INNER JOIN mst.Shift AS sh
            ON sh.CompanyID IS NULL
           AND sh.ShiftName = CASE WHEN n.n % 3 = 0 THEN N'Night' ELSE N'Day' END;
END
GO

/*  satellites for every seeded employee  */
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @DL INT = (SELECT StateID FROM mst.State WHERE StateName = N'Delhi');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

INSERT INTO hr.EmployeeStatutory (EmpID, CompanyID, AdharCardNo, PanCardNo, UANNo, ESICNo, PaymentMode)
SELECT e.EmpID, e.CompanyID,
       RIGHT(N'000000000000' + CAST(200000000000 + e.EmpID * 977 AS NVARCHAR(12)), 12),
       N'ABCPD' + RIGHT(N'0000' + CAST(1000 + e.EmpID AS NVARCHAR(4)), 4) + N'K',
       RIGHT(N'000000000000' + CAST(100000000000 + e.EmpID * 313 AS NVARCHAR(12)), 12),
       RIGHT(N'0000000000' + CAST(3100000000 + e.EmpID * 71 AS NVARCHAR(10)), 10),
       N'Bank Transfer'
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeStatutory AS s WHERE s.EmpID = e.EmpID);

INSERT INTO hr.EmployeeAddress (CompanyID, EmpID, AddressType, Address1, City, StateID, Pin, Telephone)
SELECT e.CompanyID, e.EmpID, 'P',
       CONCAT(N'H.No ', e.EmpID, N', Village Rampur, Post Sultanpur'), N'Sultanpur', @DL, N'110030', e.Mobile1
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeAddress AS a WHERE a.EmpID = e.EmpID AND a.AddressType = 'P');

INSERT INTO hr.EmployeeAddress (CompanyID, EmpID, AddressType, Address1, City, StateID, Pin, Telephone)
SELECT e.CompanyID, e.EmpID, 'R',
       CONCAT(N'Room ', e.EmpID, N', Guard Barrack, Okhla Phase II'), N'New Delhi', @DL, N'110020', e.Mobile1
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeAddress AS a WHERE a.EmpID = e.EmpID AND a.AddressType = 'R');

INSERT INTO hr.EmployeeFamily (CompanyID, EmpID, Relation, Name, Dependent)
SELECT e.CompanyID, e.EmpID, N'Father', CONCAT(N'Late Shri ', e.LastName, N' Prasad'), 0
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeFamily AS f WHERE f.EmpID = e.EmpID AND f.Relation = N'Father');

INSERT INTO hr.EmployeeBank (CompanyID, EmpID, IsJoint, BankID, BankName, BranchName,
                             BankAcNo, IFSCcode, AcType, NameInBankPassbook, IsBankAdded, BankAddedDate)
SELECT e.CompanyID, e.EmpID, 0, b.BankID, b.BankName, N'Okhla Industrial Area',
       RIGHT(N'00000000000' + CAST(30000000000 + e.EmpID * 4111 AS NVARCHAR(11)), 11),
       N'SBIN0001234', N'Savings', e.EmpFullName, 1, SYSDATETIME()
FROM hr.Employee AS e
CROSS APPLY (SELECT TOP (1) BankID, BankName FROM mst.Bank WHERE BankName = N'State Bank of India') AS b
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeBank AS k WHERE k.EmpID = e.EmpID AND k.IsJoint = 0);

INSERT INTO hr.EmployeeVerification (EmpID, CompanyID, IsPoliceVerification, PoliceVerificationNo,
                                     PoliceStationName, Pvsenddate, Pvreturndate, PVValidUpTo, VerificationDate)
SELECT e.EmpID, e.CompanyID,
       CASE WHEN e.EmpID % 8 = 0 THEN 0 ELSE 1 END,
       CASE WHEN e.EmpID % 8 = 0 THEN NULL ELSE CONCAT(N'PV/2025/', e.EmpID) END,
       N'PS Okhla Industrial Area',
       DATEADD(DAY, -100, @Today),
       CASE WHEN e.EmpID % 8 = 0 THEN NULL ELSE DATEADD(DAY, -70, @Today) END,
       CASE WHEN e.EmpID % 8 = 0 THEN NULL
            WHEN e.EmpID % 11 = 0 THEN DATEADD(DAY, 20, @Today)   -- a few expiring soon
            ELSE DATEADD(YEAR, 2, @Today) END,
       CASE WHEN e.EmpID % 8 = 0 THEN NULL ELSE DATEADD(DAY, -70, @Today) END
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeVerification AS v WHERE v.EmpID = e.EmpID);

INSERT INTO hr.EmployeePhysical (EmpID, CompanyID, Height, Weight, Chest, Shoesize, TshirtSize, Trousersize)
SELECT e.EmpID, e.CompanyID,
       CAST(165 + (e.EmpID % 15) AS NVARCHAR(20)), CAST(58 + (e.EmpID % 20) AS NVARCHAR(20)),
       CAST(84 + (e.EmpID % 10) AS NVARCHAR(20)),
       CAST(7 + (e.EmpID % 4) AS NVARCHAR(10)),
       CASE e.EmpID % 4 WHEN 0 THEN N'M' WHEN 1 THEN N'L' WHEN 2 THEN N'XL' ELSE N'XXL' END,
       CAST(30 + (e.EmpID % 8) AS NVARCHAR(10))
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeePhysical AS p WHERE p.EmpID = e.EmpID);

INSERT INTO hr.EmployeeGunLicence (EmpID, CompanyID, GunanType, TypeArm, GunNo, LicenseNo, Licenseexpire, IssueDate)
SELECT e.EmpID, e.CompanyID, N'Armed Guard', N'12 Bore DBBL',
       CONCAT(N'GUN/', e.EmpID), CONCAT(N'ARMS/DL/', 2024, N'/', e.EmpID),
       DATEADD(YEAR, 2, @Today), DATEADD(YEAR, -1, @Today)
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti AND e.IsGunman = 1
  AND NOT EXISTS (SELECT 1 FROM hr.EmployeeGunLicence AS g WHERE g.EmpID = e.EmpID);
GO

/*==============================================================================
  SALARY STRUCTURES
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

INSERT INTO fin.SalaryStructure (CompanyID, EmpID, EffectiveFrom, BasicWages, HRAAmt, FoodAllow,
                                 LeaveAllow, ReliverAllow, SpAllowance, OtRatePerHour,
                                 IsPfApplicable, IsEsicApplicable, IsPtApplicable, IsLwfApplicable)
SELECT e.CompanyID, e.EmpID, DATEADD(MONTH, -6, DATEFROMPARTS(YEAR(SYSDATETIME()), MONTH(SYSDATETIME()), 1)),
       CASE WHEN e.IsGunman = 1 THEN 15600.00 ELSE 12400.00 END,
       CASE WHEN e.IsGunman = 1 THEN  3120.00 ELSE  2480.00 END,
       1200.00, 800.00,
       CASE WHEN e.IsReliever = 1 THEN 1000.00 ELSE 0 END,
       CASE WHEN e.IsGunman = 1 THEN 1500.00 ELSE 600.00 END,
       75.00, 1, 1, 1, 1
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti
  AND NOT EXISTS (SELECT 1 FROM fin.SalaryStructure AS s WHERE s.EmpID = e.EmpID);
GO

/*==============================================================================
  DEPLOYMENT  (fill each post to contracted strength where employees allow)
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);

IF NOT EXISTS (SELECT 1 FROM ops.Deployment WHERE CompanyID = @Diti)
BEGIN
    ;WITH slots AS (
        SELECT p.PostID, p.UnitID, u.BranchID, p.ShiftID, p.DesignationID, p.IsArmed,
               Slot = v.n,
               rn = ROW_NUMBER() OVER (ORDER BY p.PostID, v.n)
        FROM crm.UnitPost AS p
        INNER JOIN crm.Unit AS u ON u.UnitID = p.UnitID
        CROSS APPLY (SELECT TOP (p.RequiredStrength) n = ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
                     FROM sys.all_objects) AS v
        WHERE p.CompanyID = @Diti AND p.IsActive = 1
    ),
    emps AS (
        SELECT e.EmpID, e.IsGunman,
               rn = ROW_NUMBER() OVER (ORDER BY e.IsGunman DESC, e.EmpID)
        FROM hr.Employee AS e
        WHERE e.CompanyID = @Diti AND e.EmpStatus = N'Active' AND e.IsReliever = 0
    )
    INSERT INTO ops.Deployment (CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID, DesignationID,
                                FromDate, Status, IsApproved)
    SELECT @Diti, s.BranchID, s.UnitID, s.PostID, e.EmpID, s.ShiftID, s.DesignationID,
           DATEADD(DAY, -60, @Today), N'Active', 1
    FROM slots AS s
    INNER JOIN emps AS e ON e.rn = s.rn;

    UPDATE e
    SET e.UnitID = d.UnitID, e.Clientid = u.ClientID, e.ShiftID = d.ShiftID,
        e.DoDeployment = d.FromDate
    FROM hr.Employee AS e
    INNER JOIN ops.Deployment AS d ON d.EmpID = e.EmpID AND d.Status = N'Active'
    INNER JOIN crm.Unit AS u ON u.UnitID = d.UnitID
    WHERE e.CompanyID = @Diti;
END
GO

/*==============================================================================
  SUPERVISORS ON UNITS
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

;WITH sup AS (
    SELECT e.EmpID, rn = ROW_NUMBER() OVER (ORDER BY e.EmpID)
    FROM hr.Employee AS e
    INNER JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    WHERE e.CompanyID = @Diti AND d.DesignationName IN (N'Supervisor', N'Head Guard')
),
un AS (
    SELECT UnitID, rn = ((ROW_NUMBER() OVER (ORDER BY UnitID) - 1) % 3) + 1
    FROM crm.Unit WHERE CompanyID = @Diti
)
UPDATE u
SET u.SupervisorEmpID = s.EmpID
FROM crm.Unit AS u
INNER JOIN un  ON un.UnitID = u.UnitID
INNER JOIN sup AS s ON s.rn = un.rn
WHERE u.CompanyID = @Diti AND u.SupervisorEmpID IS NULL;
GO

/*==============================================================================
  USERS
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Shield INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'SFS');
DECLARE @HO INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-HO');
DECLARE @SfsHO INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Shield AND BranchCode = N'SFS-HO');
DECLARE @Pw NVARCHAR(500) = N'PLAINTEXT:Admin@123';

MERGE sec.Users AS t
USING (VALUES
    (CAST(NULL AS INT), CAST(NULL AS INT), N'superadmin',   N'9999900000', N'SUPER_ADMIN',    1),
    (@Diti,   @HO,    N'diti.admin',    N'9811000101', N'COMPANY_ADMIN', 2),
    (@Diti,   @HO,    N'diti.ops',      N'9811000102', N'OPERATIONS',    9),
    (@Diti,   @HO,    N'diti.hr',       N'9811000103', N'HR',            10),
    (@Diti,   @HO,    N'diti.accounts', N'9811000104', N'ACCOUNTS',      11),
    (@Diti,   @HO,    N'diti.sup1',     N'9811000105', N'SUPERVISOR',    3),
    (@Diti,   @HO,    N'diti.sup2',     N'9811000106', N'SUPERVISOR',    3),
    (@Diti,   @HO,    N'diti.sup3',     N'9811000107', N'SUPERVISOR',    3),
    (@Diti,   @HO,    N'diti.sales1',   N'9811000108', N'SALES',         6),
    (@Diti,   @HO,    N'diti.gate1',    N'9811000109', N'GATEKEEPER',    4),
    (@Diti,   @HO,    N'diti.patrol1',  N'9811000110', N'NIGHT_PATROL',  5),
    (@Shield, @SfsHO, N'shield.admin',  N'9822000201', N'COMPANY_ADMIN', 2)
) AS s(CompanyID, BranchID, UserName, MobileNo, RoleCode, LoginType)
   ON t.UserName = s.UserName
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, BranchID, UserName, MobileNo, LegacyPasswordHash, MustChangePassword,
            RoleID, LoginType, IsActive, IsApproved)
    VALUES (s.CompanyID, s.BranchID, s.UserName, s.MobileNo, @Pw, 0,
            (SELECT RoleID FROM sec.Role WHERE RoleCode = s.RoleCode AND CompanyID IS NULL),
            s.LoginType, 1, 1);
GO

/*  link supervisor logins to real employee records, and give every guard a login */
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Pw NVARCHAR(500) = N'PLAINTEXT:Guard@123';
DECLARE @EmpRole INT = (SELECT RoleID FROM sec.Role WHERE RoleCode = N'EMPLOYEE' AND CompanyID IS NULL);

;WITH sup AS (
    SELECT e.EmpID, rn = ROW_NUMBER() OVER (ORDER BY e.EmpID)
    FROM hr.Employee AS e
    INNER JOIN mst.Designation AS d ON d.DesignationID = e.DesignationID
    WHERE e.CompanyID = @Diti AND d.DesignationName IN (N'Supervisor', N'Head Guard')
)
UPDATE u SET u.EmpID = s.EmpID
FROM sec.Users AS u
INNER JOIN sup AS s ON s.rn = CAST(RIGHT(u.UserName, 1) AS INT)
WHERE u.CompanyID = @Diti AND u.UserName LIKE N'diti.sup%' AND u.EmpID IS NULL;

INSERT INTO sec.Users (CompanyID, BranchID, EmpID, UserName, MobileNo, LegacyPasswordHash,
                       MustChangePassword, RoleID, LoginType, IsActive, IsApproved)
SELECT e.CompanyID, e.BranchID, e.EmpID, LOWER(e.EmpCode), e.Mobile1, @Pw, 0, @EmpRole, 8, 1, 1
FROM hr.Employee AS e
WHERE e.CompanyID = @Diti AND e.EmpStatus = N'Active'
  AND NOT EXISTS (SELECT 1 FROM sec.Users AS u WHERE u.EmpID = e.EmpID)
  AND (SELECT COUNT(*) FROM sec.Users WHERE CompanyID = @Diti) < 95;   -- respect MaxUsers
GO

/*  client portal logins  */
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @Pw NVARCHAR(500) = N'PLAINTEXT:Client@123';
DECLARE @ClientRole INT = (SELECT RoleID FROM sec.Role WHERE RoleCode = N'CLIENT' AND CompanyID IS NULL);

INSERT INTO sec.Users (CompanyID, BranchID, ClientID, UserName, MobileNo, LegacyPasswordHash,
                       MustChangePassword, RoleID, LoginType, IsActive, IsApproved)
SELECT c.CompanyID, c.BranchID, c.ClientID,
       LOWER(REPLACE(c.ClientCode, N'CL', N'client')), c.ContactNo, @Pw, 0, @ClientRole, 7, 1, 1
FROM crm.Client AS c
WHERE c.CompanyID = @Diti
  AND c.ClientCode IN (N'CL001', N'CL003', N'CL005', N'CL006')
  AND NOT EXISTS (SELECT 1 FROM sec.Users AS u WHERE u.ClientID = c.ClientID);
GO

/*==============================================================================
  QR CHECKPOINTS AND PATROL ROUNDS
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

IF NOT EXISTS (SELECT 1 FROM ops.QrCheckpoint WHERE CompanyID = @Diti)
    INSERT INTO ops.QrCheckpoint (CompanyID, BranchID, UnitID, QrCode, Name, Location,
                                  Latitude, Longitude, MaxDistanceMeters, RequirePhoto, SortOrder)
    SELECT u.CompanyID, u.BranchID, u.UnitID,
           LOWER(CONVERT(NVARCHAR(64), NEWID())),
           CONCAT(N'CP-', v.n, N' ', v.Label),
           CONCAT(u.UnitName, N' / ', v.Label),
           u.Latitude  + (v.n * 0.00012),
           u.Longitude + (v.n * 0.00010),
           50,
           CASE WHEN v.n = 1 THEN 1 ELSE 0 END,
           v.n
    FROM crm.Unit AS u
    CROSS JOIN (VALUES (1,N'Main Gate'),(2,N'Rear Boundary'),(3,N'Generator Room')) AS v(n, Label)
    WHERE u.CompanyID = @Diti AND u.IsActive = 1;
GO

DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

IF NOT EXISTS (SELECT 1 FROM ops.PatrolRound WHERE CompanyID = @Diti)
BEGIN
    INSERT INTO ops.PatrolRound (CompanyID, UnitID, RoundName, StartTime, EndTime,
                                 GraceMinutes, DaysOfWeek)
    SELECT u.CompanyID, u.UnitID, v.RoundName, v.StartTime, v.EndTime, 15, N'1,2,3,4,5,6,7'
    FROM crm.Unit AS u
    CROSS JOIN (VALUES
        (N'Night Round 1', CAST('22:00' AS TIME), CAST('23:00' AS TIME)),
        (N'Night Round 2', CAST('01:00' AS TIME), CAST('02:00' AS TIME))
    ) AS v(RoundName, StartTime, EndTime)
    WHERE u.CompanyID = @Diti AND u.UnitCode IN (N'U005', N'U007', N'U011', N'U009', N'U008', N'U003');

    INSERT INTO ops.PatrolRoundCheckpoint (RoundID, QrID, SequenceNo)
    SELECT r.RoundID, q.QrID, q.SortOrder
    FROM ops.PatrolRound AS r
    INNER JOIN ops.QrCheckpoint AS q ON q.UnitID = r.UnitID
    WHERE r.CompanyID = @Diti;

    UPDATE r
    SET r.ExpectedCheckpoints = (SELECT COUNT(*) FROM ops.PatrolRoundCheckpoint AS rc WHERE rc.RoundID = r.RoundID)
    FROM ops.PatrolRound AS r WHERE r.CompanyID = @Diti;
END
GO

/*==============================================================================
  OPENING UNIFORM STOCK
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');

INSERT INTO inv.Stock (CompanyID, BranchID, ItemID, Opstock, Qty, MinLevel)
SELECT b.CompanyID, b.BranchID, i.ItemID, 200, 200, 25
FROM org.Branch AS b
CROSS JOIN mst.UniformItem AS i
WHERE b.CompanyID = @Diti AND i.CompanyID IS NULL
  AND NOT EXISTS (SELECT 1 FROM inv.Stock AS s
                  WHERE s.CompanyID = b.CompanyID AND s.BranchID = b.BranchID AND s.ItemID = i.ItemID);
GO

/*==============================================================================
  RECRUITMENT PIPELINE
==============================================================================*/
DECLARE @Diti INT = (SELECT CompanyID FROM org.Company WHERE CompanyCode = N'DTI');
DECLARE @HO INT = (SELECT BranchID FROM org.Branch WHERE CompanyID = @Diti AND BranchCode = N'DTI-HO');
DECLARE @Today DATE = CAST(SYSDATETIME() AS DATE);
DECLARE @Guard INT = (SELECT DesignationID FROM mst.Designation WHERE DesignationName = N'Security Guard' AND CompanyID IS NULL);

IF NOT EXISTS (SELECT 1 FROM hr.Recruit WHERE CompanyID = @Diti)
    INSERT INTO hr.Recruit (CompanyID, BranchID, Name, Mobile, AdharCardNo, Dated, SourceBy,
                            DesignationID, Status, Remark)
    VALUES
    (@Diti, @HO, N'Ravinder Singh',  N'9876500011', N'411122223331', DATEADD(DAY,-2,@Today), N'Walk-in',     @Guard, N'New',      NULL),
    (@Diti, @HO, N'Satish Kumar',    N'9876500012', N'411122223332', DATEADD(DAY,-4,@Today), N'Referral',    @Guard, N'New',      NULL),
    (@Diti, @HO, N'Vikram Rathore',  N'9876500013', N'411122223333', DATEADD(DAY,-7,@Today), N'Ex-serviceman',@Guard,N'Screened', N'Ex-Army, good physique'),
    (@Diti, @HO, N'Harpreet Kaur',   N'9876500014', N'411122223334', DATEADD(DAY,-9,@Today), N'Job Portal',  @Guard, N'Screened', N'For lady guard post'),
    (@Diti, @HO, N'Mohd Irfan',      N'9876500015', N'411122223335', DATEADD(DAY,-12,@Today),N'Walk-in',     @Guard, N'Verified', N'PV initiated'),
    (@Diti, @HO, N'Bhupinder Yadav', N'9876500016', N'411122223336', DATEADD(DAY,-15,@Today),N'Referral',    @Guard, N'Approved', N'Ready to convert'),
    (@Diti, @HO, N'Karan Thapa',     N'9876500017', N'411122223337', DATEADD(DAY,-20,@Today),N'Agent',       @Guard, N'Waitlist', N'No vacancy at present'),
    (@Diti, @HO, N'Sohan Lal',       N'9876500018', N'411122223338', DATEADD(DAY,-25,@Today),N'Walk-in',     @Guard, N'Rejected', N'Failed physical standards');
GO

PRINT '710_seed_demo_tenant.sql  ->  OK';
GO
SELECT N'  companies   = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM org.Company;
SELECT N'  branches    = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM org.Branch;
SELECT N'  users       = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM sec.Users;
SELECT N'  clients     = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM crm.Client;
SELECT N'  units       = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM crm.Unit;
SELECT N'  posts       = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM crm.UnitPost;
SELECT N'  employees   = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM hr.Employee;
SELECT N'  deployments = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM ops.Deployment;
SELECT N'  checkpoints = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM ops.QrCheckpoint;
SELECT N'  recruits    = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM hr.Recruit;
GO
