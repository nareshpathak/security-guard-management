/*==============================================================================
  700_seed_reference.sql
  Platform reference data - shared by every tenant (CompanyID IS NULL).
  Spec: docs/prd/01-database.md §8.1

  Idempotent: every insert is guarded by NOT EXISTS on the natural key, so the
  script can be re-run without duplicating rows.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*------------------------------------------------------------------ COUNTRY */
IF NOT EXISTS (SELECT 1 FROM mst.Country WHERE CountryName = N'India')
    INSERT INTO mst.Country (CountryName, IsoCode) VALUES (N'India', N'IN');
GO

DECLARE @IndiaID INT = (SELECT CountryID FROM mst.Country WHERE CountryName = N'India');

/*-------------------------------------------------- STATES with GST codes   */
MERGE mst.State AS t
USING (VALUES
    (N'Jammu and Kashmir',N'JK',N'01'), (N'Himachal Pradesh',N'HP',N'02'),
    (N'Punjab',N'PB',N'03'),            (N'Chandigarh',N'CH',N'04'),
    (N'Uttarakhand',N'UK',N'05'),       (N'Haryana',N'HR',N'06'),
    (N'Delhi',N'DL',N'07'),             (N'Rajasthan',N'RJ',N'08'),
    (N'Uttar Pradesh',N'UP',N'09'),     (N'Bihar',N'BR',N'10'),
    (N'Sikkim',N'SK',N'11'),            (N'Arunachal Pradesh',N'AR',N'12'),
    (N'Nagaland',N'NL',N'13'),          (N'Manipur',N'MN',N'14'),
    (N'Mizoram',N'MZ',N'15'),           (N'Tripura',N'TR',N'16'),
    (N'Meghalaya',N'ML',N'17'),         (N'Assam',N'AS',N'18'),
    (N'West Bengal',N'WB',N'19'),       (N'Jharkhand',N'JH',N'20'),
    (N'Odisha',N'OD',N'21'),            (N'Chhattisgarh',N'CG',N'22'),
    (N'Madhya Pradesh',N'MP',N'23'),    (N'Gujarat',N'GJ',N'24'),
    (N'Dadra and Nagar Haveli and Daman and Diu',N'DN',N'26'),
    (N'Maharashtra',N'MH',N'27'),       (N'Karnataka',N'KA',N'29'),
    (N'Goa',N'GA',N'30'),               (N'Lakshadweep',N'LD',N'31'),
    (N'Kerala',N'KL',N'32'),            (N'Tamil Nadu',N'TN',N'33'),
    (N'Puducherry',N'PY',N'34'),        (N'Andaman and Nicobar Islands',N'AN',N'35'),
    (N'Telangana',N'TS',N'36'),         (N'Andhra Pradesh',N'AP',N'37'),
    (N'Ladakh',N'LA',N'38')
) AS s(StateName, StateCode, GstStateCode)
   ON t.StateName = s.StateName AND t.CountryID = @IndiaID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CountryID, StateName, StateCode, GstStateCode)
    VALUES (@IndiaID, s.StateName, s.StateCode, s.GstStateCode);
GO

/*-------------------------------------------------------- MAJOR CITIES      */
MERGE mst.City AS t
USING (VALUES
    (N'New Delhi',N'Delhi'), (N'Gurugram',N'Haryana'), (N'Faridabad',N'Haryana'),
    (N'Noida',N'Uttar Pradesh'), (N'Ghaziabad',N'Uttar Pradesh'), (N'Lucknow',N'Uttar Pradesh'),
    (N'Kanpur',N'Uttar Pradesh'), (N'Agra',N'Uttar Pradesh'), (N'Varanasi',N'Uttar Pradesh'),
    (N'Mumbai',N'Maharashtra'), (N'Pune',N'Maharashtra'), (N'Nagpur',N'Maharashtra'),
    (N'Thane',N'Maharashtra'), (N'Nashik',N'Maharashtra'),
    (N'Bengaluru',N'Karnataka'), (N'Mysuru',N'Karnataka'),
    (N'Chennai',N'Tamil Nadu'), (N'Coimbatore',N'Tamil Nadu'),
    (N'Hyderabad',N'Telangana'), (N'Warangal',N'Telangana'),
    (N'Kolkata',N'West Bengal'), (N'Howrah',N'West Bengal'),
    (N'Ahmedabad',N'Gujarat'), (N'Surat',N'Gujarat'), (N'Vadodara',N'Gujarat'), (N'Rajkot',N'Gujarat'),
    (N'Jaipur',N'Rajasthan'), (N'Jodhpur',N'Rajasthan'), (N'Udaipur',N'Rajasthan'),
    (N'Bhopal',N'Madhya Pradesh'), (N'Indore',N'Madhya Pradesh'), (N'Jabalpur',N'Madhya Pradesh'),
    (N'Patna',N'Bihar'), (N'Ranchi',N'Jharkhand'), (N'Raipur',N'Chhattisgarh'),
    (N'Bhubaneswar',N'Odisha'), (N'Guwahati',N'Assam'), (N'Chandigarh',N'Chandigarh'),
    (N'Ludhiana',N'Punjab'), (N'Amritsar',N'Punjab'), (N'Dehradun',N'Uttarakhand'),
    (N'Shimla',N'Himachal Pradesh'), (N'Kochi',N'Kerala'), (N'Thiruvananthapuram',N'Kerala'),
    (N'Visakhapatnam',N'Andhra Pradesh'), (N'Vijayawada',N'Andhra Pradesh'), (N'Panaji',N'Goa')
) AS s(CityName, StateName)
   ON t.CityName = s.CityName
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CityName, StateID)
    VALUES (s.CityName, (SELECT StateID FROM mst.State WHERE StateName = s.StateName));
GO

/*------------------------------------------------------------------- ROLES  */
MERGE sec.Role AS t
USING (VALUES
    (N'SUPER_ADMIN',   N'Super Admin',      N'Platform operator. No tenant data unless impersonating.'),
    (N'COMPANY_ADMIN', N'Company Admin',    N'Full access within the agency.'),
    (N'BRANCH_ADMIN',  N'Branch Admin',     N'Full access within assigned branches.'),
    (N'OPERATIONS',    N'Operations',       N'Deployment, turnout, movement, incidents.'),
    (N'HR',            N'HR Executive',     N'Recruitment, documents, verification, training.'),
    (N'ACCOUNTS',      N'Accounts',         N'Payroll, advances, invoicing, ledgers.'),
    (N'SUPERVISOR',    N'Field Supervisor', N'Attendance approval and field reports for own units.'),
    (N'GATEKEEPER',    N'Gate Keeper',      N'Gate pass entry only.'),
    (N'NIGHT_PATROL',  N'Night Patrol',     N'QR checkpoint patrol.'),
    (N'SALES',         N'Sales Executive',  N'Visits, follow-ups, new contracts.'),
    (N'EMPLOYEE',      N'Employee',         N'Own attendance, salary slip, documents.'),
    (N'CLIENT',        N'Client',           N'Own units, guards, patrol proof, invoices.')
) AS s(RoleCode, RoleName, Description)
   ON t.RoleCode = s.RoleCode AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, RoleCode, RoleName, Description, IsSystem)
    VALUES (NULL, s.RoleCode, s.RoleName, s.Description, 1);
GO

/*--------------------------------------------------------------- LOGIN TYPE */
MERGE mst.LoginType AS t
USING (VALUES
    (1, N'Super Admin', N'SUPER_ADMIN'), (2, N'Admin',       N'COMPANY_ADMIN'),
    (3, N'Supervisor',  N'SUPERVISOR'),  (4, N'Gate Keeper', N'GATEKEEPER'),
    (5, N'Night Patrol',N'NIGHT_PATROL'),(6, N'Sales',       N'SALES'),
    (7, N'Client',      N'CLIENT'),      (8, N'Employee',    N'EMPLOYEE'),
    (9, N'Operations',  N'OPERATIONS'),  (10,N'HR',          N'HR'),
    (11,N'Accounts',    N'ACCOUNTS'),    (12,N'Branch Admin',N'BRANCH_ADMIN')
) AS s(LoginTypeID, Name, RoleCode)
   ON t.LoginTypeID = s.LoginTypeID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (LoginTypeID, Name, RoleCode) VALUES (s.LoginTypeID, s.Name, s.RoleCode);
GO

/*-------------------------------------------------------------- PERMISSIONS */
MERGE sec.Permission AS t
USING (VALUES
    (N'M1', N'M1.Profile.View',        N'View own profile',            N'Profile',    N'View', 10),
    (N'M2', N'M2.Tenant.Manage',       N'Manage tenants',              N'Tenant',     N'Edit', 20),
    (N'M3', N'M3.Master.View',         N'View masters',                N'Master',     N'View', 30),
    (N'M3', N'M3.Master.Edit',         N'Edit masters',                N'Master',     N'Edit', 31),
    (N'M4', N'M4.Client.View',         N'View clients and units',      N'Client',     N'View', 40),
    (N'M4', N'M4.Client.Edit',         N'Add or edit clients/units',   N'Client',     N'Edit', 41),
    (N'M5', N'M5.Recruit.View',        N'View recruitment pipeline',   N'Recruit',    N'View', 50),
    (N'M5', N'M5.Recruit.Edit',        N'Add or edit recruits',        N'Recruit',    N'Edit', 51),
    (N'M5', N'M5.Recruit.Approve',     N'Approve or reject recruits',  N'Recruit',    N'Approve', 52),
    (N'M6', N'M6.Employee.View',       N'View employees',              N'Employee',   N'View', 60),
    (N'M6', N'M6.Employee.Edit',       N'Add or edit employees',       N'Employee',   N'Edit', 61),
    (N'M6', N'M6.Employee.ViewSensitive', N'View Aadhaar, PAN, bank',  N'Employee',   N'ViewSensitive', 62),
    (N'M7', N'M7.Deployment.View',     N'View deployments',            N'Deployment', N'View', 70),
    (N'M7', N'M7.Deployment.Edit',     N'Deploy and move guards',      N'Deployment', N'Edit', 71),
    (N'M7', N'M7.Deployment.Approve',  N'Approve strength changes',    N'Deployment', N'Approve', 72),
    (N'M8', N'M8.Attendance.View',     N'View attendance',             N'Attendance', N'View', 80),
    (N'M8', N'M8.Attendance.Punch',    N'Punch own attendance',        N'Attendance', N'Create', 81),
    (N'M8', N'M8.Attendance.Edit',     N'Mark attendance for others',  N'Attendance', N'Edit', 82),
    (N'M8', N'M8.Attendance.Approve',  N'Approve attendance',          N'Attendance', N'Approve', 83),
    (N'M9', N'M9.Patrol.View',         N'View patrol logs',            N'Patrol',     N'View', 90),
    (N'M9', N'M9.Patrol.Scan',         N'Scan checkpoints',            N'Patrol',     N'Create', 91),
    (N'M9', N'M9.Patrol.Edit',         N'Manage checkpoints/rounds',   N'Patrol',     N'Edit', 92),
    (N'M10',N'M10.Tracking.View',      N'View live map and trails',    N'Tracking',   N'View', 100),
    (N'M11',N'M11.Task.View',          N'View tasks',                  N'Task',       N'View', 110),
    (N'M11',N'M11.Task.Edit',          N'Create and assign tasks',     N'Task',       N'Edit', 111),
    (N'M12',N'M12.Incident.View',      N'View incidents',              N'Incident',   N'View', 120),
    (N'M12',N'M12.Incident.Edit',      N'Record incidents',            N'Incident',   N'Edit', 121),
    (N'M12',N'M12.Complaint.View',     N'View complaints',             N'Complaint',  N'View', 122),
    (N'M12',N'M12.Complaint.Edit',     N'Raise and update complaints', N'Complaint',  N'Edit', 123),
    (N'M12',N'M12.Complaint.Approve',  N'Close complaints',            N'Complaint',  N'Approve', 124),
    (N'M13',N'M13.Sales.View',         N'View sales pipeline',         N'Sales',      N'View', 130),
    (N'M13',N'M13.Sales.Edit',         N'Record visits and follow-ups',N'Sales',      N'Edit', 131),
    (N'M14',N'M14.Inventory.View',     N'View uniform stock',          N'Inventory',  N'View', 140),
    (N'M14',N'M14.Inventory.Edit',     N'Issue and return uniform',    N'Inventory',  N'Edit', 141),
    (N'M15',N'M15.Payroll.View',       N'View payroll',                N'Payroll',    N'View', 150),
    (N'M15',N'M15.Payroll.Edit',       N'Generate and edit payroll',   N'Payroll',    N'Edit', 151),
    (N'M15',N'M15.Payroll.Approve',    N'Lock payroll',                N'Payroll',    N'Approve', 152),
    (N'M15',N'M15.Invoice.View',       N'View invoices',               N'Invoice',    N'View', 153),
    (N'M15',N'M15.Invoice.Edit',       N'Generate invoices',           N'Invoice',    N'Edit', 154),
    (N'M16',N'M16.Hr.View',            N'View HR lifecycle',           N'Hr',         N'View', 160),
    (N'M16',N'M16.Hr.Edit',            N'Record resign/left/rejoin',   N'Hr',         N'Edit', 161),
    (N'M16',N'M16.GatePass.Edit',      N'Record gate passes',          N'GatePass',   N'Edit', 162),
    (N'M16',N'M16.Request.Approve',    N'Approve employee requests',   N'Request',    N'Approve', 163),
    (N'RPT',N'RPT.Report.View',        N'View reports',                N'Report',     N'View', 200),
    (N'RPT',N'RPT.Report.Export',      N'Export reports',              N'Report',     N'Export', 201),
    (N'SET',N'SET.Settings.Edit',      N'Manage settings and roles',   N'Settings',   N'Edit', 210),
    (N'SET',N'SET.Audit.View',         N'View the audit trail',        N'Audit',      N'View', 211)
) AS s(Module, Code, Name, Entity, [Action], SortOrder)
   ON t.Code = s.Code
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Module, Code, Name, Entity, [Action], SortOrder)
    VALUES (s.Module, s.Code, s.Name, s.Entity, s.[Action], s.SortOrder);
GO

/*-------------------------------- ROLE x PERMISSION matrix (docs/prd/05 §1.1) */
;WITH grants AS (
    SELECT RoleCode, Code, CanView, CanCreate, CanEdit, CanDelete, CanApprove, CanExport
    FROM (VALUES
        /* COMPANY_ADMIN: everything except platform administration */
        (N'COMPANY_ADMIN', N'*', 1,1,1,1,1,1),
        /* BRANCH_ADMIN: everything except settings and payroll locking */
        (N'BRANCH_ADMIN',  N'*', 1,1,1,0,1,1),
        (N'OPERATIONS',    N'M4.Client.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M6.Employee.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M7.Deployment.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M7.Deployment.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M7.Deployment.Approve',1,0,0,0,1,0),
        (N'OPERATIONS',    N'M8.Attendance.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M8.Attendance.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M8.Attendance.Approve',1,0,0,0,1,0),
        (N'OPERATIONS',    N'M9.Patrol.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M9.Patrol.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M10.Tracking.View',1,0,0,0,0,0),
        (N'OPERATIONS',    N'M11.Task.View',1,0,0,0,0,0),
        (N'OPERATIONS',    N'M11.Task.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M12.Incident.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M12.Incident.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M12.Complaint.View',1,0,0,0,0,1),
        (N'OPERATIONS',    N'M12.Complaint.Edit',1,1,1,0,0,0),
        (N'OPERATIONS',    N'M12.Complaint.Approve',1,0,0,0,1,0),
        (N'OPERATIONS',    N'RPT.Report.View',1,0,0,0,0,1),
        (N'HR',            N'M3.Master.View',1,0,0,0,0,0),
        (N'HR',            N'M5.Recruit.View',1,0,0,0,0,1),
        (N'HR',            N'M5.Recruit.Edit',1,1,1,0,0,0),
        (N'HR',            N'M5.Recruit.Approve',1,0,0,0,1,0),
        (N'HR',            N'M6.Employee.View',1,0,0,0,0,1),
        (N'HR',            N'M6.Employee.Edit',1,1,1,0,0,0),
        (N'HR',            N'M6.Employee.ViewSensitive',1,0,0,0,0,0),
        (N'HR',            N'M16.Hr.View',1,0,0,0,0,1),
        (N'HR',            N'M16.Hr.Edit',1,1,1,0,0,0),
        (N'HR',            N'M16.Request.Approve',1,0,0,0,1,0),
        (N'HR',            N'M14.Inventory.View',1,0,0,0,0,0),
        (N'HR',            N'RPT.Report.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M6.Employee.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M6.Employee.ViewSensitive',1,0,0,0,0,0),
        (N'ACCOUNTS',      N'M8.Attendance.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M14.Inventory.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M14.Inventory.Edit',1,1,1,0,0,0),
        (N'ACCOUNTS',      N'M15.Payroll.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M15.Payroll.Edit',1,1,1,0,0,0),
        (N'ACCOUNTS',      N'M15.Payroll.Approve',1,0,0,0,1,0),
        (N'ACCOUNTS',      N'M15.Invoice.View',1,0,0,0,0,1),
        (N'ACCOUNTS',      N'M15.Invoice.Edit',1,1,1,0,0,0),
        (N'ACCOUNTS',      N'RPT.Report.View',1,0,0,0,0,1),
        (N'SUPERVISOR',    N'M6.Employee.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M7.Deployment.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M7.Deployment.Edit',1,1,1,0,0,0),
        (N'SUPERVISOR',    N'M8.Attendance.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M8.Attendance.Edit',1,1,1,0,0,0),
        (N'SUPERVISOR',    N'M8.Attendance.Approve',1,0,0,0,1,0),
        (N'SUPERVISOR',    N'M9.Patrol.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M11.Task.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M11.Task.Edit',1,1,1,0,0,0),
        (N'SUPERVISOR',    N'M12.Incident.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M12.Incident.Edit',1,1,1,0,0,0),
        (N'SUPERVISOR',    N'M12.Complaint.View',1,0,0,0,0,0),
        (N'SUPERVISOR',    N'M12.Complaint.Edit',1,1,1,0,0,0),
        (N'SUPERVISOR',    N'M16.Hr.Edit',1,1,0,0,0,0),
        (N'SUPERVISOR',    N'M1.Profile.View',1,0,0,0,0,0),
        (N'GATEKEEPER',    N'M16.GatePass.Edit',1,1,1,0,0,0),
        (N'GATEKEEPER',    N'M1.Profile.View',1,0,0,0,0,0),
        (N'GATEKEEPER',    N'M8.Attendance.Punch',1,1,0,0,0,0),
        (N'NIGHT_PATROL',  N'M9.Patrol.Scan',1,1,0,0,0,0),
        (N'NIGHT_PATROL',  N'M9.Patrol.View',1,0,0,0,0,0),
        (N'NIGHT_PATROL',  N'M12.Incident.Edit',1,1,0,0,0,0),
        (N'NIGHT_PATROL',  N'M1.Profile.View',1,0,0,0,0,0),
        (N'NIGHT_PATROL',  N'M8.Attendance.Punch',1,1,0,0,0,0),
        (N'SALES',         N'M13.Sales.View',1,0,0,0,0,1),
        (N'SALES',         N'M13.Sales.Edit',1,1,1,0,0,0),
        (N'SALES',         N'M4.Client.View',1,0,0,0,0,0),
        (N'SALES',         N'M1.Profile.View',1,0,0,0,0,0),
        (N'EMPLOYEE',      N'M1.Profile.View',1,0,0,0,0,0),
        (N'EMPLOYEE',      N'M8.Attendance.Punch',1,1,0,0,0,0),
        (N'EMPLOYEE',      N'M8.Attendance.View',1,0,0,0,0,0),
        (N'EMPLOYEE',      N'M15.Payroll.View',1,0,0,0,0,0),
        (N'EMPLOYEE',      N'M12.Complaint.Edit',1,1,0,0,0,0),
        (N'EMPLOYEE',      N'M14.Inventory.View',1,0,0,0,0,0),
        (N'CLIENT',        N'M4.Client.View',1,0,0,0,0,0),
        (N'CLIENT',        N'M8.Attendance.View',1,0,0,0,0,1),
        (N'CLIENT',        N'M9.Patrol.View',1,0,0,0,0,1),
        (N'CLIENT',        N'M12.Complaint.View',1,0,0,0,0,0),
        (N'CLIENT',        N'M12.Complaint.Edit',1,1,0,0,0,0),
        (N'CLIENT',        N'M15.Invoice.View',1,0,0,0,0,1),
        (N'SUPER_ADMIN',   N'M2.Tenant.Manage',1,1,1,1,1,1),
        (N'SUPER_ADMIN',   N'M3.Master.Edit',1,1,1,1,0,1),
        (N'SUPER_ADMIN',   N'SET.Settings.Edit',1,1,1,1,0,0),
        (N'SUPER_ADMIN',   N'SET.Audit.View',1,0,0,0,0,1)
    ) AS v(RoleCode, Code, CanView, CanCreate, CanEdit, CanDelete, CanApprove, CanExport)
),
expanded AS (
    SELECT r.RoleID, p.PermissionID, g.CanView, g.CanCreate, g.CanEdit, g.CanDelete, g.CanApprove, g.CanExport
    FROM grants AS g
    INNER JOIN sec.Role AS r ON r.RoleCode = g.RoleCode AND r.CompanyID IS NULL
    INNER JOIN sec.Permission AS p ON (g.Code = N'*' AND p.Module NOT IN (N'M2', N'SET')) OR p.Code = g.Code
)
MERGE sec.RolePermission AS t
USING (SELECT RoleID, PermissionID,
              CanView = MAX(CanView), CanCreate = MAX(CanCreate), CanEdit = MAX(CanEdit),
              CanDelete = MAX(CanDelete), CanApprove = MAX(CanApprove), CanExport = MAX(CanExport)
       FROM expanded GROUP BY RoleID, PermissionID) AS s
   ON t.RoleID = s.RoleID AND t.PermissionID = s.PermissionID
WHEN MATCHED THEN UPDATE SET
    CanView = s.CanView, CanCreate = s.CanCreate, CanEdit = s.CanEdit,
    CanDelete = s.CanDelete, CanApprove = s.CanApprove, CanExport = s.CanExport,
    UpdateDate = SYSDATETIME()
WHEN NOT MATCHED BY TARGET THEN
    INSERT (RoleID, PermissionID, CanView, CanCreate, CanEdit, CanDelete, CanApprove, CanExport)
    VALUES (s.RoleID, s.PermissionID, s.CanView, s.CanCreate, s.CanEdit, s.CanDelete, s.CanApprove, s.CanExport);
GO

/*------------------------------------------------------------ HR CLASSIFIERS */
MERGE mst.Grade AS t USING (VALUES (N'A',1),(N'B',2),(N'C',3),(N'D',4)) AS s(GradeName, SortOrder)
   ON t.GradeName = s.GradeName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN INSERT (CompanyID, GradeName, SortOrder) VALUES (NULL, s.GradeName, s.SortOrder);
GO

MERGE mst.Category AS t
USING (VALUES (N'Unskilled',1),(N'Semi-skilled',2),(N'Skilled',3),(N'Highly Skilled',4)) AS s(CategoryName, SortOrder)
   ON t.CategoryName = s.CategoryName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN INSERT (CompanyID, CategoryName, SortOrder) VALUES (NULL, s.CategoryName, s.SortOrder);
GO

MERGE mst.Designation AS t
USING (VALUES
    (N'Security Guard',1,0),        (N'Head Guard',2,0),
    (N'Gunman',3,1),                (N'Lady Guard',4,0),
    (N'Supervisor',5,0),            (N'Assistant Security Officer',6,0),
    (N'Security Officer',7,0),      (N'Housekeeping',8,0),
    (N'Driver',9,0),                (N'Fire Operator',10,0),
    (N'CCTV Operator',11,0),        (N'Gate Keeper',12,0)
) AS s(DesignationName, SortOrder, IsGunmanRole)
   ON t.DesignationName = s.DesignationName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, DesignationName, SortOrder, IsGunmanRole)
    VALUES (NULL, s.DesignationName, s.SortOrder, s.IsGunmanRole);
GO

MERGE mst.Qualification AS t
USING (VALUES (N'Below 8th',1),(N'8th Pass',2),(N'10th Pass',3),(N'12th Pass',4),
              (N'ITI',5),(N'Diploma',6),(N'Graduate',7),(N'Post Graduate',8)) AS s(QualificationName, SortOrder)
   ON t.QualificationName = s.QualificationName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, QualificationName, SortOrder) VALUES (NULL, s.QualificationName, s.SortOrder);
GO

MERGE mst.Shift AS t
USING (VALUES
    (N'Day',     CAST('08:00' AS TIME), CAST('20:00' AS TIME), 0, 6.0, 11.0),
    (N'Night',   CAST('20:00' AS TIME), CAST('08:00' AS TIME), 1, 6.0, 11.0),
    (N'General', CAST('09:00' AS TIME), CAST('18:00' AS TIME), 0, 4.0,  8.0),
    (N'Morning', CAST('06:00' AS TIME), CAST('14:00' AS TIME), 0, 4.0,  7.5),
    (N'Evening', CAST('14:00' AS TIME), CAST('22:00' AS TIME), 0, 4.0,  7.5)
) AS s(ShiftName, StartTime, EndTime, IsNight, HalfDayHours, FullDayHours)
   ON t.ShiftName = s.ShiftName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, ShiftName, StartTime, EndTime, IsNight, HalfDayHours, FullDayHours)
    VALUES (NULL, s.ShiftName, s.StartTime, s.EndTime, s.IsNight, s.HalfDayHours, s.FullDayHours);
GO

/*------------------------------------------------------------- OPS LOOKUPS  */
MERGE mst.ComplaintType AS t
USING (VALUES (N'Guard Absent',4),(N'Late Arrival',8),(N'Misbehaviour',24),
              (N'Uniform Issue',48),(N'Sleeping on Duty',4),(N'Theft',2),
              (N'Poor Grooming',48),(N'Mobile Usage on Duty',24),(N'Other',24)) AS s(ComplaintTypeName, DefaultSlaHours)
   ON t.ComplaintTypeName = s.ComplaintTypeName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, ComplaintTypeName, DefaultSlaHours) VALUES (NULL, s.ComplaintTypeName, s.DefaultSlaHours);
GO

MERGE mst.IncidentType AS t
USING (VALUES (N'Theft',4),(N'Fire',4),(N'Trespassing',3),(N'Medical Emergency',4),
              (N'Vehicle Damage',2),(N'Altercation',3),(N'Equipment Failure',2),
              (N'Suspicious Activity',3),(N'Property Damage',2),(N'Other',2)) AS s(IncidentTypeName, Severity)
   ON t.IncidentTypeName = s.IncidentTypeName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, IncidentTypeName, Severity) VALUES (NULL, s.IncidentTypeName, s.Severity);
GO

MERGE mst.ServiceType AS t
USING (VALUES (N'Security Guarding'),(N'Armed Guarding'),(N'Housekeeping'),
              (N'Event Security'),(N'Facility Management'),(N'Fire Safety')) AS s(ServiceName)
   ON t.ServiceName = s.ServiceName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN INSERT (CompanyID, ServiceName) VALUES (NULL, s.ServiceName);
GO

MERGE mst.UniformItem AS t
USING (VALUES
    (N'Shirt',450.00),(N'Trouser',550.00),(N'Shoes',900.00),(N'Belt',150.00),
    (N'Cap',120.00),(N'Whistle',40.00),(N'Jersey',600.00),(N'Raincoat',350.00),
    (N'Torch',250.00),(N'Baton',180.00),(N'ID Card',50.00),(N'Name Plate',60.00),
    (N'Socks',80.00),(N'Tie',120.00)
) AS s(ItemName, Rate)
   ON t.ItemName = s.ItemName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN INSERT (CompanyID, ItemName, Rate) VALUES (NULL, s.ItemName, s.Rate);
GO

MERGE mst.TaskStatus AS t
USING (VALUES (N'Pending',N'#F59E0B',0,1),(N'In-Progress',N'#0EA5E9',0,2),
              (N'On-Hold',N'#64748B',0,3),(N'Completed',N'#16A34A',1,4),
              (N'Closed',N'#0B5FFF',1,5),(N'Rejected',N'#DC2626',1,6)) AS s(Name, ColorHex, IsTerminal, SortOrder)
   ON t.Name = s.Name
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Name, ColorHex, IsTerminal, SortOrder) VALUES (s.Name, s.ColorHex, s.IsTerminal, s.SortOrder);
GO

MERGE mst.Priority AS t
USING (VALUES (N'Low',N'#64748B',1),(N'Medium',N'#0EA5E9',2),
              (N'High',N'#F59E0B',3),(N'Critical',N'#DC2626',4)) AS s(Name, ColorHex, SortOrder)
   ON t.Name = s.Name
WHEN NOT MATCHED BY TARGET THEN INSERT (Name, ColorHex, SortOrder) VALUES (s.Name, s.ColorHex, s.SortOrder);
GO

MERGE mst.TaskRepetition AS t
USING (VALUES (N'None',0,1),(N'Daily',1,2),(N'Weekly',7,3),
              (N'Monthly',30,4),(N'Quarterly',90,5)) AS s(Name, IntervalDays, SortOrder)
   ON t.Name = s.Name
WHEN NOT MATCHED BY TARGET THEN INSERT (Name, IntervalDays, SortOrder) VALUES (s.Name, s.IntervalDays, s.SortOrder);
GO

MERGE mst.DocumentType AS t
USING (VALUES
    (N'Photograph',N'Employee',1,0,1),      (N'Aadhaar Card',N'Employee',1,0,2),
    (N'PAN Card',N'Employee',0,0,3),        (N'Voter ID',N'Employee',0,0,4),
    (N'Driving Licence',N'Employee',0,1,5), (N'Bank Passbook',N'Employee',1,0,6),
    (N'Educational Certificate',N'Employee',0,0,7),
    (N'Police Verification',N'Employee',1,1,8),
    (N'Medical Certificate',N'Employee',1,1,9),
    (N'Gun Licence',N'Employee',0,1,10),    (N'Discharge Certificate',N'Employee',0,0,11),
    (N'Appointment Letter',N'Employee',0,0,12),
    (N'Agreement',N'Unit',1,1,20),          (N'Work Order',N'Unit',1,1,21),
    (N'PSARA Licence',N'Company',1,1,30),   (N'GST Certificate',N'Company',1,0,31)
) AS s(DocTypeName, OwnerType, IsMandatory, HasExpiry, SortOrder)
   ON t.DocTypeName = s.DocTypeName AND t.CompanyID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, DocTypeName, OwnerType, IsMandatory, HasExpiry, SortOrder)
    VALUES (NULL, s.DocTypeName, s.OwnerType, s.IsMandatory, s.HasExpiry, s.SortOrder);
GO

/*--------------------------------------------------------------- STATUTORY  */
MERGE mst.StatutoryRate AS t
USING (VALUES
    (N'PF_EMP',   CAST('2014-09-01' AS DATE), 12.000, 15000.00, N'Employee provident fund'),
    (N'PF_ER',    CAST('2014-09-01' AS DATE),  3.670, 15000.00, N'Employer PF share after EPS'),
    (N'EPS',      CAST('2014-09-01' AS DATE),  8.330, 15000.00, N'Employee pension scheme'),
    (N'EDLI',     CAST('2014-09-01' AS DATE),  0.500, 15000.00, N'EDLI contribution'),
    (N'ADMIN_CHG',CAST('2018-06-01' AS DATE),  0.500, 15000.00, N'PF administration charges'),
    (N'ESIC_EMP', CAST('2019-07-01' AS DATE),  0.750, 21000.00, N'Employee ESIC'),
    (N'ESIC_ER',  CAST('2019-07-01' AS DATE),  3.250, 21000.00, N'Employer ESIC')
) AS s(RateCode, EffectiveFrom, [Percent], CeilingAmount, Remark)
   ON t.RateCode = s.RateCode AND t.EffectiveFrom = s.EffectiveFrom
WHEN NOT MATCHED BY TARGET THEN
    INSERT (RateCode, EffectiveFrom, [Percent], CeilingAmount, Remark)
    VALUES (s.RateCode, s.EffectiveFrom, s.[Percent], s.CeilingAmount, s.Remark);
GO

/*  Professional tax slabs. These change by state budget - treat as a starting
    point and reconcile with the client's accountant before go-live.  */
MERGE mst.PtSlab AS t
USING (VALUES
    (N'Maharashtra',       0.00,  7500.00,   0.00, NULL),
    (N'Maharashtra',    7501.00, 10000.00, 175.00, NULL),
    (N'Maharashtra',   10001.00,     NULL, 200.00, NULL),
    (N'Maharashtra',   10001.00,     NULL, 300.00, 2),
    (N'Karnataka',         0.00, 24999.00,   0.00, NULL),
    (N'Karnataka',     25000.00,     NULL, 200.00, NULL),
    (N'West Bengal',       0.00, 10000.00,   0.00, NULL),
    (N'West Bengal',   10001.00, 15000.00, 110.00, NULL),
    (N'West Bengal',   15001.00, 25000.00, 130.00, NULL),
    (N'West Bengal',   25001.00, 40000.00, 150.00, NULL),
    (N'West Bengal',   40001.00,     NULL, 200.00, NULL),
    (N'Gujarat',           0.00, 11999.00,   0.00, NULL),
    (N'Gujarat',       12000.00,     NULL, 200.00, NULL),
    (N'Madhya Pradesh',    0.00, 18750.00,   0.00, NULL),
    (N'Madhya Pradesh',18751.00, 25000.00, 125.00, NULL),
    (N'Madhya Pradesh',25001.00, 33333.00, 167.00, NULL),
    (N'Madhya Pradesh',33334.00,     NULL, 208.00, NULL),
    (N'Tamil Nadu',        0.00, 21000.00,   0.00, NULL),
    (N'Tamil Nadu',    21001.00, 30000.00, 135.00, NULL),
    (N'Tamil Nadu',    30001.00, 45000.00, 315.00, NULL),
    (N'Tamil Nadu',    45001.00,     NULL, 690.00, NULL)
) AS s(StateName, FromAmount, ToAmount, Amount, MonthNo)
   ON t.StateID = (SELECT StateID FROM mst.State WHERE StateName = s.StateName)
  AND t.FromAmount = s.FromAmount
  AND ISNULL(t.MonthNo, 0) = ISNULL(s.MonthNo, 0)
WHEN NOT MATCHED BY TARGET THEN
    INSERT (StateID, FromAmount, ToAmount, Amount, MonthNo, EffectiveFrom)
    VALUES ((SELECT StateID FROM mst.State WHERE StateName = s.StateName),
            s.FromAmount, s.ToAmount, s.Amount, s.MonthNo, CAST('2020-04-01' AS DATE));
GO

MERGE mst.LwfSlab AS t
USING (VALUES
    (N'Maharashtra',    0.00,  3000.00,  6.00, 18.00, N'6,12'),
    (N'Maharashtra', 3000.01,      NULL, 12.00, 36.00, N'6,12'),
    (N'Karnataka',      0.00,      NULL, 20.00, 40.00, N'12'),
    (N'Delhi',          0.00,      NULL,  0.75,  2.25, N'6,12'),
    (N'Haryana',        0.00,      NULL, 31.00, 62.00, N'12'),
    (N'Gujarat',        0.00,      NULL,  6.00, 12.00, N'6,12'),
    (N'Madhya Pradesh', 0.00,      NULL, 10.00, 30.00, N'6,12'),
    (N'Tamil Nadu',     0.00,      NULL, 20.00, 40.00, N'12'),
    (N'West Bengal',    0.00,      NULL,  3.00,  15.00, N'6,12')
) AS s(StateName, FromAmount, ToAmount, EmployeeAmount, EmployerAmount, DeductionMonths)
   ON t.StateID = (SELECT StateID FROM mst.State WHERE StateName = s.StateName)
  AND t.FromAmount = s.FromAmount
WHEN NOT MATCHED BY TARGET THEN
    INSERT (StateID, FromAmount, ToAmount, EmployeeAmount, EmployerAmount, DeductionMonths, EffectiveFrom)
    VALUES ((SELECT StateID FROM mst.State WHERE StateName = s.StateName),
            s.FromAmount, s.ToAmount, s.EmployeeAmount, s.EmployerAmount, s.DeductionMonths,
            CAST('2020-04-01' AS DATE));
GO

/*------------------------------------------------------------------- BANKS  */
MERGE mst.Bank AS t
USING (VALUES
    (N'State Bank of India'),(N'HDFC Bank'),(N'ICICI Bank'),(N'Axis Bank'),
    (N'Punjab National Bank'),(N'Bank of Baroda'),(N'Canara Bank'),(N'Union Bank of India'),
    (N'Kotak Mahindra Bank'),(N'IndusInd Bank'),(N'Yes Bank'),(N'IDBI Bank'),
    (N'Indian Bank'),(N'Central Bank of India'),(N'UCO Bank'),(N'Bank of India'),
    (N'Indian Overseas Bank'),(N'Bank of Maharashtra'),(N'Punjab and Sind Bank'),
    (N'Federal Bank'),(N'South Indian Bank'),(N'RBL Bank'),(N'Bandhan Bank'),
    (N'AU Small Finance Bank'),(N'India Post Payments Bank')
) AS s(BankName)
   ON t.BankName = s.BankName
WHEN NOT MATCHED BY TARGET THEN INSERT (BankName) VALUES (s.BankName);
GO

/*----------------------------------------------------------------- HOLIDAYS */
DECLARE @Yr INT = YEAR(SYSDATETIME());
MERGE mst.Holiday AS t
USING (VALUES
    (DATEFROMPARTS(@Yr, 1, 26), N'Republic Day'),
    (DATEFROMPARTS(@Yr, 5,  1), N'Labour Day'),
    (DATEFROMPARTS(@Yr, 8, 15), N'Independence Day'),
    (DATEFROMPARTS(@Yr,10,  2), N'Gandhi Jayanti'),
    (DATEFROMPARTS(@Yr,12, 25), N'Christmas')
) AS s(HolidayDate, HolidayName)
   ON t.HolidayDate = s.HolidayDate AND t.CompanyID IS NULL AND t.StateID IS NULL
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CompanyID, StateID, HolidayDate, HolidayName, IsPaid)
    VALUES (NULL, NULL, s.HolidayDate, s.HolidayName, 1);
GO

PRINT '700_seed_reference.sql  ->  OK';
GO
SELECT N'  states       = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM mst.State;
SELECT N'  cities       = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM mst.City;
SELECT N'  roles        = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM sec.Role WHERE CompanyID IS NULL;
SELECT N'  permissions  = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM sec.Permission;
SELECT N'  role grants  = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM sec.RolePermission;
SELECT N'  designations = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM mst.Designation;
SELECT N'  uniform items= ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM mst.UniformItem;
SELECT N'  banks        = ' + CAST(COUNT(*) AS NVARCHAR(10)) FROM mst.Bank;
GO
