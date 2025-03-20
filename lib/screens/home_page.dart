import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:localxcel/database/db_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<List<String>> excelData = [];
  List<String> filteredRow = [];
  DbHelper? dbRef;

  Future<void> pickAndReadExcelFile() async {
    try {
      // Open file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        await dbRef?.deleteAllData();
        File file = File(result.files.single.path!);

        // Read the Excel file
        var bytes = file.readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        List<List<String>> data = [];

        // Iterate over the rows and columns in the first sheet
        for (var table in excel.tables.keys) {
          for (var row in excel.tables[table]!.rows) {
            // Filter out null cells and convert them to strings
            filteredRow = row
                .where((cell) => cell != null) // Skip null cells
                .map((cell) =>
                    cell!.value.toString()) // Convert non-null cells to strings
                .toList();

            if (filteredRow.isNotEmpty) {
              data.add(filteredRow); // Add non-empty rows

              debugPrint('$filteredRow');

              await dbRef?.addData(
                  excelid: filteredRow[0],
                  excelname: filteredRow[1],
                  excelemail: filteredRow[2]);
            }
          }
          break; // Read only the first sheet
        }
        loadDataFromDB();
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Error : duplicate data will be not save again',
              style: TextStyle(color: Colors.white),
            )),
      );
    }
  }

  Future<void> loadDataFromDB() async {
    try {
      var data = await dbRef?.getAllData();

      if (data != null) {
        List<List<String>> loadedData = data.map((row) {
          return [
            row['id'] as String,
            row['name'] as String,
            row['email'] as String,
          ];
        }).toList();

        setState(() {
          excelData = loadedData;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  @override
  void initState() {
    dbRef = DbHelper.getInstance;
    super.initState();
    loadDataFromDB();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        centerTitle: true,
      ),
      body: excelData.isEmpty
          ? const Center(
              child: Text('No data loaded'),
            )
          : ListView.builder(
              itemCount: excelData.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(excelData[index][0]),
                      ),
                      title: Text(excelData[index][1]),
                      subtitle: Text(excelData[index][2]),
                      trailing: Icon(Icons.share),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          pickAndReadExcelFile();
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
