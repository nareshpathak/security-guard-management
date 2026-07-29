/*==============================================================================
  001_schemas.sql
  Diti365 - Security Agency Management System
  Creates the ten database schemas. Idempotent.
  Spec: docs/prd/01-database.md §1
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID('mst') IS NULL EXEC('CREATE SCHEMA mst AUTHORIZATION dbo;');   -- master / reference data
GO
IF SCHEMA_ID('org') IS NULL EXEC('CREATE SCHEMA org AUTHORIZATION dbo;');   -- tenant, company, branch
GO
IF SCHEMA_ID('sec') IS NULL EXEC('CREATE SCHEMA sec AUTHORIZATION dbo;');   -- auth, users, roles, permissions
GO
IF SCHEMA_ID('hr')  IS NULL EXEC('CREATE SCHEMA hr  AUTHORIZATION dbo;');   -- people: recruits, employees
GO
IF SCHEMA_ID('crm') IS NULL EXEC('CREATE SCHEMA crm AUTHORIZATION dbo;');   -- clients, units, sales
GO
IF SCHEMA_ID('ops') IS NULL EXEC('CREATE SCHEMA ops AUTHORIZATION dbo;');   -- deployment, attendance, patrol, tasks
GO
IF SCHEMA_ID('inv') IS NULL EXEC('CREATE SCHEMA inv AUTHORIZATION dbo;');   -- uniform and stock
GO
IF SCHEMA_ID('fin') IS NULL EXEC('CREATE SCHEMA fin AUTHORIZATION dbo;');   -- payroll and billing
GO
IF SCHEMA_ID('doc') IS NULL EXEC('CREATE SCHEMA doc AUTHORIZATION dbo;');   -- documents and communication
GO
IF SCHEMA_ID('aud') IS NULL EXEC('CREATE SCHEMA aud AUTHORIZATION dbo;');   -- audit trail
GO

PRINT '001_schemas.sql  ->  OK';
GO
