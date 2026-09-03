import 'dijkstra.dart';

class Stepp {
  Node? from;
  Node? to;
  bool tavizkhat;
  int min;
  int? khat1;
  int? khat2;
  int? index1;
  int? index2;

  Stepp({
    required this.from,
    required this.to,
    required this.min,
    this.tavizkhat = false,
    this.khat1,
    this.khat2,
    this.index1,
    this.index2,
  });
}

class Masiryab {
  int getIntersectKhat(Node node1, Node node2) {
    var khatIntersect = node1.khat.toList();
    khatIntersect.removeWhere((element) => !node2.khat.contains(element));
    return khatIntersect[0];
  }

  bool HasIntersectKhat(Node node1, Node node2) {
    var khatIntersect = node1.khat.toList();
    khatIntersect.removeWhere((element) => !node2.khat.contains(element));
    return khatIntersect.isNotEmpty;
  }

  Future<List<Stepp>> GetPath(
      String istgahMabda, String istgahMaghsad) async {
    List<Stepp> path = [];
    Dijkstra dijkstra = Dijkstra();
    return dijkstra.init().then((_) {
      var res = dijkstra.GetPath(istgahMabda, istgahMaghsad);
      var stack = res.second;
      Node fromnode = stack.pop(), tonode = fromnode;
      int khat = getIntersectKhat(fromnode, stack.peek);
      int index = 0;
      if (fromnode.khat[0] == khat) {
        index = fromnode.index[0];
      } else if (fromnode.khat[1] == khat) {
        index = fromnode.index[1];
      }
      path.add(
          Stepp(from: fromnode, to: null, min: 17, khat2: khat, index2: index));
      int counter = 29;
      while (stack.isNotEmpty) {
        tonode = stack.pop();
        index = 0;
        if (tonode.khat[0] == khat) {
          index = tonode.index[0];
        } else if (tonode.khat[1] == khat) {
          index = tonode.index[1];
        }
        path.add(Stepp(
            from: fromnode, to: tonode, min: 2, khat2: khat, index2: index));
        counter += 2;
        if (tonode.isTavizKhat && stack.isNotEmpty) {
          Node old = fromnode;
          fromnode = tonode;
          tonode = stack.peek;
          var khatIntersectOldTo = old.khat.toList();
          khatIntersectOldTo
              .removeWhere((element) => !tonode.khat.contains(element));
          if (khatIntersectOldTo.isEmpty ||
              !fromnode.khat.contains(khatIntersectOldTo[0])) {
            // taviz khat
            var khatIntersectOldFrom = old.khat.toList();
            khatIntersectOldFrom
                .removeWhere((element) => !fromnode.khat.contains(element));
            var khatIntersectFromTo = fromnode.khat.toList();
            khatIntersectFromTo
                .removeWhere((element) => !tonode.khat.contains(element));
            khat = khatIntersectFromTo[0];
            int index1 = 0, index2 = 0;
            if (fromnode.khat[0] == khatIntersectOldFrom[0]) {
              index1 = fromnode.index[0];
              index2 = fromnode.index[1];
            } else if (fromnode.khat[1] == khatIntersectOldFrom[0]) {
              index1 = fromnode.index[1];
              index2 = fromnode.index[0];
            }

            path.add(Stepp(
                from: fromnode,
                to: fromnode,
                min: 10,
                tavizkhat: true,
                khat1: khatIntersectOldFrom[0],
                khat2: khatIntersectFromTo[0],
                index1: index1,
                index2: index2));
            counter += 10;
          }
        } else {
          fromnode = tonode;
        }
      }

      path.add(Stepp(from: null, to: tonode, min: 12, khat2: khat));
      path.insert(0, Stepp(from: null, to: null, min: counter));
      return path;
    });
  }
}
