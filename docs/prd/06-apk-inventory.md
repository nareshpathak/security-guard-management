# Appendix — Raw Evidence Extracted from `Diti365.apk`

Everything below was decompiled/extracted from the shipped production APK and is the factual basis for this PRD. Use it as the **feature-parity checklist**: nothing here may be dropped in the rebuild without an explicit decision.

## A. Application identity
| Attribute | Value |
|---|---|
| Package | `com.diti.securityguarding` |
| Version name | `4.8` |
| APK size | 19.1 MB |
| Build | Native Android (Kotlin/Java), XML layouts with DataBinding, 11 dex files |
| Networking | Retrofit + OkHttp + Gson; Picasso for images |
| Auth/Push | Firebase Auth (phone OTP), Firebase Cloud Messaging, Firebase Realtime Database (chat), Firebase Firestore |
| Maps | Google Maps SDK + Play Services Location |
| Other SDKs | ZXing/journeyapps barcode scanner, dhaval2404 ImagePicker, uCrop, Edmodo CropImage, Dexter (permissions) |

## B. Backend endpoints observed
| Base URL | Purpose |
|---|---|
| `http://web521.66.232.new.ocpwebserver.com/api/Users/` | auth, profile, masters |
| `http://web521.66.232.new.ocpwebserver.com/api/Operation/` | core operations |
| `http://web521.66.232.new.ocpwebserver.com/api/Tasks/` | task management |
| `http://web521.66.232.new.ocpwebserver.com/api/Sales/` | sales/CRM |
| `http://web521.66.232.new.ocpwebserver.com/api/Report/` | reports |
| `http://web.securityguardingsoftwares.com/PrintSalary.aspx?TypeID=3&SalaryId=` | legacy salary slip print (WebView) |
| `http://jpsonline.in/PrintDailAttendance.aspx?CID=` | legacy attendance register print |
| `http://jpsonline.in/Report_CrInvoicePrint.aspx?BIDs=` | legacy invoice print |

> **All plain HTTP.** `usesCleartextTraffic="true"` in the manifest. This is the single most urgent defect to fix.

## C. Android permissions requested
`INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `CAMERA`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `BIND_JOB_SERVICE`, `DUMP`, plus AdServices/AD_ID and camera/wifi hardware features.

## D. Activities (27)
```
Addclientlocation_act
Addrecrut_act
Addreliever_act
Cclist_act
Changepass_act
Chat_act
ClientMainActivity
Closedtaskdetail_act
Createqr_act
Documentdetails_act
Documentupload_act
EmployeeMainActivity
Employeedetails_act
Enterotp_act
Familydetail_act
Forgotpass_act
GoogleService
Locationfetch_act
Login_act
MainActivity
SalesMainActivity
Splash_act
Statushistory_act
Taskdetails_act
Userlist_act
```

## E. Fragments (90)
```
Addclient_frag
Addreliever_frag
Adminfollowrpt_frag
Adminnextfollowrpt_frag
Adminvisitrpt_frag
Approveattend_frag
Assignedunitcomplaints_frag
Attendanceop_frag
Attendancepunch_frag
Attendancesummary_frag
Clientrelation_frag
Clientrelationrpt_frag
Companylogdetail_frag
Companyloginrpt_frag
Companylogrpt_frag
Complaint_frag
Contractterminaterpt_frag
Contracttermination_frag
Dailyattendanceprint_frag
Dashboard_frag
Data_frag
Dutylist_frag
Eventrpt_frag
Fieldreport_frag
Followup_frag
Followuprpt_frag
Gatepassentry_frag
Gatepassreport_frag
HomeAdmin_frag
HomeGatekeeper_frag
HomeMapsActivity
HomeNightPatrol_frag
HomeSales_frag
HomeSuperAdmin_frag
HomeSupervisor_frag
IncDecDeployment_frag
IncdecRpt_frag
Incident_frag
Incidentrpt_frag
Issueadvnce_frag
Left_frag
Locationlog_frag
Locationuserlog_frag
LogReportAdmin_frag
Logsummary_frag
Movement_frag
Movementrpt_frag
Myclients_frag
Mycomplaints_frag
Myunits_frag
Newcontract_frag
Newcontractrpt_frag
Newjoin_frag
Nextfollowup_frag
Operationrpt_frag
Operations_frag
Profile_frag
Qrloglist_frag
Qrscanner_frag
Recievedtasklist_frag
Rejoin_frag
Reportdetail_frag
Request_frag
Resign_frag
Resignrpt_frag
Salaryslip_frag
Salesvisitentry_frag
Salesvisitrpt_frag
SelfAttendancepunch_frag
Showattendance_frag
Showbill_frag
Shownightpatrol_frag
Showselfattend_frag
Stafflist_frag
Suggestion_frag
Taskassign_frag
Taskhistory_frag
Tasklist_frag
Taskshome_frag
Temporaryevent_frag
Todaylog_frag
Training_frag
Trainingrpt_frag
Turnout_frag
Uniform_frag
Uniformissue_frag
Uniformledger_frag
Uniformstock_frag
Unifromreturn_frag
Visitentry_frag
Waitlist_frag
```

## F. RecyclerView adapters — one per list surface (46)
```
AssignedComplaintAdapter
AttendancelistAdapter
AttendfroappAdapter
ClientlistAdapter
ClientrelationlistAdapter
CompanylogAdapter
CompanylogdetailAdapter
CompanyloginAdapter
ComplaintAdapter
ContractterminatelistAdapter
EventlistAdapter
FieldrptAdapter
FollowlistAdapter
GatepassAdapter
IncdeclistAdapter
IncidentlistAdapter
ItemlistAdapter
LedgerlistAdapter
LocationlogAdapter
LocationuserlogAdapter
MessageAdapter
MovementlistAdapter
NewcontractlistAdapter
NextFollowlistAdapter
PendinglistAdapter
QrlistAdapter
RecievedtasklistAdapter
RecruitAdapter
RecruitmentrptAdapter
RelieverselAdapter
ResignlistAdapter
SalaryslipAdapter
SelfattendAdapter
ShowattendAdapter
ShowbillAdapter
StafflistAdapter
StatushistoryAdapter
StocklistAdapter
SummarylistAdapter
TasklistAdapter
TraininglistAdapter
UnitlistAdapter
UserlistAdapter
VisitlistAdapter
```

## G. Retrofit API methods — complete list (120)
Source: `com.diti.securityguarding.interfaces.Apis`

```
GetUniformLedger
active
addclient
addclientqr
addfamily
addgunman
addrecruits
addsite
addtask
approve
attendforapproval
bankdetails
changepass
checkdeviceid
checkexpire
checknum
clientRelation
clientrelationRpt
closetask
closetaskhistorylist
contractTermination
contractterminationRpt
deletetask
docdetail
eventRpt
followReport
followupEntry
getAttendanceCount
getCompanylog
getCompanylogdetail
getLoginLog
getVisitLog
getattendance
getattendsummary
getbill
getbranchstock
getcity
getcomplaint
getcomplaintype
getcount
getdesignation
getemp
getemployee
getlist
getlocationlog
getpendingrecruit
getprofile
getqrdistance
getqrlist
getqrlistadmin
getqrlistsummary
getqualification
getrecruitdata
getrecruits
getreliever
getrights
getrptdetail
getsalary
getselfattendance
getstafflist
getstates
getstock
getsubdropdown
gettasklistby
gettasklistto
gettaskstatus
getturnoutrpt
gettype
getunit
getunitcomplaint
getunitemployee
getuserchecklists
getuserlists
getuserlocationlog
getuserunit
incDecDeployment
incdecRpt
incidentRpt
insertadvance
insertattendance
insertattendancein
insertattendanceout
insertcomplaint
insertfield
insertgatepass
insertincident
insertleft
insertrejoin
insertrequest
insertsuggestion
insertturnout
issueemployee
issueitem
login
movement
movementRpt
newcontractDeployment
newcontractRpt
nextfollowReport
readqr
readqrwithimage
readtask
resign
resignRpt
returnemployee
returnitem
temporaryEvent
trackLocation
trackRpt
training
trainingRpt
updateFlag
updatecomplaintstatus
updaterecruits
updatesite
updatetaskstatus
updatetoken
uploaddoc
visitEntry
visitReport
```

## H. Data models (DTOs) and their fields

These are the exact JSON shapes the current API returns. New v1-compatible endpoints must reproduce them field-for-field.

### `Addrecruitmodel$Datum` (199 fields)

```
AcType, AddQualificationID, AddressDuration, AdharCardNo, AreaID, AreainLicensevalid, BankAcNo,
BankAddedDate, BankAddedUserId, BankForSalary, BankID, BankName, BankName1, BankPassbook, BeltNo,
BioDataSubmissionDate, BirthPlace, BlackListedDate, BlackListedReason, Bloodgroup, BranchID, BranchName,
CardNo, Category, CategoryID, CharacterAssessed, Cheque, Chest, CityID, CityName, ClientName, Clientid,
Comments, CompanyID, CountryID, Criminology, DateofLeft, Dateofdischarge, Dependent, DesignationID,
DesignationName, DlNo, DoDeployment, Dob, Dob1, DobDistrictID, DobStateID, DocAAdhar, DocAAdhar2, DocDL,
DocEsic, DocEsic2, DocPAN, DocUAN, DocVoterId, DoctorAddress, DoctorDesignation, DoctorPhoneNo,
DoctorQualification, DoctorRegNo, Doctorname, DocumentFilename, Doj, Doj1, Dol, ESICNo, EmailId1, EmailId2,
EmpCode, EmpFullName, EmpID, EmpSign, EmpStatus, EmployeeEyes, Employeetype, FatherDob, FatherDob1,
FatherName, FirstName, ForeignAddress, Gender, GradeID, GunModelNum, GunNo, GunanType, Height,
HigestEducationInstitue, Hospital, ID, IFSCcode, IdCardExpireDate, IdCardIssueDate, IdCardNo, IdentitySign,
IfscCodeId, InsertDate, InstituteName, IsApplyEmpSalaryStructure, IsApproved, IsBankAdded, IsBlackListed,
IsCancel, IsExService, IsGunman, IsNotBilling, IsPermanent, IsPoliceVerification, IsReject, Isform11pf,
Isformfullfinal, IssueDate, JointAcName, JointAcNo, JointBankId, JointBankName, JointBranchName,
JointIfscCodeId, LastName, LeftReason, LicenseNo, LicenseProduce, Licenseexpire, Licenseexpire1, Married,
MedicalCertificateImg, MedicalCertificateIssue, MedicalCertificateIssueDate, MedicalDate, Middlename,
Mobile1, Mobile2, MotherDob, MotherDob1, Mothername, NameInBankPassbook, NameInBankPassbookLast, Nationality,
NotaryStampPadNo, OldEmpCode, OtherNationality, PFNo, PVValidUpTo, Paddress1, Paddress2, Pan, PanCardNo,
PaymentMode, Pcity, Percentage, Photo, PoliceCertificateImg, PoliceStationName, PoliceVerificationNo, Ppin,
PrDistrictID, PrStateID, Praddress1, Praddress2, Prcity, ProfessionalQualification, Prpin, Prtelephone,
Ptelephone, Pvreturndate, Pvsenddate, QualificationID, QualificationName, Rank, Regiment, RegionID,
RemarkByThana, Salutation, Selfie, ServiceSno, ShiftID, Shoesize, SpouseName, StateID, StateName, SwipeNo,
Trousersize, TshirtSize, TypeArm, UANNo, UnitID, UnitName, Userid, VerificationDate, VoterId, Waist,
Wcpamount, Wcpexpdate, Wcpno, Weight, WifeDob, WifeDob1, Wifename, pDistrictID, pStateID
```

### `Addrecruitmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Addrelmodel` (2 fields)

```
Name, Post
```

### `Addtaskmodel$Datum` (18 fields)

```
Assignedby, Assignedby_Name, Assignedto, Assignedto_Name, Attachment, Description, DueDays, EndDate, Heading,
Id, Important, ListStatus, Name, Priority, RepetitionId, StartDate, TaskStatus, UserId
```

### `Addtaskmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Attendanceforapprovmodel$Datum` (4 fields)

```
AdditionalProperties, Attendancecount, NOS, Servicename
```

### `Attendanceforapprovmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `ClientRelationmodel$Datum` (7 fields)

```
ContactPerson, Dated, Executive, MobileNo, Remark, Timing, UnitName
```

### `ClientRelationmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Companymodel$Datum` (11 fields)

```
ClientId, CompanyAddress, CompanyID, CompanyName, Id, IsExpired, LoginCount, Mobile, Name, Sno, UserCount
```

### `Companymodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Complaintmodel$Datum` (6 fields)

```
AdditionalProperties, Complainttype, Description, ID, InsertDate, IsClosed
```

### `Complaintmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Contractmodel$Datum` (4 fields)

```
Dated, Remark, Timing, UnitName
```

### `Contractmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Deviceidmodel$Datum` (2 fields)

```
AdditionalProperties, DeviceId
```

### `Deviceidmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `EmpInfoModel$Datum` (5 fields)

```
AlreadyExist, Designation, EmpID, EmpName, OldEmpCode
```

### `EmpInfoModel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Employeemodel$Datum` (15 fields)

```
AdditionalProperties, BeltNo, BranchID, Clientid, CompanyID, DesignationName, EmailId, EmpID, FirstName,
LastName, MobileNo, Password, Photo, UnitID, UnitName
```

### `Employeemodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Eventmodel$Datum` (7 fields)

```
EndDate, EndTime, NOP, StartDate, StartTime, TypeOfService, UnitName
```

### `Eventmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Expirymodel$Datum` (3 fields)

```
AdditionalProperties, DeviceId, Expires
```

### `Expirymodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Fieldrptdetailmodel$Datum` (9 fields)

```
AdditionalProperties, ContactPerson, Createdate, DesignationName, Joindate, Name, Photo, Remark, UnitName
```

### `Fieldrptdetailmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Followupmodel$Datum` (10 fields)

```
CompanyName, ContactNo, ContactPerson, FollowupDate, Id, Location, NextFollowupDate, Purpose, Remark,
StopFollow
```

### `Followupmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Gatepassmodel$Datum` (6 fields)

```
Dated, MobileNo, Name, Purpose, VehicleNo, VisitorImage
```

### `Gatepassmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Getcitymodel$Datum` (3 fields)

```
ID, Name, PhotoUrl
```

### `Getcitymodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Getqualificationmodel$Datum` (6 fields)

```
InsertDate, IsApproved, IsCancel, IsReject, QualificationID, QualificationName
```

### `Getqualificationmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Getstatesmodel$Datum` (10 fields)

```
CmpAddress, CountryID, GSTIN, GstStateCode, IsApproved, IsCancel, IsReject, StateCode, StateID, StateName
```

### `Getstatesmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Incdecmodel$Datum` (6 fields)

```
Dated, Nop, Remark, Status, Timing, UnitName
```

### `Incdecmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Incidentmodel$Datum` (6 fields)

```
BeltNo, FullName, IncidentDate, IncidentTime, IncidentType, Remark
```

### `Incidentmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Ledgermodel$Datum` (3 fields)

```
IssuedQty, ItemName, RecievedQty
```

### `Ledgermodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Loginmodel$Datum` (16 fields)

```
AttendanceCount, BranchID, Companyid, Designation, Deviceid, EmpCode, Employeetype, Firstname, Id, Lastname,
LoginType, MobileNo, Name, PhotoUrl, TokenNo, Unit
```

### `Loginmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Messagemodel` (6 fields)

```
Id, Message, Name, Read, Timestamp, Type
```

### `Movementmodel$Datum` (6 fields)

```
GuardName, InstructionBy, MovementDate, MovementTime, PostName, UnitName
```

### `Movementmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Newcontractmodel$Datum` (5 fields)

```
Dated, Nop, Remark, Timing, UnitName
```

### `Newcontractmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Newmembermodel$Datum` (9 fields)

```
AdditionalProperties, ClientId, CompanyAddress, CompanyName, Id, Isexpired, Mobile, Name, Sno
```

### `Newmembermodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Profilemodel$Datum` (22 fields)

```
AdditionalProperties, Address, BankAcNo, BankName, BeltNo, BloodGroup, Dated, DesignationName,
DrivingLicenceNo, IFSCcode, IsPoliceVerification, IsReliever, Maritalstatus, Mobile1, Name, Paddress1, Photo,
ReportingSuperwiser, Rownum, Shiftname, TrainingDate, UnitName
```

### `Profilemodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Qrdistancemodel$Datum` (2 fields)

```
Latitude, Longitude
```

### `Qrdistancemodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Qrmodel$Datum` (9 fields)

```
Image, Location, Name, Photo, QrCode, Remark, Scantime, Sno, TotalScanCount
```

### `Qrmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Recruitmodel$Datum` (4 fields)

```
AdditionalProperties, Dated, Mobile, Name
```

### `Recruitmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Reportcountmodel$Datum` (3 fields)

```
Fieldcount, Recruitcount, Turnoutcount
```

### `Reportcountmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Resignmodel$Datum` (5 fields)

```
Dated, GuardName, Remark, Timing, UnitName
```

### `Resignmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Salaryslipmodel$Datum` (18 fields)

```
BasicWages, BonusAmt, ClientName, DeductionAmt, ESICAmt, FoodAllow, HRAAmt, LeaveAllow, LwfEmp, MixOther,
MonthYear, NetPayble, PFAmt, PtEmp, ReliverAllow, SpAllowance, TotalEarnings, WcsSalaryID
```

### `Salaryslipmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Showattendmodel$Datum` (23 fields)

```
Address, BloodGroup, CompanyID, Dated, DesignationName, DrivingLicenceNo, EmpCode, Empid, Expires, FirstName,
Id, IsPoliceVerification, IsReliever, LastName, LoginType, Maritalstatus, Name, Photo, Rownum, Shiftname,
TokenNo, TrainingDate, UnitName
```

### `Showattendmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Showbillmodel$Datum` (4 fields)

```
Bid, GrandTotal, Month, Year
```

### `Showbillmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Stockmodel$Datum` (3 fields)

```
ItemName, Opstock, Qty
```

### `Stockmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Tasklistsmodel$Datum` (25 fields)

```
Assignedby, Assignedby_Name, Assignedto, Assignedto_Name, Attachment, Cnt, Description, DueDays, EndDate,
EndTime, Heading, Id, InsertDate, InsertDated, Isclosed, Isread, ListStatus, Name, Priority, StartDate,
StartTime, TaskStatus, TaskStatus_Name, Task_id, UserId
```

### `Tasklistsmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Taskmodel` (4 fields)

```
Assignedby, Date, Heading, Time
```

### `Trackmodel$Datum` (2 fields)

```
Latitude, Longitude
```

### `Trackmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Trainingmodel$Datum` (5 fields)

```
Dated, Nop, Remark, Timing, UnitName
```

### `Trainingmodel` (5 fields)

```
Data, Id, Message, Status, Success
```

### `Turnoutmodel$Datum` (5 fields)

```
AdditionalProperties, EmpId, EmpName, Id, UnitName
```

### `Turnoutmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Uniformitemmodel$Datum` (4 fields)

```
AdditionalProperties, ItemID, ItemName, Rate
```

### `Uniformitemmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Unitmodel$Datum` (10 fields)

```
AdditionalProperties, AgreementExpDate, AgreementNo, ID, Name, OrderDate, OrderExpiryDate, OrderNo, UnitName,
WorkStartDate
```

### `Unitmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```

### `Visitmodel$Datum` (7 fields)

```
CompanyName, ContactNo, ContactPerson, Id, Location, Purpose, Remark
```

### `Visitmodel` (6 fields)

```
AdditionalProperties, Data, Id, Message, Status, Success
```


## I. Role dashboards found in the APK

| Home fragment / activity | Role |
|---|---|
| `HomeSuperAdmin_frag` | Platform / multi-company super admin |
| `HomeAdmin_frag` | Agency admin |
| `HomeSupervisor_frag` | Field supervisor |
| `HomeGatekeeper_frag` | Gate keeper |
| `HomeNightPatrol_frag` | Night patrolling officer |
| `HomeSales_frag` | Sales executive |
| `ClientMainActivity` | Client login |
| `EmployeeMainActivity` | Guard/employee login |
| `MainActivity` | Router / shared shell |
| `SalesMainActivity` | Sales shell |
| `HomeMapsActivity` | Live map |

## J. Feature-parity checklist

Use this list to sign off Phase 3. Every item must exist in the new system (web, mobile, or both).

- [ ] Login, OTP verification, forgot password, change password, device-ID binding, licence expiry check, FCM token registration
- [ ] Super-admin company list, company log, company login report, new member registration
- [ ] Masters: states, cities, designations, qualifications, complaint types, generic type/sub-dropdown lists
- [ ] Client add, client location add, client list (CC list), my clients, my units, unit add/update
- [ ] Recruit add, update, pending list, recruit data, waitlist, new joins, recruitment report
- [ ] Employee details, staff list, profile, family details, bank details, gunman details, reliever add/select
- [ ] Document upload, document details, document expiry
- [ ] Attendance: self-punch, punch in/out, operator entry, approval queue, approve, summary, show attendance, show self attendance, daily attendance print, attendance count
- [ ] Deployment: inc/dec, new contract, contract termination, temporary event, movement, turnout, duty list
- [ ] QR: create QR, QR list, QR scanner, read QR, read QR with image, QR distance, QR logs (admin/client/supervisor/location/summary)
- [ ] Location: fetch/track service, location log, user location log, today log, log summary, admin log report, maps view
- [ ] Tasks: assign, list by/to, received tasks, task details, status history, close, closed task detail, task home, delete, read, checklists
- [ ] Incidents: entry, report; Field report: entry, detail, count
- [ ] Complaints: raise, my complaints, assigned unit complaints, status update; Suggestions
- [ ] Sales: visit entry, visit report, admin visit report, follow-up, follow-up report, next follow-up, admin follow reports, client relation entry/report
- [ ] Uniform: item issue, employee issue, item return, employee return, stock, branch stock, ledger
- [ ] HR: resign, resign report, left, rejoin, training, training report, requests, issue advance
- [ ] Gate pass: entry, report
- [ ] Salary slip, show bill/invoice
- [ ] Chat / messaging, push notifications
- [ ] Reports: event, inc/dec, movement, new contract, contract termination, resignation, training, incident, turnout

---

## K. Coverage verification (automated check against this PRD)

| Check | Result |
|---|---|
| Retrofit API methods extracted from `Apis` interface | **120** |
| Methods explicitly covered in `PRD.md` + `docs/01`–`05` | **120 / 120 (100 %)** |
| Fragments extracted | 91 |
| Fragments covered by name or by their module/report key | 91 / 91 |
| Activities extracted | 27 |
| DTO models extracted and reproduced in the schema spec | 63 |

The following report fragments are covered by their **report key** in `docs/03-web.md` §4.9 and their SP in `docs/01-database.md` §7.5 rather than by fragment name — they are report views of modules already specified in full:

`Dashboard_frag` → role dashboards (`docs/03-web.md` §3) · `Data_frag` / `Operations_frag` / `Operationrpt_frag` → Operations section shell and operations report · `Eventrpt_frag` → Temporary Event report (`usp_Report_Event`) · `IncdecRpt_frag` → IncDec report (`usp_Report_IncDec`) · `Movementrpt_frag` → Movement report (`usp_Report_Movement`) · `Newcontractrpt_frag` → New Contract report (`usp_Report_NewContract`) · `Contractterminaterpt_frag` → Contract Termination report (`usp_Report_ContractTermination`) · `Resignrpt_frag` → Resignation report (`usp_Report_Resign`) · `Companylogdetail_frag` → Company log detail (`usp_Company_GetLogDetail`) · `Addreliever_frag` → Reliever assignment (`usp_Employee_AddReliever`, deployment screen).
