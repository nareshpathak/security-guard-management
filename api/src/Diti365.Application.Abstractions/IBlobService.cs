namespace Diti365.Application.Abstractions
{
    public interface IBlobService
    {
        /// <summary>
        /// Create an upload URL (SAS in production, direct API upload in development).
        /// Returns the upload URL (where the client should PUT/POST the file) and the final blob URL.
        /// </summary>
        Task<(string UploadUrl, string BlobUrl, string Method)> CreateUploadUrlAsync(string fileName, CancellationToken ct);

        /// <summary>
        /// Save an uploaded stream and return the accessible blob URL.
        /// </summary>
        Task<string> SaveAsync(Stream content, string fileName, CancellationToken ct);
    }
}