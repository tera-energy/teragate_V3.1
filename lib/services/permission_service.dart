import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> callPermissions() async {
  if (await getState()) {
    return true;
  }

  if (Platform.isAndroid) {
    AppSettings.openAppSettings();
  }
  return false;
}

List<Permission> _getPermissions() {
  List<Permission> permissions = [Permission.location];

  if (Platform.isAndroid) {
    permissions.add(Permission.bluetoothScan);
    permissions.add(Permission.bluetoothConnect);
    permissions.add(Permission.bluetooth);
    permissions.add(Permission.locationAlways);
    permissions.add(Permission.locationWhenInUse);
  }

  return permissions;
}

Future<bool> getState() async {
  List<Permission> permissions = _getPermissions();
  Map<Permission, PermissionStatus> statuses = await permissions.request();
  if (statuses.values.every((element) => element.isGranted)) {
    return true;
  }

  return false;
}

Future<bool> checkDeviceLocationIsOn() async {
  bool isOn = false;

  isOn = await Geolocator.isLocationServiceEnabled();
  if (!isOn) Future.error('Location Services are disabled');

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return isOn;
  }
  isOn = true;
  return isOn;
}
