import 'package:flutter/material.dart';

class TrackerDrawer extends StatelessWidget {
  const TrackerDrawer({
    Key? key,
    required this.ProNick,
    required this.SnapID,
  }) : super(key: key);

  final String ProNick;
  final String SnapID;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(children: [
        DrawerHeader(
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 163, 93, 202),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Pro Nickname: $ProNick",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Snap ID: $SnapID",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          title: const Text(
            'Home',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            // Update the state of the app
            // ...
            // Then close the drawer
            Navigator.pop(context);
          },
        ),
        ListTile(
          title: const Text(
            'Settings',
            style: TextStyle(color: Colors.white),
          ),
          onTap: () {
            // Update the state of the app
            // ...
            // Then close the drawer
            Navigator.pop(context);
          },
        ),
      ]),
    );
  }
}
