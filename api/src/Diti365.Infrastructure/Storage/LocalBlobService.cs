using Diti365.Application;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Http;

namespace Diti365.Infrastructure.Storage;

public sealed class LocalBlobOptions
{
    public string UploadPath { get; init; } = "uploads";
}

public sealed class LocalBlobService : IBlobService
{
    private readonly string _uploadPath;
    private readonly IHttpContextAccessor _http;

    public LocalBlobService(IConfiguration config, IHttpContextAccessor http)
    {
        var o = new LocalBlobOptions();
        var section = config.GetSection("LocalBlob");
        if (section.Exists()) section.Bind(o);

        _uploadPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", o.UploadPath));
        _http = http;
        Directory.CreateDirectory(_uploadPath);
    }

    public Task<(string UploadUrl, string BlobUrl, string Method)> CreateUploadUrlAsync(string fileName, CancellationToken ct)
    {
        // For local development just return the API upload endpoint.
        var id = Guid.NewGuid().ToString("N");
        var saveFileName = id + Path.GetExtension(fileName);
        var req = _http.HttpContext?.Request;
        var baseUrl = req is null ? "http://localhost:5000" : $"{req.Scheme}://{req.Host.Value}";
        var uploadUrl = $"{baseUrl}/api/v2/blob/upload?fileName={Uri.EscapeDataString(saveFileName)}";
        var blobUrl = $"{baseUrl}/api/v2/blob/files/{Uri.EscapeDataString(saveFileName)}";
        return Task.FromResult((uploadUrl, blobUrl, "POST"));
    }

    public async Task<string> SaveAsync(Stream content, string fileName, CancellationToken ct)
    {
        var dest = Path.Combine(_uploadPath, fileName);
        // Ensure no directory traversal
        dest = Path.GetFullPath(dest);
        if (!dest.StartsWith(_uploadPath, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Invalid file name");

        using var fs = new FileStream(dest, FileMode.Create, FileAccess.Write, FileShare.None);
        await content.CopyToAsync(fs, ct).ConfigureAwait(false);
        var req = _http.HttpContext?.Request;
        var baseUrl = req is null ? "http://localhost:5000" : $"{req.Scheme}://{req.Host.Value}";
        return $"{baseUrl}/api/v2/blob/files/{Uri.EscapeDataString(fileName)}";
    }
}
