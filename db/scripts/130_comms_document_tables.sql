/*==============================================================================
  130_comms_document_tables.sql
  Document vault, chat and notifications (schema: doc)
  Spec: docs/prd/01-database.md §2.9

  doc.Document.OwnerID is deliberately polymorphic (OwnerType + OwnerID) and
  therefore has no foreign key. Referential integrity is enforced by the
  stored procedures that write to it.
==============================================================================*/
SET NOCOUNT ON;
GO
-- Required for filtered indexes, indexed views and computed-column indexes.
-- sqlcmd defaults QUOTED_IDENTIFIER to OFF, so it must be set explicitly.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/*---------------------------------------------------------------- DOCUMENT */
IF OBJECT_ID('doc.Document','U') IS NULL
CREATE TABLE doc.Document (
    DocumentID       INT            IDENTITY(1,1) NOT NULL CONSTRAINT PK_doc_Document PRIMARY KEY,
    CompanyID        INT            NOT NULL,
    OwnerType        NVARCHAR(20)   NOT NULL,      -- Employee / Unit / Client / Company / Incident / Task
    OwnerID          INT            NOT NULL,
    DocTypeID        INT            NULL,
    DocumentFilename NVARCHAR(300)  NULL,
    BlobUrl          NVARCHAR(1000) NOT NULL,
    MimeType         NVARCHAR(100)  NULL,
    SizeBytes        BIGINT         NULL,
    IssueDate        DATE           NULL,
    ExpiryDate       DATE           NULL,
    IsVerified       BIT            NOT NULL CONSTRAINT DF_doc_Document_IsVerified DEFAULT (0),
    VerifiedBy       INT            NULL,
    VerifiedOn       DATETIME2(0)   NULL,
    ScanStatus       NVARCHAR(20)   NOT NULL CONSTRAINT DF_doc_Document_ScanStatus DEFAULT (N'Pending'),
    Remark           NVARCHAR(500)  NULL,
    IsCancel         BIT            NOT NULL CONSTRAINT DF_doc_Document_IsCancel   DEFAULT (0),
    InsertDate       DATETIME2(0)   NOT NULL CONSTRAINT DF_doc_Document_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID     INT            NULL,
    UpdateDate       DATETIME2(0)   NULL,
    UpdateUserID     INT            NULL,
    CONSTRAINT FK_doc_Document_Company    FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_doc_Document_DocType    FOREIGN KEY (DocTypeID)  REFERENCES mst.DocumentType (DocTypeID),
    CONSTRAINT FK_doc_Document_VerifiedBy FOREIGN KEY (VerifiedBy) REFERENCES sec.Users (UserID),
    CONSTRAINT CK_doc_Document_OwnerType  CHECK (OwnerType IN (N'Employee',N'Unit',N'Client',N'Company',N'Incident',N'Task')),
    CONSTRAINT CK_doc_Document_ScanStatus CHECK (ScanStatus IN (N'Pending',N'Clean',N'Infected',N'Failed'))
);
GO

IF OBJECT_ID('doc.DocumentExpiryAlert','U') IS NULL
CREATE TABLE doc.DocumentExpiryAlert (
    AlertID         INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_doc_DocumentExpiryAlert PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    DocumentID      INT             NOT NULL,
    AlertOn         DATE            NOT NULL,
    AlertLevel      TINYINT         NOT NULL,      -- 90 / 30 / 7 days before expiry
    IsSent          BIT             NOT NULL CONSTRAINT DF_doc_DocumentExpiryAlert_IsSent DEFAULT (0),
    SentOn          DATETIME2(0)    NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_doc_DocumentExpiryAlert_InsertDate DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_doc_DocumentExpiryAlert_Company  FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_doc_DocumentExpiryAlert_Document FOREIGN KEY (DocumentID) REFERENCES doc.Document (DocumentID),
    CONSTRAINT UQ_doc_DocumentExpiryAlert UNIQUE (DocumentID, AlertLevel)
);
GO

/*-------------------------------------------------------------------- CHAT */
IF OBJECT_ID('doc.ChatThread','U') IS NULL
CREATE TABLE doc.ChatThread (
    ThreadID        INT             IDENTITY(1,1) NOT NULL CONSTRAINT PK_doc_ChatThread PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    ThreadType      NVARCHAR(20)    NOT NULL CONSTRAINT DF_doc_ChatThread_Type DEFAULT (N'Direct'),
    Title           NVARCHAR(200)   NULL,
    UserAID         INT             NULL,
    UserBID         INT             NULL,
    LastMessageAt   DATETIME2(0)    NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_doc_ChatThread_IsCancel   DEFAULT (0),
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_doc_ChatThread_InsertDate DEFAULT (SYSDATETIME()),
    InsertUserID    INT             NULL,
    CONSTRAINT FK_doc_ChatThread_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_doc_ChatThread_UserA   FOREIGN KEY (UserAID)   REFERENCES sec.Users (UserID),
    CONSTRAINT FK_doc_ChatThread_UserB   FOREIGN KEY (UserBID)   REFERENCES sec.Users (UserID),
    CONSTRAINT CK_doc_ChatThread_Type CHECK (ThreadType IN (N'Direct',N'Group',N'Broadcast'))
);
GO

IF OBJECT_ID('doc.ChatMessage','U') IS NULL
CREATE TABLE doc.ChatMessage (
    MessageID       BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_doc_ChatMessage PRIMARY KEY,
    ThreadID        INT             NOT NULL,
    CompanyID       INT             NOT NULL,
    FromUserID      INT             NOT NULL,
    ToUserID        INT             NULL,
    Body            NVARCHAR(MAX)   NULL,
    MessageType     NVARCHAR(20)    NOT NULL CONSTRAINT DF_doc_ChatMessage_Type DEFAULT (N'Text'),
    AttachmentUrl   NVARCHAR(1000)  NULL,
    Latitude        DECIMAL(10,7)   NULL,
    Longitude       DECIMAL(10,7)   NULL,
    SentAt          DATETIME2(0)    NOT NULL CONSTRAINT DF_doc_ChatMessage_SentAt DEFAULT (SYSDATETIME()),
    ReadAt          DATETIME2(0)    NULL,
    ClientRequestId UNIQUEIDENTIFIER NULL,
    IsCancel        BIT             NOT NULL CONSTRAINT DF_doc_ChatMessage_IsCancel DEFAULT (0),
    CONSTRAINT FK_doc_ChatMessage_Thread   FOREIGN KEY (ThreadID)   REFERENCES doc.ChatThread (ThreadID),
    CONSTRAINT FK_doc_ChatMessage_Company  FOREIGN KEY (CompanyID)  REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_doc_ChatMessage_FromUser FOREIGN KEY (FromUserID) REFERENCES sec.Users (UserID),
    CONSTRAINT FK_doc_ChatMessage_ToUser   FOREIGN KEY (ToUserID)   REFERENCES sec.Users (UserID),
    CONSTRAINT CK_doc_ChatMessage_Type CHECK (MessageType IN (N'Text',N'Image',N'File',N'Location'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='UX_doc_ChatMessage_ClientRequestId' AND object_id=OBJECT_ID('doc.ChatMessage'))
    CREATE UNIQUE INDEX UX_doc_ChatMessage_ClientRequestId
        ON doc.ChatMessage (ClientRequestId) WHERE ClientRequestId IS NOT NULL;
GO

/*----------------------------------------------------------- NOTIFICATIONS */
IF OBJECT_ID('doc.Notification','U') IS NULL
CREATE TABLE doc.Notification (
    NotificationID  BIGINT          IDENTITY(1,1) NOT NULL CONSTRAINT PK_doc_Notification PRIMARY KEY,
    CompanyID       INT             NOT NULL,
    UserID          INT             NOT NULL,
    Title           NVARCHAR(200)   NOT NULL,
    Body            NVARCHAR(1000)  NULL,
    DataJson        NVARCHAR(MAX)   NULL,
    Category        NVARCHAR(50)    NULL,          -- Attendance / Patrol / Task / Complaint / Payroll / Alert
    DeepLink        NVARCHAR(300)   NULL,
    IsRead          BIT             NOT NULL CONSTRAINT DF_doc_Notification_IsRead DEFAULT (0),
    ReadAt          DATETIME2(0)    NULL,
    SentAt          DATETIME2(0)    NULL,
    FcmMessageId    NVARCHAR(200)   NULL,
    InsertDate      DATETIME2(0)    NOT NULL CONSTRAINT DF_doc_Notification_InsertDate DEFAULT (SYSDATETIME()),
    CONSTRAINT FK_doc_Notification_Company FOREIGN KEY (CompanyID) REFERENCES org.Company (CompanyID),
    CONSTRAINT FK_doc_Notification_User    FOREIGN KEY (UserID)    REFERENCES sec.Users (UserID),
    CONSTRAINT CK_doc_Notification_Data    CHECK (DataJson IS NULL OR ISJSON(DataJson) = 1)
);
GO

PRINT '130_comms_document_tables.sql  ->  OK  (5 tables)';
GO
