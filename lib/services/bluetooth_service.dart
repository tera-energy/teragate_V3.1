import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:teragate_ble_repo/config/env.dart';
import 'package:teragate_ble_repo/models/storage_model.dart';
import 'package:teragate_ble_repo/utils/time_util.dart';

class BluetoothService {
  static FlutterBluePlus flutterBluePlus = FlutterBluePlus.instance;
  static final List<String> macAddresses = ["B0:10:A0:74:A8:8F", "B0:10:A0:74:F1:A4"];
  static final List<Guid> defualtServiceUuid = [Guid("00001235-0000-1000-8000-00805F9B34FB")];
  static List<Guid> withServices = [];
  static Timer? bleScanTimer;

  static Future<void> turnOnBluetooth() async {
    if (Platform.isAndroid) flutterBluePlus.turnOn();
  }

  static Future<void> turnOffBluetooth() async {
    if (Platform.isAndroid) flutterBluePlus.turnOff();
  }

  static Future<void> setWithServices(List<String>? uuids) async {
    if (uuids == null) {
      withServices = defualtServiceUuid;
    } else {
      List<Guid> serviceUuids = <Guid>[];
      for (String el in uuids) {
        serviceUuids.add(Guid(el));
      }
      withServices = serviceUuids;
    }
  }

  static Future<void> startBLEScan(StreamController streamController) async {
    if (withServices.isEmpty) {
      List<String>? uuids = await SharedStorage.readList(Env.KEY_SHARE_UUID);
      if (uuids == null || uuids.isEmpty) {
        // 앱 처음 실행
        setWithServices(null);
      } else {
        // 이전 실행에서 uuids 동기화 후 저장된 uuids값
        setWithServices(uuids);
      }
    }

    bleScanTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      flutterBluePlus.startScan(
        scanMode: const ScanMode(0),
        timeout: const Duration(seconds: 2),
        withServices: withServices.isEmpty ? const [] : withServices,
        // macAddresses: Platform.isAndroid ? macAddresses : const [],
        // allowDuplicates: true,
      );

      // distinct() 이전 데이터와 같은 데이터는 건너뜀
      flutterBluePlus.scanResults.distinct().listen((results) {
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
              getDateToStringForAll(r.timeStamp),
            ).toString();
            // Log.debug(r.toString());
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
