import 'dart:collection';

import 'dijkstra.dart';
import 'pair.dart';
import 'stack.dart';

class Stepp {
  Node? from;
  Node? to;
  bool tavizkhat;
  int min;
  Stepp(
      {required this.from,
      required this.to,
      required this.min,
      this.tavizkhat = false,
      this.khat1,
      this.khat2,
      this.index1,
      this.index2});
  int? khat1;
  int? khat2;
  int? index1;
  int? index2;
}

class Masiryab {
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

  Future<List<Stepp>> GetPath(
      String istgah_mabda, String istgah_maghsad) async {
    List<Stepp> path = [];
    Dijkstra dijkstra = Dijkstra();
    return dijkstra.init().then((_) {
      var res = dijkstra.GetPath(istgah_mabda, istgah_maghsad);
      var stack = res.second;
      // print(res.first + 29);
      // printRes(path);
      Node fromnode = stack.pop(), tonode = fromnode;
      // print("Savar istgah ${fromnode.name} shavid :17min");
      // path.add("Savar istgah ${fromnode.name} shavid :17min");
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
        // khat = getIntersectKhat(fromnode, tonode);
        // print("from ${fromnode.name} to ${tonode.name} :2min");
        // path.add("from ${fromnode.name} to ${tonode.name} :2min");
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
          var khat_intersect_old_to = old.khat.toList();
          khat_intersect_old_to
              .removeWhere((element) => !tonode.khat.contains(element));
          if (khat_intersect_old_to.isEmpty ||
              !fromnode.khat.contains(khat_intersect_old_to[0])) {
            //taviz khat
            var khat_intersect_old_from = old.khat.toList();
            khat_intersect_old_from
                .removeWhere((element) => !fromnode.khat.contains(element));
            var khat_intersect_from_to = fromnode.khat.toList();
            khat_intersect_from_to
                .removeWhere((element) => !tonode.khat.contains(element));
            // print(
            // "inside ${fromnode.name} taghir khat az khat_${khat_intersect_old_from[0]} be khat_${khat_intersect_from_to[0]} :10min");
            // path.add(
            // "inside ${fromnode.name} taghir khat az khat_${khat_intersect_old_from[0]} be khat_${khat_intersect_from_to[0]} :10min");
            khat = khat_intersect_from_to[0];
            int index1 = 0, index2 = 0;
            if (fromnode.khat[0] == khat_intersect_old_from[0]) {
              index1 = fromnode.index[0];
              index2 = fromnode.index[1];
            } else if (fromnode.khat[1] == khat_intersect_old_from[0]) {
              index1 = fromnode.index[1];
              index2 = fromnode.index[0];
            }

            path.add(Stepp(
                from: fromnode,
                to: fromnode,
                min: 10,
                tavizkhat: true,
                khat1: khat_intersect_old_from[0],
                khat2: khat_intersect_from_to[0],
                index1: index1,
                index2: index2));
            counter += 10;
          }
        } else {
          fromnode = tonode;
        }
      }
      // print("az istgah ${tonode.name} piade shavid! safar be salamat :12min");
      // path.add(
      //     "az istgah ${tonode.name} piade shavid! safar be salamat :12min");

      path.add(Stepp(from: null, to: tonode, min: 12, khat2: khat));
      // print(counter);
      path.insert(0, Stepp(from: null, to: null, min: counter));
      return path;
    });
  }
}
// void main(List<String> arguments) async {
//   // print('Hello world!');
//   // test();
//   Dijkstra dijkstra = Dijkstra();
//   // var istgah_mabda = stdin.readLineSync(encoding: utf8);
//   // var istgah_maghsad = stdin.readLineSync(encoding: utf8);
//   String istgah_mabda = "Daneshgah-e_Elm-o_San'at";
//   // istgah_mabda = "Tehranpars";
//   String istgah_maghsad = "Mahdiyeh";
//   // istgah_maghsad = "Daneshgah-e_Elm-o_San'at";
//   dijkstra.init().then((_) {
//     var res = dijkstra.GetPath(istgah_mabda, istgah_maghsad);
//     var path = res.second;
//     print(res.first + 29);
//     printRes(path);
//     // while (path.isNotEmpty) {
//     //   Node node = path.pop();
//     //   print(
//     //       "${node.name} khat ${node.khat[0]} ${(node.isTavizKhat ? node.khat[1] : '')}");
//     // }
//   });
// }

// void test() {
//   SplayTreeSet<Pair<int, String>> set = SplayTreeSet(
//     (key1, key2) => key1.first.compareTo(key2.first),
//   );
//   set.add(Pair(4, "avali"));
//   set.add(Pair(4, "dovomi"));
//   set.add(Pair(1, "sevomi"));
//   set.add(Pair(6, "chaharomi"));
//   set.add(Pair(3, "panjomi"));
//   set.add(Pair(4, "shishomi"));
//   for (var item in set.toList()) {
//     print("${item.first} ${item.second}");
//   }
// }

void printRes(Stack<Node> stack) {
  Node fromnode = stack.pop(), tonode = fromnode;
  print("Savar istgah ${fromnode.name} shavid :17min");
  int counter = 29;
  while (stack.isNotEmpty) {
    tonode = stack.pop();
    print("from ${fromnode.name} to ${tonode.name} :2min");
    counter += 2;
    // if (fromnode.khat[0] == tonode.khat[0])
    //   print("from ${fromnode.name} to ${tonode.name} :2min");
    // else {
    //   print("from ${fromnode.name} to ${tonode.name} :2min");
    //   print(
    //       "inside ${tonode.name} taghir khat az khat_${tonode.khat[0]} be khat_${tonode.khat[0]} :10min");
    // }

    if (tonode.isTavizKhat && stack.isNotEmpty) {
      Node old = fromnode;
      fromnode = tonode;
      tonode = stack.peek;
      var khat_intersect_old_to = old.khat.toList();
      khat_intersect_old_to
          .removeWhere((element) => !tonode.khat.contains(element));
      if (khat_intersect_old_to.isEmpty) {
        //taviz khat
        var khat_intersect_old_from = old.khat.toList();
        khat_intersect_old_from
            .removeWhere((element) => !fromnode.khat.contains(element));
        var khat_intersect_from_to = fromnode.khat.toList();
        khat_intersect_from_to
            .removeWhere((element) => !tonode.khat.contains(element));
        print(
            "inside ${fromnode.name} taghir khat az khat_${khat_intersect_old_from[0]} be khat_${khat_intersect_from_to[0]} :10min");
        counter += 10;
      }
    } else {
      fromnode = tonode;
    }
  }
  print("az istgah ${tonode.name} piade shavid! safar be salamat :12min");
  print(counter);
}
