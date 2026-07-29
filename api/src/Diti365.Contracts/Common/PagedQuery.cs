namespace Diti365.Contracts.Common;

/// <summary>
/// The standard list query. Every list endpoint accepts these. PageSize is clamped
/// server-side; an unbounded query is never issued. docs/prd/02-api.md §10.
/// </summary>
public record PagedQuery
{
    private const int MaxPageSize = 200;
    private int _pageSize = 50;
    private int _page = 1;

    public int Page
    {
        get => _page;
        init => _page = value < 1 ? 1 : value;
    }

    public int PageSize
    {
        get => _pageSize;
        init => _pageSize = value switch { < 1 => 50, > MaxPageSize => MaxPageSize, _ => value };
    }

    public string? Search { get; init; }
    public string? SortBy { get; init; }
    public string? SortDir { get; init; } = "asc";
    public DateOnly? From { get; init; }
    public DateOnly? To { get; init; }
    public int? BranchId { get; init; }
    public int? UnitId { get; init; }
    public string? Status { get; init; }
}
