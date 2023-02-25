import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_review/launch_review.dart';
import 'package:snap_tracker_app/stardisplay.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewStore {
  static final LocalStorage _localStorage = LocalStorage('review.txt');
  static int _reviewTime;
  static int _reviewRating;
  static const int _waitBeforeShow = 24 * 60 * 60 * 1000; // 24 hours

  static Future init() async {
    String raw = await _localStorage.read();
    try {
      List<String> splits = raw.split(':');
      _reviewTime = int.parse(splits[0]);
      _reviewRating = int.parse(splits[1]);
    } catch (_) {
      await save(-1);
    }
  }

  static Future save(int rating) async {
    _reviewTime = DateTime.now().millisecondsSinceEpoch;
    _reviewRating = rating;
    await _localStorage.write("$_reviewTime:$_reviewRating");
  }

  static bool shouldShow() {
    if (Platform.isIOS) {
      return false;
    }
    return _reviewRating == -1 &&
        DateTime.now().millisecondsSinceEpoch > _reviewTime + _waitBeforeShow;
  }

  static void show(BuildContext context) async {
    int currentRating = 5;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: BetterStatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'Help us make the app better and share your impression'),
                  Container(height: 20),
                  IconTheme(
                    data: const IconThemeData(
                      color: Colors.amber,
                      size: 46,
                    ),
                    child: StarDisplay(
                      value: currentRating,
                      onTap: (rating) {
                        setState(() {
                          currentRating = rating;
                        });
                      },
                    ),
                  ),
                  Visibility(
                    visible: currentRating < 4,
                    child: Column(
                      children: [
                        Container(height: 20),
                        const Text(
                            'We are improving our app all the time, write us a few words by submitting this form'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL'),
              onPressed: () async {
                await save(0);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('SUBMIT'),
              onPressed: () async {
                await save(currentRating);
                if (currentRating >= 4) {
                  LaunchReview.launch(
                    androidAppId: 'com.mtgarenapro.snap_tracker_app',
                  );
                } else {
                  launch(
                      'mailto:admin@marvelsnap.pro?subject=Mobile%20App%20Review');
                }
              },
            ),
          ],
        );
      },
    );
  }
}
