import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';
import 'package:move_to_background/move_to_background.dart';
import 'package:simple_fontellico_progress_dialog/simple_fontico_loading.dart';
import 'package:teragate_ble_repo/State/widgets/custom_text.dart';
import 'package:teragate_ble_repo/config/env.dart';
import 'package:teragate_ble_repo/models/result_model.dart';
import 'package:teragate_ble_repo/models/storage_model.dart';
import 'package:teragate_ble_repo/services/beacon_service.dart';
import 'package:teragate_ble_repo/services/server_service.dart';
import 'package:teragate_ble_repo/services/permission_service.dart';
import 'package:teragate_ble_repo/services/bluetooth_service.dart' as bluetooth_service;
import 'package:teragate_ble_repo/state/widgets/bottom_navbar.dart';
import 'package:teragate_ble_repo/state/widgets/coustom_Businesscard.dart';
import 'package:teragate_ble_repo/state/widgets/synchonization_dialog.dart';
import 'package:teragate_ble_repo/utils/alarm_util.dart';
import 'package:teragate_ble_repo/utils/time_util.dart';

class Place extends StatefulWidget {
  final StreamController eventStreamController;
  final StreamController beaconStreamController;

  const Place({required this.eventStreamController, required this.beaconStreamController, Key? key}) : super(key: key);

  @override
  State<Place> createState() => _PlaceState();
}

class _PlaceState extends State<Place> {
  List<String> placeList = [""];
  late SimpleFontelicoProgressDialog dialog;
  BeaconInfoData beaconInfoData = BeaconInfoData(uuid: "", place: "");
  BLEInfoData bleInfoData = BLEInfoData(uuid: "", place: "");
  late SecureStorage secureStorage;
  WorkInfo? workInfo;

  @override
  void initState() {
    secureStorage = SecureStorage();
    _initUUIDList();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    workInfo = Env.INIT_STATE_WORK_INFO;
    Env.EVENT_FUNCTION = _setUI;
    Env.BEACON_FUNCTION = _setBeaconUI;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    dialog = SimpleFontelicoProgressDialog(context: context, barrierDimisable: false, duration: const Duration(milliseconds: 3000));
    return _createWillPopScope(Container(
      padding: EdgeInsets.only(top: statusBarHeight),
      decoration: const BoxDecoration(color: Color(0xffF5F5F5)),
      child: Scaffold(
          body: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 40.0,
                    width: 40.0,
                    margin: const EdgeInsets.only(top: 20.0, right: 20.0),
                    // padding: const EdgeInsets.all(1.0),
                    decoration: const BoxDecoration(),
                    child: Material(
                      color: Colors.white,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(6.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          showLogoutDialog(context);
                          // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        },
                        borderRadius: const BorderRadius.all(
                          Radius.circular(6.0),
                        ),
                        child: const Icon(
                          Icons.logout,
                          size: 18.0,
                          color: Color(0xff3450FF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Container(
                                margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 5),
                                padding: const EdgeInsets.only(top: 15),
                                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                                  CustomText(
                                    text: "?????? ????????? ??????",
                                    size: 18,
                                    weight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ])),
                          ],
                        )),
                    Expanded(
                        flex: 7,
                        child: createContainer(Column(
                          children: [
                            Expanded(flex: 5, child: placeList == null ? const SizedBox() : initGridView(placeList)),
                            Expanded(
                                flex: 1,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    CustomText(
                                      text: "??????????????? ???????????? ????????? ?????? ??????",
                                      size: 12,
                                      weight: FontWeight.w400,
                                      color: Color(0xff6E6C6C),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: CustomText(
                                        text: "?????? ????????? ????????? ???????????????",
                                        size: 12,
                                        weight: FontWeight.w400,
                                        color: Color(0xff6E6C6C),
                                      ),
                                    ),
                                  ],
                                )),
                          ],
                        ))),
                    Expanded(
                        flex: 2,
                        child: Container(
                            padding: const EdgeInsets.only(top: 8),
                            child: createContainerwhite(CustomBusinessCard(Env.WORK_COMPANY_NAME, Env.WORK_KR_NAME, Env.WORK_POSITION_NAME, Env.WORK_PHOTO_PATH, workInfo)))),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavBar(
            currentLocation: Env.OLD_PLACE,
            currentTime: getPickerTime(getNow()),
            function: _synchonizationPlaceUI,
          )),
    ));
  }

  @override
  void dispose() {
    super.dispose();
  }

  WillPopScope _createWillPopScope(Widget widget) {
    return WillPopScope(
        onWillPop: () {
          MoveToBackground.moveTaskToBack();
          return Future(() => false);
        },
        child: widget);
  }

  Container createContainer(Widget widget) {
    return Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: widget);
  }

  Container createContainerwhite(Widget widget) {
    return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: widget);
  }

  GridView initGridView(List list) {
    return GridView.builder(
        itemCount: list.length, //item ??????
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, //1 ?????? ?????? ????????? item ??????
          childAspectRatio: 1 / 1, //item ??? ?????? 1, ?????? 2 ??? ??????
          mainAxisSpacing: 10, //?????? Padding
          crossAxisSpacing: 10, //?????? Padding
        ),
        itemBuilder: ((context, index) {
          return Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xffF5F5F5), borderRadius: BorderRadius.circular(8)),
              child: Stack(alignment: Alignment.topLeft, children: [
                Env.OLD_PLACE == ""
                    ? Container()
                    : (Env.OLD_PLACE == list[index]
                        ? const Icon(
                            Icons.location_on_rounded,
                            color: Colors.red,
                            size: 10,
                          )
                        : Container()),
                Center(
                    child: Align(
                        alignment: Alignment.center,
                        child: CustomText(
                          text: list[index],
                          size: 12,
                          weight: FontWeight.bold,
                          color: Colors.black,
                          isOverlfow: false,
                        )))
              ]));
        }));
  }

  void _setUI(WorkInfo workInfo) {
    setState(() {
      this.workInfo = workInfo;
    });
  }

  Future<void> _synchonizationPlaceUI(WorkInfo? workInfo) async {
    if (Platform.isAndroid) {
      checkDeviceLocationIsOn().then((value) {
        if (value) {
          showAlertDialog(context, text: "????????? ?????? ????????? ???????????????.", action: AppSettings.openLocationSettings);
        } else {
          _checkDeviceBluetoothIsOn().then((value) {
            if (!value) {
              showAlertDialog(context, text: "????????? ???????????? ????????? ???????????????.", action: AppSettings.openBluetoothSettings);
            } else {
              _requestBELInfo();
            }
          });
        }
      });
    }

    if (Platform.isIOS) {
      _checkIOSDeviceLocationIsOn().then((value) {
        if (!value) {
          showSnackBar(context, "????????? ?????? ????????? ???????????????.");
        } else {
          _checkDeviceBluetoothIsOn().then((value) {
            if (!value) {
              showSnackBar(context, "????????? Bluetooth ????????? ???????????????.");
            } else {
              _requestBELInfo();
            }
          });
        }
      });
    }
  }

  void _initUUIDList() async {
    setState(() {
      placeList = _deduplication(Env.UUIDS.entries.map((e) => e.value).toList());
    });
  }

  void _setBeaconUI(BeaconInfoData beaconInfoData) {
    this.beaconInfoData = beaconInfoData;
    setState(() {});
  }

  List<String> _deduplication(List<String> list) {
    var deduplicationlist = list.toSet();
    list = deduplicationlist.toList();
    return list;
  }

  // ?????? ?????? ??????
  Future<void> _requestBeaconIfon() async {
    //  ?????? ?????? ?????? ( ????????? )
    List<String> sharedStorageuuid = [];
    dialog.show(message: "?????????...");
    if (Platform.isIOS) {
      stopBeacon();
    }

    sendMessageByBeacon(context, secureStorage).then((configInfo) async {
      if (configInfo!.success!) {
        List<BeaconInfoData> placeInfo = configInfo.beaconInfoDatas;

        for (BeaconInfoData beaconInfoData in placeInfo) {
          secureStorage.write(beaconInfoData.uuid, beaconInfoData.place);
          sharedStorageuuid.add(beaconInfoData.uuid);
          placeList.add(beaconInfoData.place);
        }
        SharedStorage.write(Env.KEY_SHARE_UUID, sharedStorageuuid);

        placeList = _deduplication(placeList);

        setState(() {});
        if (Platform.isIOS) {
          initBeacon(context, widget.beaconStreamController, secureStorage, sharedStorageuuid);
        }

        dialog.hide();
        showSyncDialog(context, widget: SyncDialog(warning: true));
      } else {
        dialog.hide();
        showSyncDialog(context, widget: SyncDialog(warning: false));
      }
    });
  }

  // BLE ?????? ??????
  Future<void> _requestBELInfo() async {
    List<String> sharedStorageuuid = [];
    dialog.show(message: "?????????...");

    sendMessageByBLE(context, secureStorage).then((bleInfo) {
      // Log.debug("request ble info : ${bleInfo!.success}");
      if (bleInfo!.success!) {
        List<BLEInfoData> placeInfo = bleInfo.bleInfoDatas;

        for (BLEInfoData bleInfoData in placeInfo) {
          secureStorage.write(bleInfoData.uuid, bleInfoData.place);
          sharedStorageuuid.add(bleInfoData.uuid);
          placeList.add(bleInfoData.place);
        }
        SharedStorage.write(Env.KEY_SHARE_UUID, sharedStorageuuid);

        setState(() {
          placeList = _deduplication(placeList);
        });

        bluetooth_service.BluetoothService.setWithServices(sharedStorageuuid).then((value) {
          // ????????? ??? ????????? uuid????????? ????????? ?????????
          bluetooth_service.BluetoothService.stopBLEScan().then((value) => bluetooth_service.BluetoothService.startBLEScan(widget.beaconStreamController));
        });

        dialog.hide();
        showSyncDialog(context, widget: SyncDialog(warning: true));
      } else {
        dialog.hide();
        showSyncDialog(context, widget: SyncDialog(warning: false));
      }
    });
  }

  // ???????????? on/off ??????
  Future<bool> _checkDeviceBluetoothIsOn() async {
    FlutterBluePlus flutterBlue = FlutterBluePlus.instance;
    return await flutterBlue.isOn;
  }

  // ?????? on/off ??????
  Future<bool> _checkIOSDeviceLocationIsOn() async {
    Location location = Location();
    return await location.serviceEnabled();
  }
}
