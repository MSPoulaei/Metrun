import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'dijkstra.dart';
import 'pair.dart';

class IstgahReader {
  final String path;
  final String splitter;

  IstgahReader({
    this.path = 'assets/data/metrofa.txt',
    this.splitter = ',',
  });

  Future<Pair<Set<String>, List<Pair<String, String>>>> readStates() async {
    final Set<String> all = <String>{};
    final List<Pair<String, String>> firstLast = [];
    final content = await rootBundle.loadString(path);
    final lines = const LineSplitter().convert(content);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final list = line.split(splitter);
      if (list.isNotEmpty) {
        firstLast.add(Pair(list.first, list.last));
        all.addAll(list);
      }
    }
    return Pair(all, firstLast);
  }

  Future<SplayTreeMap<String, Node>> readFile() async {
    final SplayTreeMap<String, Node> nodes = SplayTreeMap();
    final content = await rootBundle.loadString(path);
    final lines = const LineSplitter().convert(content);

    int currentKhat = 1;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final List<String> istgahs = line.split(splitter);
      for (var i = 0; i < istgahs.length; i++) {
        final String istgah = istgahs[i];
        if (nodes.containsKey(istgah)) {
          nodes[istgah]?.khat.add(currentKhat);
          nodes[istgah]?.index.add(i);
        } else {
          final Node node = Node(name: istgah, khat: [currentKhat], index: [i]);
          nodes[istgah] = node;
        }

        if (i > 0) {
          final String istgah1 = istgahs[i - 1];
          final String istgah2 = istgahs[i];
          nodes[istgah1]!
              .edges
              .add(Edge(from: nodes[istgah1]!, to: nodes[istgah2]!));
          nodes[istgah2]!
              .edges
              .add(Edge(from: nodes[istgah2]!, to: nodes[istgah1]!));
        }
      }
      currentKhat++;
    }
    return nodes;
  }
}
