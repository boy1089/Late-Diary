import 'package:flutter/material.dart';
import 'package:test_location_2nd/Note/NoteManager.dart';
import 'package:test_location_2nd/Util/DateHandler.dart';
import '../Util/global.dart';
import 'package:test_location_2nd/Util/Util.dart';
import 'package:test_location_2nd/Photo/PhotoDataManager.dart';
import 'package:test_location_2nd/Sensor/SensorDataManager.dart';

import 'package:test_location_2nd/Util/global.dart' as global;

import 'package:test_location_2nd/Location/AddressFinder.dart';
import 'package:test_location_2nd/Location/Coordinate.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:math';

class DayPageStateProvider with ChangeNotifier {
  PhotoDataManager photoDataManager = PhotoDataManager();
  SensorDataManager sensorDataManager = SensorDataManager();
  NoteManager noteManager = NoteManager();

  double zoomInAngle = 0.0;
  bool isZoomIn = false;
  bool isBottomNavigationBarShown = true;
  int lastNavigationIndex = 0;
  bool isZoomInImageVisible = false;
  String date = formatDate(DateTime.now());

  List<String> availableDates = [];
  Map summaryOfGooglePhotoData = {};
  List photoForPlot = [];
  dynamic photoData = [[]];
  dynamic sensorDataForPlot = [[]];
  List<List<dynamic>> photoDataForPlot = [[]];
  Map<int, String?> addresses = {};
  String note = "";

  Future<void> updateDataForUi() async {
    photoForPlot = [];
    photoDataForPlot = [];
    photoData = [[]];
    Stopwatch stopwatch = Stopwatch()..start();
    try {
      photoData = await updatePhotoData();
      photoForPlot = selectPhotoForPlot(photoData, true);
    } catch (e) {
      print("while updating Ui, error is occrued : $e");
    }
    print("time elapsed : ${stopwatch.elapsed}");
    // //convert data type..
    photoDataForPlot = List<List>.generate(
        photoForPlot.length, (index) => photoForPlot.elementAt(index));
    print("time elapsed : ${stopwatch.elapsed}");
    addresses = await updateAddress();
    print("time elapsed : ${stopwatch.elapsed}");
    await updateSensorData();
    print("time elapsed : ${stopwatch.elapsed}");
    try {
      note = await noteManager.readNote(date);
    } catch (e) {
      note = "";
      print("while updating UI, reading note, error is occured : $e");
    }
    print("updateUi done");
    print("time elapsed : ${stopwatch.elapsed}");
  }

  Future updatePhotoData() async {
    print("dayPage, updatePhotoFromLocal, date : $date");
    List<List<dynamic>> data = await photoDataManager.getPhotoOfDate(date);
    print("dayPage, updatePhotoFromLocal, files : $data");
    photoData = modifyListForPlot(data, executeTranspose: true);
    return photoData;
  }

  List subsamplePhotoForPlot(List input) {
    print("DayPage selectImageForPlot : ${input}");
    if (input[0] == null) return photoForPlot;
    if (input[0].length == 0) return photoForPlot;
    photoForPlot.add([input.first[0], input.first[1], input.first[2]]);
    int j = 0;
    for (int i = 1; i < input.length - 2; i++) {
      if ((input[i][0] - photoForPlot[j][0]).abs() >
          global.kMinimumTimeDifferenceBetweenImages_ZoomIn) {
        photoForPlot.add([input[i][0], input[i][1], input[i][2]]);
        j = i;
      } else {
        photoForPlot.add([input[i][0], input[i][1], input[i][2]]);
      }
    }

    photoForPlot.add([input.last[0], input.last[1], input.last[2]]);
    print("selectImagesForPlot done, $photoForPlot");
    return photoForPlot;
  }

  List selectPhotoForPlot(List input, bool sampleImages) {
    print("DayPage selectImageForPlot : ${input}");
    if (input[0] == null) return photoForPlot;
    if (input[0].length == 0) return photoForPlot;

    photoForPlot.add([input.first[0], input.first[1], input.first[2], true]);
    int j = 0;
    int k = 0;

    double timeDiffForZoomIn = 0.000;
    double timeDiffForZoomOut = global.kMinimumTimeDifferenceBetweenImages_ZoomOut;
    if(sampleImages)
      // timeDiffForZoomIn = global.kMinimumTimeDifferenceBetweenImages_ZoomIn;
      timeDiffForZoomIn = 0.25;


    for (int i = 1; i < input.length - 2; i++) {
      double timeDifferenceBetweenImagesForZoomOut =
          (input[i][0] - photoForPlot[k][0]).abs();
      double timeDifferenceBetweenImagesForZoomIn =
          (input[i][0] - photoForPlot[j][0]).abs();


      if (timeDifferenceBetweenImagesForZoomIn >
          timeDiffForZoomIn) {
        print("$i/ ${input.length}, $j, $k, $timeDifferenceBetweenImagesForZoomIn");
            bool isGoodForZoomOut = timeDifferenceBetweenImagesForZoomOut >
                timeDiffForZoomOut;
        photoForPlot.add(
            [input[i][0], input[i][1], input[i][2], isGoodForZoomOut]);
        j +=1;

        if (isGoodForZoomOut) {
          k = j;
        }

      }
    }

    // for (int i = 1; i < input.length - 2; i++) {
    //   if ((input[i][0] - photoForPlot[j][0]).abs() >
    //       global.kMinimumTimeDifferenceBetweenImages_ZoomOut) {
    //     photoForPlot.add([input[i][0], input[i][1], input[i][2], true]);
    //     j = i;
    //   } else {
    //     photoForPlot.add([input[i][0], input[i][1], input[i][2], false]);
    //   }
    // }

    photoForPlot.add([input.last[0], input.last[1], input.last[2], true]);
    print("selectImagesForPlot done, $photoForPlot");
    return photoForPlot;
  }

  Future<void> updateSensorData() async {
    var sensorData = await this.sensorDataManager.openFile(date);
    try {
      sensorDataForPlot = modifyListForPlot(subsampleList(sensorData, 10));
    } catch (e) {
      sensorDataForPlot = [[]];
      print("error during updating sensorData : $e");
    }
    print("sensorDataForPlot : $sensorDataForPlot");
  }

  Future<Map<int, String?>> updateAddress() async {
    Map<int, int> selectedIndex = {};
    Map<int, String?> addresses = {};
    List<Placemark?> addressOfFiles = [];

    files = transpose(photoForPlot)[1];

    selectedIndex = selectIndexForLocation(files);
    addressOfFiles = await getAddressOfFiles(selectedIndex.values.toList());
    addresses = Map<int, String?>.fromIterable(
        List.generate(selectedIndex.keys.length, (i) => i),
        key: (item) => selectedIndex.keys.elementAt(item),
        // value: (item) => "${addressOfFiles
        //     .elementAt(item)
        //     ?.locality}, ${addressOfFiles.elementAt(item)?.thoroughfare}" );
        value: (item) => "${addressOfFiles.elementAt(item)?.locality}");
    return addresses;
  }

  Map<int, int> selectIndexForLocation(files) {
    Map<int, int> indexForSelectedFile = {};
    List<DateTime?> datetimes = List<DateTime?>.generate(files.length,
        (i) => global.infoFromFiles[files.elementAt(i)]?.datetime);
    datetimes = datetimes.whereType<DateTime>().toList();
    List<int> times =
        List<int>.generate(datetimes.length, (i) => datetimes[i]!.hour);
    Set<int> setOfTimes = times.toSet();
    for (int i = 0; i < setOfTimes.length; i++)
      indexForSelectedFile[setOfTimes.elementAt(i)] =
          (times.indexOf(setOfTimes.elementAt(i)));
    return indexForSelectedFile;
  }

  Future<List<Placemark?>> getAddressOfFiles(List<int> index) async {
    List<Placemark?> listOfAddress = [];
    for (int i = 0; i < index.length; i++) {
      Coordinate? coordinate =
          global.infoFromFiles[files[index.elementAt(i)]]!.coordinate;
      print(coordinate);
      if (coordinate == null) {
        listOfAddress.add(null);
      }
      Placemark? address = await AddressFinder.getAddressFromCoordinate(
          coordinate?.latitude, coordinate?.longitude);
      listOfAddress.add(address);
    }
    return listOfAddress;
  }

  void writeNote() {
    if (note != "") {
      noteManager.writeNote(date, note);
      noteManager.notes[date] = note;
    }
    if (note == "") {
      noteManager.tryDeleteNote(date);
      try {
        noteManager.notes.remove(date);
      } catch (e) {
        print("error during writeNote : $e");
      }
    }
  }

  void deleteNote() {
    noteManager.tryDeleteNote(date);
  }

  void setDate(String date) {
    this.date = date;
    print("date : ${this.date}");
  }

  void setIsZoomInImageVisible(bool isZoomInImageVisible) {
    this.isZoomInImageVisible = isZoomInImageVisible;
    notifyListeners();
  }

  void setBottomNavigationBarShown(bool isBottomNavigationBarShown) {
    this.isBottomNavigationBarShown = isBottomNavigationBarShown;
    print("isBottomNavigationBarShown : $isBottomNavigationBarShown");
    notifyListeners();
  }

  void setLastNavigationIndex(int index) {
    lastNavigationIndex = index;
  }

  void setSummaryOfGooglePhotoData(data) {
    summaryOfGooglePhotoData = data;
  }

  void setZoomInRotationAngle(angle) {
    // print("provider set zoomInAngle to $angle");
    zoomInAngle = angle;
    notifyListeners();
  }

  void setZoomInState(isZoomIn) {
    print("provider set isZoomIn to $isZoomIn");
    this.isZoomIn = isZoomIn;
    notifyListeners();
  }

  void setAvailableDates(availableDates) {
    print("provider set isZoomIn to $isZoomIn");
    this.availableDates = availableDates;
    notifyListeners();
  }

  void setNote(note) {
    // print("provider set zoomInAngle to $angle");
    this.note = note;
    notifyListeners();
  }

  @override
  void dispose() {
    print("provider disposed");
  }
}
