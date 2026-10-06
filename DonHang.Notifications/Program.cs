using DonHang.Messaging;
using DonHang.Notifications;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

var builder = WebApplication.CreateBuilder(args);

// lesson: backend.l3.message-broker
// The Notifications service, on its own from stage-3. Its database is
// donhang_notifications, which no other service opens; it learns about
// orders only from RabbitMQ, so it runs, and keeps sending, whether or not
// DonHang.Api is up, and the api places orders whether or not this is up.
var connectionString = builder.Configuration.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default is not set");
builder.Services.AddDbContext<NotificationsDbContext>(options => options.UseNpgsql(connectionString));

// lesson: backend.l3.consumer-acknowledgements
// Two hosted services in one process: OrderEventsConsumer turns each message
// into a pending notifications row, and NotificationSender sends those rows
// as emails, exactly as it did inside the api until stage-2.
var rabbitMq = builder.Configuration.GetSection("RabbitMq").Get<RabbitMqSettings>() ?? new RabbitMqSettings();
builder.Services.AddRabbitMq(rabbitMq, clientName: "donhang-notifications");
builder.Services.AddHostedService<OrderEventsConsumer>();

var smtp = builder.Configuration.GetSection("Smtp").Get<SmtpSettings>() ?? new SmtpSettings();
builder.Services.AddSingleton<IEmailSender>(new MailKitEmailSender(smtp));
builder.Services.AddScoped<NotificationQueue>();
builder.Services.AddHostedService<NotificationSender>();

// lesson: backend.l3.opentelemetry-sdk
// The same tracing as DonHang.Api's, under this service's own name. Its
// spans are the consumer's and the SQL it runs; nothing calls it over HTTP.
var sampleRatio = builder.Configuration.GetValue("Telemetry:SampleRatio", 0.1);
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService("donhang-notifications"))
    .WithTracing(tracing => tracing
        .SetSampler(new ParentBasedSampler(new TraceIdRatioBasedSampler(sampleRatio)))
        .AddNpgsql()
        .AddSource(MessageTracing.SourceName)
        .AddOtlpExporter());

// Ready once the database answers; RabbitMQ is left out, as in the api.
builder.Services.AddHealthChecks()
    .AddDbContextCheck<NotificationsDbContext>(tags: ["ready"]);

// The migrations run before this starts: the notifications-migrate service
// applies them with this project's migration bundle, as migrate does for the api.
var app = builder.Build();
app.MapHealthChecks("/health/live", new HealthCheckOptions { Predicate = _ => false });
app.MapHealthChecks("/health/ready", new HealthCheckOptions { Predicate = check => check.Tags.Contains("ready") });

app.Run();

// .NET 10 makes the Program class of a web project public, so that tests can
// start it; DonHang.Api's tests do (ApiFactory). DonHang.Tests references this
// project too, and two public Program classes would clash there, so this
// one stays internal: its tests use its classes, never the whole program.
internal partial class Program;
