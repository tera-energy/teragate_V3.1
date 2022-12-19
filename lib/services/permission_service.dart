import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as location;
import 'package:permission_handler/permission_handler.dart' as permission;

class PermissionManager {
  static final PermissionManager _instance = PermissionManager._internal();

  factory PermissionManager() => _instance;

  PermissionManager._internal() {
    flutterBluePlus = FlutterBluePlus.instance;
    loc = location.Location();
    callPermissions();
    checkDeviceLocationIsOn();
    checkDeviceBluetoothIsOn();
  }

  FlutterBluePlus? flutterBluePlus;
  location.Location? loc;

  Future<bool> callPermissions() async {
    if (await getState()) {
      return true;
    }

    if (Platform.isAndroid) {
      bool nearDeviceIsDenied = await permission.Permission.nearbyWifiDevices.isDenied;

      if (nearDeviceIsDenied) {
        permission.Permission.nearbyWifiDevices.request();
      }
    }
    return false;
  }

  List<permission.Permission> _getPermissions() {
    List<permission.Permission> permissions = [permission.Permission.location];

    if (Platform.isAndroid) {
      permissions.add(permission.Permission.bluetoothScan);
      permissions.add(permission.Permission.bluetoothConnect);
    }

    return permissions;
  }

  Future<bool> getState() async {
    List<permission.Permission> permissions = _getPermissions();
    Map<permission.Permission, permission.PermissionStatus> statuses = await permissions.request();
    if (statuses.values.every((element) => element.isGranted)) {
      return true;
    }

    return false;
  }

  Future<bool> checkDeviceLocationIsOn() async {
    bool isOn = false;
    if (Platform.isAndroid) {
      isOn = await Geolocator.isLocationServiceEnabled();
      if (!isOn) Future.error('Location Services are disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return isOn;
      }
      isOn = true;
    } else if (Platform.isIOS) {
      isOn = await loc!.serviceEnabled();
    }

    return isOn;
  }

// 블루투스 on/off 확인
  Future<bool> checkDeviceBluetoothIsOn() async {
    return await flutterBluePlus!.isOn;
  }
}
