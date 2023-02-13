class ParsingMetadata {
  final Map<String, dynamic> logSender;
  final Map<String, dynamic> logParser;
  final List<String> FilesToParse;
  final Map<String, List<String>> Variables;
  final Map<String, List<String>> ExtractFromFiles;
  final Map<String, List<String>> ResolveRefs;
  final Map<String, Map<String, List<String>>> GatherFromArray;
  final Map<String, List<String>> ExtractFromFilesCombo;
  final List<String> sendToServer;

  const ParsingMetadata({
    required this.logSender,
    required this.logParser,
    required this.FilesToParse,
    required this.Variables,
    required this.ExtractFromFiles,
    required this.ResolveRefs,
    required this.GatherFromArray,
    required this.ExtractFromFilesCombo,
    required this.sendToServer,
  });

  factory ParsingMetadata.fromJson(Map<String, dynamic> json) {
    return ParsingMetadata(
      logSender: json['logSender'],
      logParser: json['logParser'],
      FilesToParse:
          (json['FilesToParse'] as List).map((item) => item as String).toList(),
      Variables: (json['Variables'] as Map).map((key, value) => MapEntry(
          key as String,
          (value as List).map((item) => item as String).toList())),
      ExtractFromFiles: (json['ExtractFromFiles'] as Map).map((key, value) =>
          MapEntry(key as String,
              (value as List).map((item) => item as String).toList())),
      ResolveRefs: (json['ResolveRefs'] as Map).map((key, value) => MapEntry(
          key as String,
          (value as List).map((item) => item as String).toList())),
      GatherFromArray: (json['GatherFromArray'] as Map).map(
          (keyOuter, valueOuter) => MapEntry(
              keyOuter as String,
              (valueOuter as Map).map((keyInner, valueInner) => MapEntry(
                  keyInner,
                  (valueInner as List)
                      .map((item) => item.toString())
                      .toList())))),
      ExtractFromFilesCombo: (json['ExtractFromFilesCombo'] as Map).map(
          (key, value) => MapEntry(key as String,
              (value as List).map((item) => item as String).toList())),
      sendToServer:
          (json['sendToServer'] as List).map((item) => item as String).toList(),
    );
  }
}
