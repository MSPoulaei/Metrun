import 'dart:collection';

import 'istgah_reader.dart';
import 'pair.dart';
import 'stack.dart';
import 'package:collection/collection.dart';

class Dijkstra {
  SplayTreeMap<String, Node>? nodesSave;
  Future init() async {
    IstgahReader istgahReader = IstgahReader();
    return nodesSave = await istgahReader.readFile();
  }

  int getIntersectKhat(Node node1, Node node2) {
    var khatIntersectOldFrom = node1.khat.toList();
    khatIntersectOldFrom
        .removeWhere((element) => !node2.khat.contains(element));
    return khatIntersectOldFrom[0];
  }

  bool hasIntersectKhat(Node node1, Node node2) {
    var khatIntersectOldFrom = node1.khat.toList();
    khatIntersectOldFrom
        .removeWhere((element) => !node2.khat.contains(element));
    return khatIntersectOldFrom.isNotEmpty;
  }

  Pair<int, Stack<Node>> getPath(String istgah1, String istgah2) {
    HeapPriorityQueue<Node> queue = HeapPriorityQueue(
      (p0, p1) => p0.distanceFromSource.compareTo(p1.distanceFromSource),
    );
    var values = nodesSave!.values;
    values
        .firstWhere((element) => element.name == istgah1)
        .distanceFromSource = 0;
    queue.addAll(values);

    Node? currentNode;
    while (true) {
      currentNode = queue.removeFirst();
      if (currentNode.name == istgah2) break;
      for (var edge in currentNode.edges) {
        Node toNode = edge.to;
        int additionalCost = 0;
        if (currentNode.isTavizKhat && currentNode.previous != null) {
          if (hasIntersectKhat(currentNode.previous!, toNode)) {
            if (!currentNode.khat
                .contains(getIntersectKhat(currentNode.previous!, toNode))) {
              additionalCost = 10;
            }
          } else {
            additionalCost = 10;
          }
        }
        if (currentNode.distanceFromSource + edge.weight + additionalCost <
            toNode.distanceFromSource) {
          queue.remove(toNode);
          toNode.distanceFromSource =
              currentNode.distanceFromSource + edge.weight + additionalCost;
          toNode.previous = currentNode;
          queue.add(toNode);
        } else if (toNode.isTavizKhat) {
          queue.add(Node.from(
              name: toNode.name,
              khat: toNode.khat,
              edges: toNode.edges,
              distanceFromSource: currentNode.distanceFromSource +
                  edge.weight +
                  additionalCost,
              index: toNode.index,
              previous: currentNode));
        }
      }
    }
    int distance = currentNode.distanceFromSource;
    Stack<Node> path = Stack<Node>();
    while (currentNode != null) {
      path.push(currentNode);
      currentNode = currentNode.previous;
    }
    return Pair(distance, path);
  }
}

class Node {
  String name;
  List<int> khat;
  List<int> index;
  List<Edge> edges = <Edge>[];
  int distanceFromSource = 0x7fffffff; //infinity
  Node? previous;
  bool get isTavizKhat => khat.length > 1;
  Node({required this.name, required this.khat, required this.index});
  Node.from(
      {required this.name,
      required this.khat,
      required this.edges,
      required this.distanceFromSource,
      required this.index,
      this.previous});
}

class Edge {
  Node from;
  Node to;
  int weight;
  Edge({required this.from, required this.to, this.weight = 2});
}
