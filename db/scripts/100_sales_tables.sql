/*==============================================================================
  100_sales_tables.sql
  INTENTIONALLY EMPTY - kept so the numbering in docs/prd/01-database.md §0
  stays intact.

  The sales / CRM tables (crm.SalesVisit, crm.FollowUp, crm.ClientRelationVisit,
  crm.Contract) live in 040_client_unit_tables.sql. They belong to the crm schema
  and every one of them has a foreign key to crm.Client or crm.Unit, so creating
  them alongside their parents keeps the dependency order simple. Splitting them
  into a separate script bought nothing.

  See DECISIONS.md #13.
==============================================================================*/
SET NOCOUNT ON;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

PRINT '100_sales_tables.sql  ->  OK  (no objects; sales tables are in 040)';
GO
