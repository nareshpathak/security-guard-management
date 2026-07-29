namespace Diti365.Domain;

/// <summary>
/// Raised by the application and infrastructure layers when a business rule is
/// violated. The exception middleware maps <see cref="Code"/> and
/// <see cref="StatusCode"/> straight into an RFC 7807 response.
/// </summary>
public sealed class DomainException : Exception
{
    public string Code { get; }
    public int StatusCode { get; }
    public IReadOnlyDictionary<string, string[]>? Errors { get; }

    public DomainException(string code, string message, int statusCode = 422,
                           IReadOnlyDictionary<string, string[]>? errors = null,
                           Exception? inner = null)
        : base(message, inner)
    {
        Code = code;
        StatusCode = statusCode;
        Errors = errors;
    }

    public static DomainException NotFound(string what) =>
        new(ErrorCodes.NotFound, $"{what} was not found.", 404);

    public static DomainException Forbidden(string message) =>
        new(ErrorCodes.PermissionDenied, message, 403);

    /// <summary>
    /// A request the caller can fix by sending different values. 400 rather than
    /// 422 because these are malformed inputs, not rule violations - a client
    /// retrying the same body unchanged will always fail.
    /// </summary>
    public static DomainException Validation(string message) =>
        new(ErrorCodes.ValidationFailed, message, 400);
}
