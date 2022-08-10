import 'dart:io';

import 'package:flutter/material.dart';
import 'package:masiryab_metro/IstgahReader.dart';
import 'package:masiryab_metro/masiryab.dart';
import 'package:masiryab_metro/widget/AutoComplete.dart';

import 'pair.dart';

void main() {
  // IstgahReader istgahReader = IstgahReader();
  // istgahReader.ReadFile();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Metrun',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.orange,
      ),
      home: const MyHomePage(title: 'Metro Tehran Navigator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool selected1 = false, selected2 = false;
  Set<String> _options = Set();
  List<Pair<String, String>> _firstLastIstgah = [];
  TextEditingController mabda = TextEditingController();
  TextEditingController maghsad = TextEditingController();
  late Future<List<Stepp>> _path;
  bool _gotdata = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _path = emptylist();
    getOptions();
  }

  Future<List<Stepp>> emptylist() async {
    return [];
  }

  void getOptions() async {
    IstgahReader istgahReader = IstgahReader();
    await istgahReader.ReadStates().then((value) {
      setState(() {
        _options = value.first;
        _firstLastIstgah = value.second;
      });
    });
  }

  void assign1(TextEditingController textEditingController) {
    mabda = textEditingController;
  }

  void assign2(TextEditingController textEditingController) {
    maghsad = textEditingController;
  }

  void Select1() async {
    setState(() {
      selected1 = true;
      print("1 selected");
    });
    await GetPath();
  }

  void Select2() async {
    setState(() {
      selected2 = true;
      print("2 selected");
    });
    await GetPath();
  }

  Future GetPath() async {
    if (!selected1 || !selected2) return;
    if (mabda.text.isEmpty || maghsad.text.isEmpty) return;
    if (!_options.contains(mabda.text)) return;
    if (!_options.contains(maghsad.text)) return;
    if (mabda.text == maghsad.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("funny"),
      ));
      return;
    }
    setState(() {
      _path = Masiryab().GetPath(mabda.text, maghsad.text);
      _gotdata = true;
    });
  }

  Color getColorByKhat(int khat) {
    switch (khat) {
      case 1:
        return Color(0xffef2e25);
      case 2:
        return Color(0xff04509f);
      case 3:
        return Color(0xff18C0F5);
      case 4:
        return Color(0xffFAD103);
      case 5:
        return Color(0xff06885c);
      case 6:
        return Color(0xfff670ab);
      case 7:
        return Color(0xff85317a);
      default:
        return Color.fromARGB(0, 255, 255, 255);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.orange.shade600,
        actions: [
          IconButton(
            onPressed: () {
              var photourl = "assets/images/metro_map.jpg";
              // photourl ="https://quera.org/qbox/view/dRHVhlpuiG/metro_map.jpg";
              // Image.file(File(photourl));
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: true,
                  barrierDismissible: false,
                  pageBuilder: (BuildContext context, _, __) {
                    return Scaffold(
                      body: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.cancel_sharp)),
                            ),
                            Expanded(
                              child: InteractiveViewer(
                                scaleEnabled: true,
                                panEnabled: true,
                                child: Hero(
                                  tag: photourl,
                                  child: Center(child: Image.asset(photourl)

                                      // CachedNetworkImage(
                                      //   imageUrl: photourl,
                                      //   placeholder: (context, url) =>
                                      //       const CupertinoActivityIndicator(),
                                      // ),
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            icon: Icon(
              Icons.map,
              color: Colors.white,
            ),
            tooltip: "نقشه مترو",
            // tooltip: "نقشه مترو",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              AutocompleteBasic(
                  options: _options,
                  assign: assign1,
                  lable: "مبدا",
                  select: Select1),
              AutocompleteBasic(
                  options: _options,
                  assign: assign2,
                  lable: "مقصد",
                  select: Select2),
              SizedBox(
                height: 20,
              ),
              Center(
                child: Column(
                  children: [
                    FutureBuilder<List<Stepp>>(
                        future: _path,
                        builder: (BuildContext context,
                            AsyncSnapshot<List<Stepp>> snapshot) {
                          if (!snapshot.hasData || !_gotdata) {
                            return SizedBox.shrink();
                            // return CircularProgressIndicator(
                            //   value: 0.8,
                            // );
                            //Center(child: Text('Loading...'));
                          }
                          if (snapshot.data!.isEmpty) return Container();
                          final step = snapshot.data![0];
                          int min = step.min % 60;
                          int hour = step.min ~/ 60;
                          List<int> khats = snapshot.data!
                              .sublist(1)
                              .map((e) => e.khat2!)
                              .toList();
                          String text = "مدت سفر: ${min} دقیقه";
                          if (hour > 0) {
                            text = "مدت سفر: ${hour} ساعت و  ${min} دقیقه";
                          }
                          return Center(
                            child: Card(
                              elevation: 10,
                              child: Container(
                                // margin: ,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 10),
                                decoration: BoxDecoration(
                                  // shape: BoxShape.,

                                  borderRadius: BorderRadius.circular(5),
                                  // border: BoxBorder(),

                                  // color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.transparent,
                                        spreadRadius: 3),
                                  ],
                                  // shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: khats
                                        .map((e) => getColorByKhat(e))
                                        .toList(),
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    // stops: [
                                    //   0.0,
                                    //   1.0
                                    // ],
                                    // tileMode: TileMode.clamp
                                  ),
                                ),
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                    FutureBuilder<List<Stepp>>(
                        future: _path,
                        builder: (BuildContext context,
                            AsyncSnapshot<List<Stepp>> snapshot) {
                          if (!snapshot.hasData || !_gotdata) {
                            return SizedBox.shrink();
                            // return CircularProgressIndicator(
                            //   value: 0.8,
                            // );
                            //Center(child: Text('Loading...'));
                          }
                          return snapshot.data!.isEmpty
                              ? Center(child: Text(''))
                              : SingleChildScrollView(
                                  child: Container(
                                    height: 480,
                                    child: ListView.builder(
                                      itemCount: snapshot.data!.length,
                                      itemBuilder: (context, index) {
                                        final step = snapshot.data![index];
                                        if (index == 0) {
                                          return Container();
                                        }
                                        var text = "";

                                        if (step.to == null) {
                                          final nextStep =
                                              snapshot.data![index + 1];
                                          int nextindex = nextStep.tavizkhat
                                              ? nextStep.index1!
                                              : nextStep.index2!;
                                          int diff = nextindex - step.index2!;
                                          String samt = "";
                                          if (diff > 0) {
                                            samt = _firstLastIstgah[
                                                    step.khat2! - 1]
                                                .second;
                                          } else {
                                            samt = _firstLastIstgah[
                                                    step.khat2! - 1]
                                                .first;
                                          }
                                          text =
                                              "سوار مترو ایستگاه ${step.from!.name} شوید. (به سمت ${samt})";
                                        } else if (step.from == null) {
                                          text =
                                              "از مترو ایستگاه ${step.to!.name} پیاده شوید!";
                                        } else if (step.tavizkhat) {
                                          final nextStep =
                                              snapshot.data![index + 1];
                                          int nextindex = nextStep.tavizkhat
                                              ? nextStep.index1!
                                              : nextStep.index2!;
                                          int diff = nextindex - step.index2!;
                                          String samt = "";
                                          if (diff > 0) {
                                            samt = _firstLastIstgah[
                                                    step.khat2! - 1]
                                                .second;
                                          } else {
                                            samt = _firstLastIstgah[
                                                    step.khat2! - 1]
                                                .first;
                                          }
                                          text =
                                              "در ایستگاه ${step.from!.name}  از خط ${step.khat1} به ${step.khat2} تعویض خط انجام دهید. (به سمت ${samt})";
                                        } else {
                                          // text =
                                          //     "${step.from!.name} => ${step.to!.name}";
                                          text =
                                              "${step.from!.name} ← ${step.to!.name}";
                                        }
                                        return Center(
                                          child: Card(
                                            elevation: 6,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 1),
                                              child: Directionality(
                                                textDirection:
                                                    TextDirection.rtl,
                                                child: ListTile(
                                                  leading: !step.tavizkhat
                                                      ? CircleAvatar(
                                                          backgroundColor:
                                                              getColorByKhat(
                                                                  step.khat2!),
                                                          child: Text(
                                                              step.min
                                                                  .toString(),
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white)),
                                                        )
                                                      : Container(
                                                          decoration:
                                                              BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            gradient:
                                                                LinearGradient(
                                                              colors: [
                                                                getColorByKhat(
                                                                    step.khat1!),
                                                                getColorByKhat(
                                                                    step.khat1!),
                                                                getColorByKhat(
                                                                    step.khat2!),
                                                              ],
                                                              begin: Alignment
                                                                  .centerRight,
                                                              end: Alignment
                                                                  .centerLeft,
                                                              stops: [
                                                                0.0,
                                                                0.5,
                                                                0.5
                                                              ],
                                                              // tileMode:
                                                              //     TileMode
                                                              //         .clamp
                                                            ),
                                                          ),
                                                          child: CircleAvatar(
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            //     getColorByKhat(
                                                            //         step.khat2!),
                                                            child: Text(
                                                                step.min
                                                                    .toString(),
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .white)),
                                                          ),
                                                        ),
                                                  // trailing: IconButton(
                                                  //   icon: Icon(
                                                  //     Icons.delete,
                                                  //   ),
                                                  //   color: Colors.red,
                                                  //   onPressed: () {},
                                                  // ),
                                                  // CircleAvatar(
                                                  //   backgroundImage: Image.asset(
                                                  //       "assets/images/avatar.png"),
                                                  // ),
                                                  title: Text(text),
                                                  // subtitle: Text(student.stdno),
                                                  // onTap: () {
                                                  // setState(() {
                                                  //   if (selectedId == null) {
                                                  //     textController.text = student.name;
                                                  //     selectedId = student.id;
                                                  //   } else {
                                                  //     textController.text = '';
                                                  //     selectedId = null;
                                                  //   }
                                                  // });
                                                  // },
                                                  // onLongPress: () {
                                                  // setState(() {
                                                  // DatabaseHelper.instance
                                                  //     .remove(student.id!);
                                                  // });
                                                  // },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                        }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
