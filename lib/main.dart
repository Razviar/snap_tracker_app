import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:appcheck/appcheck.dart';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_storage/saf.dart';
import 'package:http/http.dart' as http;
import 'package:snap_tracker_app/apiModels.dart';
import 'package:snap_tracker_app/notification_service.dart';
import 'package:snap_tracker_app/status.dart';
import 'package:snap_tracker_app/trackerDrawer.dart';
import 'package:snap_tracker_app/trackinghandler.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
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
    return WithForegroundTask(
        child: MaterialApp(
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
    ));
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
  State<MyHomePage> createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _readPlayerDataFromJson(true);
  }

  ReceivePort? _receivePort;
  String AppVersion = "";
  String playerNick = "";
  String playerNickNoHash = "";
  String playerID = "";
  String playerUID = "";
  String playerProNick = "";
  String playerProToken = "";
  String syncButtonText = "Sync Account!";
  String parsedTill = "";
  String requestCode = "";
  bool isGameInstalled = false;
  bool isGameFolderLoaded = false;
  bool isLoggedIn = false;
  bool isParserRunning = false;
  bool isBatteryOptimizationDisabled = false;
  Timer? timer;
  DateTime currentBackPressTime = DateTime.now();

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'snap-tracker-notification',
          channelName: 'Snap Tracker',
          channelDescription: 'Notifications from Snap Tracker',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          playSound: false,
          isSticky: true,
          iconData: const NotificationIconData(
              resType: ResourceType.drawable,
              resPrefix: ResourcePrefix.ic,
              name: "stat_logo_crop")),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 3000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  bool _registerReceivePort(ReceivePort? newReceivePort) {
    if (newReceivePort == null) {
      return false;
    }

    _closeReceivePort();

    _receivePort = newReceivePort;
    _receivePort?.listen((message) {
      _timeUpdateWork();
    });

    return _receivePort != null;
  }

  void _closeReceivePort() {
    _receivePort?.close();
    _receivePort = null;
  }

  Future<String> _getVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<void> _readPlayerDataFromJson(bool initialTest) async {
    final String ver = await _getVersion();
    setState(() {
      AppVersion = ver;
    });

    bool? isBatteryOptimizationDisabled =
        await DisableBatteryOptimization.isBatteryOptimizationDisabled;

    if (isBatteryOptimizationDisabled == true) {
      setState(() {
        isBatteryOptimizationDisabled = true;
      });
    }

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
    } else if (initialTest) {
      try {
        final exists = await AppCheck.isAppEnabled("com.nvsgames.snap");

        if (exists) {
          setState(() {
            isGameInstalled = true;
          });
        }
      } catch (ex) {
        setState(() {
          isGameInstalled = false;
        });
      }
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
        parsedTill = "...";
        isGameFolderLoaded = true;
      });

      final isAlreadyParsing = await FlutterForegroundTask.isRunningService;
      if (isAlreadyParsing) {
        setState(() {
          isParserRunning = true;
        });
      }
      _timeUpdateWork();
    }
  }

  Future<void> _startSync() async {
    if (syncButtonText == "Sync Account!") {
      setState(() {
        syncButtonText = "Requesting...";
      });
      //print(requestCode);
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
        if (timer != null) {
          timer?.cancel();
          setState(() {
            timer = null;
          });
        }
      }
    }
  }

  Future<void> _startTheParserGlobally() async {
    await NotificationService().prepareNotifications();
    //print('starting parser globally!');
    setState(() {
      parsedTill = "Launching tracker...";
      isParserRunning = true;
    });

    final ReceivePort? receivePort = FlutterForegroundTask.receivePort;
    final bool isRegistered = _registerReceivePort(receivePort);
    if (!isRegistered) {
      //print('Failed to register receivePort!');
      return;
    }

    //print(isRegistered);

    if (await FlutterForegroundTask.isRunningService) {
      //print('is running');
      return;
    } else {
      //print('starting service!');
      final test = await FlutterForegroundTask.startService(
        notificationTitle: 'Marvel Snap Tracker',
        notificationText: 'Tracker is running.',
        callback: startCallback,
      );
      //print(test);
      return;
    }

    //Timer.periodic(const Duration(seconds: 10), _timerWork);
  }

  Future<void> _timeUpdateWork() async {
    //print('updateCheck!');
    final pref = await SharedPreferences.getInstance();
    pref.reload();
    String? biggestDate = pref.getString('biggestDate');
    //print(biggestDate);
    if (biggestDate != parsedTill && biggestDate != null) {
      setState(() {
        parsedTill = biggestDate;
      });
      //print(biggestDate);
    }
  }

  Future<void> _stopTheParserGlobally() async {
    //print('stopping parser globally!');
    await FlutterForegroundTask.stopService();
    setState(() {
      isParserRunning = false;
    });
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
      drawer: isGameFolderLoaded && isLoggedIn
          ? TrackerDrawer(
              SnapID: playerNick,
              ProNick: playerProNick,
              version: AppVersion,
            )
          : null,
      body: WillPopScope(onWillPop: onWillPop, child: bodyGenerator()),
    );
  }

  Center bodyGenerator() {
    return Center(
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
            Column(children: [
              TrackerStatus(
                  SnapID: playerNick,
                  parsedTill: parsedTill,
                  ProNick: playerProNick,
                  isParserRunning: isParserRunning),
              MaterialButton(
                onPressed: () {
                  //_pickFile();
                  if (isParserRunning) {
                    _stopTheParserGlobally();
                  } else {
                    _startTheParserGlobally();
                  }
                },
                color: isParserRunning
                    ? Colors.red
                    : const Color.fromARGB(255, 163, 93, 202),
                child: SizedBox(
                  width: 200,
                  child: Center(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: isParserRunning
                              ? const Icon(
                                  Icons.stop,
                                  color: Colors.white,
                                )
                              : const Icon(Icons.play_arrow,
                                  color: Colors.white),
                        ),
                        Text(
                          isParserRunning ? 'Stop Tracker' : 'Start Tracker',
                          style: const TextStyle(color: Colors.white),
                        )
                      ])),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Column(
                  children: isBatteryOptimizationDisabled
                      ? []
                      : [
                          const Text('Troubleshooting'),
                          MaterialButton(
                              color: Colors.blueGrey,
                              onPressed: () {
                                DisableBatteryOptimization
                                    .showDisableBatteryOptimizationSettings();
                                setState(() {
                                  isBatteryOptimizationDisabled = true;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Disable Battery Saving",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ))
                        ],
                ),
              )
            ])
        ],
      ),
    );
  }

  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (now.difference(currentBackPressTime) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      Fluttertoast.showToast(msg: "Swipe Back again to exit");
      return Future.value(false);
    }
    return Future.value(true);
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
          color: const Color.fromARGB(255, 163, 93, 202),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Image(width: 130, image: AssetImage('images/Screenshot_1.jpg')),
            Image(width: 130, image: AssetImage('images/Screenshot_2.jpg')),
          ],
        ),
        Padding(
            padding: const EdgeInsets.all(20),
            child: RichText(
                text: const TextSpan(
              style: TextStyle(
                fontSize: 14.0,
              ),
              children: <TextSpan>[
                TextSpan(
                    text:
                        "First we need to get access to Marvel Snap Logs. To do it please click <Locate Game Data> button, make sure you see "),
                TextSpan(
                    text: '"nvprod" folder',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: " and click "),
                TextSpan(
                    text: '<Use This Folder>',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                    text:
                        " button below the explorer to let us track it. When you click the button <Locate Game Data>, nvprod will be opened by default, so in the most cases all you need to do is click <Use This Folder> at the bottom of the screen."),
              ],
            ))),
        isGameInstalled
            ? MaterialButton(
                onPressed: () {
                  //_pickFile();
                  _readPlayerDataFromJson(false);
                },
                color: const Color.fromARGB(255, 163, 93, 202),
                child: const Text(
                  'Locate Game Data',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(20),
                child: RichText(
                    text: const TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                        text:
                            "It looks like you don't have Marvel Snap installed or never run it on this device.",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text:
                            " This app is useful only if you have Marvel Snap installed on your phone. Please install the game, run it at least once and restart the tracker."),
                  ],
                )),
              ),
      ],
    );
  }
}

@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}
