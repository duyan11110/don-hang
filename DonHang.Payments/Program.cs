using DonHang.Messaging;
using DonHang.Payments;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;

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

var gateway = builder.Configuration.GetSection("Gateway").Get<GatewaySettings>() ?? new GatewaySettings();
builder.Services.AddHttpClient<GatewayRefundClient>(http =>
{
    http.BaseAddress = new Uri(gateway.BaseAddress);
    http.DefaultRequestHeaders.Authorization = new("Bearer", gateway.ApiKey);
    http.Timeout = TimeSpan.FromSeconds(10);
});

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

builder.Services.AddHealthChecks()
    .AddDbContextCheck<PaymentsDbContext>(tags: ["ready"]);

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = check => check.Tags.Contains("ready") });

app.Run();

// .NET 10 makes the Program class of a web project public, so that tests can
// start it; DonHang.Api's tests do (ApiFactory). DonHang.Tests references this
// project too, and two public Program classes would clash there, so this
// one stays internal: its tests use its classes, never the whole program.
internal partial class Program;
