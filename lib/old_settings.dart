import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

const DB_NAME = 'zap.db';

class ZapUser {
  String pin;
  String recoveryWords;
  String? bronzeApiKey;
  String? bronzeApiSecret;
  ZapUser(this.pin, this.recoveryWords, this.bronzeApiKey, this.bronzeApiSecret);
}

Future<ZapUser?> extractZapUserFromOldAppDb() async {
  var path = join(await getDatabasesPath(), DB_NAME); // android db location
  if (!await databaseExists(path) && (Platform.isIOS || Platform.isMacOS))
    path = join(join((await getLibraryDirectory()).path, 'LocalDatabase'),
        DB_NAME); // ios db location
  if (await databaseExists(path)) {
    var database = await openDatabase(path);
    // import zap wallet
    var rows = await database.query('zapuser');
    if (rows.length > 0) {
      var row = rows.first;
      if (row.containsKey('pin') && row.containsKey('recoverywords')) {
        var pin = row['pin'] as String;
        var recoveryWords = row['recoverywords'] as String;
        // import bronze api key
        String? bronzeApiKey;
        String? bronzeApiSecret;
        var rows = await database.query('bronzeapikey');
        if (rows.length > 0) {
          var row = rows.first;
          if (row.containsKey('apikey') && row.containsKey('apisecret')) {
            bronzeApiKey = row['apikey'] as String?;
            bronzeApiSecret = row['apisecret'] as String?;
          }
        }
        return ZapUser(pin, recoveryWords, bronzeApiKey, bronzeApiSecret);
      }
    }
  }
  return null;
}
