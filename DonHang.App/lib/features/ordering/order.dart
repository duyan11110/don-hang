// lesson: frontend.l1.fetching-with-http-package
// Shapes matching DonHang.Api's order DTOs (DonHang.Api/Dtos.cs), only the
// fields the app uses. From stage-4 they live in the Ordering feature.
class OrderItemRequest {
  final int productId;
  final int quantity;
  final int unitPriceVnd;

  OrderItemRequest({required this.productId, required this.quantity, required this.unitPriceVnd});

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'quantity': quantity,
        'unitPriceVnd': unitPriceVnd,
      };

  // From stage-3 a queued order keeps its items on the device as JSON.
  factory OrderItemRequest.fromJson(Map<String, dynamic> json) => OrderItemRequest(
        productId: json['productId'] as int,
        quantity: json['quantity'] as int,
        unitPriceVnd: json['unitPriceVnd'] as int,
      );
}

// lesson: frontend.l3.sync-conflicts
// From stage-3 the answer's items are read too: their prices are the ones
// the API charged, which can differ from the ones the customer saw. Each
// has the same three fields as an item of the request, so it reuses that class.
class OrderResult {
  final int id;
  final String status;
  final List<OrderItemRequest> items;

  OrderResult({required this.id, required this.status, this.items = const []});

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        id: json['id'] as int,
        status: json['status'] as String,
        items: [
          for (final item in json['items'] as List<dynamic>? ?? [])
            OrderItemRequest.fromJson(item as Map<String, dynamic>),
        ],
      );

  // A queued order keeps the API's answer on the device, in the same shape.
  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'items': [for (final item in items) item.toJson()],
      };
}

// What a list of items costs: each price times its quantity, added up.
int totalVnd(List<OrderItemRequest> items) {
  var total = 0;
  for (final item in items) {
    total += item.quantity * item.unitPriceVnd;
  }
  return total;
}
