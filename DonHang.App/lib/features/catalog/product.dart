// lesson: frontend.l1.fetching-with-http-package
// The shape matching DonHang.Api's ProductDto (DonHang.Api/Dtos.cs), nothing
// more. From stage-4 it lives in the Catalog feature, which owns products.
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

  // From stage-3: the shape the saved product list is kept in, the same as
  // the API's, so fromJson reads both (frontend.l3.offline-first).
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'priceVnd': priceVnd};
}
