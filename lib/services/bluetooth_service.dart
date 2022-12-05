import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:teragate_ble_repo/utils/log_util.dart';

class BluetoothService {
  static FlutterBluePlus flutterBluePlus = FlutterBluePlus.instance;
  static final List<String> macAddresses = ["B0:10:A0:74:A8:8F", "B0:10:A0:74:F1:A4"];
  static final List<Guid> withServices = [];
  static Timer? bleScanTimer;

  static Future<void> turnOnBluetooth() async {
    if (Platform.isAndroid) flutterBluePlus.turnOn();
  }

  static Future<void> turnOffBluetooth() async {
    if (Platform.isAndroid) flutterBluePlus.turnOff();
  }

  static Future<void> startBLEScan(StreamController streamController) async {
    bleScanTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      flutterBluePlus.startScan(
        scanMode: const ScanMode(0),
        timeout: const Duration(seconds: 2),
        macAddresses: Platform.isAndroid ? macAddresses : const [],
        allowDuplicates: true,
      );

      flutterBluePlus.scanResults.listen((results) {
        dynamic eventMap;

        for (ScanResult r in results) {
          if (r.advertisementData.serviceUuids.isNotEmpty) {
            eventMap = BLEScanInfo(
              r.device.id.toString(),
              r.device.name,
              r.device.type.toString(),
              r.advertisementData.localName,
              r.advertisementData.txPowerLevel,
              r.advertisementData.serviceUuids,
              r.rssi,
              r.timeStamp.toString(),
            ).toString();
            // Log.debug(r.toString());
            // Log.debug('service UUid : ${r.advertisementData.serviceUuids}');
            streamController.add(eventMap);
          }
        }
      });

      flutterBluePlus.stopScan();
    });
  }

  static Future<void> stopBLEScan() async {
    bleScanTimer!.cancel();
  }
}

class BLEScanInfo {
  String id;
  String name;
  String type;
  String localName;
  int? txPowerLevel;
  List<String> serviceUuids;
  int rssi;
  String timeStamp;

  BLEScanInfo(this.id, this.name, this.type, this.localName, this.txPowerLevel, this.serviceUuids, this.rssi, this.timeStamp);

  Map<String, dynamic> toJson() {
    return {"id": id, "name": name, "type": type, "localName": localName, "txPowerLevel": txPowerLevel, "serviceUuids": serviceUuids, "rssi": rssi, "timeStamp": timeStamp};
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
