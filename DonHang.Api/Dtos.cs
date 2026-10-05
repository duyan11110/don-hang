using System.ComponentModel.DataAnnotations;

namespace DonHang.Api;

// lesson: backend.l1.dtos-and-serialization
// The API answers in these shapes, never in the entity shapes from DonHang.Domain.
public sealed record ProductDto(int Id, string Name, int PriceVnd);

// lesson: backend.l2.cache-invalidation
public sealed record UpdateProductPriceRequest([Range(1, int.MaxValue)] int PriceVnd);

// lesson: design.l3.storing-value-objects
// The JSON keeps unitPriceVnd as a plain number from stage-3 too: Vnd stays
// inside DonHang.Domain, and the controller passes on its Amount.
public sealed record OrderItemDto(int ProductId, int Quantity, int UnitPriceVnd);

public sealed record OrderDto(int Id, int CustomerId, string Status, DateTimeOffset PlacedAt, List<OrderItemDto> Items);

public sealed record CreateOrderItemRequest(int ProductId, int Quantity, int UnitPriceVnd);

public sealed record CreateOrderRequest(List<CreateOrderItemRequest> Items);

// lesson: backend.l1.efcore-n-plus-one
public sealed record OrderSummaryDto(int Id, string Status, string CustomerName);

// lesson: design.l3.read-model
public sealed record OrderStatusChangeDto(string Event, string Status, DateTimeOffset OccurredAt);

// lesson: backend.l2.api-versioning
// The /api/v2/orders shape. Breaking for a v1 client: `items` is now `lines`
// (each with its own total) and `customerId` is gone — the caller is the
// customer. v1's OrderDto above stays exactly as it was.
public sealed record OrderLineV2Dto(int ProductId, int Quantity, int UnitPriceVnd, int LineTotalVnd);

public sealed record OrderV2Dto(int Id, string Status, DateTimeOffset PlacedAt, List<OrderLineV2Dto> Lines, int TotalVnd);

public sealed record CreateOrderLineV2Request(int ProductId, int Quantity, int UnitPriceVnd);

public sealed record CreateOrderV2Request(List<CreateOrderLineV2Request> Lines);
