import 'dart:collection';

import 'IstgahReader.dart';
import 'pair.dart';
import 'stack.dart';
import 'package:collection/collection.dart';

class Dijkstra {
  SplayTreeMap<String, Node>? nodes_save = null;
  Future init() async {
    IstgahReader istgahReader = IstgahReader();
    return nodes_save = await istgahReader.ReadFile();
  }

  int getIntersectKhat(Node node1, Node node2) {
    var khat_intersect_old_from = node1.khat.toList();
    khat_intersect_old_from
        .removeWhere((element) => !node2.khat.contains(element));
    return khat_intersect_old_from[0];
  }

  bool HasIntersectKhat(Node node1, Node node2) {
    var khat_intersect_old_from = node1.khat.toList();
    khat_intersect_old_from
        .removeWhere((element) => !node2.khat.contains(element));
    return khat_intersect_old_from.isNotEmpty;
  }

  Pair<int, Stack<Node>> GetPath(String istgah1, String istgah2) {
    // TreeMap nodes = TreeMap();
    // SplayTreeSet<Node> set = SplayTreeSet.from(
    //   nodes_save!.values,
    //   (key1, key2) =>
    //       key1.distance_from_source.compareTo(key2.distance_from_source),
    // );
    HeapPriorityQueue<Node> queue = HeapPriorityQueue(
      (p0, p1) => p0.distance_from_source.compareTo(p1.distance_from_source),
    );
    var values = nodes_save!.values;
    values
        .firstWhere((element) => element.name == istgah1)
        .distance_from_source = 0;
    queue.addAll(values);
    // nodes.tree = SplayTreeMap.from(nodes_save!);
    // nodes.tree[istgah1]!.distance_from_source = 0;

    Node? currentNode;
    while (true) {
      // currentNode = nodes.tree[nodes.tree.firstKey()]!;
      currentNode = queue.removeFirst();
      if (currentNode.name == istgah2) break;
      for (var edge in currentNode.edges) {
        Node toNode = edge.to;
        int additionalCost = 0;
        if (currentNode.isTavizKhat && currentNode.previous != null) {
          if (HasIntersectKhat(currentNode.previous!, toNode)) {
            if (!currentNode.khat
                .contains(getIntersectKhat(currentNode.previous!, toNode))) {
              additionalCost = 10;
            }
          } else {
            additionalCost = 10;
          }
        }
        if (currentNode.distance_from_source + edge.weight + additionalCost <
            toNode.distance_from_source) {
          queue.remove(toNode);
          toNode.distance_from_source =
              currentNode.distance_from_source + edge.weight + additionalCost;
          toNode.previous = currentNode;
          queue.add(toNode);
        } else if (toNode.isTavizKhat) {
          queue.add(Node.from(
              name: toNode.name,
              khat: toNode.khat,
              edges: toNode.edges,
              distance_from_source: currentNode.distance_from_source +
                  edge.weight +
                  additionalCost,
              index: toNode.index,
              previous: currentNode));
        }
      }
      // queue.removeFirst();
      // nodes.tree.remove(currentNode.name);
    }
    int distance = currentNode.distance_from_source;
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
  int distance_from_source = 0x7fffffff; //infinity
  Node? previous = null;
  bool get isTavizKhat => khat.length > 1;
  Node({required this.name, required this.khat,required this.index});
  Node.from(
      {required this.name,
      required this.khat,
      required this.edges,
      required this.distance_from_source,
      required this.index,
      this.previous});
}

class Edge {
  Node from;
  Node to;
  int weight;
  Edge({required this.from, required this.to, this.weight = 2});
}
