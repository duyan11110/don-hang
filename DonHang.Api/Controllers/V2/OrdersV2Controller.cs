using System.Security.Claims;
using DonHang.Api.Monitoring;
using DonHang.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DonHang.Api.Controllers.V2;

// lesson: backend.l2.api-versioning
// Version 2 of the orders endpoints. It calls the same OrderService and the
// same repository as OrdersController; only the URL and the DTOs differ, so
// no business rule exists twice.
[ApiController]
[Route("api/v2/orders")]
public sealed class OrdersV2Controller(
    OrderService orderService,
    IOrderRepository repository,
    ICustomerRepository customers,
    IAuthorizationService authorization) : ControllerBase
{
    [Authorize]
    [HttpPost]
    public async Task<ActionResult<OrderV2Dto>> Create(
        CreateOrderV2Request request,
        [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
    {
        var subject = User.FindFirstValue("sub");
        var customer = subject is null ? null : await customers.FindByIdentitySubjectAsync(subject);
        if (customer is null) return Forbid();

        // As in v1, a line's unitPriceVnd is ignored: the price comes from Catalog.
        var requested = request.Lines
            .Select(l => new RequestedItem(l.ProductId, l.Quantity))
            .ToList();

        var (order, created) = await orderService.PlaceOrderAsync(customer.Id, requested, idempotencyKey);
        if (created) OrderMetrics.OrdersPlaced.Inc();
        return CreatedAtAction(nameof(Get), new { id = order.Id }, ToDto(order));
    }

    // The same OrderOwner check as GET /api/v1/orders/{id}.
    [Authorize]
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderV2Dto>> Get(int id)
    {
        var order = await repository.FindForReadingAsync(id);
        if (order is null) return NotFound();

        var allowed = await authorization.AuthorizeAsync(User, order, "OrderOwner");
        if (!allowed.Succeeded) return Forbid();

        return Ok(ToDto(order));
    }

    private static OrderV2Dto ToDto(Order order)
    {
        var lines = order.Items
            .Select(i => new OrderLineV2Dto(i.ProductId, i.Quantity, i.UnitPrice.Amount, i.UnitPrice.Times(i.Quantity).Amount))
            .ToList();
        return new OrderV2Dto(order.Id, order.Status, order.PlacedAt, lines, order.Total.Amount);
    }
}
