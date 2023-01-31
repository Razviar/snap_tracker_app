import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/saf.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'apiModels.dart';
import 'parser.dart';
import 'status.dart';
import 'trackerDrawer.dart';

void main() {
  runApp(const MyApp());
}

String generateRandomString(int len) {
  var r = Random();
  const chars =
      'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
  return List.generate(len, (index) => chars[r.nextInt(chars.length)]).join();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marvel Snap Tracker',
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
          primarySwatch: Colors.blueGrey,
          scaffoldBackgroundColor: const Color.fromARGB(255, 19, 23, 27),
          drawerTheme: const DrawerThemeData(
            backgroundColor: Color.fromARGB(255, 46, 54, 63),
          ),
          textTheme: const TextTheme(
              bodyMedium:
                  TextStyle(color: Color.fromARGB(255, 176, 186, 197)))),
      home: const MyHomePage(title: 'Marvel Snap Tracker'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

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
  @override
  void initState() {
    super.initState();
    _readJson(true);
  }

  String playerNick = "";
  String playerNickNoHash = "";
  String playerID = "";
  String playerUID = "";
  String playerProNick = "";
  String playerProToken = "";
  String syncButtonText = "Sync Account!";
  String parsedTill = "";
  String requestCode = "";
  bool isGameFolderLoaded = false;
  bool isLoggedIn = false;
  Timer? timer;

  Future<void> _readJson(bool initialTest) async {
    //final String pathToOpen = file.path ?? 'default';
    Uri? selectedUriDir;
    final pref = await SharedPreferences.getInstance();
    final scopeStoragePersistUrl = pref.getString('gameDataUri');

    final StoragePlayerUID = pref.getString('playerUID');
    final StoragePlayerProNick = pref.getString('playerProNick');
    final StoragePlayerProToken = pref.getString('playerProToken');

    if (StoragePlayerUID != null &&
        StoragePlayerProNick != null &&
        StoragePlayerProToken != null) {
      setState(() {
        playerUID = StoragePlayerUID;
        playerProNick = StoragePlayerProNick;
        playerProToken = StoragePlayerProToken;
        isLoggedIn = true;
      });
    }
    // Check User has already grant permission to any directory or not
    if (scopeStoragePersistUrl != null &&
        await isPersistedUri(Uri.parse(scopeStoragePersistUrl)) &&
        (await exists(Uri.parse(scopeStoragePersistUrl)) ?? false)) {
      selectedUriDir = Uri.parse(scopeStoragePersistUrl);
    } else if (!initialTest) {
      selectedUriDir = await openDocumentTree(
          grantWritePermission: false,
          initialUri: Uri.parse(
              "content://com.android.externalstorage.documents/tree/primary%3AAndroid%2Fdata%2Fcom.nvsgames.snap%2Ffiles%2FStandalone%2FStates%2Fnvprod"));
      await pref.setString('gameDataUri', selectedUriDir.toString());
    }

    if (selectedUriDir == null) {
      return;
    }

    final existingFile = await findFile(selectedUriDir, "ProfileState.json");

    if (existingFile == null) {
      return;
    }

    /*print(existingFile.uri);
    print(existingFile.type);
    print(existingFile.lastModified);*/
    final contents = await existingFile.getContentAsString();
    if (contents == null) {
      return;
    }
    final lastModifiedDate = existingFile.lastModified;
    final bracketOpen = contents.indexOf("{");
    Map<String, dynamic> data =
        await json.decode(contents.substring(bracketOpen));
    if (data.containsKey('ServerState')) {
      final snapNick = data['ServerState']['Account']['SnapId'];
      final snapId = data['ServerState']['Account']['Id'];

      await pref.setString('snapNick', snapNick);
      await pref.setString('snapId', snapId);

      setState(() {
        playerNick = snapNick ?? "";
        playerNickNoHash = snapNick.toString().split("#")[0];
        playerID = snapId ?? "";
        parsedTill = existingFile.lastModified != null
            ? DateFormat('yyyy-MM-dd kk:mm:ss')
                .format(lastModifiedDate ?? DateTime.now())
            : "";
        isGameFolderLoaded = true;
      });
      startTheParser(selectedUriDir);
    }
  }

  Future<void> _startSync() async {
    if (syncButtonText == "Sync Account!") {
      setState(() {
        syncButtonText = "Requesting...";
      });
      print(requestCode);
      final response = await http.post(
        Uri.parse('https://marvelsnap.pro/snap/do.php?cmd=mobilesync'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(
            <String, String>{'playerid': playerNick, 'plguid': playerID}),
      );
      if (response.statusCode == 200) {
        final responce = SyncResponce.fromJson(jsonDecode(response.body));
        final code = responce.request;
        setState(() {
          requestCode = code;
        });
        final uri = Uri.parse('https://marvelsnap.pro/sync/?request=$code');
        if (await canLaunchUrl(uri)) {
          setState(() {
            timer = Timer.periodic(const Duration(seconds: 3),
                (Timer t) => _checkForSyncComplete());
          });

          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch url';
        }
      }
    } else {
      final uri =
          Uri.parse('https://marvelsnap.pro/sync/?request=$requestCode');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch url';
      }
    }
  }

  Future<void> _checkForSyncComplete() async {
    final response = await http.post(
      Uri.parse('https://marvelsnap.pro/snap/do.php?cmd=mobiletokencheck'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'request': requestCode,
      }),
    );
    if (response.statusCode == 200) {
      final responseResult =
          CheckTokenResponce.fromJson(jsonDecode(response.body));
      if (responseResult.nick != '') {
        setState(() {
          playerUID = responseResult.uid;
          playerProNick = responseResult.nick;
          playerProToken = responseResult.token;
          isLoggedIn = true;
        });
        final pref = await SharedPreferences.getInstance();
        await pref.setString('playerUID', playerUID);
        await pref.setString('playerProNick', playerProNick);
        await pref.setString('playerProToken', playerProToken);

        final scopeStoragePersistUrl = pref.getString('gameDataUri');
        if (scopeStoragePersistUrl != null &&
            await isPersistedUri(Uri.parse(scopeStoragePersistUrl)) &&
            (await exists(Uri.parse(scopeStoragePersistUrl)) ?? false)) {
          startTheParser(Uri.parse(scopeStoragePersistUrl));
        }
      }
    }
  }

  void startTheParser(Uri selectedUriDir) {
    LogParser logParser = LogParser(selectedUriDir: selectedUriDir);
    logParser.startParser();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      drawer: TrackerDrawer(
        SnapID: playerNick,
        ProNick: playerProNick,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    playerNickNoHash != ''
                        ? "Hello, $playerNickNoHash!"
                        : playerProNick != ''
                            ? "Hello, $playerProNick!"
                            : "Hello, Fellow Snapper!",
                    textAlign: TextAlign.center,
                    textScaleFactor: 2,
                  ),
                )
              ],
            ),
            if (!isGameFolderLoaded) LocateSNAP(),
            if (isGameFolderLoaded && !isLoggedIn) SyncAccount(),
            if (isGameFolderLoaded && isLoggedIn)
              TrackerStatus(
                SnapID: playerNick,
                parsedTill: parsedTill,
                ProNick: playerProNick,
              ),
          ],
        ),
      ),
    );
  }

  Column SyncAccount() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            "Now let's sync account $playerNick we found with MarvelSnap.Pro account",
            textAlign: TextAlign.center,
          ),
        ),
        MaterialButton(
          onPressed: () {
            _startSync();
          },
          color: Colors.green,
          child: Text(
            syncButtonText,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Column LocateSNAP() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
              "First we need to get access to Marvel Snap Logs. To do it please locate Marvel Snap logs files and click Use This Folder button to let us track it."),
        ),
        MaterialButton(
          onPressed: () {
            //_pickFile();
            _readJson(false);
          },
          color: Colors.green,
          child: const Text(
            'Locate Game Data',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
