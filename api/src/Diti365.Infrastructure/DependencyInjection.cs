using Diti365.Application.Abstractions;
using Diti365.Infrastructure.Data;
using Diti365.Infrastructure.Repositories;
using Diti365.Infrastructure.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Diti365.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddDiti365Infrastructure(this IServiceCollection services, IConfiguration config)
    {
        services.Configure<DbOptions>(config.GetSection(DbOptions.SectionName));
        services.Configure<JwtOptions>(config.GetSection(JwtOptions.SectionName));

        // Scoped: the executor reads ICurrentUser, which is per request.
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<IDbExecutor, DbExecutor>();

        services.AddSingleton<IPasswordHasher, PasswordHasher>();
        services.AddSingleton<ITokenService, TokenService>();
        services.AddScoped<IOtpService, OtpService>();
        services.AddScoped<IRefreshTokenStore, RefreshTokenStore>();
        services.AddScoped<IAuthService, AuthService>();

        services.AddScoped<IAuthRepository,       AuthRepository>();
        services.AddScoped<IMasterRepository,     MasterRepository>();
        services.AddScoped<IAttendanceRepository, AttendanceRepository>();
        services.AddScoped<IOpsRepository,        OpsRepository>();
        services.AddScoped<IPeopleRepository,     PeopleRepository>();
        services.AddScoped<IWorkflowRepository,   WorkflowRepository>();
        services.AddScoped<IFinanceRepository,    FinanceRepository>();
        services.AddScoped<ISalesRepository,      SalesRepository>();
        services.AddScoped<IReportRepository,     ReportRepository>();

        // Blob storage: local dev fallback implemented. In production replace with AzureBlobService.
                services.AddSingleton<Diti365.Application.IBlobService, Diti365.Infrastructure.Storage.LocalBlobService>();

        return services;
    }
}
