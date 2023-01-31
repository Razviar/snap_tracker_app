class SyncResponce {
  final String mode;
  final String request;

  const SyncResponce({
    required this.mode,
    required this.request,
  });

  factory SyncResponce.fromJson(Map<String, dynamic> json) {
    return SyncResponce(
      mode: json['mode'],
      request: json['request'],
    );
  }
}

class CheckTokenResponce {
  final String uid;
  final String token;
  final String nick;

  const CheckTokenResponce({
    required this.uid,
    required this.token,
    required this.nick,
  });

  factory CheckTokenResponce.fromJson(Map<String, dynamic> json) {
    return CheckTokenResponce(
      uid: json['uid'],
      token: json['token'],
      nick: json['nick'],
    );
  }
}
