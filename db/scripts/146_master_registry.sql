/*==============================================================================
  146_master_registry.sql
  A registry of the reference tables an administrator may manage.

  WHY A REGISTRY RATHER THAN 84 PROCEDURES
  There are 28 master tables. Hand-writing list/save/status procedures for each
  is 84 near-identical procedures - and 84 places for one of them to drift.

  WHY THIS IS NOT AN INJECTION HOLE
  The API never sends a table name. It sends a MasterKey, which must already
  exist in this registry; the schema, table and column names come from here and
  every one of them is passed through QUOTENAME before it reaches sp_executesql.
  Values are passed as parameters, never concatenated. A caller who invents a
  key gets THROW 51031, not a query.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('mst.MasterRegistry', 'U') IS NULL
CREATE TABLE mst.MasterRegistry (
    MasterKey       NVARCHAR(50)  NOT NULL CONSTRAINT PK_mst_MasterRegistry PRIMARY KEY,
    Label           NVARCHAR(100) NOT NULL,
    GroupName       NVARCHAR(50)  NOT NULL,
    SchemaName      SYSNAME       NOT NULL,
    TableName       SYSNAME       NOT NULL,
    IdColumn        SYSNAME       NOT NULL,
    NameColumn      SYSNAME       NOT NULL,
    CodeColumn      SYSNAME       NULL,
    SortColumn      SYSNAME       NULL,
    ParentColumn    SYSNAME       NULL,
    ParentKey       NVARCHAR(50)  NULL,     -- registry key of the parent master
    /*  Tenant-scoped masters carry a CompanyID and each agency edits its own.
        Global ones - states, banks, IFSC codes - are platform reference data
        and only SUPER_ADMIN may touch them.  */
    IsCompanyScoped BIT           NOT NULL,
    IsPlatformOnly  BIT           NOT NULL CONSTRAINT DF_mst_MasterRegistry_Platform DEFAULT (0),
    HasIsActive     BIT           NOT NULL CONSTRAINT DF_mst_MasterRegistry_Active   DEFAULT (0),
    SortOrder       INT           NOT NULL CONSTRAINT DF_mst_MasterRegistry_Sort     DEFAULT (100)
);
GO

/*  Idempotent seed. Adding a master to the product means adding a row here,
    not writing three more procedures.  */
MERGE mst.MasterRegistry AS t
USING (VALUES
    -- key                label                  group        schema table            id                 name                  code            sort         parent col      parent key  scoped platform active sort
    ('designation',       'Designations',        'People',    'mst', 'Designation',   'DesignationID',   'DesignationName',    NULL,           'SortOrder', NULL,           NULL,       1, 0, 0, 10),
    ('grade',             'Grades',              'People',    'mst', 'Grade',         'GradeID',         'GradeName',          NULL,           'SortOrder', NULL,           NULL,       1, 0, 0, 20),
    ('qualification',     'Qualifications',      'People',    'mst', 'Qualification', 'QualificationID', 'QualificationName',  NULL,           'SortOrder', NULL,           NULL,       1, 0, 0, 30),
    ('documenttype',      'Document types',      'People',    'mst', 'DocumentType',  'DocTypeID',       'DocTypeName',        NULL,           'SortOrder', NULL,           NULL,       1, 0, 0, 40),
    ('shift',             'Shifts',              'Operations','mst', 'Shift',         'ShiftID',         'ShiftName',          NULL,           NULL,        NULL,           NULL,       1, 0, 0, 50),
    ('category',          'Post categories',     'Operations','mst', 'Category',      'CategoryID',      'CategoryName',       NULL,           'SortOrder', NULL,           NULL,       1, 0, 0, 60),
    ('servicetype',       'Service types',       'Operations','mst', 'ServiceType',   'ServiceTypeID',   'ServiceName',        NULL,           NULL,        NULL,           NULL,       1, 0, 0, 70),
    ('incidenttype',      'Incident types',      'Operations','mst', 'IncidentType',  'IncidentTypeID',  'IncidentTypeName',   NULL,           NULL,        NULL,           NULL,       1, 0, 0, 80),
    ('complainttype',     'Complaint types',     'Operations','mst', 'ComplaintType', 'ComplaintTypeID', 'ComplaintTypeName',  NULL,           NULL,        NULL,           NULL,       1, 0, 0, 90),
    ('uniformitem',       'Uniform items',       'Stores',    'mst', 'UniformItem',   'ItemID',          'ItemName',           NULL,           NULL,        NULL,           NULL,       1, 0, 0, 100),
    ('priority',          'Priorities',          'Tasks',     'mst', 'Priority',      'PriorityID',      'Name',               NULL,           'SortOrder', NULL,           NULL,       0, 0, 0, 110),
    ('taskstatus',        'Task statuses',       'Tasks',     'mst', 'TaskStatus',    'TaskStatusID',    'Name',               NULL,           'SortOrder', NULL,           NULL,       0, 0, 0, 120),
    ('repetition',        'Task repetitions',    'Tasks',     'mst', 'TaskRepetition','RepetitionID',    'Name',               NULL,           'SortOrder', NULL,           NULL,       0, 0, 0, 130),
    ('region',            'Regions',             'Geography', 'mst', 'Region',        'RegionID',        'RegionName',         NULL,           NULL,        NULL,           NULL,       1, 0, 0, 140),
    ('area',              'Areas',               'Geography', 'mst', 'Area',          'AreaID',          'AreaName',           NULL,           NULL,        'RegionID',     'region',   1, 0, 0, 150),
    ('holiday',           'Holidays',            'Payroll',   'mst', 'Holiday',       'HolidayID',       'HolidayName',        NULL,           NULL,        NULL,           NULL,       1, 0, 0, 160),
    ('branch',            'Branches',            'Company',   'org', 'Branch',        'BranchID',        'BranchName',         'BranchCode',   NULL,        NULL,           NULL,       1, 0, 1, 170),
    -- Platform reference data. Shared by every tenant, so only SUPER_ADMIN edits it.
    ('country',           'Countries',           'Geography', 'mst', 'Country',       'CountryID',       'CountryName',        'IsoCode',      NULL,        NULL,           NULL,       0, 1, 0, 200),
    ('state',             'States',              'Geography', 'mst', 'State',         'StateID',         'StateName',          'StateCode',    NULL,        'CountryID',    'country',  0, 1, 0, 210),
    ('district',          'Districts',           'Geography', 'mst', 'District',      'DistrictID',      'DistrictName',       NULL,           NULL,        'StateID',      'state',    0, 1, 0, 220),
    ('city',              'Cities',              'Geography', 'mst', 'City',          'CityID',          'CityName',           NULL,           NULL,        'DistrictID',   'district', 0, 1, 0, 230),
    ('bank',              'Banks',               'Finance',   'mst', 'Bank',          'BankID',          'BankName',           NULL,           NULL,        NULL,           NULL,       0, 1, 0, 240),
    ('logintype',         'Login types',         'Security',  'mst', 'LoginType',     'LoginTypeID',     'Name',               'RoleCode',     NULL,        NULL,           NULL,       0, 1, 0, 250)
) AS s (MasterKey, Label, GroupName, SchemaName, TableName, IdColumn, NameColumn, CodeColumn,
        SortColumn, ParentColumn, ParentKey, IsCompanyScoped, IsPlatformOnly, HasIsActive, SortOrder)
ON t.MasterKey = s.MasterKey
WHEN MATCHED THEN UPDATE SET
    t.Label = s.Label, t.GroupName = s.GroupName, t.SchemaName = s.SchemaName, t.TableName = s.TableName,
    t.IdColumn = s.IdColumn, t.NameColumn = s.NameColumn, t.CodeColumn = s.CodeColumn,
    t.SortColumn = s.SortColumn, t.ParentColumn = s.ParentColumn, t.ParentKey = s.ParentKey,
    t.IsCompanyScoped = s.IsCompanyScoped, t.IsPlatformOnly = s.IsPlatformOnly,
    t.HasIsActive = s.HasIsActive, t.SortOrder = s.SortOrder
WHEN NOT MATCHED THEN INSERT (MasterKey, Label, GroupName, SchemaName, TableName, IdColumn, NameColumn,
    CodeColumn, SortColumn, ParentColumn, ParentKey, IsCompanyScoped, IsPlatformOnly, HasIsActive, SortOrder)
VALUES (s.MasterKey, s.Label, s.GroupName, s.SchemaName, s.TableName, s.IdColumn, s.NameColumn,
    s.CodeColumn, s.SortColumn, s.ParentColumn, s.ParentKey, s.IsCompanyScoped, s.IsPlatformOnly,
    s.HasIsActive, s.SortOrder);
GO

PRINT '146_master_registry.sql  ->  OK';
GO
