using System.IO;

namespace Diti365.Application
{
    // Intentionally placed inside Diti365.Application to avoid adding a new project.
    public interface IBlobService
    {
        Task<(string UploadUrl, string BlobUrl, string Method)> CreateUploadUrlAsync(string fileName, CancellationToken ct);
        Task<string> SaveAsync(Stream content, string fileName, CancellationToken ct);
    }
}
