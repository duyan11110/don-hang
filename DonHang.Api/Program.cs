using DonHang.Api.Authorization;
using DonHang.Api.Messaging;
using DonHang.Api.Middleware;
using DonHang.Catalog;
using DonHang.Domain;
using DonHang.Infrastructure;
using DonHang.Messaging;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.RateLimiting;
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

// lesson: design.l3.modules-cut-through-layers
// Two modules in one process. Catalog registers everything it has itself;
// Ordering is still DonHang.Domain plus DonHang.Infrastructure. Both get the
// same connection string: they share one database, not one another's tables.
builder.Services.AddCatalogModule(connectionString, redisConfiguration);
builder.Services.AddDonHangInfrastructure(connectionString);
builder.Services.AddScoped<OrderService>();

// lesson: backend.l3.outbox-relay
// From stage-3 the api sends no email itself (DonHang.Notifications does).
// What other services must hear about leaves as outbox rows: OutboxRelay, a
// hosted service in this process, publishes them to donhang.orders, and
// PaymentEventsConsumer reads what DonHang.Payments publishes back.
var rabbitMq = builder.Configuration.GetSection("RabbitMq").Get<RabbitMqSettings>() ?? new RabbitMqSettings();
builder.Services.AddRabbitMq(rabbitMq, clientName: "donhang-api");
builder.Services.AddOutboxRelay<DonHangDbContext>(exchange: "donhang.orders");
builder.Services.AddHostedService<PaymentEventsConsumer>();

// lesson: backend.l2.oauth2-roles
// lesson: backend.l2.openid-connect-id-token
// lesson: backend.l2.validating-provider-tokens
// Keycloak issues the tokens; the api only checks them. AddJwtBearer fetches
// Keycloak's metadata and public keys before checking the first token, keeps
// them, and fetches them again from time to time. It checks each token's
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
// the api still answers from PostgreSQL. So is RabbitMQ, from stage-3: while
// it is down, orders are still accepted and their messages wait in the outbox.
builder.Services.AddHealthChecks()
    .AddDbContextCheck<DonHangDbContext>(tags: ["ready"]);

// lesson: frontend.l1.fetching-with-http-package
// DonHang.App (app-web:8081) and the api are different origins behind
// Caddy (api:8080); bearer tokens need no cookies, so a permissive dev policy
// is enough here — no credentials to leak. From stage-3 the app may also read
// Retry-After, which a browser hides from another origin unless exposed.
builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()
        .WithExposedHeaders("Retry-After")));

// lesson: backend.l3.rate-limiting
// "orders": each customer may place PermitLimit orders per fixed Window,
// counted by the `sub` of the access token. Not by client IP address: behind
// Caddy every request reaches the api from Caddy's address. Each api process
// keeps its own counts in memory, so two copies allow twice as many.
var ordersLimit = new FixedWindowRateLimiterOptions { PermitLimit = 10, Window = TimeSpan.FromMinutes(1) };
builder.Configuration.GetSection("RateLimiting:Orders").Bind(ordersLimit);

// lesson: backend.l3.bulkhead
// "catalog-reads": at most PermitLimit product reads run at once and QueueLimit
// more wait for a turn; any read beyond that is refused at once. With Redis
// down every product read needs a database connection, and orders need them too.
var catalogReads = new ConcurrencyLimiterOptions { PermitLimit = 20, QueueLimit = 5 };
builder.Configuration.GetSection("RateLimiting:CatalogReads").Bind(catalogReads);

builder.Services.AddRateLimiter(options =>
{
    options.AddPolicy("orders", context =>
    {
        var customer = context.User.FindFirst("sub")?.Value;
        if (customer is null) return RateLimitPartition.GetNoLimiter("signed-out");
        return RateLimitPartition.GetFixedWindowLimiter(customer, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = ordersLimit.PermitLimit,
            Window = ordersLimit.Window,
        });
    });
    options.AddConcurrencyLimiter("catalog-reads", limiter =>
    {
        limiter.PermitLimit = catalogReads.PermitLimit;
        limiter.QueueLimit = catalogReads.QueueLimit;
    });

    // lesson: backend.l3.rate-limiting
    // A refused request never reaches the controller: the middleware answers
    // it with RejectionStatusCode, 503 unless set. A fixed window knows when
    // its next permit comes, so that refusal becomes 429 with Retry-After in
    // whole seconds. The concurrency limiter cannot know: its refusals stay 503.
    options.OnRejected = (context, _) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
            context.HttpContext.Response.Headers.RetryAfter = ((int)Math.Ceiling(retryAfter.TotalSeconds)).ToString();
        }
        return ValueTask.CompletedTask;
    };
});

// lesson: devops.l2.migrations-in-the-pipeline
// Until stage-1 the app applied pending migrations here, every time it
// started. From stage-2 it does not: the migrate service runs the migration
// bundle first, and Compose starts this app only once that has succeeded.
var app = builder.Build();

// lesson: devops.l2.metrics-endpoint
// Measures every request except those to /metrics itself: how many, with
// which status code, how long. First in the pipeline, so a request that
// throws is still counted, with the 500 that ExceptionHandlingMiddleware
// below turns it into.
app.UseHttpMetrics();

// lesson: backend.l1.middleware-pipeline
// Order matters: every request logged, then exceptions caught, then the
// terminal middleware (auth, routing) that decides how to answer it. From
// stage-2 the logging comes before the exception handling (only the metrics
// come earlier), so that a request that threw is logged too, with the 500
// that ExceptionHandlingMiddleware turned it into.
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseCors();
app.UseAuthentication();
// lesson: backend.l3.rate-limiting
// After authentication, so that the "orders" policy can read the caller's
// `sub`; only endpoints marked [EnableRateLimiting] are limited.
app.UseRateLimiter();
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
