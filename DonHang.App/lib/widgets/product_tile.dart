import 'package:flutter/material.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

// lesson: frontend.l1.accessibility-basics
// lesson: frontend.l2.messages-with-values
// One product, the same piece in a list or a grid. The Semantics label gives a
// screen reader one clear sentence instead of two loose texts; the minimum
// height keeps the tap target at least 48 logical pixels. From stage-2 the
// price and that sentence are whole messages with the price as a placeholder,
// formatted for the user's language.
class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductTile({super.key, required this.product, this.onTap});

  // lesson: frontend.l3.semantic-tokens
  // From stage-3 the sizes are tokens: the tap target and the padding every
  // tile shares, not two numbers that could drift apart from other places.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.productSemanticsLabel(product.name, product.priceVnd),
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Sizes.minTapTarget),
          child: Padding(
            padding: Insets.tile,
            child: Row(
              children: [
                Expanded(child: Text(product.name)),
                Text(l10n.productPrice(product.priceVnd)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
