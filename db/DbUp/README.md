DbUp Runner

This small console app runs the SQL migration scripts in db/scripts in numeric order using DbUp.

Build:
  cd db\DbUp
  dotnet build

Run (provide a connection string):
  cd db\DbUp
  dotnet run -- --connectionString "Server=localhost;Database=Diti365_Dev;Trusted_Connection=True;TrustServerCertificate=True"

Or use the pre-built runner DLL:
  dotnet bin\Debug\net10.0\DbUpRunner.dll --connectionString "Server=localhost;Database=Diti365_Dev;Trusted_Connection=True;TrustServerCertificate=True"

Notes:
- The runner expects the scripts folder at ../scripts relative to the project output. If needed, pass --scripts "C:\path\to\db\scripts".
- Scripts are executed in filename order. All scripts are idempotent; re-running is safe.
- Use this runner where sqlcmd is not available or when running migrations from CI.

Security:
- Avoid embedding secrets in repo. Prefer passing connection string via environment variable (e.g., DOTNET_ENVIRONMENT) or CI secret.

For local development the existing PowerShell helper db\run-all.ps1 remains the recommended, interactive option.