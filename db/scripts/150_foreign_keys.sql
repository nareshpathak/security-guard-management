/*==============================================================================
  150_foreign_keys.sql
  Cross-schema foreign keys that could not be created inline because the target
  table is built in a later script (forward references).

  Runs after every table script. Extend this file as later modules are added.
  Idempotent: each constraint is created only if it does not already exist.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*-- helper pattern -----------------------------------------------------------
   IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_x')
       ALTER TABLE ... ADD CONSTRAINT FK_x FOREIGN KEY ... REFERENCES ...;
-----------------------------------------------------------------------------*/

/*==================  mst.* tenant overrides -> org.Company  ================*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Region_Company')
    ALTER TABLE mst.Region        ADD CONSTRAINT FK_mst_Region_Company        FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Area_Company')
    ALTER TABLE mst.Area          ADD CONSTRAINT FK_mst_Area_Company          FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Grade_Company')
    ALTER TABLE mst.Grade         ADD CONSTRAINT FK_mst_Grade_Company         FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Category_Company')
    ALTER TABLE mst.Category      ADD CONSTRAINT FK_mst_Category_Company      FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Designation_Company')
    ALTER TABLE mst.Designation   ADD CONSTRAINT FK_mst_Designation_Company   FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Qualification_Company')
    ALTER TABLE mst.Qualification ADD CONSTRAINT FK_mst_Qualification_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Shift_Company')
    ALTER TABLE mst.Shift         ADD CONSTRAINT FK_mst_Shift_Company         FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_ComplaintType_Company')
    ALTER TABLE mst.ComplaintType ADD CONSTRAINT FK_mst_ComplaintType_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_IncidentType_Company')
    ALTER TABLE mst.IncidentType  ADD CONSTRAINT FK_mst_IncidentType_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_ServiceType_Company')
    ALTER TABLE mst.ServiceType   ADD CONSTRAINT FK_mst_ServiceType_Company   FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_UniformItem_Company')
    ALTER TABLE mst.UniformItem   ADD CONSTRAINT FK_mst_UniformItem_Company   FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_Holiday_Company')
    ALTER TABLE mst.Holiday       ADD CONSTRAINT FK_mst_Holiday_Company       FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_mst_DocumentType_Company')
    ALTER TABLE mst.DocumentType  ADD CONSTRAINT FK_mst_DocumentType_Company  FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID);
GO

/*==========================  sec.Users -> hr / crm  ========================*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_sec_Users_Employee')
    ALTER TABLE sec.Users ADD CONSTRAINT FK_sec_Users_Employee FOREIGN KEY (EmpID)    REFERENCES hr.Employee (EmpID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_sec_Users_Client')
    ALTER TABLE sec.Users ADD CONSTRAINT FK_sec_Users_Client   FOREIGN KEY (ClientID) REFERENCES crm.Client (ClientID);
GO

/*============================  hr.* -> crm.Unit  ===========================*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_Employee_Unit')
    ALTER TABLE hr.Employee ADD CONSTRAINT FK_hr_Employee_Unit   FOREIGN KEY (UnitID)   REFERENCES crm.Unit (UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_Employee_Client')
    ALTER TABLE hr.Employee ADD CONSTRAINT FK_hr_Employee_Client FOREIGN KEY (Clientid) REFERENCES crm.Client (ClientID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_Recruit_Employee')
    ALTER TABLE hr.Recruit ADD CONSTRAINT FK_hr_Recruit_Employee FOREIGN KEY (EmpID) REFERENCES hr.Employee (EmpID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_EmpStatusHistory_FromUnit')
    ALTER TABLE hr.EmployeeStatusHistory ADD CONSTRAINT FK_hr_EmpStatusHistory_FromUnit FOREIGN KEY (FromUnitID) REFERENCES crm.Unit (UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_EmpStatusHistory_ToUnit')
    ALTER TABLE hr.EmployeeStatusHistory ADD CONSTRAINT FK_hr_EmpStatusHistory_ToUnit   FOREIGN KEY (ToUnitID)   REFERENCES crm.Unit (UnitID);
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_hr_Training_Unit')
    ALTER TABLE hr.Training ADD CONSTRAINT FK_hr_Training_Unit FOREIGN KEY (UnitID) REFERENCES crm.Unit (UnitID);
GO

PRINT '150_foreign_keys.sql  ->  OK';
GO
