using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Diti365.Api.Filters;
using Diti365.Api.Middleware;
using Diti365.Application.Abstractions;
using Diti365.Infrastructure;
using Diti365.Infrastructure.Security;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------- logging
builder.Host.UseSerilog((ctx, cfg) => cfg
    .ReadFrom.Configuration(ctx.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/diti365-.log", rollingInterval: RollingInterval.Day, retainedFileCountLimit: 30));

// ---------------------------------------------------------------- services
builder.Services.AddHttpContextAccessor();
builder.Services.AddDiti365Infrastructure(builder.Configuration);

builder.Services
    .AddControllers(options =>
    {
        // Runs on every action: rejects any attempt to pass a tenant id from the client.
        options.Filters.Add<TenantGuardFilter>();
    })
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
        o.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// ---------------------------------------------------------------- auth
var jwt = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();

if (string.IsNullOrWhiteSpace(jwt.SigningKey) || Encoding.UTF8.GetByteCount(jwt.SigningKey) < 32)
{
    // Failing at startup is the point. A weak or missing signing key must never reach
    // an environment where it could quietly mint forgeable tokens.
    throw new InvalidOperationException(
        "Jwt:SigningKey is missing or shorter than 32 bytes. Set it from an environment " +
        "variable or Key Vault - never in a committed appsettings file.");
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ClockSkew = TimeSpan.FromSeconds(30)
        };

        // SignalR passes the token in the query string, because browsers cannot set
        // headers on a WebSocket handshake.
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();

// ---------------------------------------------------------------- rate limits
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = 429;

    // Login and OTP: five attempts per identity per fifteen minutes.
    options.AddPolicy("auth", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(15) }));

    // Everything else, per authenticated user.
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            ctx.User.FindFirst("sub")?.Value ?? ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 300, Window = TimeSpan.FromMinutes(1) }));
});

// ---------------------------------------------------------------- cors
builder.Services.AddCors(options => options.AddDefaultPolicy(policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod().AllowCredentials();
}));

// ---------------------------------------------------------------- swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Diti365 API",
        Version = "v2",
        Description =
            "Security Agency Management System.\n\n" +
            "Two surfaces:\n" +
            "* api/v2/* - the current REST API used by the web console and the new mobile app.\n" +
            "* api/{Users|Operation|Tasks|Sales|Report}/* - legacy compatibility for " +
            "Diti365.apk v4.8, which returns the {Success, Status, Id, Message, Data} envelope."
    });

    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        [new OpenApiSecurityScheme { Reference = new OpenApiReference
            { Type = ReferenceType.SecurityScheme, Id = "Bearer" } }] = Array.Empty<string>()
    });

    // V1 and V2 both declare a SalesController. Attribute routing handles that fine,
    // but Swagger derives schema ids from short type names, so use full names to keep
    // any future same-named DTO from colliding.
    c.CustomSchemaIds(t => t.FullName?.Replace('+', '.'));

    // Two controllers may share a name across V1 and V2; disambiguate the tag.
    c.TagActionsBy(api => [api.GroupName ?? api.ActionDescriptor.RouteValues["controller"] +
        (api.RelativePath?.StartsWith("api/v2", StringComparison.OrdinalIgnoreCase) == true ? " (v2)" : " (legacy)")]);
    c.DocInclusionPredicate((_, _) => true);

    var xml = Path.Combine(AppContext.BaseDirectory, "Diti365.Api.xml");
    if (File.Exists(xml)) c.IncludeXmlComments(xml);
});

builder.Services.AddHealthChecks();
builder.Services.AddResponseCompression();

var app = builder.Build();

// ---------------------------------------------------------------- pipeline
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<RequestLoggingMiddleware>();

if (app.Environment.IsDevelopment())
{
    // Swagger is a development affordance. On other environments the OpenAPI file is
    // published to the docs site instead of being served from the API.
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "Diti365 API v2"));
}
else
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseResponseCompression();
app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health/live");
app.MapHealthChecks("/health/ready");

app.Run();

/// <summary>Exposed so the integration test project can spin the host up.</summary>
public partial class Program;
