// search_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/image_with_fallback.dart';
import '../../../core/widgets/text_form.dart';
import '../../../l10n/app_localizations.dart';
import '../data/data_source/search_remote_data_source.dart';
import '../data/models/search_models.dart';
import '../data/repo/search_repo.dart';
import '../manager/search_cubit.dart';
import '../manager/search_states.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Entry point: call this from any button's onPressed
// ─────────────────────────────────────────────────────────────────────────────

void showSearchDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Search',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => const _SearchDialogProvider(),
    transitionBuilder: (_, anim, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BlocProvider wrapper so the cubit is scoped to the dialog lifetime
// ─────────────────────────────────────────────────────────────────────────────

class _SearchDialogProvider extends StatelessWidget {
  const _SearchDialogProvider();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchCubit(
        SearchRepositoryImpl(SearchRemoteDataSource()),
      ),
      child: const _SearchDialog(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The dialog itself
// ─────────────────────────────────────────────────────────────────────────────

class _SearchDialog extends StatefulWidget {
  const _SearchDialog();

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();
    final mq = MediaQuery.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, mq.padding.top + 16, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.82,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Search field ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppTextFormField(
                          label: AppLocalizations.of(context)!.search,
                          controller: _controller,
                          focusNode: _focusNode,
                          isRequired: false,
                          prefixIcon: const Icon(Icons.search_rounded),
                          onChanged: cubit.onQueryChanged,
                          textInputAction: TextInputAction.search,
                          onFieldSubmitted: (_) {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Results ───────────────────────────────────────────────
                Flexible(
                  child: BlocBuilder<SearchCubit, SearchState>(
                    builder: (context, state) {
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: switch (state) {
                          SearchInitial() => const _HintView(),
                          SearchLoading() => const _LoadingView(),
                          SearchEmpty() => const _EmptyView(),
                          SearchError(:final message) =>
                              _ErrorView(message: message),
                          SearchSuccess(:final result) => _ResultsList(
                            result: result,
                            onItemTapped: () => Navigator.of(context).pop(),
                          ),
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results list
// ─────────────────────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final SearchResponse result;
  final VoidCallback onItemTapped;

  const _ResultsList({required this.result, required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      shrinkWrap: true,
      children: [
        if (result.categories.isNotEmpty) ...[
          _SectionHeader(title: AppLocalizations.of(context)!.categories),
          ...result.categories.map(
                (c) => _SearchTile(
              name: c.displayName,
              imageUrl: c.imageUrl ?? c.iconUrl,
              onTap: () {
                onItemTapped();
                context.push('/categories/${c.id}', extra: c);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (result.products.isNotEmpty) ...[
          _SectionHeader(title: AppLocalizations.of(context)!.products),
          ...result.products.map(
                (p) => _SearchTile(
              name: p.displayName,
              imageUrl: p.primaryImage,
              onTap: () {
                onItemTapped();
                context.push('/products/${p.id}', extra: p);
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SearchTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  const _SearchTile({
    required this.name,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ImageWithIconFallback(
                  imageUrl: imageUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  iconSize: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  const _HintView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.typeToSearchProducts,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.noResultsFound,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        style: TextStyle(color: Colors.red.shade400, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}