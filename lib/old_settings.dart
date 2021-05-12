import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

const DB_NAME = 'zap.db';

class ZapUser {
  String pin;
  String recoveryWords;
  ZapUser(this.pin, this.recoveryWords);
}

Future<ZapUser?> extractZapUserFromOldAppDb() async {
  var path = join(await getDatabasesPath(), DB_NAME); // android db location
  if (!await databaseExists(path))
    path = join(join((await getLibraryDirectory()).path, 'LocalDatabase'),
        DB_NAME); // ios db location
  if (await databaseExists(path)) {
    var database = await openDatabase(path);
    var rows = await database.query('zapuser');
    if (rows.length > 0) {
      var row = rows.first;
      if (row.containsKey('pin') && row.containsKey('recoverywords')) {
        return ZapUser(row['pin'] as String, row['recoverywords'] as String);
      }
    }
  }
  return null;
}
