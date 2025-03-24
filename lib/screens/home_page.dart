import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:localxcel/database/db_helper.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? ipAddress;

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

  Future<void> getWifiIp() async {
    try {
      wifiIp = await info.getWifiIP();
      if (wifiIp == null || wifiIp!.isEmpty) {
        debugPrint('WiFi IP is null or empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.red,
            content: Text(
              'Please connect to WiFi network',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        debugPrint('WiFi IP obtained: $wifiIp');
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error getting WiFi IP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error getting WiFi IP. Please check WiFi connection',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> boundUdpSocket() async {
    if (wifiIp != null && wifiIp!.isNotEmpty) {
      try {
        // Validate IP address format before binding
        final address = InternetAddress(wifiIp!);
        udpSocket = await RawDatagramSocket.bind(address, 5555);
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
      } catch (e) {
        debugPrint('Invalid IP address format: $wifiIp');
      }
    } else {
      debugPrint('Failed to get Wifi ip address');
    }
  }

  @override
  void initState() {
    super.initState();

    getWifiIp().then((_) {
      // Only bind UDP socket after getting WiFi IP
      if (wifiIp != null && wifiIp!.isNotEmpty) {
        boundUdpSocket();
      }
    });

    getDeviceInfo();
    dbRef = DbHelper.getInstance;
    loadDataFromDB();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.sizeOf(context).height;
    double width = MediaQuery.sizeOf(context).width;

    TextEditingController ipController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text('$deviceBrand $deviceModel'),
        centerTitle: true,
        actions: [
          IconButton(
              onPressed: () {
                showModalBottomSheet(
                    context: context,
                    builder: (context) {
                      return ipBottomSheet(height, width, ipController);
                    });
              },
              icon: Icon(Icons.add))
        ],
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
                            var sharedPref =
                                await SharedPreferences.getInstance();
                            ipAddress = sharedPref.getString("ipAddress");

                            if (ipAddress == null || ipAddress!.isEmpty) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text(
                                        "Please set receiver device's ip address from (+) button",
                                        style: TextStyle(color: Colors.white),
                                      )));
                            } else {
                              try {
                                // Validate IP address format before sending
                                final address = InternetAddress(ipAddress!);
                                udpSocket?.send(
                                    '${excelData[index][1]} from : $deviceBrand $deviceModel'
                                        .codeUnits,
                                    address,
                                    5555);
                                debugPrint('message sent successfully');
                              } catch (e) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text(
                                          "Invalid IP address format",
                                          style: TextStyle(color: Colors.white),
                                        )));
                              }
                            }
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

  Widget ipBottomSheet(
    height,
    width,
    ipController,
  ) {
    return Container(
      padding: EdgeInsets.only(left: 25, right: 25, top: 10),
      height: height * 0.25 + MediaQuery.of(context).viewInsets.bottom,
      width: width * 1.0,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: width * 0.15,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white,
            ),
          ),
          SizedBox(height: height * 0.03),
          TextFormField(
            controller: ipController,
            decoration: InputDecoration(
                label: Text('Enter IP Address'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10))),
          ),
          SizedBox(height: height * 0.03),
          SizedBox(
              width: double.maxFinite,
              child: ElevatedButton(
                  onPressed: () async {
                    var sharedPref = await SharedPreferences.getInstance();
                    await sharedPref.setString("ipAddress", ipController.text);
                    Navigator.pop(context);
                  },
                  style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(Colors.deepPurple)),
                  child: Text('Confirm')))
        ],
      ),
    );
  }
}
