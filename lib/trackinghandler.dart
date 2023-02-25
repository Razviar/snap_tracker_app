import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:snap_tracker_app/parser.dart';

class MyTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  LogParser? _globalLogParser;
  int _eventCount = 0;

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
      final parsedTillString =
          await _globalLogParser?.runParser(_eventCount == 0);
      if (parsedTillString != null) {
        final formattedDate =
            DateFormat('yyyy-MM-dd kk:mm:ss').format(parsedTillString);
        FlutterForegroundTask.updateService(
          notificationTitle: 'Marvel Snap Tracker',
          notificationText: 'Tracker is running. Parsed till: $formattedDate',
        );
      }
    } catch (ex) {
      print(ex.toString());
    }

    // Send data to the main isolate.
    sendPort?.send('ping');

    _eventCount++;
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
