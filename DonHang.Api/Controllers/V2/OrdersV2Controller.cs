using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
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
public sealed class OrdersV2Controller(OrderService orderService, IOrderRepository repository) : ControllerBase
{
    [Authorize]
    [HttpPost]
    public async Task<ActionResult<OrderV2Dto>> Create(
        CreateOrderV2Request request,
        [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
    {
        var customerId = int.Parse(User.FindFirstValue(JwtRegisteredClaimNames.Sub)!);
        var items = request.Lines
            .Select(l => new OrderItem { ProductId = l.ProductId, Quantity = l.Quantity, UnitPriceVnd = l.UnitPriceVnd })
            .ToList();

        var order = await orderService.PlaceOrderAsync(customerId, items, idempotencyKey);
        return CreatedAtAction(nameof(Get), new { id = order.Id }, ToDto(order));
    }

    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderV2Dto>> Get(int id)
    {
        var order = await repository.FindForReadingAsync(id);
        if (order is null) return NotFound();
        return Ok(ToDto(order));
    }

    private static OrderV2Dto ToDto(Order order)
    {
        var lines = order.Items
            .Select(i => new OrderLineV2Dto(i.ProductId, i.Quantity, i.UnitPriceVnd, i.Quantity * i.UnitPriceVnd))
            .ToList();
        return new OrderV2Dto(order.Id, order.Status, order.PlacedAt, lines, lines.Sum(l => l.LineTotalVnd));
    }
}
