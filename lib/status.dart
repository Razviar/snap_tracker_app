import 'package:flutter/material.dart';

class TrackerStatus extends StatelessWidget {
  const TrackerStatus(
      {Key? key,
      required this.ProNick,
      required this.SnapID,
      required this.parsedTill,
      required this.isParserRunning})
      : super(key: key);

  final String ProNick;
  final String SnapID;
  final String parsedTill;
  final bool isParserRunning;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Pro Nickname: $ProNick",
            style: const TextStyle(fontSize: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Snap ID: $SnapID",
            style: const TextStyle(fontSize: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Parsed Till: $parsedTill",
            style: const TextStyle(
                fontSize: 18, color: Color.fromARGB(255, 57, 152, 61)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Parser Status: ${isParserRunning ? "Running" : "Paused"}",
            style: const TextStyle(
                fontSize: 18, color: Color.fromARGB(255, 57, 152, 61)),
          ),
        ),
      ],
    );
  }
}
