using Diti365.Api.Controllers;
using Diti365.Application;
using Diti365.Contracts.Common;
using Diti365.Application.Abstractions;
using Microsoft.AspNetCore.Mvc;

namespace Diti365.Api.Controllers.V2;

[Route("api/v2/blob")]
public sealed class BlobController(ICurrentUser currentUser, IBlobService blobs) : ApiControllerBase(currentUser)
{
    // Returns an upload URL and the final blob URL. In production this would be a SAS URL.
    [HttpPost("sas")]
    public async Task<ActionResult<ApiResponse<object>>> CreateSas([FromBody] CreateSasRequest r, CancellationToken ct)
    {
        var (uploadUrl, blobUrl, method) = await blobs.CreateUploadUrlAsync(r.FileName, ct);
        return Data<object>(new { uploadUrl, blobUrl, method });
    }

    // Accepts a multipart/form-data upload and saves locally (dev fallback).
    [HttpPost("upload")]
    [RequestSizeLimit(50_000_000)]
    public async Task<ActionResult<ApiResponse<object>>> Upload([FromQuery] string fileName, CancellationToken ct)
    {
        if (!Request.HasFormContentType || Request.Form.Files.Count == 0)
            throw new Diti365.Domain.DomainException("ValidationFailed", "No file uploaded.", 400);

        var file = Request.Form.Files[0];
        await using var stream = file.OpenReadStream();
        var url = await blobs.SaveAsync(stream, fileName, ct);
        return Data<object>(new { url });
    }

    [HttpGet("files/{fileName}")]
    public IActionResult Download(string fileName)
    {
        var path = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "uploads", fileName));
        if (!System.IO.File.Exists(path)) return NotFound();
        var contentType = "application/octet-stream";
        return PhysicalFile(path, contentType, fileName);
    }
}

public sealed record CreateSasRequest(string FileName);