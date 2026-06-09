import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/repo/product_repo.dart';
import 'filterable_bulk_product_screen.dart';

class AllLastPurchasedScreen extends StatelessWidget {
  const AllLastPurchasedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ProductRepositoryImpl();
    return FilterableBulkProductScreen(
      title: AppLocalizations.of(context)!.purchasedBefore,
        fetcher: ({required skip, required limit, categoryId, keyword}) =>
            repo.getProducts(
              skip: skip,
              limit: limit,
              isLastPurchased: true,
              categoryId: categoryId,
              keyword: keyword,
            ),);
  }
}
