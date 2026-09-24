namespace DonHang.Api;

// lesson: backend.l1.dtos-and-serialization
// The API answers in these shapes, never in the entity shapes from DonHang.Domain.
public sealed record ProductDto(int Id, string Name, int PriceVnd);

public sealed record OrderItemDto(int ProductId, int Quantity, int UnitPriceVnd);

public sealed record OrderDto(int Id, int CustomerId, string Status, DateTimeOffset PlacedAt, List<OrderItemDto> Items);

public sealed record CreateOrderItemRequest(int ProductId, int Quantity, int UnitPriceVnd);

public sealed record CreateOrderRequest(List<CreateOrderItemRequest> Items);

public sealed record LoginRequest(string Email, string Password);

public sealed record LoginResponse(string Token);

// lesson: backend.l1.efcore-n-plus-one
public sealed record OrderSummaryDto(int Id, string Status, string CustomerName);
