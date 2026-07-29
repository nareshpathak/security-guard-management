using Diti365.Api.Controllers;
using Diti365.Api.Filters;
using Diti365.Application.Abstractions;
using Diti365.Application.Security;
using Diti365.Contracts.Common;
using Diti365.Domain;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/v2")]
public sealed class FinanceController(ICurrentUser currentUser, IFinanceRepository repo)
    : ApiControllerBase(currentUser)
{
    /// <summary>
    /// Step 2 of the payroll wizard: the blocking list.
    ///
    /// Unapproved attendance, missing salary structures, missing bank details and
    /// employees with no attendance at all. Nothing is generated until this is empty,
    /// because a payroll run built on unapproved days pays people for time nobody
    /// verified.
    /// </summary>
    [HttpGet("payroll/validate"), HasPermission(Perm.PayrollView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Validate(
        [FromQuery] string monthYear, [FromQuery] int? branchId) =>
        Data(await repo.ValidatePayrollAsync(monthYear, branchId, Ct));

    [HttpPost("payroll/runs"), HasPermission(Perm.PayrollEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Generate([FromBody] GeneratePayrollRequest r) =>
        Command(await repo.GeneratePayrollAsync(r.MonthYear, r.BranchId, Ct));

    /// <summary>
    /// Locking is irreversible by design. It also recovers advance instalments and
    /// uniform amounts exactly once, and closes the month for attendance edits.
    /// </summary>
    [HttpPost("payroll/runs/{runId:int}/lock"), HasPermission(Perm.PayrollApprove)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Lock(int runId) =>
        Command(await repo.LockPayrollAsync(runId, Ct));

    [HttpGet("payroll/runs/{runId:int}"), HasPermission(Perm.PayrollView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Register(
        int runId, [FromQuery] PagedQuery q) =>
        Data(await repo.GetPayrollRegisterAsync(runId, q.Page, q.PageSize, Ct));

    /// <summary>A guard reads his own slip; anyone else needs the payroll view permission.</summary>
    [HttpGet("payroll/slips/{empId:int}/{monthYear}")]
    public async Task<ActionResult<ApiResponse<Row?>>> Slip(int empId, string monthYear)
    {
        if (empId != Me.EmpId && !Me.Has(Perm.PayrollView))
            throw DomainException.Forbidden("You may only view your own salary slip.");

        return Data(await repo.GetSalarySlipAsync(empId, monthYear, Ct));
    }

    [HttpGet("payroll/runs/{runId:int}/bank-advice"), HasPermission(Perm.PayrollApprove)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> BankAdvice(int runId) =>
        Data(await repo.GetBankAdviceAsync(runId, Ct));

    /// <summary>PF ECR or ESIC return dataset for the month.</summary>
    [HttpGet("payroll/runs/{runId:int}/statutory/{returnType}"), HasPermission(Perm.PayrollView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Statutory(int runId, string returnType) =>
        Data(await repo.GetStatutoryReturnAsync(runId, returnType, Ct));

    // --------------------------------------------------------------- billing

    [HttpPost("invoices/generate"), HasPermission(Perm.InvoiceEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> GenerateInvoice([FromBody] GenerateInvoiceRequest r) =>
        Command(await repo.GenerateInvoiceAsync(r.ClientId, r.Month, r.Year, r.UnitId, r.GstPercent, Ct));

    [HttpGet("invoices"), HasPermission(Perm.InvoiceView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Invoices(
        [FromQuery] PagedQuery q, [FromQuery] int? clientId, [FromQuery] short? year,
        [FromQuery] bool onlyOutstanding = false)
    {
        var result = await repo.GetInvoicesAsync(clientId, q.Status, year, onlyOutstanding, q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    [HttpGet("invoices/{bid:int}"), HasPermission(Perm.InvoiceView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<IReadOnlyList<Row>>>>> Invoice(int bid) =>
        Data(await repo.GetInvoiceDetailAsync(bid, Ct));

    [HttpPost("receipts"), HasPermission(Perm.InvoiceEdit)]
    public async Task<ActionResult<ApiResponse<SpResult>>> Receipt([FromBody] ReceiptRequest r) =>
        Command(await repo.RecordReceiptAsync(r.ClientId, r.Amount, r.Bid, r.ReceivedOn, r.Mode, r.RefNo, r.Remark, Ct));

    /// <summary>Collections, newest first. Filter by invoice to see what has been paid against it.</summary>
    [HttpGet("receipts"), HasPermission(Perm.InvoiceView)]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Receipts(
        [FromQuery] PagedQuery q, [FromQuery] int? clientId, [FromQuery] int? bid, [FromQuery] string? mode)
    {
        var result = await repo.GetReceiptsAsync(clientId, bid, q.BranchId, mode, q.Search, q.From, q.To,
                                                 q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }

    /// <summary>
    /// Salary advances with the amount recovered so far.
    ///
    /// A guard may look at his own advances without the payroll permission -
    /// refusing that would be absurd, it is his own money.
    /// </summary>
    [HttpGet("advances")]
    public async Task<ActionResult<ApiResponse<IReadOnlyList<Row>>>> Advances(
        [FromQuery] PagedQuery q, [FromQuery] int? empId)
    {
        if (!Me.Has(Perm.PayrollView))
        {
            if (empId is not null && empId != Me.EmpId)
                throw DomainException.Forbidden("You may only view your own advances.");
            empId = Me.EmpId;
        }

        var result = await repo.GetAdvancesAsync(empId, q.BranchId, q.Status, q.Search, q.From, q.To,
                                                 q.Page, q.PageSize, Ct);
        return Paged(result, q);
    }
}

public sealed record GeneratePayrollRequest(string MonthYear, int? BranchId = null);
public sealed record GenerateInvoiceRequest(int ClientId, byte Month, short Year,
    int? UnitId = null, decimal GstPercent = 18.00m);
public sealed record ReceiptRequest(int ClientId, decimal Amount, int? Bid = null,
    DateOnly? ReceivedOn = null, string? Mode = null, string? RefNo = null, string? Remark = null);
