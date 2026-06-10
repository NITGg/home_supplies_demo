import 'package:flutter/material.dart';

/// A simple text field for filtering already-loaded data on screen
/// (as opposed to triggering a server-side search).
class LocalSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool hasQuery;

  const LocalSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.hasQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: hasQuery
              ? IconButton(
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: controller.clear,
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}
