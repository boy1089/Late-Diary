import 'package:flutter/foundation.dart';
import 'package:lateDiary/Location/Coordinate.dart';
import 'package:lateDiary/Data/infoFromFile.dart';
import 'package:lateDiary/Data/DataRepository.dart';

import 'AndroidDataManager.dart';
import 'IosDataManager.dart';

abstract class DataManagerInterface extends ChangeNotifier {
  factory DataManagerInterface(String type) {
    switch (type) {
      case "ios": return IosDataManager();
      case "android": return AndroidDataManager();
      default: return AndroidDataManager();
    }
  }

  Map<String, int> summaryOfPhotoData = {};
  Map<String, double> summaryOfLocationData = {};
  Map<String, Coordinate> summaryOfCoordinate = {};

  List setOfDates = [];
  List dates = [];
  List datetimes = [];
  List setOfDatetimes = [];
  List files = [];
  List? filesNotUpdated = [];
  List<String>? datesOutOfDate = [];

  Map<dynamic, InfoFromFile> infoFromFiles = {};

  DataRepository dataRepository = DataRepository();

  Future<void> init() async {}
  static Future<Map<dynamic, InfoFromFile>> updateDatesOnInfo_ios(
      List input) async {
    return {};
  }

  void executeSlowProcesses() async {}
  Future<List?> matchFilesAndInfo2() async {}
  Future<void> addFilesToInfo(List? filenames) async {}
  Future<void> updateDateOnInfo(List? input) async {}
  Future<List<String>> resetInfoFromFiles() async {
    return [];
  }

  static Future<List> updateDatesFromInfo(List input) async {
    return [];
  }

  static Future<Map<dynamic, InfoFromFile>> updateExifOnInfo_compute(
      List input) async {
    return {};
  }

  static Future<Map<String, int>> updateSummaryOfPhotoFromInfo(
      List input) async {
    return {};
  }

  static Future<Map<String, double>>
      updateSummaryOfLocationDataFromInfo2_compute(List input) async {
    return {};
  }

  static Future<Map<String, double>>
      updateSummaryOfLocationDataFromInfo_compute(List input) async {
    return {};
  }

  @override
  dispose(){
    print("DataManager disposed");
    super.dispose();
  }


}
