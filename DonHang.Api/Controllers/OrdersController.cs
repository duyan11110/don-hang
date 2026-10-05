using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using DonHang.Api.Monitoring;
using DonHang.Domain;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace DonHang.Api.Controllers;

// lesson: backend.l1.creating-a-resource
[ApiController]
[Route("api/v1/orders")]
public sealed class OrdersController(
    OrderService orderService,
    IOrderRepository repository,
    ICustomerRepository customers,
    IAuthorizationService authorization) : ControllerBase
{
    private const int MaxPageSize = 100;

    // lesson: backend.l1.rest-for-writes
    // Requires a signed-in customer; customer_id comes from the token's `sub`
    // claim, never from the request body (frontend.l1.creating-an-order).
    // A caller with no customer row, such as a staff member, gets 403.
    // lesson: backend.l2.idempotent-endpoints
    // The optional Idempotency-Key header is created by the client once per
    // order it means to place; a retry sends the same value again.
    [Authorize]
    [HttpPost]
    public async Task<ActionResult<OrderDto>> Create(
        CreateOrderRequest request,
        [FromHeader(Name = "Idempotency-Key")] string? idempotencyKey)
    {
        var customer = await CurrentCustomerAsync();
        if (customer is null) return Forbid();

        var items = request.Items
            .Select(i => new OrderItem(i.ProductId, i.Quantity, new Vnd(i.UnitPriceVnd)))
            .ToList();

        var (order, created) = await orderService.PlaceOrderAsync(customer.Id, items, idempotencyKey);

        // lesson: devops.l2.counters-and-rate
        // Counted only when an order was really created: a retry that repeats
        // an Idempotency-Key gets the earlier order back and adds nothing.
        if (created) OrderMetrics.OrdersPlaced.Inc();
        return CreatedAtAction(nameof(Get), new { id = order.Id }, ToDto(order));
    }

    // lesson: backend.l2.no-tracking-queries
    // Only reads the order to build the response, so it loads it untracked.
    // lesson: backend.l2.resource-based-authorization
    // Who may read an order depends on the order, so the check runs after
    // loading it: its owner or staff get it, another customer gets 403.
    [Authorize]
    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDto>> Get(int id)
    {
        var order = await repository.FindForReadingAsync(id);
        if (order is null) return NotFound();

        var allowed = await authorization.AuthorizeAsync(User, order, "OrderOwner");
        if (!allowed.Succeeded) return Forbid();

        return Ok(ToDto(order));
    }

    // lesson: design.l2.domain-model
    // Whether this order may be cancelled is Order.Cancel()'s decision; a
    // refusal arrives here as OrderStatusException and leaves as a 409.
    // The same OrderOwner check as Get runs first, on an untracked copy.
    [Authorize]
    [HttpPatch("{id:int}/cancel")]
    public async Task<ActionResult<OrderDto>> Cancel(int id)
    {
        var existing = await repository.FindForReadingAsync(id);
        if (existing is null) return NotFound();

        var allowed = await authorization.AuthorizeAsync(User, existing, "OrderOwner");
        if (!allowed.Succeeded) return Forbid();

        var order = await orderService.CancelOrderAsync(id);
        return Ok(ToDto(order));
    }

    // lesson: design.l2.status-changes-through-methods
    // lesson: backend.l2.role-based-access
    // The endpoint decides who may ship: the StaffOnly policy lets in only a
    // token whose roles include "staff" (403 for a customer, 401 with no
    // token). Order.Ship() decides whether this order can be shipped.
    [Authorize(Policy = "StaffOnly")]
    [HttpPatch("{id:int}/ship")]
    public async Task<ActionResult<OrderDto>> Ship(int id)
    {
        var order = await orderService.ShipOrderAsync(id);
        return Ok(ToDto(order));
    }

    // lesson: backend.l1.efcore-n-plus-one
    // lesson: backend.l2.cursor-pagination
    // GET /api/v1/orders?after=120&limit=20: the signed-in customer's orders
    // with an id greater than `after`, sorted by id. The client sends the last
    // id it received as the next `after`.
    [Authorize]
    [HttpGet]
    public async Task<ActionResult<List<OrderSummaryDto>>> List(
        [FromQuery, Range(0, int.MaxValue)] int after = 0,
        [FromQuery, Range(1, MaxPageSize)] int limit = 20)
    {
        var customer = await CurrentCustomerAsync();
        if (customer is null) return Forbid();

        var orders = await repository.ListByCustomerAsync(customer.Id, after, limit);
        return Ok(orders.Select(o => new OrderSummaryDto(o.Id, o.Status, o.CustomerName)).ToList());
    }

    // lesson: backend.l2.validating-provider-tokens
    // `sub` is Keycloak's id for the caller, not a customers.id, so it is
    // looked up in customers.identity_subject instead of parsed as a number.
    private async Task<Customer?> CurrentCustomerAsync()
    {
        var subject = User.FindFirstValue("sub");
        return subject is null ? null : await customers.FindByIdentitySubjectAsync(subject);
    }

    private static OrderDto ToDto(Order order) => new(
        order.Id,
        order.CustomerId,
        order.Status,
        order.PlacedAt,
        order.Items.Select(i => new OrderItemDto(i.ProductId, i.Quantity, i.UnitPrice.Amount)).ToList());
}
