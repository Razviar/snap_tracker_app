import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_storage/saf.dart';
import 'parsing_metadata_model.dart';

class LogParser {
  LogParser() : super();

  ParsingMetadata? parsingMetadata;
  Uri? selectedUriDir;
  String? marvelAccID;

  Future<DateTime?> runParser(bool firstRun) async {
    //print("starting parser!!!");
    final pref = await SharedPreferences.getInstance();

    String textualParsingMetadata = '';
    final response = await http.get(
        Uri.parse('https://marvelsnap.pro/snap/json/parsing_metadata.json'));
    if (response.statusCode != 200) {
      return null;
    }
    textualParsingMetadata = response.body;

    final scopeStoragePersistUrl = pref.getString('gameDataUri');
    if (scopeStoragePersistUrl == null) {
      return null;
    }
    final uriDir = Uri.parse(scopeStoragePersistUrl);
    final playerID = pref.getString('snapId');
    if (playerID == null) {
      return null;
    }

    selectedUriDir = uriDir;
    marvelAccID = playerID;
    parsingMetadata =
        ParsingMetadata.fromJson(jsonDecode(textualParsingMetadata));
    final parsedTill = await parserLoop(firstRun);
    return parsedTill;
  }

  void setUri(Uri uriToSet) {
    selectedUriDir = uriToSet;
  }

  Future<DateTime?> parserLoop(bool firstRun) async {
    //print("doing inner loop!");
    /*print(selectedUriDir);
    print(marvelAccID);*/
    if (parsingMetadata == null ||
        selectedUriDir == null ||
        marvelAccID == null) {
      return null;
    }
    final pref = await SharedPreferences.getInstance();
    Map<String, dynamic> parsedResults = {};
    Map<String, int> variables = {};

    final updateDatesTextual = pref.getString('updateDates');
    final updateDatesPreviousTextual = pref.getString('updateDatesPrevious');

    Map<String, String?> updateDates = {};

    if (updateDatesTextual != null) {
      updateDates = (json.decode(updateDatesTextual) as Map)
          .map((key, value) => MapEntry(key as String, value?.toString()));
    }

    Map<String, String?> updateDatesPrevious = {};

    DateTime? biggestDate;

    if (updateDatesPreviousTextual != null) {
      updateDatesPrevious = (json.decode(updateDatesPreviousTextual) as Map)
          .map((key, value) => MapEntry(key as String, value?.toString()));
    }

    for (var fileToParse in parsingMetadata!.FilesToParse) {
      //print(fileToParse);
      final existingFile = await findFile(selectedUriDir!, fileToParse);

      if (existingFile == null) {
        continue;
      }
      final lastModifiedDate = existingFile.lastModified;

      if (biggestDate == null ||
          (biggestDate.compareTo(lastModifiedDate!) < 0)) {
        biggestDate = lastModifiedDate;
      }

      //print(lastModifiedDate);
      bool needToParse = false;
      if (updateDates.containsKey(fileToParse) && lastModifiedDate != null) {
        if (DateTime.parse(updateDates[fileToParse]!)
                .compareTo(lastModifiedDate) <
            0) {
          needToParse = true;
          updateDatesPrevious[fileToParse] = updateDates[fileToParse];
          updateDates[fileToParse] = lastModifiedDate.toIso8601String();
        }
      } else {
        needToParse = true;
        updateDatesPrevious[fileToParse] = updateDates[fileToParse];
        updateDates[fileToParse] = lastModifiedDate!.toIso8601String();
      }

      //print(needToParse);
      if (!needToParse && !firstRun) {
        //print('nothing changed!');
        continue;
      }

      final contents = await existingFile.getContentAsString();
      //print(contents);
      if (contents == null) {
        continue;
      }

      final bracketOpen = contents.indexOf("{");
      dynamic data = await json.decode(contents.substring(bracketOpen));

      //-----------VARIABLES-------------
      //print('Variables');
      try {
        parsingMetadata!.Variables.forEach((VariableName, pathList) {
          if (pathList[0] != fileToParse) {
            return;
          }
          try {
            //print(VariableName);
            List<dynamic> interestingThing =
                (extractValue(data, pathList.sublist(1), null) as List)
                    .map((item) => item as dynamic)
                    .toList();
            //print(interestingThing);

            switch (VariableName) {
              case 'PLAYER_ID':
                int i = 0;
                for (var extractedElement in interestingThing) {
                  List<String> addedPath = [i.toString(), 'AccountId'];
                  //print([...pathList, ...addedPath]);
                  String? extractedAccountID = extractValue(
                      data, [...pathList.sublist(1), ...addedPath], null);

                  //print(extractedAccountID);
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
          } catch (e) {
            //print(e.toString());
          }
        });
      } catch (e) {
        //print(e.toString());
      }
      /*print('Variables!');
      print(variables);*/

      //-----------Direct extraction-------------
      //print('ExtractFromFiles');
      try {
        parsingMetadata!.ExtractFromFiles.forEach((dataObjectName, pathList) {
          if (pathList[0] != fileToParse) {
            return;
          }
          try {
            //print(dataObjectName);
            var interestingThing =
                extractValue(data, pathList.sublist(1), variables);
            parsedResults[dataObjectName] = interestingThing;
            //print(interestingThing);
          } catch (e) {
            //print(e.toString());
          }
        });
      } catch (e) {
        //print(e.toString());
      }

      //-----------Resolve Refs-------------
      //print('ResolveRefs');
      try {
        parsingMetadata!.ResolveRefs.forEach((dataObjectName, pathList) {
          if (pathList[0] != fileToParse) {
            return;
          }
          try {
            List<String> pathTointerestingThing = pathList.sublist(1);
            List<dynamic>? interestingThing =
                extractValue(data, pathList.sublist(1), variables);

            if (interestingThing != null) {
              for (int i = 0; i < interestingThing.length; i++) {
                Map<String, dynamic> ResolvedArrayElement = extractValue(
                    data, [...pathTointerestingThing, i.toString()], variables);
                parsedResults[dataObjectName] = ResolvedArrayElement;
              }
            }
          } catch (e) {
            //print(e.toString());
          }
          //print(interestingThing);
        });
      } catch (e) {
        //print(e.toString());
      }

      //-----------Gather From Array-------------
      //print('GatherFromArray');

      try {
        parsingMetadata!.GatherFromArray
            .forEach((dataObjectName, arrayParseInstructions) {
          //print(arrayParseInstructions);
          if (arrayParseInstructions['path']![0] != fileToParse) {
            return;
          }
          try {
            List<String> pathToInterestingArray =
                arrayParseInstructions['path']!.sublist(1);
            List<dynamic> interestingArray =
                extractValue(data, pathToInterestingArray, variables);
            List<String> attrsToGet =
                arrayParseInstructions['attrsToGet'] ?? [];
            //print(interestingArray);
            for (int i = 0; i < interestingArray.length; i++) {
              Map<String, dynamic> gatheredResult = {};
              Map<String, dynamic> ResolvedArrayElement = extractValue(
                  data, [...pathToInterestingArray, i.toString()], variables);
              //print(ResolvedArrayElement);
              for (var attrToGet in attrsToGet) {
                var extrectedArrayElement =
                    extractValue(ResolvedArrayElement, [attrToGet], variables);
                gatheredResult[attrToGet] = extrectedArrayElement;
              }
              if (gatheredResult.isNotEmpty) {
                if (parsedResults[dataObjectName] == null) {
                  parsedResults[dataObjectName] = [];
                }
                (parsedResults[dataObjectName] as List).add(gatheredResult);
              }
              /*print(dataObjectName);
          print(parsedResults[dataObjectName]);*/
            }
          } catch (e) {
            //print(e.toString());
          }
        });
      } catch (e) {
        //print(e.toString());
      }
      //print(contents);
    }

    /*print(updateDates);
    print(updateDatesPrevious);*/

    await pref.setString('updateDates', json.encode(updateDates));
    await pref.setString(
        'updateDatesPrevious', json.encode(updateDatesPrevious));
    await pref.setString(
        'biggestDate', DateFormat('yyyy-MM-dd kk:mm:ss').format(biggestDate!));

    //-----------Combo-------------
    //print('Combo');
    try {
      parsingMetadata!.ExtractFromFilesCombo
          .forEach((ComboDataPointName, ComboDataElementsList) {
        Map<String, dynamic> gatheredResult = {};
        try {
          ComboDataElementsList.sublist(1).forEach((DataToPutInCombo) {
            if (gatheredResult.isNotEmpty) {
              if (DataToPutInCombo == 'TheFileTimestamp' &&
                  updateDates[ComboDataElementsList[0]] != null) {
                gatheredResult[DataToPutInCombo] =
                    DateTime.parse(updateDates[ComboDataElementsList[0]]!)
                            .millisecondsSinceEpoch /
                        1000;
                return;
              }

              if (DataToPutInCombo == 'StartTimestamp' &&
                  updateDatesPrevious[ComboDataElementsList[0]] != null) {
                gatheredResult[DataToPutInCombo] = DateTime.parse(
                            updateDatesPrevious[ComboDataElementsList[0]]!)
                        .millisecondsSinceEpoch /
                    1000;
                return;
              }
            }

            if (parsedResults[DataToPutInCombo] != null) {
              gatheredResult[DataToPutInCombo] =
                  parsedResults[DataToPutInCombo];
            }

            if (variables[DataToPutInCombo] != null) {
              gatheredResult[DataToPutInCombo] = variables[DataToPutInCombo];
            }
          });
        } catch (e) {
          //print(e.toString());
        }
        if (gatheredResult.isNotEmpty) {
          parsedResults[ComboDataPointName] = gatheredResult;
        }
      });
    } catch (e) {
      //print(e.toString());
    }
    //print(parsedResults);

    //-----------Preparing Server Dispatch-------------
    List<Map<String, dynamic>> eventsToSend = [];

    for (var importantData in parsingMetadata!.sendToServer) {
      try {
        if (parsedResults[importantData] != null) {
          eventsToSend.add({
            "time": "0",
            "indicator": importantData,
            "json": jsonEncode(parsedResults[importantData]),
            "uid": marvelAccID
          });
        }
      } catch (e) {
        //print(e.toString());
      }
    }

    if (eventsToSend.isNotEmpty) {
      await UploadToServer(eventsToSend);
    }

    return biggestDate;
  }

  Future<void> UploadToServer(List<Map<String, dynamic>> eventsToSend) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;
    final response = await http.post(
      Uri.parse(
          'https://marvelsnap.pro/snap/donew2.php?cmd=cm_uploadpackfile&version=${version}m'),
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
            //print('doing replacement!');
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

      if (value is Map && value['\$ref'] != null) {
        value = getObject(data, '\$id', value['\$ref']);
      }
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
