using Diti365.Contracts.Common;
using Diti365.Infrastructure.Repositories;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V1;

using Row = IReadOnlyDictionary<string, object?>;

[Route("api/Tasks")]
public sealed class TasksController(IWorkflowRepository workflow) : LegacyControllerBase
{
    [HttpPost("addtask")]
    public async Task<ActionResult<LegacyEnvelope<object>>> AddTask([FromBody] V1TaskBody b) =>
        FromSp(await workflow.CreateTaskAsync(b.Heading ?? "", b.AssignedTo, b.Description, b.UnitId,
            b.StartDate, b.EndDate, b.StartTime, b.EndTime, b.PriorityId, b.RepetitionId,
            b.Attachment, b.Important, b.Checklist, b.ParentTaskId, Ct));

    [HttpGet("gettasklistby")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetTaskListBy(
        [FromQuery] int? statusId, [FromQuery] int? unitId, [FromQuery] string? search,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await workflow.GetTasksAsync("by", statusId, null, unitId, false, search, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("gettasklistto")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetTaskListTo(
        [FromQuery] int? statusId, [FromQuery] int? unitId, [FromQuery] string? search,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var result = await workflow.GetTasksAsync("to", statusId, null, unitId, false, search, page, pageSize, Ct);
        return OkData(result.Items);
    }

    [HttpGet("gettaskstatus")]
    [HttpGet("closetaskhistorylist")]
    public async Task<ActionResult<LegacyEnvelope<Row>>> GetTaskStatus([FromQuery] int taskId)
    {
        var sets = await workflow.GetTaskDetailAsync(taskId, Ct);
        return OkData(sets.Count > 0 ? sets[0] : Array.Empty<Row>());
    }

    [HttpPost("updatetaskstatus")]
    [HttpPost("closetask")]
    public async Task<ActionResult<LegacyEnvelope<object>>> UpdateTaskStatus([FromBody] V1TaskStatusBody b) =>
        FromSp(await workflow.UpdateTaskStatusAsync(b.TaskId, b.StatusId, b.Remark, b.Attachment, Ct));

    [HttpPost("deletetask")]
    public async Task<ActionResult<LegacyEnvelope<object>>> DeleteTask([FromBody] V1TaskIdBody b) =>
        FromSp(await workflow.DeleteTaskAsync(b.TaskId, Ct));

    [HttpPost("readtask")]
    public async Task<ActionResult<LegacyEnvelope<object>>> ReadTask([FromBody] V1TaskIdBody b) =>
        FromSp(await workflow.MarkTaskReadAsync(b.TaskId, Ct));
}

public sealed record V1TaskBody(
    string? Heading = null, int AssignedTo = 0, string? Description = null, int? UnitId = null,
    DateOnly? StartDate = null, DateOnly? EndDate = null, TimeOnly? StartTime = null, TimeOnly? EndTime = null,
    int? PriorityId = null, int? RepetitionId = null, string? Attachment = null, bool Important = false,
    IReadOnlyList<string>? Checklist = null, int? ParentTaskId = null);

public sealed record V1TaskStatusBody(int TaskId, int StatusId, string? Remark = null, string? Attachment = null);
public sealed record V1TaskIdBody(int TaskId);
