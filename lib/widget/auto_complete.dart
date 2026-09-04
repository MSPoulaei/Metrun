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
        final rawQ = textEditingValue.text.trim();
        if (rawQ.isEmpty) {
          return const Iterable<String>.empty();
        }
        final nq = _normalizeForSearch(rawQ);
        if (nq.isEmpty) {
          return const Iterable<String>.empty();
        }

        final scored = <_SearchMatch>[];
        for (final option in options) {
          final no = _normalizeForSearch(option);
          if (!no.contains(nq)) continue;

          final words = no.split(' ');
          int tier;
          if (no.startsWith(nq)) {
            tier = 0; // Entire station starts with query
          } else if (words.any((w) => w.startsWith(nq))) {
            tier = 1; // A word starts with query (e.g. 'آزادی' in 'میدان آزادی' when typing 'ا' or 'ازادی')
          } else {
            tier = 2; // Query appears within a word
          }
          scored.add(_SearchMatch(option, tier, option.length));
        }

        scored.sort((a, b) {
          if (a.tier != b.tier) return a.tier.compareTo(b.tier);
          if (a.length != b.length) return a.length.compareTo(b.length);
          return a.option.compareTo(b.option);
        });

        return scored.map((m) => m.option);
      },
      onSelected: (String selection) {
        select();
        debugPrint('Selected station: $selection');
      },
    );
  }
}

class _SearchMatch {
  final String option;
  final int tier;
  final int length;
  const _SearchMatch(this.option, this.tier, this.length);
}

/// Normalizes Persian and Arabic text for tolerant search matching:
/// - Unifies all Alef forms (آ, أ, إ, ٱ -> ا)
/// - Unifies Yeh forms (ي, ى, ئ -> ی)
/// - Unifies Kaf forms (ك -> ک)
/// - Maps Teh Marbuta (ة -> ه)
/// - Strips diacritics / harakat and normalizes punctuation / ZWNJ
String _normalizeForSearch(String text) {
  if (text.isEmpty) return '';
  var s = text;
  // Normalize Alef variants
  s = s.replaceAll(RegExp(r'[آأإٱ]'), 'ا');
  // Normalize Yeh variants
  s = s.replaceAll(RegExp(r'[يىئ]'), 'ی');
  // Normalize Kaf
  s = s.replaceAll('ك', 'ک');
  // Normalize Teh Marbuta
  s = s.replaceAll('ة', 'ه');
  // Replace ZWNJ and punctuation with spaces
  s = s.replaceAll(RegExp(r'[\u200c\u200d\u200e\u200f\(\)\[\]\-–—،,._]'), ' ');
  // Remove Arabic diacritics / accents
  s = s.replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');
  // Collapse whitespace
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  return s;
}
