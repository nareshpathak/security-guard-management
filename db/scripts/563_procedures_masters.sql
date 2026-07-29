/*==============================================================================
  563_procedures_masters.sql
  Master management: catalogue, list, save, activate, delete.

  Every identifier comes from mst.MasterRegistry and passes through QUOTENAME.
  Every value is a parameter to sp_executesql. The caller supplies a MasterKey
  and nothing else that reaches the SQL text.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*==============================================================================
  usp_Master_GetCatalog
  What this user is allowed to manage. Drives the master screen's picker.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Master_GetCatalog
    @CompanyID INT,
    @UserID    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsPlatform BIT = 0;
    SELECT @IsPlatform = CASE WHEN r.RoleCode = N'SUPER_ADMIN' THEN 1 ELSE 0 END
    FROM sec.Users AS u
    INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID
    WHERE u.UserID = @UserID;

    SELECT
        m.MasterKey, m.Label, m.GroupName,
        m.IsCompanyScoped, m.IsPlatformOnly, m.HasIsActive,
        HasCode   = CAST(CASE WHEN m.CodeColumn   IS NULL THEN 0 ELSE 1 END AS BIT),
        HasSort   = CAST(CASE WHEN m.SortColumn   IS NULL THEN 0 ELSE 1 END AS BIT),
        HasParent = CAST(CASE WHEN m.ParentColumn IS NULL THEN 0 ELSE 1 END AS BIT),
        m.ParentKey,
        /*  Platform reference data is shown to everyone so an agency admin can
            see what a state or bank is called, but it is read-only for them.  */
        CanEdit = CAST(CASE WHEN m.IsPlatformOnly = 1 AND @IsPlatform = 0 THEN 0 ELSE 1 END AS BIT)
    FROM mst.MasterRegistry AS m
    ORDER BY m.GroupName, m.SortOrder, m.Label;
END;
GO

/*==============================================================================
  usp_Master_GetEntries
  One page of one master, with search and an active/inactive filter.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Master_GetEntries
    @CompanyID       INT,
    @UserID          INT,
    @MasterKey       NVARCHAR(50),
    @Search          NVARCHAR(200) = NULL,
    @ParentID        INT           = NULL,
    @IncludeInactive BIT           = 0,
    @PageNo          INT           = 1,
    @PageSize        INT           = 50
AS
BEGIN
    SET NOCOUNT ON;
    IF @PageSize IS NULL OR @PageSize < 1 SET @PageSize = 50;
    IF @PageSize > 500 SET @PageSize = 500;
    IF @PageNo   IS NULL OR @PageNo   < 1 SET @PageNo   = 1;

    DECLARE @Schema SYSNAME, @Table SYSNAME, @Id SYSNAME, @Name SYSNAME,
            @Code SYSNAME, @Sort SYSNAME, @Parent SYSNAME,
            @Scoped BIT, @HasActive BIT;

    SELECT @Schema = SchemaName, @Table = TableName, @Id = IdColumn, @Name = NameColumn,
           @Code = CodeColumn, @Sort = SortColumn, @Parent = ParentColumn,
           @Scoped = IsCompanyScoped, @HasActive = HasIsActive
    FROM mst.MasterRegistry WHERE MasterKey = @MasterKey;

    IF @Schema IS NULL THROW 51031, 'Unknown master.', 1;

    DECLARE @sql NVARCHAR(MAX) =
        N'SELECT Id = t.' + QUOTENAME(@Id) + N',' + CHAR(10) +
        N'       Name = t.' + QUOTENAME(@Name) + N',' + CHAR(10) +
        N'       Code = ' + CASE WHEN @Code IS NULL THEN N'CAST(NULL AS NVARCHAR(50))'
                                 ELSE N'CAST(t.' + QUOTENAME(@Code) + N' AS NVARCHAR(50))' END + N',' + CHAR(10) +
        N'       SortOrder = ' + CASE WHEN @Sort IS NULL THEN N'CAST(NULL AS INT)'
                                      ELSE N't.' + QUOTENAME(@Sort) END + N',' + CHAR(10) +
        N'       ParentId = ' + CASE WHEN @Parent IS NULL THEN N'CAST(NULL AS INT)'
                                     ELSE N't.' + QUOTENAME(@Parent) END + N',' + CHAR(10) +
        N'       IsActive = ' + CASE WHEN @HasActive = 1 THEN N't.IsActive'
                                     ELSE N'CAST(1 AS BIT)' END + N',' + CHAR(10) +
        N'       t.InsertDate' + CHAR(10) +
        N'FROM ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' AS t' + CHAR(10) +
        N'WHERE t.IsCancel = 0' + CHAR(10) +
        /*  A tenant sees its own rows plus the platform defaults, which carry a
            NULL CompanyID. Dropping those would empty half the dropdowns.  */
        CASE WHEN @Scoped = 1 THEN N'  AND (t.CompanyID IS NULL OR t.CompanyID = @CompanyID)' + CHAR(10) ELSE N'' END +
        CASE WHEN @HasActive = 1 THEN N'  AND (@IncludeInactive = 1 OR t.IsActive = 1)' + CHAR(10) ELSE N'' END +
        CASE WHEN @Parent IS NULL THEN N'' ELSE N'  AND (@ParentID IS NULL OR t.' + QUOTENAME(@Parent) + N' = @ParentID)' + CHAR(10) END +
        N'  AND (@Search IS NULL OR t.' + QUOTENAME(@Name) + N' LIKE N''%'' + @Search + N''%''' +
        CASE WHEN @Code IS NULL THEN N')' ELSE N' OR t.' + QUOTENAME(@Code) + N' LIKE N''%'' + @Search + N''%'')' END + CHAR(10) +
        N'ORDER BY ' + CASE WHEN @Sort IS NULL THEN N't.' + QUOTENAME(@Name)
                            ELSE N't.' + QUOTENAME(@Sort) + N', t.' + QUOTENAME(@Name) END + CHAR(10) +
        N'OFFSET (@PageNo - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;' + CHAR(10) + CHAR(10) +
        N'SELECT TotalRows = COUNT(*) FROM ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' AS t' + CHAR(10) +
        N'WHERE t.IsCancel = 0' + CHAR(10) +
        CASE WHEN @Scoped = 1 THEN N'  AND (t.CompanyID IS NULL OR t.CompanyID = @CompanyID)' + CHAR(10) ELSE N'' END +
        CASE WHEN @HasActive = 1 THEN N'  AND (@IncludeInactive = 1 OR t.IsActive = 1)' + CHAR(10) ELSE N'' END +
        CASE WHEN @Parent IS NULL THEN N'' ELSE N'  AND (@ParentID IS NULL OR t.' + QUOTENAME(@Parent) + N' = @ParentID)' + CHAR(10) END +
        N'  AND (@Search IS NULL OR t.' + QUOTENAME(@Name) + N' LIKE N''%'' + @Search + N''%''' +
        CASE WHEN @Code IS NULL THEN N');' ELSE N' OR t.' + QUOTENAME(@Code) + N' LIKE N''%'' + @Search + N''%'');' END;

    EXEC sp_executesql @sql,
        N'@CompanyID INT, @Search NVARCHAR(200), @ParentID INT, @IncludeInactive BIT, @PageNo INT, @PageSize INT',
        @CompanyID, @Search, @ParentID, @IncludeInactive, @PageNo, @PageSize;
END;
GO

/*==============================================================================
  usp_Master_Save
  Insert or update one entry. @Id NULL inserts.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Master_Save
    @CompanyID INT,
    @UserID    INT,
    @MasterKey NVARCHAR(50),
    @Id        INT           = NULL,
    @Name      NVARCHAR(200),
    @Code      NVARCHAR(50)  = NULL,
    @SortOrder INT           = NULL,
    @ParentID  INT           = NULL,
    @IsActive  BIT           = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Name IS NULL OR LEN(LTRIM(RTRIM(@Name))) = 0
        THROW 51032, 'A name is required.', 1;

    DECLARE @Schema SYSNAME, @Table SYSNAME, @IdCol SYSNAME, @NameCol SYSNAME,
            @CodeCol SYSNAME, @SortCol SYSNAME, @ParentCol SYSNAME,
            @Scoped BIT, @HasActive BIT, @PlatformOnly BIT;

    SELECT @Schema = SchemaName, @Table = TableName, @IdCol = IdColumn, @NameCol = NameColumn,
           @CodeCol = CodeColumn, @SortCol = SortColumn, @ParentCol = ParentColumn,
           @Scoped = IsCompanyScoped, @HasActive = HasIsActive, @PlatformOnly = IsPlatformOnly
    FROM mst.MasterRegistry WHERE MasterKey = @MasterKey;

    IF @Schema IS NULL THROW 51031, 'Unknown master.', 1;

    /*  Platform reference data is shared by every tenant. One agency renaming a
        state would rename it for all of them, so only SUPER_ADMIN may.  */
    IF @PlatformOnly = 1
       AND NOT EXISTS (SELECT 1 FROM sec.Users AS u
                       INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID
                       WHERE u.UserID = @UserID AND r.RoleCode = N'SUPER_ADMIN')
        THROW 51033, 'This list is shared across all agencies and can only be changed by the platform administrator.', 1;

    SET @Name = LTRIM(RTRIM(@Name));

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @NewId INT;

    IF @Id IS NULL
    BEGIN
        /*  A duplicate name in a dropdown is how "Security Guard" ends up in a
            master four times. Rejecting it here is cheaper than cleaning it up.  */
        SET @sql =
            N'IF EXISTS (SELECT 1 FROM ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) +
            N' WHERE IsCancel = 0 AND ' + QUOTENAME(@NameCol) + N' = @Name' +
            CASE WHEN @Scoped = 1 THEN N' AND (CompanyID IS NULL OR CompanyID = @CompanyID)' ELSE N'' END +
            CASE WHEN @ParentCol IS NULL THEN N'' ELSE N' AND ' + QUOTENAME(@ParentCol) + N' = @ParentID' END +
            N') THROW 51034, ''That name already exists in this list.'', 1;' + CHAR(10) +
            N'INSERT INTO ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' (' +
            QUOTENAME(@NameCol) +
            CASE WHEN @Scoped    = 1    THEN N', CompanyID'          ELSE N'' END +
            CASE WHEN @CodeCol   IS NULL THEN N''  ELSE N', ' + QUOTENAME(@CodeCol)   END +
            CASE WHEN @SortCol   IS NULL THEN N''  ELSE N', ' + QUOTENAME(@SortCol)   END +
            CASE WHEN @ParentCol IS NULL THEN N''  ELSE N', ' + QUOTENAME(@ParentCol) END +
            CASE WHEN @HasActive = 1    THEN N', IsActive'           ELSE N'' END +
            N', InsertDate, InsertUserID) VALUES (@Name' +
            CASE WHEN @Scoped    = 1    THEN N', @CompanyID' ELSE N'' END +
            CASE WHEN @CodeCol   IS NULL THEN N''  ELSE N', @Code'     END +
            CASE WHEN @SortCol   IS NULL THEN N''  ELSE N', ISNULL(@SortOrder, 100)' END +
            CASE WHEN @ParentCol IS NULL THEN N''  ELSE N', @ParentID' END +
            CASE WHEN @HasActive = 1    THEN N', @IsActive'  ELSE N'' END +
            N', SYSDATETIME(), @UserID);' + CHAR(10) +
            N'SET @NewId = CAST(SCOPE_IDENTITY() AS INT);';

        EXEC sp_executesql @sql,
            N'@CompanyID INT, @UserID INT, @Name NVARCHAR(200), @Code NVARCHAR(50), @SortOrder INT, @ParentID INT, @IsActive BIT, @NewId INT OUTPUT',
            @CompanyID, @UserID, @Name, @Code, @SortOrder, @ParentID, @IsActive, @NewId OUTPUT;

        SELECT Success = CAST(1 AS BIT), Status = 200, Id = @NewId, Message = N'Added';
        RETURN;
    END

    /*  A tenant must not be able to edit another tenant's row, nor a platform
        default, by supplying its id. The UPDATE carries the same scope test as
        the read.  */
    SET @sql =
        N'UPDATE ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' SET ' +
        QUOTENAME(@NameCol) + N' = @Name' +
        CASE WHEN @CodeCol   IS NULL THEN N'' ELSE N', ' + QUOTENAME(@CodeCol)   + N' = @Code' END +
        CASE WHEN @SortCol   IS NULL THEN N'' ELSE N', ' + QUOTENAME(@SortCol)   + N' = ISNULL(@SortOrder, ' + QUOTENAME(@SortCol) + N')' END +
        CASE WHEN @ParentCol IS NULL THEN N'' ELSE N', ' + QUOTENAME(@ParentCol) + N' = ISNULL(@ParentID, ' + QUOTENAME(@ParentCol) + N')' END +
        CASE WHEN @HasActive = 1    THEN N', IsActive = @IsActive' ELSE N'' END +
        N', UpdateDate = SYSDATETIME(), UpdateUserID = @UserID' + CHAR(10) +
        N'WHERE ' + QUOTENAME(@IdCol) + N' = @Id AND IsCancel = 0' +
        CASE WHEN @Scoped = 1 THEN N' AND CompanyID = @CompanyID' ELSE N'' END + N';';

    DECLARE @Rows INT;
    EXEC sp_executesql @sql,
        N'@CompanyID INT, @UserID INT, @Id INT, @Name NVARCHAR(200), @Code NVARCHAR(50), @SortOrder INT, @ParentID INT, @IsActive BIT',
        @CompanyID, @UserID, @Id, @Name, @Code, @SortOrder, @ParentID, @IsActive;

    SET @Rows = @@ROWCOUNT;

    IF @Rows = 0
        SELECT Success = CAST(0 AS BIT), Status = 404, Id = @Id,
               Message = N'That entry does not exist, or belongs to another agency.';
    ELSE
        SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Id, Message = N'Saved';
END;
GO

/*==============================================================================
  usp_Master_SetStatus
  Deactivate, reactivate, or cancel an entry.

  Cancelling is refused while anything still points at the row. A designation
  that vanishes from under 300 employees is not a deletion, it is a corruption.
==============================================================================*/
CREATE OR ALTER PROCEDURE dbo.usp_Master_SetStatus
    @CompanyID INT,
    @UserID    INT,
    @MasterKey NVARCHAR(50),
    @Id        INT,
    @IsActive  BIT = NULL,   -- NULL leaves it alone
    @Cancel    BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Schema SYSNAME, @Table SYSNAME, @IdCol SYSNAME,
            @Scoped BIT, @HasActive BIT, @PlatformOnly BIT;

    SELECT @Schema = SchemaName, @Table = TableName, @IdCol = IdColumn,
           @Scoped = IsCompanyScoped, @HasActive = HasIsActive, @PlatformOnly = IsPlatformOnly
    FROM mst.MasterRegistry WHERE MasterKey = @MasterKey;

    IF @Schema IS NULL THROW 51031, 'Unknown master.', 1;

    IF @PlatformOnly = 1
       AND NOT EXISTS (SELECT 1 FROM sec.Users AS u
                       INNER JOIN sec.Role AS r ON r.RoleID = u.RoleID
                       WHERE u.UserID = @UserID AND r.RoleCode = N'SUPER_ADMIN')
        THROW 51033, 'This list is shared across all agencies and can only be changed by the platform administrator.', 1;

    IF @Cancel = 1
    BEGIN
        /*  Count every foreign key pointing at this row before removing it.
            sys.foreign_keys knows the answer; hard-coding the referencing
            tables would rot the first time somebody adds one.  */
        DECLARE @refs INT = 0, @refTable NVARCHAR(300), @refCol SYSNAME, @cnt INT;
        DECLARE @check NVARCHAR(MAX);

        DECLARE fk CURSOR LOCAL FAST_FORWARD FOR
            SELECT QUOTENAME(SCHEMA_NAME(ft.schema_id)) + N'.' + QUOTENAME(ft.name), fc.name
            FROM sys.foreign_keys AS f
            INNER JOIN sys.tables  AS ft ON ft.object_id = f.parent_object_id
            INNER JOIN sys.foreign_key_columns AS fkc ON fkc.constraint_object_id = f.object_id
            INNER JOIN sys.columns AS fc ON fc.object_id = fkc.parent_object_id AND fc.column_id = fkc.parent_column_id
            WHERE f.referenced_object_id = OBJECT_ID(QUOTENAME(@Schema) + '.' + QUOTENAME(@Table));

        OPEN fk;
        FETCH NEXT FROM fk INTO @refTable, @refCol;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @check = N'SELECT @cnt = COUNT(*) FROM ' + @refTable + N' WHERE ' + QUOTENAME(@refCol) + N' = @Id;';
            EXEC sp_executesql @check, N'@Id INT, @cnt INT OUTPUT', @Id, @cnt OUTPUT;
            SET @refs = @refs + ISNULL(@cnt, 0);
            FETCH NEXT FROM fk INTO @refTable, @refCol;
        END
        CLOSE fk; DEALLOCATE fk;

        IF @refs > 0
        BEGIN
            SELECT Success = CAST(0 AS BIT), Status = 409, Id = @Id,
                   Message = CONCAT(N'Still used by ', @refs, N' record(s). Deactivate it instead so existing records keep their meaning.');
            RETURN;
        END
    END

    DECLARE @sql NVARCHAR(MAX) =
        N'UPDATE ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' SET ' +
        CASE WHEN @Cancel = 1 THEN N'IsCancel = 1'
             WHEN @HasActive = 1 THEN N'IsActive = @IsActive'
             /*  A master with no IsActive column can only be cancelled. Saying
                 so is better than silently doing nothing.  */
             ELSE N'IsCancel = IsCancel' END +
        N', UpdateDate = SYSDATETIME(), UpdateUserID = @UserID' +
        N' WHERE ' + QUOTENAME(@IdCol) + N' = @Id AND IsCancel = 0' +
        CASE WHEN @Scoped = 1 THEN N' AND CompanyID = @CompanyID' ELSE N'' END + N';';

    EXEC sp_executesql @sql,
        N'@CompanyID INT, @UserID INT, @Id INT, @IsActive BIT',
        @CompanyID, @UserID, @Id, @IsActive;

    IF @@ROWCOUNT = 0
        SELECT Success = CAST(0 AS BIT), Status = 404, Id = @Id,
               Message = N'That entry does not exist, or belongs to another agency.';
    ELSE IF @Cancel = 1
        SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Id, Message = N'Deleted';
    ELSE IF @HasActive = 0
        SELECT Success = CAST(0 AS BIT), Status = 422, Id = @Id,
               Message = N'This list does not support deactivating. Delete the entry instead.';
    ELSE
        SELECT Success = CAST(1 AS BIT), Status = 200, Id = @Id,
               Message = CASE WHEN @IsActive = 1 THEN N'Activated' ELSE N'Deactivated' END;
END;
GO

PRINT '563_procedures_masters.sql  ->  OK';
GO
