import 'package:flutter/material.dart';
import '../app_theme.dart';

class AutocompleteBasic extends StatelessWidget {
  final void Function(TextEditingController) assign;
  final VoidCallback select;
  final String label;
  final Set<String> options;
  final Widget? prefixIcon;

  const AutocompleteBasic({
    super.key,
    required this.options,
    required this.assign,
    String? label,
    String? lable,
    required this.select,
    this.prefixIcon,
  }) : label = label ?? (lable ?? '');

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        assign(textEditingController);
        return TextField(
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            floatingLabelStyle: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: textEditingController,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: AppColors.textMuted),
                  tooltip: 'پاک کردن',
                  onPressed: textEditingController.clear,
                );
              },
            ),
          ),
            controller: textEditingController,
            onSubmitted: (_) => onFieldSubmitted,
            focusNode: focusNode,
          );
        },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        final q = textEditingValue.text.trim();
        final ql = q.toLowerCase();
        final matches = options.where((String option) {
          return option.contains(q) || option.toLowerCase().contains(ql);
        }).toList();

        // Prefer prefix / starts-with for Persian typing
        matches.sort((a, b) {
          final ap = a.startsWith(q) ? 0 : 1;
          final bp = b.startsWith(q) ? 0 : 1;
          if (ap != bp) return ap - bp;
          return a.length.compareTo(b.length);
        });
        return matches;
      },
      onSelected: (String selection) {
        select();
        debugPrint('Selected station: $selection');
      },
    );
  }
}
