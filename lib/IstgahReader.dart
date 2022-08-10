import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'dijkstra.dart';
import 'pair.dart';

class IstgahReader {
  String path = "assets/data/metrofa.txt";
  String splitter = ',';

// Future<List<String>> getFileLines() async {
//   final data = await rootBundle.load('assets/bot.txt');
//   final directory = (await getTemporaryDirectory()).path;
//   final file = await writeToFile(data, '$directory/bot.txt');
//   return await file.readAsLines();
// }

// Future<File> writeToFile(ByteData data, String path) {
//   return File(path).writeAsBytes(data.buffer.asUint8List(
//     data.offsetInBytes,
//     data.lengthInBytes,
//   ));
// }
  Future<File> getFileFromAssets(String path) async {
    final byteData = await rootBundle.load(path);

    final file = File('${(await getTemporaryDirectory()).path}/$path');
    return await file.create(recursive: true).then((value) async {
      return await value.writeAsBytes(
        byteData.buffer
            .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    });
  }

  Future<Pair<Set<String>, List<Pair<String, String>>>> ReadStates() async {
    Set<String> all = Set();
    List<Pair<String, String>> firstLast = [];
    var file = await getFileFromAssets(path);
    Stream<String> lines = file
        .openRead()
        .transform(utf8.decoder) // Decode bytes to UTF-8.
        .transform(LineSplitter());
    return lines.forEach((line) {
      final list = line.split(splitter);
      firstLast.add(Pair(list.first, list.last));
      all.addAll(list);
    }).then((value) {
      return Pair(all, firstLast);
    });
    // await for (var line in lines) {
    //   all.addAll(line.split(' '));
    // }
    // return all;
  }

  Future<SplayTreeMap<String, Node>> ReadFile() async {
    // TreeMap nodes = TreeMap();
    SplayTreeMap<String, Node> nodes = SplayTreeMap();
    // SplayTreeSet<Node> nodes2 = SplayTreeSet<Node>();
    // var file = File(path);
    var file = await getFileFromAssets(path);
    Stream<String> lines = file
        .openRead()
        .transform(utf8.decoder) // Decode bytes to UTF-8.
        .transform(LineSplitter());
    int currentKhat = 1;
    await for (var line in lines) {
      // print('$line: ${line.length} characters');
      List<String> istgahs = line.split(splitter);
      for (var i = 0; i < istgahs.length; i++) {
        String istgah = istgahs[i];
        //create node
        if (nodes.containsKey(istgah)) {
          nodes[istgah]?.khat.add(currentKhat);
          nodes[istgah]?.index.add(i);
        } else {
          Node node = Node(name: istgah, khat: [currentKhat], index: [i]);
          // nodes.add(istgah, node);
          nodes[istgah] = node;
        }

        if (i > 0) {
          //add edge to previous node
          String istgah1 = istgahs[i - 1];
          String istgah2 = istgahs[i];
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

    // print('File is now closed.');
    return nodes;
  }
}
