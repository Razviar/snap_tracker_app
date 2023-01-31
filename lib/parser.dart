import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_storage/saf.dart';
import 'parsing_metadata_model.dart';

class LogParser {
  LogParser({
    required this.selectedUriDir,
  }) : super();

  ParsingMetadata? parsingMetadata;
  Uri selectedUriDir;
  Map<String, DateTime?> updateDates = {};

  Future<void> startParser() async {
    print("strating parser!");
    final response = await http.get(
        Uri.parse('https://marvelsnap.pro/snap/json/parsing_metadata.json'));
    if (response.statusCode == 200) {
      parsingMetadata = ParsingMetadata.fromJson(jsonDecode(response.body));
      _ParserLoop();
    }
  }

  void setUri(Uri uriToSet) {
    selectedUriDir = uriToSet;
  }

  Future<void> _ParserLoop() async {
    if (parsingMetadata == null) {
      return;
    }
    for (var fileToParse in parsingMetadata!.FilesToParse) {
      print(fileToParse);
      final existingFile = await findFile(selectedUriDir, fileToParse);

      if (existingFile == null) {
        continue;
      }

      final contents = await existingFile.getContentAsString();
      if (contents == null) {
        continue;
      }
      final lastModifiedDate = existingFile.lastModified;
      final bracketOpen = contents.indexOf("{");
      Map<String, dynamic> data =
          await json.decode(contents.substring(bracketOpen));
      print(contents);
    }
  }
}
