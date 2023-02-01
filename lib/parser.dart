import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_storage/saf.dart';
import 'parsing_metadata_model.dart';

class LogParser {
  LogParser({required this.selectedUriDir, required this.marvelAccID})
      : super();

  ParsingMetadata? parsingMetadata;
  Uri selectedUriDir;
  String marvelAccID;
  Map<String, DateTime?> updateDates = {};
  Map<String, DateTime?> updateDatesPrevious = {};

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

    Map<String, dynamic> parsedResults = {};
    Map<String, int> variables = {};

    for (var fileToParse in parsingMetadata!.FilesToParse) {
      print(fileToParse);
      final existingFile = await findFile(selectedUriDir, fileToParse);

      if (existingFile == null) {
        continue;
      }
      final lastModifiedDate = existingFile.lastModified;
      bool needToParse = false;
      if (updateDates.containsKey(fileToParse) && lastModifiedDate != null) {
        if (updateDates[fileToParse]!.compareTo(lastModifiedDate) < 0) {
          needToParse = true;
          updateDatesPrevious[fileToParse] = updateDates[fileToParse];
          updateDates[fileToParse] = lastModifiedDate;
        }
      } else {
        needToParse = true;
        updateDatesPrevious[fileToParse] = updateDates[fileToParse];
        updateDates[fileToParse] = lastModifiedDate;
      }

      if (!needToParse) {
        continue;
      }

      final contents = await existingFile.getContentAsString();

      if (contents == null) {
        continue;
      }

      final bracketOpen = contents.indexOf("{");
      dynamic data = await json.decode(contents.substring(bracketOpen));

      //-----------VARIABLES-------------
      parsingMetadata!.Variables.forEach((VariableName, pathList) {
        if (pathList[0] != fileToParse) {
          return;
        }
        print(VariableName);
        List<dynamic> interestingThing =
            (extractValue(data, pathList.sublist(1), null) as List)
                .map((item) => item as dynamic)
                .toList();
        print(interestingThing);

        switch (VariableName) {
          case 'PLAYER_ID':
            int i = 0;
            for (var extractedElement in interestingThing) {
              List<String> addedPath = [i.toString(), 'AccountId'];
              print([...pathList, ...addedPath]);
              String? extractedAccountID = extractValue(
                  data, [...pathList.sublist(1), ...addedPath], null);

              print(extractedAccountID);
              if (extractedAccountID != null &&
                  extractedAccountID == marvelAccID) {
                variables[VariableName] = i;
                variables['OPPONENT_ID'] = i == 0 ? 1 : 0;
                variables['PLAYER_NUM'] = i == 0 ? 1 : 2;
                variables['OPPONENT_NUM'] = i == 0 ? 2 : 1;
              }
              i++;
            }
            break;
        }
      });
      /*print('Variables!');
      print(variables);*/

      //-----------Direct extraction-------------
      parsingMetadata!.ExtractFromFiles.forEach((dataObjectName, pathList) {
        if (pathList[0] != fileToParse) {
          return;
        }
        //print(dataObjectName);
        var interestingThing =
            extractValue(data, pathList.sublist(1), variables);
        parsedResults[dataObjectName] = interestingThing;
        //print(interestingThing);
      });

      //-----------Gather From Array-------------
      parsingMetadata!.GatherFromArray
          .forEach((dataObjectName, arrayParseInstructions) {
        if (arrayParseInstructions['path']![0] != fileToParse) {
          return;
        }

        List<String> pathToInterestingArray =
            arrayParseInstructions['path']!.sublist(1);
        List<dynamic> interestingArray =
            extractValue(data, pathToInterestingArray, variables);
        List<String> attrsToGet = arrayParseInstructions['attrsToGet'] ?? [];
        //print(interestingArray);
        for (int i = 0; i < interestingArray.length; i++) {
          Map<String, dynamic> gatheredResult = {};
          List<String> IndexAddition = [i.toString()];
          Map<String, dynamic> ResolvedArrayElement = extractValue(
              data, [...pathToInterestingArray, ...IndexAddition], variables);
          //print(ResolvedArrayElement);
          for (var attrToGet in attrsToGet) {
            var extrectedArrayElement =
                extractValue(ResolvedArrayElement, [attrToGet], variables);
            gatheredResult[attrToGet] = extrectedArrayElement;
          }

          parsedResults[dataObjectName] = gatheredResult;
          /*print(dataObjectName);
          print(parsedResults[dataObjectName]);*/
        }
      });
      //print(contents);
    }

    //-----------Combo-------------
    parsingMetadata!.ExtractFromFilesCombo
        .forEach((ComboDataPointName, ComboDataElementsList) {
      Map<String, dynamic> gatheredResult = {};

      ComboDataElementsList.sublist(1).forEach((DataToPutInCombo) {
        if (DataToPutInCombo == 'TheFileTimestamp' &&
            updateDates[ComboDataElementsList[0]] != null) {
          gatheredResult[DataToPutInCombo] =
              updateDates[ComboDataElementsList[0]]!.millisecondsSinceEpoch /
                  1000;
          return;
        }

        if (DataToPutInCombo == 'StartTimestamp' &&
            updateDatesPrevious[ComboDataElementsList[0]] != null) {
          gatheredResult[DataToPutInCombo] =
              updateDatesPrevious[ComboDataElementsList[0]]!
                      .millisecondsSinceEpoch /
                  1000;
          return;
        }

        if (parsedResults[DataToPutInCombo] != null) {
          gatheredResult[DataToPutInCombo] = parsedResults[DataToPutInCombo];
        }

        if (variables[DataToPutInCombo] != null) {
          gatheredResult[DataToPutInCombo] = variables[DataToPutInCombo];
        }
      });

      parsedResults[ComboDataPointName] = gatheredResult;
    });

    //print(parsedResults);

    //-----------Preparing Server Dispatch-------------
    List<Map<String, dynamic>> eventsToSend = [];

    for (var importantData in parsingMetadata!.sendToServer) {
      eventsToSend.add({
        "time": "0",
        "indicator": importantData,
        "json": jsonEncode(parsedResults[importantData]),
        "uid": marvelAccID
      });
    }

    UploadToServer(eventsToSend);
    /*print(eventsToSend);
    print(base64Json);
    print(updateDates);*/
  }

  Future<void> UploadToServer(List<Map<String, dynamic>> eventsToSend) async {
    final response = await http.post(
      Uri.parse(
          'https://marvelsnap.pro/snap/donew2.php?cmd=cm_uploadpackfile&version=3.0.1m'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: base64.encode(gzip.encode(utf8.encode(jsonEncode(eventsToSend)))),
    );
  }

  dynamic extractValue(
      dynamic data, List<String> attributesPath, Map<String, int>? variables) {
    dynamic value = data;
    for (String attribute in attributesPath) {
      //print(attribute);
      if (value is Map && value['\$ref'] != null) {
        value = getObject(data, '\$id', value['\$ref']);
      }

      bool replacementDone = false;
      if (variables != null) {
        variables.forEach((variable, replacement) {
          if (attribute.toString().contains(variable) &&
              attribute.toString() != variable) {
            print('doing replacement!');
            replacementDone = true;
            String attributeWithReplacement = attribute
                .toString()
                .replaceAll(variable, replacement.toString());
            if (value is List) {
              value = value[int.tryParse(attributeWithReplacement) ?? 0];
            } else if (value is Map) {
              value = value[attributeWithReplacement];
            }
          }
        });
      }

      if (!replacementDone) {
        if (value is Map) {
          if (variables != null && variables[attribute] != null) {
            value = value[variables[attribute]];
          } else {
            value = value[attribute];
          }
        } else if (value is List) {
          if (variables != null && variables[attribute] != null) {
            value = value[variables[attribute]];
          } else if (_isNumeric(attribute)) {
            value = value[int.tryParse(attribute) ?? 0];
          } else {
            value = null;
            break;
          }
        } else {
          value = null;
          break;
        }
      }

      /*if (value[_isNumeric(attribute) ? int.tryParse(attribute) : attribute] !=
          null) {
        value =
            value[_isNumeric(attribute) ? int.tryParse(attribute) : attribute];
      } else {
        value = null;
        break;
      }*/

      if (value is Map && value['\$ref'] != null) {
        value = getObject(data, '\$id', value['\$ref']);
      }
      //print(value);
    }

    return value;
  }

  bool _isNumeric(String? str) {
    if (str == null) {
      return false;
    }
    return int.tryParse(str) != null;
  }

  dynamic getObject(dynamic o, String prop, String val) {
    if (o == null) return null;
    if (o is List && o.isEmpty) return null;
    if (o is Map && o.isEmpty) return null;

    if (o is Map && o[_isNumeric(prop) ? int.tryParse(prop) : prop] == val) {
      return o;
    }
    dynamic result;
    if (o is List) {
      for (var i = 0; i < o.length; i++) {
        result = getObject(o[i], prop, val);
        if (result != null) {
          return result;
        }
      }
    } else if (o is Map) {
      for (var p in o.keys) {
        if (p == prop) {
          if (o[_isNumeric(p) ? int.tryParse(p) : p] == val) {
            return o;
          }
        }
        if (o[_isNumeric(p) ? int.tryParse(p) : p] is List ||
            o[_isNumeric(p) ? int.tryParse(p) : p] is Map) {
          result = getObject(o[_isNumeric(p) ? int.tryParse(p) : p], prop, val);
          if (result != null) {
            return result;
          }
        }
      }
    }
  }
}
