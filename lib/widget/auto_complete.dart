import 'package:flutter/material.dart';

class AutocompleteBasic extends StatelessWidget {
  final void Function(TextEditingController) assign;
  final VoidCallback select;
  final String label;
  final Set<String> options;

  const AutocompleteBasic({
    super.key,
    required this.options,
    required this.assign,
    String? label,
    String? lable,
    required this.select,
  }) : label = label ?? (lable ?? '');

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        assign(textEditingController);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: TextField(
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            decoration: InputDecoration(
              labelText: label,
              hintTextDirection: TextDirection.rtl,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: textEditingController.clear,
              ),
            ),
            controller: textEditingController,
            onSubmitted: (_) => onFieldSubmitted,
            focusNode: focusNode,
          ),
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
