using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Diti365.Infrastructure.Security;

public interface IOtpService
{
    string Generate();
    string Hash(string mobileNo, string otp);
    Task SendAsync(string mobileNo, string otp, CancellationToken ct);
}

/// <summary>
/// OTPs are stored hashed and salted with the mobile number, so a leaked sec.Otp table
/// cannot be replayed against a different number.
///
/// SendAsync is a seam: wire it to the client's SMS gateway or Firebase Phone Auth.
/// In Development it logs instead of sending.
/// </summary>
public sealed class OtpService(ILogger<OtpService> logger, IHostEnvironment env) : IOtpService
{
    public string Generate() => RandomNumberGenerator.GetInt32(100_000, 1_000_000).ToString();

    public string Hash(string mobileNo, string otp) =>
        Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes($"{mobileNo}:{otp}:diti365")));

    public Task SendAsync(string mobileNo, string otp, CancellationToken ct)
    {
        if (env.IsDevelopment())
        {
            logger.LogWarning("DEV ONLY - OTP for {MobileNo} is {Otp}", mobileNo, otp);
            return Task.CompletedTask;
        }

        // TODO wire the SMS gateway supplied by the client. Until then the OTP is
        // generated and stored but never delivered, which fails closed rather than open.
        logger.LogError("No SMS gateway is configured; the OTP for {MobileNo} was not delivered.", mobileNo);
        return Task.CompletedTask;
    }
}
