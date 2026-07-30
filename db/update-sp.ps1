$cs = "Server=(localdb)\mssqllocaldb;Database=Diti365;Trusted_Connection=True;TrustServerCertificate=True"
$conn = New-Object System.Data.SqlClient.SqlConnection($cs)
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = @"
CREATE OR ALTER PROCEDURE dbo.usp_User_CheckDeviceId
    @UserID   INT,
    @DeviceID NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE sec.Users SET DeviceID = @DeviceID, UpdateDate = SYSDATETIME() WHERE UserID = @UserID;
    SELECT Success = CAST(1 AS BIT), Status = 200, Id = @UserID, Message = N'Device recognised', DeviceId = @DeviceID;
END;
GO
UPDATE sec.Users SET DeviceID = NULL;
"@

# Execute SQL in batches
$batches = $cmd.CommandText -split '(?i)\r?\nGO\r?\n'
foreach ($b in $batches) {
    if ($b.Trim()) {
        $cmd.CommandText = $b
        $cmd.ExecuteNonQuery()
    }
}
$conn.Close()
Write-Host "Database device lock reset successfully!"
