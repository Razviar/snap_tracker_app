import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:snap_tracker_app/parser.dart';

class MyTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  LogParser? _globalLogParser;
  bool _firstRun = true;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    //print('TaskHandler -- onStart');
    _sendPort = sendPort;
    _globalLogParser = LogParser();
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    //print('TaskHandler -- onEvent');
    try {
      final parsedTillString = _firstRun
          ? await _globalLogParser?.runParser(true)
          : await _globalLogParser?.parserLoop(false);
      if (parsedTillString != null) {
        final formattedDate =
            DateFormat('yyyy-MM-dd kk:mm:ss').format(parsedTillString);
        FlutterForegroundTask.updateService(
          notificationTitle: 'Marvel Snap Tracker',
          notificationText: 'Parsed till: $formattedDate. Tracker is running.',
        );
        sendPort?.send(formattedDate);
      }
    } catch (ex) {
      print(ex.toString());
    }
    _firstRun = false;
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    // You can use the clearAllData function to clear all the stored data.
    await FlutterForegroundTask.clearAllData();
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
    _sendPort?.send('ping');
  }
}
