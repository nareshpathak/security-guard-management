namespace Diti365.Contracts.Common;

/// <summary>
/// The legacy response shape. Diti365.apk v4.8 deserialises exactly these five
/// members, so the casing and the member names must not change.
/// </summary>
public sealed class LegacyEnvelope<T>
{
    public bool Success { get; init; }
    public int Status { get; init; }
    public int Id { get; init; }
    public string Message { get; init; } = string.Empty;
    public IReadOnlyList<T> Data { get; init; } = Array.Empty<T>();

    public static LegacyEnvelope<T> Ok(IReadOnlyList<T> data, string message = "OK", int id = 0) =>
        new() { Success = true, Status = 200, Id = id, Message = message, Data = data };

    public static LegacyEnvelope<T> Ok(string message, int id = 0) =>
        new() { Success = true, Status = 200, Id = id, Message = message, Data = Array.Empty<T>() };

    public static LegacyEnvelope<T> Fail(string message, int status = 400) =>
        new() { Success = false, Status = status, Id = 0, Message = message, Data = Array.Empty<T>() };
}

/// <summary>The v2 response shape used by the web console and the new mobile app.</summary>
public sealed class ApiResponse<T>
{
    public T? Data { get; init; }
    public ApiMeta? Meta { get; init; }
    public object? Error { get; init; }

    public static ApiResponse<T> Ok(T data, ApiMeta? meta = null) => new() { Data = data, Meta = meta };
}

public sealed class ApiMeta
{
    public int Page { get; init; }
    public int PageSize { get; init; }
    public int Total { get; init; }
    public string? SortBy { get; init; }
    public string? SortDir { get; init; }
    public int TotalPages => PageSize <= 0 ? 0 : (int)Math.Ceiling(Total / (double)PageSize);
}

/// <summary>Result of a command procedure: exactly one envelope row.</summary>
public sealed record SpResult(bool Success, int Status, int Id, string Message);

/// <summary>Result of a paged read procedure: rows plus the total-row count.</summary>
public sealed record PagedResult<T>(IReadOnlyList<T> Items, int Total)
{
    public static PagedResult<T> Empty => new(Array.Empty<T>(), 0);
}
