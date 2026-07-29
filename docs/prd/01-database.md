# Diti365 — Phase 1: Database Specification
**Engine:** Microsoft SQL Server 2019+ · **Migration tool:** DbUp · **Collation:** `SQL_Latin1_General_CP1_CI_AS`

> **Instruction to Cursor:** Generate the entire database in ONE ordered migration set under `db/scripts/`. Run order is strictly numeric. Every script must be idempotent (`IF NOT EXISTS` / `CREATE OR ALTER`). Do not use EF migrations for these objects.

```
db/
  scripts/
    001_schemas.sql
    010_master_tables.sql
    020_tenant_tables.sql
    030_people_tables.sql
    040_client_unit_tables.sql
    050_deployment_tables.sql
    060_attendance_tables.sql
    070_patrol_location_tables.sql
    080_task_tables.sql
    090_incident_complaint_tables.sql
    100_sales_tables.sql
    110_inventory_tables.sql
    120_payroll_billing_tables.sql
    130_comms_document_tables.sql
    140_audit_tables.sql
    200_indexes.sql
    300_functions.sql
    400_views.sql
    500_procedures_master.sql
    510_procedures_users.sql
    520_procedures_operation.sql
    530_procedures_tasks.sql
    540_procedures_sales.sql
    550_procedures_report.sql
    560_procedures_payroll.sql
    600_triggers.sql
    700_seed_reference.sql
    710_seed_demo_tenant.sql
    720_seed_demo_transactions.sql
  DbUp/  (console runner project)
```

---

## 1. Design Conventions

| Rule | Value |
|---|---|
| Schemas | `mst` (masters), `org` (tenant/company/branch), `hr` (people), `crm` (clients/sales), `ops` (deployment/attendance/patrol/tasks), `inv` (uniform/stock), `fin` (payroll/billing), `doc` (documents), `sec` (auth/security), `aud` (audit) |
| PK | `ID INT IDENTITY(1,1)` or `BIGINT` for high-volume logs; clustered on PK unless stated |
| Tenant key | `CompanyID INT NOT NULL` on every tenant-owned table, FK → `org.Company(CompanyID)` |
| Branch key | `BranchID INT NULL` where scoping applies |
| Audit columns | `InsertDate DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()`, `InsertUserID INT NULL`, `UpdateDate DATETIME2(0) NULL`, `UpdateUserID INT NULL` |
| Soft delete | `IsCancel BIT NOT NULL DEFAULT 0`, `IsApproved BIT NOT NULL DEFAULT 0`, `IsReject BIT NOT NULL DEFAULT 0` (this triplet already exists in the legacy models and is preserved) |
| Money | `DECIMAL(18,2)` |
| Lat/Long | `DECIMAL(10,7)` (plus a computed `GEOGRAPHY` column on unit/checkpoint tables for distance maths) |
| Dates | `DATE` for calendar dates, `DATETIME2(0)` for stamps, `TIME(0)` for shift times. **Store UTC**; convert at the edge using tenant timezone (`Asia/Kolkata` default) |
| Booleans | `BIT NOT NULL DEFAULT 0` |
| Strings | `NVARCHAR(n)`; never `TEXT`/`NTEXT` |
| Naming | Preserve legacy names exactly where they exist (`EmpID`, `UnitID`, `CompanyID`, `BeltNo`, `DesignationName`) so existing data migrates 1:1. New tables use PascalCase |
| No `SELECT *` in any SP | enforced by code review |
| Every SP | starts with `SET NOCOUNT ON;` and takes `@CompanyID INT` as its first parameter for tenant-owned data |
| Every SP | wraps writes in `BEGIN TRY / BEGIN TRAN … COMMIT / CATCH → ROLLBACK; THROW;` |

### 1.1 Reconciliation note
The legacy production database exists. This document reconstructs it from the mobile app's DTOs and endpoint list. **Before P1 sign-off, run a schema diff against production and treat production as authoritative for any conflict.** Columns marked `[NEW]` are additions required by v1.0 features.

---

## 2. Table Catalogue

### 2.1 `sec` — Authentication & Security

#### `sec.Users`
| Column | Type | Notes |
|---|---|---|
| UserID | INT IDENTITY PK | |
| CompanyID | INT FK org.Company | NULL only for SUPER_ADMIN |
| BranchID | INT NULL FK org.Branch | |
| EmpID | INT NULL FK hr.Employee | set when the user is a guard/supervisor |
| ClientID | INT NULL FK crm.Client | set when the user is a client login |
| UserName | NVARCHAR(100) | unique per company |
| MobileNo | NVARCHAR(15) | login identifier used by the app |
| EmailID | NVARCHAR(150) NULL | |
| PasswordHash | NVARCHAR(500) | PBKDF2 |
| PasswordSalt | NVARCHAR(200) | |
| LegacyPasswordHash | NVARCHAR(500) NULL | `[NEW]` for one-time migration |
| MustChangePassword | BIT | |
| LoginType | INT | FK `mst.LoginType` — mirrors legacy `Loginmodel.LoginType` |
| RoleID | INT FK sec.Role | |
| DeviceID | NVARCHAR(200) NULL | device binding (legacy `checkdeviceid`) |
| DeviceModel | NVARCHAR(120) NULL | `[NEW]` |
| FcmToken | NVARCHAR(500) NULL | legacy `updatetoken` |
| PhotoUrl | NVARCHAR(500) NULL | |
| IsActive / IsLocked | BIT | |
| FailedLoginCount | INT | lockout after 5 |
| LastLoginAt | DATETIME2 NULL | |
| ExpiresOn | DATE NULL | licence expiry (legacy `checkexpire` / `Expirymodel`) |
| audit cols | | |

#### `sec.Role`, `sec.Permission`, `sec.RolePermission`
- `Role(RoleID, CompanyID NULL, RoleCode, RoleName, IsSystem)` — the 12 role codes in PRD §2.1 seeded as `IsSystem=1`, tenants may clone.
- `Permission(PermissionID, Module, Code, Name)` — codes shaped `M{n}.{Entity}.{Action}` e.g. `M8.Attendance.Approve`.
- `RolePermission(RoleID, PermissionID, CanView, CanCreate, CanEdit, CanDelete, CanApprove, CanExport)` — backs the legacy `getrights` endpoint.

#### `sec.UserBranch` — many-to-many for multi-branch users `[NEW]`
#### `sec.RefreshToken` `[NEW]` — `(TokenID, UserID, TokenHash, ExpiresAt, RevokedAt, ReplacedByTokenHash, CreatedByIp, DeviceID)`
#### `sec.LoginLog` — `(LoginLogID BIGINT, CompanyID, UserID, LoginAt, LogoutAt, IpAddress, DeviceID, AppVersion, Platform, IsSuccess, FailReason)` — backs `getLoginLog`, `getCompanylog`, `getCompanylogdetail`.
#### `sec.Otp` — `(OtpID, MobileNo, OtpHash, Purpose, ExpiresAt, AttemptCount, ConsumedAt)` — backs `checknum` / `Enterotp_act`.

---

### 2.2 `org` — Tenant

#### `org.Company` (the agency tenant)
`CompanyID PK, CompanyName NVARCHAR(200), CompanyCode NVARCHAR(30) UNIQUE, CompanyAddress NVARCHAR(500), CityID, StateID, Pin, Mobile, Email, GSTIN NVARCHAR(15), PAN, PFCode, ESICCode, LicenceNo (PSARA), LicenceExpiry DATE, LogoUrl, ThemeColor [NEW], TimeZone NVARCHAR(50) DEFAULT 'India Standard Time' [NEW], PlanID [NEW], UserCount INT, MaxUsers INT, LoginCount INT, IsExpired BIT, ExpiryDate DATE, IsActive BIT, audit`
> Maps directly to legacy `Companymodel$Datum` (CompanyID, CompanyName, CompanyAddress, Mobile, UserCount, LoginCount, IsExpired) and `Newmembermodel$Datum`.

#### `org.Branch`
`BranchID PK, CompanyID, BranchName, BranchCode, Address, CityID, StateID, RegionID, AreaID, ContactPerson, Mobile, IsHeadOffice BIT, IsActive, audit`

#### `org.Plan` `[NEW]` — `(PlanID, PlanName, MaxUsers, MaxUnits, PricePerUserMonth, Features NVARCHAR(MAX) JSON)`
#### `org.CompanyModule` `[NEW]` — `(CompanyID, ModuleCode, IsEnabled)` — feature flags per tenant.
#### `org.CompanySetting` `[NEW]` — `(CompanyID, SettingKey, SettingValue)` — geofence radius, attendance cut-off time, OT rules, selfie mandatory Y/N, patrol grace minutes, etc.

---

### 2.3 `mst` — Master Data
All masters carry `CompanyID NULL` — `NULL` means a global/platform master; a non-null value is a tenant override.

| Table | Key columns |
|---|---|
| `mst.Country` | CountryID, CountryName, IsoCode |
| `mst.State` | StateID, CountryID, StateName, StateCode, GstStateCode, CmpAddress, GSTIN, IsApproved, IsCancel, IsReject — *matches legacy `Getstatesmodel$Datum` exactly* |
| `mst.District` | DistrictID, StateID, DistrictName |
| `mst.City` | CityID, DistrictID, StateID, CityName, PhotoUrl — *matches `Getcitymodel$Datum` (ID, Name, PhotoUrl)* |
| `mst.Region` | RegionID, CompanyID, RegionName |
| `mst.Area` | AreaID, RegionID, AreaName |
| `mst.Designation` | DesignationID, CompanyID, DesignationName, GradeID, IsGunmanRole BIT, SortOrder |
| `mst.Grade` | GradeID, GradeName |
| `mst.Category` | CategoryID, CategoryName (Unskilled/Semi-skilled/Skilled/Highly-skilled — drives minimum wage) |
| `mst.Qualification` | QualificationID, QualificationName, IsApproved, IsCancel, IsReject — *matches `Getqualificationmodel$Datum`* |
| `mst.Shift` | ShiftID, CompanyID, ShiftName, StartTime, EndTime, IsNight BIT, GraceInMinutes, GraceOutMinutes, HalfDayHours, FullDayHours |
| `mst.Bank` | BankID, BankName |
| `mst.IfscCode` | IfscCodeID, BankID, IFSCcode, BranchName, Address |
| `mst.ComplaintType` | ComplaintTypeID, CompanyID, ComplaintTypeName, DefaultSlaHours `[NEW]` |
| `mst.IncidentType` | IncidentTypeID, CompanyID, IncidentTypeName, Severity `[NEW]` |
| `mst.ServiceType` | ServiceTypeID, ServiceName (Security Guard, Gunman, Housekeeping, Supervisor…) |
| `mst.UniformItem` | ItemID, CompanyID, ItemName, Rate, Uom, ReturnableBit — *matches `Uniformitemmodel$Datum` (ItemID, ItemName, Rate)* |
| `mst.TaskRepetition` | RepetitionID, Name (None/Daily/Weekly/Monthly/Quarterly), IntervalDays |
| `mst.TaskStatus` | TaskStatusID, Name (Pending/In-Progress/On-Hold/Completed/Closed/Rejected), ColorHex |
| `mst.Priority` | PriorityID, Name (Low/Medium/High/Critical), ColorHex |
| `mst.LoginType` | LoginTypeID, Name — the role→dashboard router used by `Loginmodel.LoginType` |
| `mst.Holiday` `[NEW]` | HolidayID, CompanyID, StateID NULL, HolidayDate, HolidayName, IsPaid |
| `mst.MinimumWage` `[NEW]` | MinWageID, StateID, CategoryID, EffectiveFrom, BasicPerDay, VdaPerDay, HraPercent |
| `mst.StatutoryRate` `[NEW]` | RateID, RateCode (PF_EMP, PF_ER, ESIC_EMP, ESIC_ER, EDLI, ADMIN_CHG), EffectiveFrom, Percent, CeilingAmount |
| `mst.PtSlab` / `mst.LwfSlab` `[NEW]` | StateID, FromAmount, ToAmount, Amount, EffectiveFrom |
| `mst.DocumentType` `[NEW]` | DocTypeID, DocTypeName (Aadhaar, PAN, DL, Voter, PF, ESIC, Police Verification, Medical, Gun Licence, Photo, Signature, Passbook), IsMandatory, HasExpiry |

---

### 2.4 `hr` — People

#### `hr.Employee` — the master record (this is the big one)
The legacy `Addrecruitmodel$Datum` carries **196 fields**. They are kept but normalised into a core table plus five satellites.

**`hr.Employee` (core):**
`EmpID PK, CompanyID, BranchID, EmpCode UNIQUE-per-company, OldEmpCode, Salutation, FirstName, Middlename, LastName, EmpFullName (PERSISTED COMPUTED), Gender, Dob DATE, BirthPlace, Bloodgroup, Nationality, OtherNationality, Married BIT, SpouseName, Mobile1, Mobile2, EmailId1, EmailId2, DesignationID, GradeID, CategoryID, ShiftID, UnitID, Clientid, RegionID, AreaID, Employeetype, EmpStatus, Doj DATE, Dol DATE, DateofLeft DATE, LeftReason, DoDeployment DATE, BeltNo, CardNo, SwipeNo, IdCardNo, IdCardIssueDate, IdCardExpireDate, Photo, Selfie, EmpSign, IdentitySign, IsPermanent, IsGunman, IsReliever, IsExService, IsNotBilling, IsApproved, IsReject, IsCancel, IsBlackListed, BlackListedDate, BlackListedReason, IsApplyEmpSalaryStructure, Isform11pf, Isformfullfinal, Comments, Userid, audit`

**`hr.EmployeeAddress`** — `EmpID, AddressType(P=Permanent/R=Present), Address1, Address2, City, StateID, DistrictID, Pin, Telephone, AddressDuration, ForeignAddress`
*(legacy: Paddress1/2, Pcity, pStateID, pDistrictID, Ppin, Ptelephone vs Praddress1/2, Prcity, PrStateID, PrDistrictID, Prpin, Prtelephone)*

**`hr.EmployeeFamily`** — `FamilyID, EmpID, Relation(Father/Mother/Wife/Child/Nominee), Name, Dob, Occupation, Dependent BIT, SharePercent, AadhaarNo`
*(legacy: FatherName, FatherDob, Mothername, MotherDob, Wifename, WifeDob, Dependent)*

**`hr.EmployeePhysical`** — `EmpID, Height, Weight, Chest, Waist, Shoesize, Trousersize, TshirtSize, EmployeeEyes, IdentificationMark`

**`hr.EmployeeStatutory`** — `EmpID, AdharCardNo, PanCardNo, Pan, VoterId, DlNo, UANNo, PFNo, ESICNo, Percentage, PaymentMode, BankForSalary`

**`hr.EmployeeBank`** — `BankAccountID, EmpID, IsJoint BIT, BankID, BankName, BranchName, BankAcNo, IFSCcode, IfscCodeId, AcType, NameInBankPassbook, NameInBankPassbookLast, JointAcName, JointAcNo, JointBankId, JointBankName, JointBranchName, JointIfscCodeId, BankPassbook (doc url), Cheque (doc url), IsBankAdded, BankAddedDate, BankAddedUserId`

**`hr.EmployeeQualification`** — `EmpQualID, EmpID, QualificationID, AddQualificationID, InstituteName, HigestEducationInstitue, ProfessionalQualification, PassingYear, Percentage`

**`hr.EmployeeExService`** — `EmpID, ServiceSno, Rank, Regiment, Dateofdischarge, Criminology, CharacterAssessed`

**`hr.EmployeeVerification`** — `EmpID, IsPoliceVerification, PoliceVerificationNo, PoliceStationName, RemarkByThana, Pvsenddate, Pvreturndate, PVValidUpTo, VerificationDate, PoliceCertificateImg, NotaryStampPadNo`

**`hr.EmployeeMedical`** — `EmpID, MedicalDate, MedicalCertificateIssue, MedicalCertificateIssueDate, MedicalCertificateImg, Hospital, Doctorname, DoctorRegNo, DoctorQualification, DoctorDesignation, DoctorAddress, DoctorPhoneNo`

**`hr.EmployeeGunLicence`** — `EmpID, GunanType, TypeArm, GunNo, GunModelNum, LicenseNo, Licenseexpire, LicenseProduce, AreaID, AreainLicensevalid, IssueDate, Wcpno, Wcpamount, Wcpexpdate`

**`hr.Recruit`** — pre-hire pipeline: `RecruitID, CompanyID, BranchID, Name, Mobile, Dated, SourceBy, DesignationID, Status(New/Screened/Verified/Approved/Rejected/Waitlist/Converted), EmpID NULL (set on conversion), Remark, audit` — backs `Recruitmodel$Datum (Dated, Mobile, Name)`, `getpendingrecruit`, `getNewRecruits`, `Waitlist_frag`.

**`hr.EmployeeStatusHistory`** — `HistoryID, EmpID, EventType(Join/Resign/Left/Rejoin/Transfer/Blacklist/Unblacklist), EventDate, FromUnitID, ToUnitID, Remark, DocUrl, ApprovedBy, audit` — backs `resign`, `insertleft`, `insertrejoin`, `Resignmodel$Datum`.

**`hr.Training`** — `TrainingID, CompanyID, UnitID, TrainerEmpID, Dated, Timing, Nop, Topic, Remark, PhotoUrl` — matches `Trainingmodel$Datum (Dated, Nop, Remark, Timing, UnitName)`.
**`hr.TrainingAttendee`** — `TrainingID, EmpID, IsPresent, Score`

**`hr.EmployeeRequest`** — `RequestID, CompanyID, EmpID, RequestType(Leave/Advance/Transfer/Uniform/Other), FromDate, ToDate, Amount, Reason, Status, ApprovedBy, ApprovedOn, Remark` — backs `insertrequest`.
**`hr.Suggestion`** — `SuggestionID, CompanyID, EmpID, Subject, Description, InsertDate` — backs `insertsuggestion`.

---

### 2.5 `crm` — Clients, Units, Sales

**`crm.Client`** — `ClientID PK, CompanyID, BranchID, ClientName, ClientCode, CompanyAddress, CityID, StateID, Pin, GSTIN, PAN, ContactPerson, ContactNo, Email, IsActive, IsExpired, audit`
**`crm.ClientContact`** — `ContactID, ClientID, ContactPerson, Designation, MobileNo, Email, IsPrimary`
**`crm.Unit`** (client site) — `UnitID PK, CompanyID, BranchID, ClientID, UnitName, UnitCode, Address, CityID, StateID, Pin, Latitude, Longitude, GeofenceRadiusMeters [NEW], AgreementNo, AgreementExpDate, OrderNo, OrderDate, OrderExpiryDate, WorkStartDate, BillingCycle, IsActive, audit` — matches `Unitmodel$Datum` exactly.
**`crm.UnitPost`** `[NEW]` — `PostID, UnitID, PostName, DesignationID, ShiftID, RequiredStrength, RatePerGuard, IsArmed` — this is what makes turnout "required vs present" computable.
**`crm.UnitLocation`** — `LocationID, UnitID, LocationName, Latitude, Longitude, Description` — backs `Addclientlocation_act` / `addsite` / `updatesite`.
**`crm.ClientRelationVisit`** — `VisitID, CompanyID, UnitID, ExecutiveEmpID, ContactPerson, MobileNo, Dated, Timing, Remark` — matches `ClientRelationmodel$Datum`.
**`crm.SalesVisit`** — `VisitID, CompanyID, EmpID, CompanyName, ContactPerson, ContactNo, Location, Latitude, Longitude, Purpose, Remark, VisitDate, PhotoUrl` — matches `Visitmodel$Datum`.
**`crm.FollowUp`** — `FollowupID, CompanyID, SalesVisitID NULL, EmpID, CompanyName, ContactPerson, ContactNo, Location, Purpose, FollowupDate, NextFollowupDate, Remark, StopFollow BIT` — matches `Followupmodel$Datum`.
**`crm.Contract`** — `ContractID, CompanyID, ClientID, UnitID, ContractType(New/Renewal/Termination/Temporary), Dated, Nop, Timing, Remark, EffectiveFrom, EffectiveTo, Status` — backs `Newcontractmodel`, `Contractmodel`, `newcontractDeployment`, `contractTermination`.

---

### 2.6 `ops` — Deployment, Attendance, Patrol, Location, Tasks

**`ops.Deployment`** — `DeploymentID, CompanyID, UnitID, PostID, EmpID, ShiftID, DesignationID, FromDate, ToDate, IsReliever BIT, RelieverForEmpID NULL, Status(Active/Moved/Ended), Remark, audit`
**`ops.DeploymentChange`** (IncDec) — `ChangeID, CompanyID, UnitID, ChangeType(Increase/Decrease), Dated, Timing, Nop, Remark, Status, ApprovedBy` — matches `Incdecmodel$Datum`.
**`ops.Movement`** — `MovementID, CompanyID, EmpID (GuardName), FromUnitID, ToUnitID, PostName, MovementDate, MovementTime, InstructionBy, Remark` — matches `Movementmodel$Datum`.
**`ops.TemporaryEvent`** — `EventID, CompanyID, UnitID, TypeOfService, StartDate, EndDate, StartTime, EndTime, NOP, Remark` — matches `Eventmodel$Datum`.
**`ops.Turnout`** — `TurnoutID, CompanyID, UnitID, TurnoutDate, ShiftID, RequiredNos, PresentNos, AbsentNos, RelieverNos, VacantNos, EnteredBy, Remark` and **`ops.TurnoutDetail`** — `(TurnoutID, EmpID, EmpName, Status)` — matches `Turnoutmodel$Datum (EmpId, EmpName, UnitName)`; backs `insertturnout`, `getturnoutrpt`.

**`ops.Attendance`** — the core transactional table (partition-ready)
| Column | Type | Notes |
|---|---|---|
| AttendanceID | BIGINT IDENTITY PK | |
| CompanyID, BranchID, UnitID, PostID, EmpID, ShiftID | INT | |
| AttendanceDate | DATE | |
| InTime / OutTime | DATETIME2(0) NULL | |
| InLatitude/InLongitude/OutLatitude/OutLongitude | DECIMAL(10,7) | |
| InDistanceMeters / OutDistanceMeters | INT | computed vs unit geofence `[NEW]` |
| InSelfieUrl / OutSelfieUrl | NVARCHAR(500) | |
| Status | CHAR(2) | P, A, HD, WO, HO, LV, DS (double shift) |
| WorkedHours / OtHours | DECIMAL(5,2) | |
| Source | TINYINT | 1=SelfPunch 2=Supervisor 3=Biometric 4=Import |
| IsOffline BIT, ClientPunchAt DATETIME2, SyncedAt DATETIME2 | | `[NEW]` offline outbox reconciliation |
| ApprovalStatus | TINYINT | 0=Pending 1=Approved 2=Rejected |
| ApprovedBy, ApprovedOn, RejectReason | | |
| DeviceID, AppVersion | | |
| audit | | |

Unique index: `UX_Attendance (CompanyID, EmpID, AttendanceDate, ShiftID)` — prevents duplicate punches; offline replays are idempotent on `ClientRequestId UNIQUEIDENTIFIER` `[NEW]`.

**`ops.AttendanceSummary`** (monthly rollup, refreshed by job) — `CompanyID, EmpID, MonthYear, PresentDays, AbsentDays, HalfDays, WeekOff, Holidays, LeaveDays, OtHours, DoubleShifts` — backs `getattendsummary`, `getAttendanceCount`.

**`ops.QrCheckpoint`** — `QrID, CompanyID, UnitID, LocationID NULL, QrCode (GUID string, unique), Name, Location, Latitude, Longitude, MaxDistanceMeters, Photo, Remark, IsActive, audit` — matches `Qrmodel$Datum`, backs `addclientqr`, `getqrlist`, `getqrdistance`.
**`ops.QrScanLog`** — `ScanID BIGINT, CompanyID, QrID, UnitID, EmpID, Scantime, Latitude, Longitude, DistanceMeters, ImageUrl, Remark, IsWithinRange BIT, RoundNo, audit` — backs `readqr`, `readqrwithimage`, `getqrlistadmin`, `getqrlistsummary`.
**`ops.PatrolRound`** `[NEW]` — `RoundID, CompanyID, UnitID, RoundName, StartTime, EndTime, ExpectedCheckpoints INT, GraceMinutes` + **`ops.PatrolRoundCheckpoint`** `(RoundID, QrID, SequenceNo)` — enables missed-round alerts.

**`ops.LocationLog`** — `LogID BIGINT, CompanyID, UserID, EmpID, Latitude, Longitude, Accuracy, Speed, BatteryLevel, LoggedAt, Source(FG/BG), IsMockLocation BIT` — backs `trackLocation`, `getlocationlog`, `getuserlocationlog`, `trackRpt`. **Partition by month; retention 90 days.**

**`ops.Task`** — `TaskID, CompanyID, Heading, Description, Assignedby, Assignedto, StartDate, EndDate, StartTime, EndTime, DueDays, PriorityID, RepetitionId, TaskStatusID, Attachment, Isclosed BIT, Isread BIT, Important BIT, ParentTaskID NULL, audit` — matches `Tasklistsmodel$Datum` / `Addtaskmodel$Datum`.
**`ops.TaskStatusHistory`** — `HistoryID, TaskID, FromStatusID, ToStatusID, ChangedBy, ChangedOn, Remark, Attachment` — backs `Statushistory_act`, `closetaskhistorylist`.
**`ops.TaskChecklist`** `[NEW]` — `(ChecklistID, TaskID, ItemText, IsDone, DoneBy, DoneOn)` — backs `getuserchecklists`.

**`ops.Incident`** — `IncidentID, CompanyID, UnitID, EmpID, BeltNo, FullName, IncidentTypeID, IncidentDate, IncidentTime, Severity, Remark, ActionTaken, PhotoUrl, ReportedBy, IsClosed` — matches `Incidentmodel$Datum`.
**`ops.FieldReport`** — `ReportID, CompanyID, UnitID, SupervisorEmpID, Createdate, ContactPerson, Remark, Latitude, Longitude, PhotoUrl` + **`ops.FieldReportDetail`** `(ReportID, EmpID, Name, DesignationName, Joindate, Photo, Remark)` — matches `Fieldrptdetailmodel$Datum`; backs `insertfield`, `getrptdetail`.
**`ops.Complaint`** — `ComplaintID, CompanyID, UnitID, ClientID, RaisedByUserID, ComplaintTypeID, Description, InsertDate, AssignedToEmpID, DueOn, IsClosed BIT, ClosedOn, ClosureRemark, Status` — matches `Complaintmodel$Datum`.
**`ops.ComplaintHistory`** — `(HistoryID, ComplaintID, Status, Remark, ChangedBy, ChangedOn)`.
**`ops.GatePass`** — `GatePassID, CompanyID, UnitID, Dated, Name, MobileNo, Purpose, VehicleNo, VisitorImage, WhomToMeet, InTime, OutTime, MaterialDetails, EnteredByEmpID` — matches `Gatepassmodel$Datum`.

---

### 2.7 `inv` — Uniform & Stock

**`inv.Stock`** — `StockID, CompanyID, BranchID, ItemID, Opstock, Qty (on hand), MinLevel` — matches `Stockmodel$Datum (ItemName, Opstock, Qty)`.
**`inv.StockTxn`** — `TxnID, CompanyID, BranchID, ItemID, TxnType(Purchase/Issue/Return/Adjust/Damage), Qty, Rate, Amount, EmpID NULL, TxnDate, RefNo, Remark, audit`
**`inv.EmployeeIssue`** — `IssueID, CompanyID, EmpID, ItemID, IssuedQty, RecievedQty, IssueDate, ReturnDate, Rate, RecoverInSalary BIT, RecoveredAmount` — matches `Ledgermodel$Datum (ItemName, IssuedQty, RecievedQty)`; backs `issueitem`, `issueemployee`, `returnitem`, `returnemployee`, `GetUniformLedger`.

---

### 2.8 `fin` — Payroll & Billing

**`fin.SalaryStructure`** — `StructureID, CompanyID, EmpID, EffectiveFrom, BasicWages, HRAAmt, FoodAllow, LeaveAllow, ReliverAllow, SpAllowance, MixOther, OtRatePerHour, IsPfApplicable, IsEsicApplicable, IsPtApplicable, IsLwfApplicable`
**`fin.SalaryRun`** — `RunID, CompanyID, BranchID, MonthYear CHAR(7), Status(Draft/Locked/Paid), GeneratedBy, GeneratedOn, LockedOn, TotalNetPayable`
**`fin.Salary`** — `WcsSalaryID PK, RunID, CompanyID, EmpID, UnitID, ClientName, MonthYear, PresentDays, PayableDays, BasicWages, HRAAmt, FoodAllow, LeaveAllow, ReliverAllow, SpAllowance, BonusAmt, MixOther, OtAmount, TotalEarnings, PFAmt, ESICAmt, PtEmp, LwfEmp, AdvanceDeduction, UniformDeduction, OtherDeduction, DeductionAmt, NetPayble, PaymentMode, PaidOn, UtrNo` — **column names taken verbatim from `Salaryslipmodel$Datum`.**
**`fin.Advance`** — `AdvanceID, CompanyID, EmpID, Amount, IssueDate, Reason, InstallmentAmount, BalanceAmount, ApprovedBy, Status` — backs `insertadvance`.
**`fin.Invoice`** — `Bid PK, CompanyID, ClientID, UnitID, Month, Year, InvoiceNo, InvoiceDate, DueDate, TaxableAmount, CgstAmt, SgstAmt, IgstAmt, GrandTotal, Status(Draft/Sent/PartPaid/Paid/Overdue), PdfUrl` — matches `Showbillmodel$Datum (Bid, GrandTotal, Month, Year)`.
**`fin.InvoiceLine`** — `LineID, Bid, UnitID, PostID, DesignationName, ManDays, RatePerManDay, Amount, Description, HsnSac`
**`fin.Receipt`** `[NEW]` — `ReceiptID, CompanyID, ClientID, Bid, Amount, ReceivedOn, Mode, RefNo`

---

### 2.9 `doc` — Documents & Communication

**`doc.Document`** — `DocumentID, CompanyID, OwnerType(Employee/Unit/Client/Company/Incident/Task), OwnerID, DocTypeID, DocumentFilename, BlobUrl, MimeType, SizeBytes, IssueDate, ExpiryDate, IsVerified, VerifiedBy, VerifiedOn, Remark, audit` — backs `uploaddoc`, `docdetail`, `Documentupload_act`, `Documentdetails_act`.
**`doc.DocumentExpiryAlert`** `[NEW]` — `(AlertID, DocumentID, AlertOn, AlertLevel, IsSent, SentOn)`.
**`doc.ChatThread`** / **`doc.ChatMessage`** — `MessageID BIGINT, ThreadID, CompanyID, FromUserID, ToUserID, Body, MessageType(Text/Image/File/Location), AttachmentUrl, SentAt, ReadAt` — replaces the Firebase Realtime DB chat; matches `Messagemodel (Id, Message, Name, Read, Timestamp, Type)`.
**`doc.Notification`** — `NotificationID BIGINT, CompanyID, UserID, Title, Body, DataJson, Category, IsRead, ReadAt, SentAt, FcmMessageId`.

---

### 2.10 `aud` — Audit

**`aud.AuditLog`** — `AuditID BIGINT, CompanyID, UserID, TableName, RecordID, Action(I/U/D), OldValues NVARCHAR(MAX) JSON, NewValues NVARCHAR(MAX) JSON, ChangedAt, IpAddress, UserAgent`. Written by triggers on all financial and people tables (see §6).
**`aud.ImpersonationLog`** — `(LogID, SuperAdminUserID, TargetCompanyID, TargetUserID, StartedAt, EndedAt, Reason)`.
**`aud.ApiRequestLog`** — `(LogID BIGINT, TraceId, CompanyID, UserID, Method, Path, StatusCode, DurationMs, RequestedAt)` — 30-day retention.

---

## 3. Indexing Strategy (`200_indexes.sql`)

Mandatory covering indexes — every one leads with `CompanyID`:

```sql
CREATE INDEX IX_Attendance_Company_Date_Unit ON ops.Attendance (CompanyID, AttendanceDate, UnitID)
    INCLUDE (EmpID, Status, ApprovalStatus, InTime, OutTime, WorkedHours);
CREATE INDEX IX_Attendance_Company_Emp_Date  ON ops.Attendance (CompanyID, EmpID, AttendanceDate DESC)
    INCLUDE (Status, ShiftID, ApprovalStatus);
CREATE INDEX IX_Attendance_Approval_Queue    ON ops.Attendance (CompanyID, ApprovalStatus, AttendanceDate)
    WHERE ApprovalStatus = 0;
CREATE INDEX IX_QrScan_Company_Time          ON ops.QrScanLog (CompanyID, Scantime DESC) INCLUDE (QrID, EmpID, UnitID, IsWithinRange);
CREATE INDEX IX_LocationLog_User_Time        ON ops.LocationLog (CompanyID, UserID, LoggedAt DESC);
CREATE INDEX IX_Task_AssignedTo_Status       ON ops.Task (CompanyID, Assignedto, TaskStatusID, EndDate);
CREATE INDEX IX_Task_AssignedBy              ON ops.Task (CompanyID, Assignedby, InsertDate DESC);
CREATE INDEX IX_Employee_Company_Unit_Status ON hr.Employee (CompanyID, UnitID, EmpStatus) INCLUDE (EmpCode, FirstName, LastName, DesignationID, Mobile1);
CREATE UNIQUE INDEX UX_Employee_Company_EmpCode ON hr.Employee (CompanyID, EmpCode) WHERE IsCancel = 0;
CREATE INDEX IX_Deployment_Unit_Active       ON ops.Deployment (CompanyID, UnitID, Status) INCLUDE (EmpID, ShiftID, PostID);
CREATE INDEX IX_Complaint_Open               ON ops.Complaint (CompanyID, IsClosed, InsertDate DESC);
CREATE INDEX IX_Document_Expiry              ON doc.Document (CompanyID, ExpiryDate) WHERE ExpiryDate IS NOT NULL;
CREATE INDEX IX_Salary_Run                   ON fin.Salary (RunID, EmpID) INCLUDE (NetPayble, TotalEarnings, DeductionAmt);
CREATE INDEX IX_FollowUp_Next                ON crm.FollowUp (CompanyID, NextFollowupDate) WHERE StopFollow = 0;
```

Additional: filtered index on `sec.Users (CompanyID, MobileNo) WHERE IsActive=1`; `ops.LocationLog` and `ops.QrScanLog` use **monthly partition schemes** (`PS_ByMonth` on `PF_ByMonth`).

---

## 4. Functions (`300_functions.sql`)

| Function | Type | Purpose |
|---|---|---|
| `dbo.fnDistanceMeters(@lat1,@lon1,@lat2,@lon2)` | scalar | Haversine in metres — used for geofence and QR distance checks |
| `dbo.fnIsWithinGeofence(@lat,@lon,@unitId)` | scalar BIT | wraps the above against `crm.Unit.GeofenceRadiusMeters` |
| `dbo.fnCalcWorkedHours(@in,@out,@shiftId)` | scalar DECIMAL | shift-aware, handles night shifts crossing midnight |
| `dbo.fnAttendanceStatus(@workedHours,@shiftId)` | scalar CHAR(2) | P / HD / A per shift's HalfDayHours & FullDayHours |
| `dbo.fnPayableDays(@empId,@monthYear)` | scalar DECIMAL | present + paid holidays + weekly offs + paid leave |
| `dbo.fnPfAmount(@basic,@effectiveDate)` | scalar | applies ceiling from `mst.StatutoryRate` |
| `dbo.fnEsicAmount(@gross,@effectiveDate)` | scalar | with wage ceiling cut-off |
| `dbo.fnPtAmount(@gross,@stateId,@date)` | scalar | slab lookup |
| `dbo.fnLwfAmount(@stateId,@monthYear)` | scalar | periodic (usually June/December) |
| `dbo.fnAgeInYears(@dob,@asOn)` | scalar | recruit eligibility (18–60) |
| `dbo.fnGenerateEmpCode(@companyId,@branchId)` | scalar | next sequential code, concurrency-safe with `sp_getapplock` |
| `dbo.fnNextInvoiceNo(@companyId,@fy)` | scalar | GST-safe sequential invoice numbering |
| `dbo.fnSplitIds(@csv NVARCHAR(MAX))` | TVF | CSV → table of INT (used everywhere the app posts comma-joined IDs) |
| `dbo.fnDateRange(@from,@to)` | TVF | calendar spine for attendance registers |
| `dbo.fnUnitRequiredStrength(@unitId,@date,@shiftId)` | TVF | contracted strength incl. temporary events and IncDec changes |
| `dbo.fnUserAccessibleUnits(@companyId,@userId)` | TVF | **security-critical** — every report SP joins to this |
| `dbo.fnUserAccessibleBranches(@companyId,@userId)` | TVF | as above |

---

## 5. Views (`400_views.sql`)

| View | Purpose |
|---|---|
| `dbo.vwEmployeeFull` | Employee joined to designation, unit, client, branch, shift — the list/search backbone |
| `dbo.vwActiveDeployment` | Current active deployment per employee with post & shift |
| `dbo.vwDailyTurnout` | Per unit/date/shift: required, present, absent, reliever, vacant |
| `dbo.vwAttendanceRegister` | Employee × date matrix for the month (feeds `PrintDailAttendance` replacement) |
| `dbo.vwPendingApprovals` | Attendance + recruits + requests + advances awaiting approval, unioned with a `Kind` discriminator |
| `dbo.vwQrPatrolSummary` | Unit/date/round: expected vs scanned vs missed |
| `dbo.vwOpenComplaints` | Open complaints with ageing buckets and SLA breach flag |
| `dbo.vwDocumentExpiry` | Documents expiring in 0/30/60/90 days with owner name |
| `dbo.vwSalesPipeline` | Visits → follow-ups → contracts funnel per executive |
| `dbo.vwUniformLedger` | Per employee: issued, returned, outstanding qty and value |
| `dbo.vwInvoiceAgeing` | Client outstanding with 0-30/31-60/61-90/90+ buckets |
| `dbo.vwDashboardCounts` | Single-row-per-company counts powering `getcount` / `Reportcountmodel` |

---

## 6. Triggers (`600_triggers.sql`)

1. **Audit triggers** (`TR_{table}_Audit` AFTER INSERT/UPDATE/DELETE) on: `hr.Employee`, `hr.EmployeeBank`, `ops.Attendance`, `ops.Deployment`, `fin.Salary`, `fin.Advance`, `fin.Invoice`, `sec.Users`, `sec.RolePermission`, `crm.Unit`, `crm.Contract` → write JSON old/new into `aud.AuditLog`. Use `INSERTED`/`DELETED` with `FOR JSON PATH`.
2. **`TR_Attendance_Distance`** (INSTEAD OF INSERT/UPDATE on `ops.Attendance`) — computes `InDistanceMeters`/`OutDistanceMeters` via `fnDistanceMeters` and sets `Status`/`WorkedHours` via the functions above, so the value can never be spoofed by the client.
3. **`TR_QrScanLog_Range`** (AFTER INSERT) — sets `IsWithinRange` from `fnDistanceMeters` vs `QrCheckpoint.MaxDistanceMeters`; raises a notification row when out of range.
4. **`TR_Users_UserCount`** (AFTER INSERT/DELETE on `sec.Users`) — maintains `org.Company.UserCount` and blocks inserts beyond `MaxUsers` with `THROW 51001`.
5. **`TR_Document_ExpiryAlert`** (AFTER INSERT/UPDATE on `doc.Document`) — seeds `doc.DocumentExpiryAlert` rows at T-90/T-30/T-7.
6. **`TR_Salary_LockGuard`** (INSTEAD OF UPDATE/DELETE on `fin.Salary`) — rejects any change when the parent `fin.SalaryRun.Status <> 'Draft'`.

> No trigger may contain a `SELECT` that returns a result set. All triggers must handle multi-row DML.

---

## 7. Stored Procedures

**Naming:** `usp_{Module}_{Action}` — e.g. `usp_Attendance_InsertPunchIn`. Legacy compatibility SPs keep their original names where they exist.

Every SP: `SET NOCOUNT ON`, `@CompanyID INT` first, `@UserID INT` second, returns the legacy shape `(Success BIT, Status INT, Id INT, Message NVARCHAR(500))` as the first result set for v1 endpoints and the data as the second.

### 7.1 `510_procedures_users.sql` — Auth, profile, masters
| SP | Backs endpoint |
|---|---|
| `usp_User_Login` | `Users/login` — validates credentials, device binding, expiry, returns `Loginmodel$Datum` (AttendanceCount, BranchID, Companyid, Designation, Deviceid, EmpCode, Employeetype, Firstname, Id, Lastname, LoginType, MobileNo, Name, PhotoUrl, TokenNo, Unit) |
| `usp_User_CheckMobile` | `checknum` |
| `usp_User_GenerateOtp` / `usp_User_VerifyOtp` | OTP flow |
| `usp_User_ChangePassword` | `changepass` |
| `usp_User_ForgotPassword` | `Forgotpass_act` |
| `usp_User_CheckDeviceId` | `checkdeviceid` → `Deviceidmodel` |
| `usp_Company_CheckExpiry` | `checkexpire` → `Expirymodel` |
| `usp_User_UpdateFcmToken` | `updatetoken` |
| `usp_User_GetRights` | `getrights` — returns the permission matrix for the role |
| `usp_User_GetProfile` | `getprofile` → `Profilemodel$Datum` |
| `usp_User_GetUserList` / `usp_User_GetUserLists` | `getuserlists`, `Userlist_act` |
| `usp_User_GetLoginLog` | `getLoginLog` |
| `usp_Company_GetLog` / `usp_Company_GetLogDetail` | `getCompanylog`, `getCompanylogdetail` |
| `usp_Master_GetStates` / `GetCity` / `GetDesignation` / `GetQualification` / `GetComplaintType` / `GetType` / `GetSubDropdown` / `GetList` | `getstates`, `getcity`, `getdesignation`, `getqualification`, `getcomplaintype`, `gettype`, `getsubdropdown`, `getlist` |

### 7.2 `520_procedures_operation.sql` — the largest file
| SP | Backs endpoint |
|---|---|
| `usp_Recruit_Insert` / `_Update` / `_GetPending` / `_GetList` / `_GetData` | `addrecruits`, `updaterecruits`, `getpendingrecruit`, `getrecruits`, `getrecruitdata` |
| `usp_Employee_Get` / `_GetList` / `_GetStaffList` / `_GetUnitEmployee` | `getemp`, `getemployee`, `getstafflist`, `getunitemployee` |
| `usp_Employee_AddFamily` / `_AddBankDetails` / `_AddGunman` / `_AddReliever` / `_GetReliever` | `addfamily`, `bankdetails`, `addgunman`, `addreliever`, `getreliever` |
| `usp_Client_Add` / `usp_Site_Add` / `_Update` / `usp_Unit_Get` / `usp_Unit_GetUserUnit` / `usp_Client_GetMyClients` | `addclient`, `addsite`, `updatesite`, `getunit`, `getuserunit`, `getMyClient` |
| `usp_Attendance_InsertPunchIn` / `_InsertPunchOut` / `_Insert` (bulk) | `insertattendancein`, `insertattendanceout`, `insertattendance` |
| `usp_Attendance_Get` / `_GetSelf` / `_GetSummary` / `_GetCount` | `getattendance`, `getselfattendance`, `getattendsummary`, `getAttendanceCount` |
| `usp_Attendance_GetForApproval` / `_Approve` | `attendforapproval`, `approve` |
| `usp_Deployment_IncDec` / `_NewContract` / `_ContractTermination` / `_TemporaryEvent` / `_Movement` | `incDecDeployment`, `newcontractDeployment`, `contractTermination`, `temporaryEvent`, `movement` |
| `usp_Turnout_Insert` / `_GetReport` | `insertturnout`, `getturnoutrpt` |
| `usp_Qr_Add` / `_GetList` / `_GetListAdmin` / `_GetSummary` / `_GetDistance` / `_Scan` / `_ScanWithImage` | `addclientqr`, `getqrlist`, `getqrlistadmin`, `getqrlistsummary`, `getqrdistance`, `readqr`, `readqrwithimage` |
| `usp_Location_Track` / `_GetLog` / `_GetUserLog` / `_GetTrackReport` | `trackLocation`, `getlocationlog`, `getuserlocationlog`, `trackRpt` |
| `usp_Incident_Insert` / `_Report` | `insertincident`, `incidentRpt` |
| `usp_FieldReport_Insert` / `_GetDetail` / `_GetCount` | `insertfield`, `getrptdetail`, `getcount` |
| `usp_Complaint_Insert` / `_Get` / `_GetUnit` / `_UpdateStatus` | `insertcomplaint`, `getcomplaint`, `getunitcomplaint`, `updatecomplaintstatus` |
| `usp_GatePass_Insert` / `_Report` | `insertgatepass` |
| `usp_Uniform_IssueItem` / `_IssueEmployee` / `_ReturnItem` / `_ReturnEmployee` / `_GetStock` / `_GetBranchStock` / `_GetLedger` | `issueitem`, `issueemployee`, `returnitem`, `returnemployee`, `getstock`, `getbranchstock`, `GetUniformLedger` |
| `usp_Hr_Resign` / `_ResignReport` / `_Left` / `_Rejoin` / `_Training` / `_TrainingReport` | `resign`, `resignRpt`, `insertleft`, `insertrejoin`, `training`, `trainingRpt` |
| `usp_Request_Insert` / `usp_Suggestion_Insert` / `usp_Advance_Insert` | `insertrequest`, `insertsuggestion`, `insertadvance` |
| `usp_Document_Upload` / `_GetDetail` | `uploaddoc`, `docdetail` |
| `usp_Salary_GetSlip` / `usp_Invoice_GetList` | `getsalary`, `getbill` |
| `usp_Flag_Update` | `updateFlag` |

### 7.3 `530_procedures_tasks.sql`
`usp_Task_Insert`, `usp_Task_GetListBy`, `usp_Task_GetListTo`, `usp_Task_GetStatusList`, `usp_Task_UpdateStatus`, `usp_Task_Close`, `usp_Task_CloseHistory`, `usp_Task_Delete`, `usp_Task_MarkRead`, `usp_Task_GetChecklists`
→ `addtask`, `gettasklistby`, `gettasklistto`, `gettaskstatus`, `updatetaskstatus`, `closetask`, `closetaskhistorylist`, `deletetask`, `readtask`, `getuserchecklists`

### 7.4 `540_procedures_sales.sql`
`usp_Sales_VisitEntry`, `usp_Sales_VisitReport`, `usp_Sales_GetVisitLog`, `usp_Sales_FollowupEntry`, `usp_Sales_FollowReport`, `usp_Sales_NextFollowReport`, `usp_Sales_ClientRelation`, `usp_Sales_ClientRelationReport`
→ `visitEntry`, `visitReport`, `getVisitLog`, `followupEntry`, `followReport`, `nextfollowReport`, `clientRelation`, `clientrelationRpt`

### 7.5 `550_procedures_report.sql`
`usp_Report_Event`, `usp_Report_IncDec`, `usp_Report_Movement`, `usp_Report_NewContract`, `usp_Report_ContractTermination`, `usp_Report_Resign`, `usp_Report_Training`, `usp_Report_Incident`, `usp_Report_Turnout`, `usp_Report_Recruitment`, `usp_Report_DailyAttendanceRegister`, `usp_Report_MonthlyAttendanceSummary`, `usp_Report_PatrolSummary`, `usp_Report_DashboardCounts`
→ `eventRpt`, `incdecRpt`, `movementRpt`, `newcontractRpt`, `contractterminationRpt`, `resignRpt`, `trainingRpt`, `incidentRpt`, `getturnoutrpt`, `getcount`

All report SPs accept `@FromDate, @ToDate, @BranchID NULL, @UnitID NULL, @EmpID NULL, @PageNo, @PageSize, @SortBy, @SortDir` and return a second result set with `@TotalRows`.

### 7.6 `560_procedures_payroll.sql`
| SP | Purpose |
|---|---|
| `usp_Payroll_Generate @CompanyID,@BranchID,@MonthYear,@UserID` | Creates a `fin.SalaryRun` (Draft) and one `fin.Salary` row per active employee: pulls payable days from approved attendance, applies `fin.SalaryStructure`, computes PF/ESIC/PT/LWF via the functions, subtracts `fin.Advance` instalments and `inv.EmployeeIssue` recovery |
| `usp_Payroll_Recalculate @RunID,@EmpID NULL` | Re-runs for one or all employees while Draft |
| `usp_Payroll_Lock @RunID` | Sets Locked, blocks further edits |
| `usp_Payroll_GetSlip @CompanyID,@EmpID,@MonthYear` | Exact `Salaryslipmodel$Datum` shape |
| `usp_Payroll_BankAdvice @RunID` | NEFT upload file data |
| `usp_Invoice_Generate @CompanyID,@ClientID,@Month,@Year` | Man-days × `crm.UnitPost.RatePerGuard`, GST split by place-of-supply, writes `fin.Invoice` + `fin.InvoiceLine` |
| `usp_Invoice_Get` / `usp_Invoice_GetLines` | Bill list & print |
| `usp_Statutory_PfEcr @RunID` / `usp_Statutory_EsicReturn @RunID` | Return-file datasets |

### 7.7 Concurrency & idempotency rules
- Punch SPs accept `@ClientRequestId UNIQUEIDENTIFIER`; if a row with that id exists, return the existing id with `Success=1` (safe offline retry).
- `usp_Payroll_Generate` takes `sp_getapplock` on `payroll:{CompanyID}:{MonthYear}`.
- Code generators (`fnGenerateEmpCode`, `fnNextInvoiceNo`) use `sp_getapplock` + `UPDATE … OUTPUT` on a counter table, never `MAX()+1`.

---

## 8. Seed Data

### 8.1 `700_seed_reference.sql` — reference data (all tenants)
- 1 country (India), **36 states/UTs** with GST state codes, ~750 districts, ~2 000 major cities.
- 12 `sec.Role` rows (PRD §2.1) + ~180 `sec.Permission` rows + a full `RolePermission` matrix per system role.
- `mst.Designation`: Security Guard, Head Guard, Gunman, Supervisor, Assistant Security Officer, Security Officer, Lady Guard, Housekeeping, Driver, Fire Operator, CCTV Operator.
- `mst.Category`: Unskilled, Semi-skilled, Skilled, Highly Skilled.
- `mst.Grade`: A, B, C, D.
- `mst.Qualification`: Below 8th, 8th, 10th, 12th, ITI, Diploma, Graduate, Post Graduate.
- `mst.Shift`: Day 08:00–20:00, Night 20:00–08:00, General 09:00–18:00, Morning 06:00–14:00, Evening 14:00–22:00.
- `mst.ComplaintType`: Guard Absent, Late Arrival, Misbehaviour, Uniform Issue, Sleeping on Duty, Theft, Poor Grooming, Other.
- `mst.IncidentType`: Theft, Fire, Trespassing, Medical Emergency, Vehicle Damage, Altercation, Equipment Failure, Suspicious Activity, Other.
- `mst.UniformItem` with rates: Shirt 450, Trouser 550, Shoes 900, Belt 150, Cap 120, Whistle 40, Jersey 600, Raincoat 350, Torch 250, Baton 180, ID Card 50, Name Plate 60.
- `mst.DocumentType` (13 rows per §2.3), `mst.TaskStatus`, `mst.Priority`, `mst.TaskRepetition`, `mst.LoginType`.
- `mst.StatutoryRate`: PF employee 12 %, employer 12 % (ceiling ₹15 000), EDLI 0.5 %, admin 0.5 %; ESIC employee 0.75 %, employer 3.25 % (ceiling ₹21 000).
- `mst.PtSlab` for Maharashtra, Karnataka, West Bengal, Gujarat, Madhya Pradesh, Tamil Nadu; `mst.LwfSlab` for the same.
- ~120 `mst.Bank` rows and a sample `mst.IfscCode` set.

### 8.2 `710_seed_demo_tenant.sql`
- **Company 1:** `Diti Security Services Pvt Ltd` — Delhi HQ + 2 branches (Noida, Gurugram), plan Professional, 100 users, expiry +365 days.
- **Company 2:** `Shield Force Security` — Pune, smaller tenant, used to prove tenant isolation in tests.
- 1 `SUPER_ADMIN` (`superadmin / Admin@123`), and per tenant: 1 COMPANY_ADMIN, 2 BRANCH_ADMIN, 1 OPERATIONS, 1 HR, 1 ACCOUNTS, 3 SUPERVISOR, 2 SALES, 2 GATEKEEPER, 2 NIGHT_PATROL, 4 CLIENT logins.
- **6 clients, 12 units** with real Delhi-NCR lat/long and 150 m geofences; 24 `crm.UnitPost` rows with required strength and rates.
- **40 employees** in Company 1 with complete satellite records (addresses, family, bank, statutory, physicals, verification, medical; 4 gunmen with licences), photos referenced as seeded blob URLs.
- 8 `hr.Recruit` rows spread across pipeline stages.
- 30 `ops.QrCheckpoint` rows across the 12 units + 6 `ops.PatrolRound` definitions.
- Uniform opening stock in both branches.
- `fin.SalaryStructure` for all 40 employees.

### 8.3 `720_seed_demo_transactions.sql`
Generate with a date-loop over the **last 90 days**:
- `ops.Attendance` — ~3 400 rows (95 % present, 3 % absent, 2 % half-day), mixed sources, ~15 % pending approval in the last 3 days, punch coordinates jittered around unit geofences, ~4 % deliberately outside geofence to exercise the exception views.
- `ops.QrScanLog` — ~5 000 scans with 6 % missed rounds.
- `ops.LocationLog` — 20 000 pings for 5 supervisors.
- `ops.Task` — 120 tasks across all statuses with history rows.
- `ops.Incident` 35, `ops.FieldReport` 60 (+details), `ops.Complaint` 45 (25 closed, 20 open incl. 5 SLA-breached), `ops.GatePass` 300.
- `crm.SalesVisit` 90, `crm.FollowUp` 140, `crm.Contract` 12.
- `ops.Turnout` daily rows for all units; `ops.DeploymentChange` 15; `ops.Movement` 25; `hr.EmployeeStatusHistory` 12 (resign/left/rejoin); `hr.Training` 10.
- `inv.EmployeeIssue` 120, `inv.StockTxn` 200.
- **One completed payroll run** for the previous month (40 salary slips, locked) + **one draft run** for the current month.
- **6 invoices** (2 paid, 2 sent, 1 part-paid, 1 overdue) with lines.
- `doc.Document` ~200 rows including 12 expiring within 30 days, to light up the expiry dashboard.

> **Seed must be deterministic** — fixed random seed, fixed base date computed from `@Today = CAST(SYSDATETIME() AS DATE)`, so screenshots and tests are reproducible.

---

## 9. Data Retention & Housekeeping

| Data | Retention | Mechanism |
|---|---|---|
| `ops.LocationLog` | 90 days hot, 1 year cold | monthly partition switch → archive DB |
| `aud.ApiRequestLog` | 30 days | nightly delete job |
| Punch selfies / patrol photos | 12 months | blob lifecycle policy → cool → delete |
| `sec.LoginLog` | 24 months | |
| Attendance, payroll, invoices | 8 years (statutory) | never deleted, only archived |
| `doc.Document` | life of employment + 3 years | |

Nightly Hangfire jobs: `RefreshAttendanceSummary`, `SnapshotDailyTurnout`, `RaiseDocumentExpiryAlerts`, `DetectMissedPatrolRounds`, `MarkAbsentForNoPunch` (runs at shift end + grace), `RebuildIndexes` (weekly), `UpdateStatistics` (nightly).

---

## 10. Definition of Done — Phase 1

- [ ] `dotnet run --project db/DbUp` completes on an empty SQL Server instance with zero errors, twice in a row (idempotency proof).
- [ ] All tables, views, functions, SPs and triggers listed above exist; `sys.objects` count matches the manifest.
- [ ] Every SP has at least one smoke test in `db/tests/` executed by `tSQLt` or a xUnit integration project.
- [ ] Seed produces a tenant you can browse: 40 employees, 90 days of attendance, a locked payroll run and 6 invoices.
- [ ] Tenant isolation test: querying every SP with Company 2's id never returns a Company 1 row.
- [ ] No SP contains `SELECT *`; no table lacks `CompanyID` except `mst.*` globals and `sec.Role` system rows.
- [ ] An execution plan review shows no table scans on `ops.Attendance`, `ops.QrScanLog` or `hr.Employee` for the 20 most-used SPs.
