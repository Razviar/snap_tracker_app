import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:snap_tracker_app/parser.dart';

class MyTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  LogParser? _globalLogParser;
  bool _firstRun = true;
  int _runningWithNoChange = 0;
  DateTime? _prevDate;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    //print('TaskHandler -- onStart');
    _sendPort = sendPort;
    _globalLogParser = LogParser();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    //print('TaskHandler -- onEvent');
    try {
      final parsedTill = _firstRun
          ? await _globalLogParser?.runParser(true)
          : await _globalLogParser?.parserLoop(false);
      if (parsedTill != null) {
        if (_prevDate == parsedTill) {
          _runningWithNoChange += 4;
        } else {
          _runningWithNoChange = 0;
          _prevDate = parsedTill;

          final formattedDate =
              DateFormat('yyyy-MM-dd kk:mm:ss').format(parsedTill);
          FlutterForegroundTask.updateService(
            notificationTitle: 'Marvel Snap Tracker',
            notificationText:
                'Parsed till: $formattedDate. Tracker is running.',
          );
          sendPort?.send(formattedDate);
        }

        if (_runningWithNoChange >= 1200) {
          _runningWithNoChange = 0;
          await FlutterForegroundTask.stopService();
          sendPort?.send('game_not_running');
        }
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
