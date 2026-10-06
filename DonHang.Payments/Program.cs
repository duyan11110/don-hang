using DonHang.Messaging;
using DonHang.Payments;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Http.Resilience;
using Npgsql;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Polly;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();

// lesson: backend.l3.payments-service
// The Payments service, on its own from stage-3, with its own database,
// donhang_payments. It is the only part of Đơn Hàng that holds the payment
// gateway's address and key, and the only one that reads or writes a
// payment row; DonHang.Api reaches it through RabbitMQ only.
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default is not set");
builder.Services.AddDbContext<PaymentsDbContext>(options => options.UseNpgsql(connectionString));

// lesson: backend.l3.resilience-pipeline
// The HttpClient that GatewayRefundClient uses, with its resilience pipeline
// (AddGatewayRefundClient, at the end of this file).
var gateway = builder.Configuration.GetSection("Gateway").Get<GatewaySettings>() ?? new GatewaySettings();
builder.Services.AddGatewayRefundClient(gateway);

// lesson: backend.l3.payments-service
// Refund requests arrive the way order events reach Notifications: through
// RabbitMQ, into an inbox. The answers leave through this service's own
// outbox, which its own OutboxRelay publishes to donhang.payments.
var rabbitMq = builder.Configuration.GetSection("RabbitMq").Get<RabbitMqSettings>() ?? new RabbitMqSettings();
builder.Services.AddRabbitMq(rabbitMq, clientName: "donhang-payments");
builder.Services.AddOutboxRelay<PaymentsDbContext>(exchange: "donhang.payments");
builder.Services.AddHostedService<RefundRequestedConsumer>();

var refunds = builder.Configuration.GetSection("Refunds").Get<RefundSettings>() ?? new RefundSettings();
builder.Services.AddSingleton(refunds);
builder.Services.AddHostedService<RefundSender>();

// Tokens from the same Keycloak realm as the api, checked the same way, for
// GET /api/v1/refunds (staff only).
var authority = builder.Configuration["Keycloak:Authority"]
    ?? throw new InvalidOperationException("Keycloak:Authority is not set");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = authority;
        options.MetadataAddress = builder.Configuration["Keycloak:MetadataAddress"]
            ?? $"{authority}/.well-known/openid-configuration";
        options.Audience = "donhang-api";
        options.RequireHttpsMetadata = false;
        options.MapInboundClaims = false;
        options.TokenValidationParameters.RoleClaimType = "roles";
    });
builder.Services.AddAuthorization(options =>
    options.AddPolicy("StaffOnly", policy => policy.RequireRole("staff")));

// lesson: backend.l3.opentelemetry-sdk
// The same tracing as DonHang.Api's, under this service's own name. The
// HttpClient instrumentation records GatewayRefundClient's calls and writes
// a traceparent header on each (backend.l3.trace-context-propagation).
var sampleRatio = builder.Configuration.GetValue("Telemetry:SampleRatio", 0.1);
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService("donhang-payments"))
    .WithTracing(tracing => tracing
        .SetSampler(new ParentBasedSampler(new TraceIdRatioBasedSampler(sampleRatio)))
        .AddAspNetCoreInstrumentation(options => options.Filter = context =>
            !context.Request.Path.StartsWithSegments("/health") && !context.Request.Path.StartsWithSegments("/metrics"))
        .AddHttpClientInstrumentation()
        .AddNpgsql()
        .AddSource(MessageTracing.SourceName)
        .AddOtlpExporter());

builder.Services.AddHealthChecks()
    .AddDbContextCheck<PaymentsDbContext>(tags: ["ready"]);

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = check => check.Tags.Contains("ready") });

app.Run();

// lesson: backend.l3.resilience-pipeline
// lesson: backend.l3.circuit-breaker
// Every call through this HttpClient passes the pipeline named "gateway".
// Its strategies run in the order they are added, the first wrapping the
// rest: the circuit breaker sees every call and its outcome, including a
// call that the timeout inside it ended. There is no retry strategy, unlike
// AddStandardResilienceHandler: RefundSender already tries each refund again
// on a later round, and retries in both places would multiply the calls.
// A public static method, so that GatewayCircuitBreakerTests builds the same.
public static class GatewayPipeline
{
    public static IHttpClientBuilder AddGatewayRefundClient(this IServiceCollection services, GatewaySettings gateway)
    {
        var client = services.AddHttpClient<GatewayRefundClient>(http =>
        {
            http.BaseAddress = new Uri(gateway.BaseAddress);
            http.DefaultRequestHeaders.Authorization = new("Bearer", gateway.ApiKey);
        });
        client.AddResilienceHandler("gateway", (pipeline, context) =>
        {
            var logger = context.ServiceProvider.GetRequiredService<ILoggerFactory>().CreateLogger("DonHang.Payments.GatewayCircuit");
            // lesson: backend.l3.circuit-breaker
            // Counts as failed: an exception (no connection, the timeout) or a
            // 5xx, 408 or 429 answer. A 422 refusal is an answer like 200.
            pipeline.AddCircuitBreaker(new HttpCircuitBreakerStrategyOptions
            {
                FailureRatio = gateway.FailureRatio,
                MinimumThroughput = gateway.MinimumThroughput,
                SamplingDuration = gateway.SamplingDuration,
                BreakDuration = gateway.BreakDuration,
                OnOpened = args => Log(() => logger.LogWarning(
                    "Circuit to the gateway opened: no calls for {BreakSeconds} s", args.BreakDuration.TotalSeconds)),
                OnHalfOpened = _ => Log(() => logger.LogInformation("Circuit to the gateway half-open: one trial call")),
                OnClosed = _ => Log(() => logger.LogInformation("Circuit to the gateway closed: calls go through again")),
            });
            pipeline.AddTimeout(gateway.Timeout);
        });
        return client;
    }

    private static ValueTask Log(Action write)
    {
        write();
        return ValueTask.CompletedTask;
    }
}

// .NET 10 makes the Program class of a web project public, so that tests can
// start it; DonHang.Api's tests do (ApiFactory). DonHang.Tests references this
// project too, and two public Program classes would clash there, so this
// one stays internal: its tests use its classes, never the whole program.
internal partial class Program;
