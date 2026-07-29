using Diti365.Contracts.Common;
using Diti365.Infrastructure.Data;

namespace Diti365.Infrastructure.Repositories;

using Row = IReadOnlyDictionary<string, object?>;

public interface IFinanceRepository
{
    Task<IReadOnlyList<IReadOnlyList<Row>>> ValidatePayrollAsync(string monthYear, int? branchId, CancellationToken ct);
    Task<SpResult> GeneratePayrollAsync(string monthYear, int? branchId, CancellationToken ct);
    Task<SpResult> LockPayrollAsync(int runId, CancellationToken ct);
    Task<Row?> GetSalarySlipAsync(int empId, string monthYear, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetPayrollRegisterAsync(int runId, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetBankAdviceAsync(int runId, CancellationToken ct);
    Task<IReadOnlyList<Row>> GetStatutoryReturnAsync(int runId, string returnType, CancellationToken ct);

    Task<SpResult> GenerateInvoiceAsync(int clientId, byte month, short year, int? unitId, decimal gstPercent, CancellationToken ct);
    Task<PagedResult<Row>> GetInvoicesAsync(int? clientId, string? status, short? year, bool onlyOutstanding, int page, int pageSize, CancellationToken ct);
    Task<IReadOnlyList<IReadOnlyList<Row>>> GetInvoiceDetailAsync(int bid, CancellationToken ct);
    Task<SpResult> RecordReceiptAsync(int clientId, decimal amount, int? bid, DateOnly? receivedOn, string? mode, string? refNo, string? remark, CancellationToken ct);
    Task<PagedResult<Row>> GetReceiptsAsync(int? clientId, int? bid, int? branchId, string? mode, string? search, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);

    Task<PagedResult<Row>> GetAdvancesAsync(int? empId, int? branchId, string? status, string? search, DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct);
}

/// <summary>
/// Payroll is the highest-consequence path in the product: a defect here takes money
/// from a guard earning close to minimum wage. Nothing is computed in C# - every
/// figure comes from usp_Payroll_Generate so there is exactly one implementation of
/// the statutory rules, and it is the one covered by the golden-file tests.
/// </summary>
public sealed class FinanceRepository(IDbExecutor db) : IFinanceRepository
{
    public Task<IReadOnlyList<IReadOnlyList<Row>>> ValidatePayrollAsync(string monthYear, int? branchId, CancellationToken ct) =>
        Multi("dbo.usp_Payroll_Validate", p =>
        {
            p.Add(P.Char("@MonthYear", monthYear, 7));
            p.Add(P.Int ("@BranchID",  branchId));
        }, ct);

    public Task<SpResult> GeneratePayrollAsync(string monthYear, int? branchId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Payroll_Generate", p =>
        {
            p.Add(P.Char("@MonthYear", monthYear, 7));
            p.Add(P.Int ("@BranchID",  branchId));
            p.Add(P.OutInt("@RunID"));
        }, ct);

    public Task<SpResult> LockPayrollAsync(int runId, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Payroll_Lock", p => p.Add(P.Int("@RunID", runId)), ct);

    public Task<Row?> GetSalarySlipAsync(int empId, string monthYear, CancellationToken ct) =>
        db.QuerySingleAsync("dbo.usp_Payroll_GetSlip", p =>
        {
            p.Add(P.Int ("@EmpID",     empId));
            p.Add(P.Char("@MonthYear", monthYear, 7));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetPayrollRegisterAsync(int runId, int page, int pageSize, CancellationToken ct) =>
        Multi("dbo.usp_Payroll_GetRegister", p =>
        {
            p.Add(P.Int("@RunID",    runId));
            p.Add(P.Int("@PageNo",   page));
            p.Add(P.Int("@PageSize", pageSize));
        }, ct);

    public Task<IReadOnlyList<Row>> GetBankAdviceAsync(int runId, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Payroll_GetBankAdvice", p => p.Add(P.Int("@RunID", runId)), Map.Dynamic, ct);

    public Task<IReadOnlyList<Row>> GetStatutoryReturnAsync(int runId, string returnType, CancellationToken ct) =>
        db.QueryAsync("dbo.usp_Payroll_GetStatutoryReturn", p =>
        {
            p.Add(P.Int ("@RunID",      runId));
            p.Add(P.NVar("@ReturnType", returnType, 10));
        }, Map.Dynamic, ct);

    public Task<SpResult> GenerateInvoiceAsync(int clientId, byte month, short year, int? unitId, decimal gstPercent, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Invoice_Generate", p =>
        {
            p.Add(P.Int     ("@ClientID",   clientId));
            p.Add(P.TinyInt ("@Month",      month));
            p.Add(P.SmallInt("@Year",       year));
            p.Add(P.Int     ("@UnitID",     unitId));
            p.Add(P.Dec     ("@GstPercent", gstPercent, 5, 2));
            p.Add(P.OutInt  ("@Bid"));
        }, ct);

    public Task<PagedResult<Row>> GetInvoicesAsync(int? clientId, string? status, short? year, bool onlyOutstanding,
                                                   int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Invoice_GetList", p =>
        {
            p.Add(P.Int     ("@ClientID",         clientId));
            p.Add(P.NVar    ("@Status",           status, 20));
            p.Add(P.SmallInt("@Year",             year));
            p.Add(P.Bit     ("@OnlyOutstanding",  onlyOutstanding));
            p.Add(P.Int     ("@PageNo",           page));
            p.Add(P.Int     ("@PageSize",         pageSize));
        }, Map.Dynamic, ct);

    public Task<IReadOnlyList<IReadOnlyList<Row>>> GetInvoiceDetailAsync(int bid, CancellationToken ct) =>
        Multi("dbo.usp_Invoice_GetDetail", p => p.Add(P.Int("@Bid", bid)), ct);

    public Task<SpResult> RecordReceiptAsync(int clientId, decimal amount, int? bid, DateOnly? receivedOn,
                                             string? mode, string? refNo, string? remark, CancellationToken ct) =>
        db.ExecuteAsync("dbo.usp_Receipt_Insert", p =>
        {
            p.Add(P.Int  ("@ClientID",   clientId));
            p.Add(P.Money("@Amount",     amount));
            p.Add(P.Int  ("@Bid",        bid));
            p.Add(P.Date ("@ReceivedOn", receivedOn));
            p.Add(P.NVar ("@Mode",       mode, 30));
            p.Add(P.NVar ("@RefNo",      refNo, 50));
            p.Add(P.NVar ("@Remark",     remark, 500));
        }, ct);

    public Task<PagedResult<Row>> GetReceiptsAsync(int? clientId, int? bid, int? branchId, string? mode, string? search,
                                                   DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Receipt_GetList", p =>
        {
            p.Add(P.Int ("@ClientID", clientId));
            p.Add(P.Int ("@Bid",      bid));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Mode",     mode, 30));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Date("@From",     from));
            p.Add(P.Date("@To",       to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    public Task<PagedResult<Row>> GetAdvancesAsync(int? empId, int? branchId, string? status, string? search,
                                                   DateOnly? from, DateOnly? to, int page, int pageSize, CancellationToken ct) =>
        db.QueryPagedAsync("dbo.usp_Advance_GetList", p =>
        {
            p.Add(P.Int ("@EmpID",    empId));
            p.Add(P.Int ("@BranchID", branchId));
            p.Add(P.NVar("@Status",   status, 20));
            p.Add(P.NVar("@Search",   search, 200));
            p.Add(P.Date("@From",     from));
            p.Add(P.Date("@To",       to));
            p.Add(P.Int ("@PageNo",   page));
            p.Add(P.Int ("@PageSize", pageSize));
        }, Map.Dynamic, ct);

    private Task<IReadOnlyList<IReadOnlyList<Row>>> Multi(
        string procedure, Action<Microsoft.Data.SqlClient.SqlParameterCollection>? parameters, CancellationToken ct) =>
        db.QueryMultipleAsync(procedure, parameters, async (reader, token) =>
        {
            var sets = new List<IReadOnlyList<Row>>();
            do
            {
                var rows = new List<Row>();
                if (reader.HasRows)
                {
                    var map = Map.Dynamic(reader);
                    while (await reader.ReadAsync(token).ConfigureAwait(false)) rows.Add(map(reader));
                }
                sets.Add(rows);
            }
            while (await reader.NextResultAsync(token).ConfigureAwait(false));
            return (IReadOnlyList<IReadOnlyList<Row>>)sets;
        }, ct);
}
