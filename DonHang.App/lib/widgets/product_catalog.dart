import 'package:flutter/material.dart';
import '../models.dart';
import 'product_tile.dart';

// lesson: frontend.l1.responsive-basics
// Same ProductTile either way; only the arrangement changes. The decision reads
// the width LayoutBuilder reports for this widget, not the size of the screen.
class ProductCatalog extends StatelessWidget {
  static const double wideLayoutMinWidth = 600;
  static const double columnWidth = 300;

  final List<Product> products;

  const ProductCatalog({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < wideLayoutMinWidth) {
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) => ProductTile(product: products[index]),
          );
        }
        final columns = (constraints.maxWidth / columnWidth).floor();
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 72,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => ProductTile(product: products[index]),
        );
      },
    );
  }
}
