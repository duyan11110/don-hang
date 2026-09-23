// lesson: frontend.l1.fetching-with-http-package
// Two shapes matching DonHang.Api's DTOs (DonHang.Api/Dtos.cs), nothing more.
class Product {
  final int id;
  final String name;
  final int priceVnd;

  Product({required this.id, required this.name, required this.priceVnd});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        priceVnd: json['priceVnd'] as int,
      );
}

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
}

class OrderResult {
  final int id;
  final String status;

  OrderResult({required this.id, required this.status});

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        id: json['id'] as int,
        status: json['status'] as String,
      );
}
