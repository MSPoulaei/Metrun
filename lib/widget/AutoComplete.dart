import 'package:flutter/material.dart';

class AutocompleteBasic extends StatelessWidget {
  Function assign;
  Function select;
  String lable;
  AutocompleteBasic(
      {required this.options,
      required this.assign,
      required this.lable,
      Key? key,
      required this.select})
      : super(key: key);

  Set<String> options;

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
                labelText: lable,
                hintTextDirection: TextDirection.rtl,
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: textEditingController.clear,
                ),
              ),
              controller: textEditingController,
              onSubmitted: (_) => onFieldSubmitted,
              focusNode: focusNode),
        );
      },
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<String>.empty();
        }
        return options.where((String option) {
          return option.contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        select();
        debugPrint('You just selected $selection');
      },
    );
  }
}
