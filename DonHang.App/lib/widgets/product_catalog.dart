import 'package:flutter/material.dart';
import '../design/tokens.dart';
import '../models.dart';
import 'product_tile.dart';

// lesson: frontend.l1.responsive-basics
// Same ProductTile either way; only the arrangement changes. The decision reads
// the width LayoutBuilder reports for this widget, not the size of the screen.
class ProductCatalog extends StatelessWidget {
  static const double wideLayoutMinWidth = 600;
  static const double columnWidth = 300;

  final List<Product> products;

  // lesson: frontend.l2.futureprovider-and-asyncvalue
  // From stage-2 ProductListScreen shows its data through this widget and
  // says what a tap does; the catalog itself only lays the tiles out.
  final ValueChanged<Product>? onProductTap;

  const ProductCatalog({super.key, required this.products, this.onProductTap});

  // lesson: frontend.l3.lazy-lists
  // Both builders get an itemCount and an itemBuilder, and call the builder
  // only for the tiles in or near the visible area, more as the user
  // scrolls: how many tiles exist depends on the space, not on the list.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideLayoutMinWidth) {
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) => _tile(products[index]),
          );
        }
        final columns = (constraints.maxWidth / columnWidth).floor();
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: Sizes.gridRow,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _tile(products[index]),
        );
      },
    );
  }

  Widget _tile(Product product) {
    final onTap = onProductTap;
    return ProductTile(product: product, onTap: onTap == null ? null : () => onTap(product));
  }
}
