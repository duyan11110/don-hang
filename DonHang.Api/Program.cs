using DonHang.Api.Authorization;
using DonHang.Api.Jobs;
using DonHang.Api.Middleware;
using DonHang.Domain;
using DonHang.Infrastructure;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Prometheus;

var builder = WebApplication.CreateBuilder(args);

// lesson: backend.l1.hosting-and-program-cs
builder.Services.AddControllers();
builder.Services.AddProblemDetails();

var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default is not set");

// lesson: backend.l2.cache-aside
// "redis:6379,abortConnect=false" in the lab: the api finds Redis by its
// Compose service name, the same way it finds db.
var redisConfiguration = builder.Configuration.GetConnectionString("Redis")
    ?? throw new InvalidOperationException("ConnectionStrings:Redis is not set");
var smtp = builder.Configuration.GetSection("Smtp").Get<SmtpSettings>() ?? new SmtpSettings();
builder.Services.AddDonHangInfrastructure(connectionString, redisConfiguration, smtp);
builder.Services.AddScoped<OrderService>();

// lesson: backend.l2.hosted-services
// The host starts NotificationSender when the app starts and stops it when
// the app stops; it runs in this same process, beside the requests.
builder.Services.AddHostedService<NotificationSender>();

// lesson: backend.l2.oauth2-roles
// lesson: backend.l2.openid-connect-id-token
// lesson: backend.l2.validating-provider-tokens
// Keycloak issues the tokens; the api only checks them. AddJwtBearer reads
// Keycloak's metadata and public keys once, then checks each token's
// signature, issuer, audience and expiry itself, without calling Keycloak.
var authority = builder.Configuration["Keycloak:Authority"]
    ?? throw new InvalidOperationException("Keycloak:Authority is not set");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = authority;
        options.MetadataAddress = builder.Configuration["Keycloak:MetadataAddress"]
            ?? $"{authority}/.well-known/openid-configuration";
        // Access tokens for this api carry "donhang-api" in `aud`; an ID token
        // carries the app's client id there instead, so it is rejected.
        options.Audience = "donhang-api";
        options.RequireHttpsMetadata = false; // the lab reaches Keycloak over plain HTTP
        // Keep claim names as Keycloak wrote them ("sub", "roles"), and read
        // the caller's roles from the flat "roles" claim the realm adds.
        options.MapInboundClaims = false;
        options.TokenValidationParameters.RoleClaimType = "roles";
    });

// lesson: backend.l2.role-based-access
// lesson: backend.l2.resource-based-authorization
// Neither policy names an authentication scheme: they ask about the caller,
// not about how the caller signed in.
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("StaffOnly", policy => policy.RequireRole("staff"));
    options.AddPolicy("OrderOwner", policy => policy.AddRequirements(new OrderOwnerRequirement()));
});
builder.Services.AddScoped<IAuthorizationHandler, OrderOwnerHandler>();

// lesson: backend.l2.openapi-contract
// Builds an OpenAPI document from the controllers and DTOs while the app
// runs; MapOpenApi below serves it at /openapi/v1.json. "v1" is the
// document's name, not the /api/v1 prefix of the URLs it describes.
builder.Services.AddOpenApi();

// lesson: k8s.l1.health-endpoints
// One check: can EF Core open a connection to PostgreSQL? Tagged "ready" so
// only /health/ready runs it. Redis is left out on purpose: when it fails,
// the api still answers from PostgreSQL.
builder.Services.AddHealthChecks()
    .AddDbContextCheck<DonHangDbContext>(tags: ["ready"]);

// lesson: frontend.l1.fetching-with-http-package
// DonHang.App (app-web:8081) and the api are different origins behind
// Caddy (api:8080); bearer tokens need no cookies, so a permissive dev policy
// is enough here — no credentials to leak.
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

// lesson: devops.l2.migrations-in-the-pipeline
// Until stage-1 the app applied pending migrations here, every time it
// started. From stage-2 it does not: the migrate service runs the migration
// bundle first, and Compose starts this app only once that has succeeded.
var app = builder.Build();

// lesson: devops.l2.metrics-endpoint
// Measures every request: how many, with which status code, how long. First
// in the pipeline, so a request that throws is still counted, with the 500
// that ExceptionHandlingMiddleware below turns it into.
app.UseHttpMetrics();

// lesson: backend.l1.middleware-pipeline
// Order matters: every request logged, then exceptions caught, then the
// terminal middleware (auth, routing) that decides how to answer it. From
// stage-2 the logging comes first, so that a request that threw is logged
// too, with the 500 that ExceptionHandlingMiddleware turned it into.
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapOpenApi();

// lesson: devops.l2.metrics-endpoint
// GET /metrics answers with the current value of every metric, as text,
// whenever something asks; the api sends its metrics nowhere by itself.
// Caddy does not forward /metrics: only the donhang network reaches it, at api:8080.
app.MapMetrics();

// lesson: k8s.l1.health-endpoints
// /health/live runs no check at all: it answers Healthy while the process can
// still serve HTTP. /health/ready runs the "ready" checks: the database.
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = check => check.Tags.Contains("ready") });

app.Run();
