import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TrackerDrawer extends StatelessWidget {
  const TrackerDrawer({
    Key? key,
    required this.ProNick,
    required this.SnapID,
    required this.version,
  }) : super(key: key);

  final String ProNick;
  final String SnapID;
  final String version;

  Future<void> _goToUrl(String url) async {
    final uri = Uri.parse('https://marvelsnap.pro/$url');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch url';
      }
    } catch (ex) {}
  }

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
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Tracker Version: $version",
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        ListTile(
          title: const LinkElement(Title: "Home"),
          onTap: () {
            _goToUrl("u/");
          },
        ),
        ListTile(
          title: const LinkElement(Title: "Matches"),
          onTap: () {
            _goToUrl("matches/");
          },
        ),
        ListTile(
          title: const LinkElement(Title: "Progress"),
          onTap: () {
            _goToUrl("progress/");
          },
        ),
        ListTile(
          title: const LinkElement(Title: "Collection"),
          onTap: () {
            _goToUrl("collection/");
          },
        ),
        ListTile(
          title: const LinkElement(Title: "Decks"),
          onTap: () {
            _goToUrl("decks/");
          },
        ),
        ListTile(
          title: const LinkElement(Title: "Battles"),
          onTap: () {
            _goToUrl("battles/");
          },
        ),
      ]),
    );
  }
}

class LinkElement extends StatelessWidget {
  const LinkElement({
    super.key,
    required this.Title,
  });

  final String Title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: Icon(Icons.link, color: Colors.white),
        ),
        Text(
          Title,
          style: const TextStyle(color: Colors.white),
        )
      ]),
    );
  }
}
