import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:teragate_ble_repo/config/env.dart';
import 'package:teragate_ble_repo/models/result_model.dart';
import 'package:teragate_ble_repo/models/storage_model.dart';
import 'package:teragate_ble_repo/services/server_service.dart';
import 'package:teragate_ble_repo/utils/log_util.dart';
import 'package:teragate_ble_repo/utils/time_util.dart';

StreamSubscription startBeaconSubscription(StreamController streamController, SecureStorage secureStorage) {
  String oldScanTime = "";
  Map<String, dynamic> eventMap;
  return streamController.stream.listen((event) {
    if (event.isNotEmpty) {
      eventMap = jsonDecode(event);
      if (oldScanTime == eventMap["scanTime"]) {
        return;
      }
      _processEvent(secureStorage, eventMap);
    }
  }, onError: (dynamic error) {
    Log.error('Received error: ${error.message}');
  });
}

StreamSubscription startBLESubscription(StreamController streamController, SecureStorage secureStorage) {
  Map<String, dynamic> eventMap;

  return streamController.stream.listen((event) {
    if (event.isNotEmpty) {
      eventMap = jsonDecode(event);
      _processEvent(secureStorage, eventMap);
    }
  }, onError: (dynamic error) {
    Log.error('Received error: ${error.message}');
  });
}

Future<void> _processEvent(SecureStorage secureStorage, dynamic eventMap) async {
  String uuid;

  if (Platform.isAndroid) {
    // uuid = eventMap["serviceUuids"][0].toString().toUpperCase().substring(4, 8);
    uuid = eventMap["serviceUuids"][0].toString().toUpperCase();
  } else {
    // uuid = eventMap["serviceUuids"][0].toString().toUpperCase();
    uuid = "0000${eventMap["serviceUuids"][0].toString().toUpperCase()}-0000-1000-8000-00805F9B34FB";
  }

  Log.debug(" *** uuid = $uuid :: UUIDS SIZE = ${Env.UUIDS.length}");

  if (!Env.UUIDS.containsKey(uuid)) {
    return;
  }

  Env.INNER_TIME = getNow();

  if (Env.CURRENT_UUID != uuid) {
    Env.CURRENT_UUID = uuid;
    _getPlace(secureStorage, uuid).then((place) {
      if (Env.CURRENT_PLACE != place) {
        Env.CURRENT_PLACE = (place ?? "");
        Env.BEACON_FUNCTION!(BeaconInfoData(uuid: uuid, place: Env.CURRENT_PLACE));
      }
    });
  }
}

Future<String?> _getPlace(SecureStorage secureStorage, String uuid) async {
  return await secureStorage.read(uuid);
}

void stopBeaconSubscription(StreamSubscription? streamSubscription) {
  if (streamSubscription != null) streamSubscription.cancel();
}

Future<Timer> startBeaconTimer(BuildContext? context, SecureStorage secureStorage) async {
  String lastTime = "";

  Timer? timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    // ignore: unnecessary_null_comparison
    if (Env.INNER_TIME == null) return;

    int diff = getNow().difference(Env.INNER_TIME).inSeconds;
    Log.debug(" *** diff = $diff");

    if (Env.OLD_PLACE == "" || Env.OLD_PLACE == "---") {
      if (Env.OLD_PLACE != Env.CURRENT_PLACE) {
        Env.CHANGE_COUNT = 1;
        Env.OLD_PLACE = Env.CURRENT_PLACE;
        // 서버에 전송
        Log.debug("비콘 범위 내부 -- ${Env.LOCATION_STATE}");
        sendMessageTracking(secureStorage, Env.CURRENT_UUID, Env.CURRENT_PLACE).then((workInfo) {
          Log.debug(" tracking event = ${workInfo == null ? "" : workInfo.success.toString()}");
          // 외부에서 내부 또는 처음 설치시 상태 변경
          setLocationState(secureStorage, "in_work");
          _setWorkInfo(secureStorage);
        });
      }
    } else if (Env.OLD_PLACE != Env.CURRENT_PLACE) {
      if (Env.CHANGE_COUNT > 15) {
        Log.debug("비콘 범위 내부 지역 이동 -- ${Env.LOCATION_STATE}");
        Env.CHANGE_COUNT = 1;
        Env.OLD_PLACE = Env.CURRENT_PLACE;
        // 서버에 전송
        sendMessageTracking(secureStorage, Env.CURRENT_UUID, Env.CURRENT_PLACE).then((workInfo) {
          Log.debug(" tracking event = ${workInfo == null ? "" : workInfo.success.toString()}");
          _setWorkInfo(secureStorage);
        });
      } else {
        Env.CHANGE_COUNT++;
      }
    } else {
      Env.CHANGE_COUNT = 1;
    }

    if (lastTime != getDateToStringForHHMMInNow()) {
      lastTime = getDateToStringForHHMMInNow();
      _setWorkInfo(secureStorage);
    }
  });

  return timer;
}

void getOutUser(SecureStorage secureStorage) {
  Env.CURRENT_UUID = "";
  Env.CURRENT_PLACE = "---";
  Env.OLD_PLACE = Env.CURRENT_PLACE;
  Env.CHANGE_COUNT = 1;
  // 서버에 전송
  if (Env.LOCATION_STATE == "in_work") {
    sendMessageTracking(secureStorage, "", Env.CURRENT_PLACE).then((workInfo) {
      Log.debug(" tracking event = ${workInfo == null ? "" : workInfo.success.toString()}");
      // 외부(비콘 범위 밖) 상태 변경
      setLocationState(secureStorage, "out_work");
      _setWorkInfo(secureStorage);
      Log.debug("비콘 범위 외부로 이동 -- ${Env.LOCATION_STATE}");
    });
  }
}

void _setWorkInfo(SecureStorage secureStorage) {
  // 금일 출근 퇴근 정보 요청
  sendMessageByWork(secureStorage).then((workInfo) {
    Env.INIT_STATE_WORK_INFO = workInfo;
    Env.EVENT_FUNCTION == null ? "" : Env.EVENT_FUNCTION!(workInfo);
  });

  Future.delayed(const Duration(seconds: 2), () {
    // 일주일간 출근 퇴근 정보 요청
    sendMessageByWeekWork(secureStorage).then((weekInfo) {
      Env.INIT_STATE_WEEK_INFO = weekInfo;
      Env.EVENT_WEEK_FUNCTION == null ? "" : Env.EVENT_WEEK_FUNCTION!(weekInfo);
    });
  });
}

Future<Timer> startUiTimer(Function setUI) async {
  Timer? timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setUI();
  });

  return timer;
}

Future<void> stopTimer(Timer? timer) async {
  if (timer != null) timer.cancel();
}

// 현재 위치 상태 (내부, 외부)
Future<void> setLocationState(SecureStorage secureStorage, String? state) async {
  secureStorage.write(Env.KEY_LOCATION_STATE, state!);
  Env.LOCATION_STATE = await secureStorage.read(Env.KEY_LOCATION_STATE);
}
