import 'package:flutter/material.dart';
import '../models.dart';

// lesson: frontend.l1.accessibility-basics
// One product, the same piece in a list or a grid. The Semantics label gives a
// screen reader one clear sentence instead of two loose texts; the minimum
// height keeps the tap target at least 48 logical pixels.
class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductTile({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${product.name}, ${product.priceVnd} đồng',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text(product.name)),
                Text('${product.priceVnd} đ'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
