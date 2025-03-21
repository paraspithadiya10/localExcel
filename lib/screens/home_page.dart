import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:localxcel/database/db_helper.dart';
import 'package:network_info_plus/network_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<List<String>> excelData = [];
  List<String> filteredRow = [];

  RawDatagramSocket? udpSocket;

  final info = NetworkInfo();
  String? wifiIp = '';

  String deviceBrand = '';
  String deviceModel = '';

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

  getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    deviceBrand = androidInfo.brand;
    deviceModel = androidInfo.model;
    setState(() {});
  }

  getWifiIp() async {
    wifiIp = await info.getWifiIP();
  }

  Future<void> boundUdpSocket() async {
    if (wifiIp!.isNotEmpty || wifiIp != null) {
      udpSocket = await RawDatagramSocket.bind("192.168.1.39", 5555);
      udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = udpSocket!.receive();
          if (datagram != null) {
            String message = String.fromCharCodes(datagram.data);
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Received: $message')));
          }
        }
      });
      debugPrint(
          'UDP socket is bound to ${udpSocket!.address.address}:${udpSocket!.port}');
    } else {
      debugPrint('Failed to get Wifi ip address');
    }
  }

  @override
  void initState() {
    getWifiIp();
    boundUdpSocket();

    getDeviceInfo();

    dbRef = DbHelper.getInstance;
    loadDataFromDB();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$deviceBrand $deviceModel'),
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
                      trailing: IconButton(
                          onPressed: () async {
                            udpSocket?.send(
                                '${excelData[index][1]} from : $deviceBrand $deviceModel'
                                    .codeUnits,
                                InternetAddress("192.168.1.50"),
                                5555);
                            debugPrint('message send successfully');
                          },
                          icon: Icon(Icons.send)),
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
