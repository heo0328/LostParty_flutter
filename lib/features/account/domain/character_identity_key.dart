import 'dart:convert';

String characterIdentityKey(String serverName, String characterName) =>
    base64Url
        .encode(
          utf8.encode('${serverName.trim()}\u0000${characterName.trim()}'),
        )
        .replaceAll('=', '');
