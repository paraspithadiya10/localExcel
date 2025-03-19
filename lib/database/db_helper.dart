import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  DbHelper._();
  static final DbHelper getInstance = DbHelper._();

  static final String excelData = 'excelData';
  static final String id = 'id';
  static final String name = 'name';
  static final String email = 'email';

  Database? myDb;

  Future<Database> getDB() async {
    myDb ??= await openDB();
    return myDb!;
  }

  Future<Database> openDB() async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String path = join(appDir.path, 'excelData.db');

    return await openDatabase(path, version: 1, onCreate: (db, version) {
      db.execute(
          'create table $excelData ($id TEXT PRIMARY KEY, $name TEXT, $email TEXT)');
    });
  }

  Future<bool> addData(
      {required String excelid,
      required String excelname,
      required String excelemail}) async {
    var db = await getDB();

    int rowsEffected = await db.insert(
      excelData,
      {
        id: excelid,
        name: excelname,
        email: excelemail,
      },
    );

    return rowsEffected > 0;
  }

  Future<List<Map<String, dynamic>>> getAllData() async {
    var db = await getDB();
    return await db.query(excelData);
  }

  Future<int> deleteAllData() async {
    var db = await getDB();
    return await db.delete(excelData);
  }
}
