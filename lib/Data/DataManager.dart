import 'dart:convert';
import 'dart:io';
import 'package:glob/list_local_fs.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:glob/glob.dart';
import 'package:lateDiary/Util/DateHandler.dart';
import 'package:lateDiary/Util/Util.dart';
import 'package:lateDiary/Util/global.dart' as global;
import 'package:lateDiary/Location/LocationDataManager.dart';
import "package:lateDiary/Location/Coordinate.dart";
import 'infoFromFile.dart';
import 'package:lateDiary/Data/Directories.dart';
import 'package:lateDiary/StateProvider/DataStateProvider.dart';
import 'package:flutter/material.dart';

class DataManager extends ChangeNotifier {
  DataManager._privateConstructor();
  static final DataManager _instance = DataManager._privateConstructor();
  factory DataManager() {
    return _instance;
  }

  Map<String, int> summaryOfPhotoData = {};
  Map<String, double> summaryOfLocationData = {};
  Map<String, Coordinate> summaryOfCoordinate = {};
  LocationDataManager locationDataManager = LocationDataManager();

  List<String> files = [];
  List<String>? filesNotUpdated = [];
  List<String>? datesOutOfDate = [];

  Map<String, InfoFromFile> infoFromFiles = {};

  late DataStateProvider dataStateProvider;
  var context;

  void setProvider(provider) {
    this.dataStateProvider = provider;
  }

  Future<void> init() async {
    // dataStateProvider = Provider.of<DataStateProvider>(context, listen: false);
    Stopwatch stopwatch = Stopwatch()..start();

    print("DataManager instance is initializing..");
    //get list of image files from local. --> update new images
    files = await getAllFiles();
    print("getAllFiles done, time elapsed : ${stopwatch.elapsed}");
    await readInfoFromJson();
    await readSummaryOfPhoto();
    await readSummaryOfLocation();
    notifyListeners();

    // find the files which are in local but not in Info
    filesNotUpdated = await matchFilesAndInfo2();

    print("time elapsed : ${stopwatch.elapsed}");
    // update info which are not updated
    await addFilesToInfo(filesNotUpdated);
    print("addFilesToinfo done, time elapsed : ${stopwatch.elapsed}");

    await updateDateOnInfo(filesNotUpdated);
    print("updateDateOnInfo done, time elapsed : ${stopwatch.elapsed}");

    var result =
        await compute(updateDatesFromInfo, [infoFromFiles, filesNotUpdated]);
    print("updateDatesFromInfo done, time elapsed : ${stopwatch.elapsed}");
    global.setOfDates = result[0];
    global.setOfDatetimes = result[1];
    global.dates = result[2];
    global.datetimes = result[3];
    print("date during init, ${global.dates.length}");

    //find the dates which are out of date based on the number of photo.
    global.summaryOfPhotoData = await compute(updateSummaryOfPhotoFromInfo,
        [global.setOfDates, global.summaryOfPhotoData]);
    print("updateSummaryOfPhoto done, time elapsed : ${stopwatch.elapsed}");

    print("DataManager initialization done");
    notifyListeners();
  }

  void executeSlowProcesses() async {
    Stopwatch stopwatch = new Stopwatch()..start();

    if (filesNotUpdated == []) return;

    int lengthOfFiles = filesNotUpdated!.length;

    for (int i = 0; i < lengthOfFiles / 100.floor(); i++) {
      // for (int i = 0; i < 4; i++) {
      print("executingSlowProcesses... $i / ${lengthOfFiles / 100.floor()}");

      //part of Files
      List<String> partOfFilesNotupdated = filesNotUpdated!.sublist(i * 100,
          lengthOfFiles < (i + 1) * 100 ? lengthOfFiles : (i + 1) * 100);

      // await updateExifOnInfo(partOfFilesNotupdated);
      infoFromFiles = await compute(
          updateExifOnInfo_compute, [partOfFilesNotupdated, infoFromFiles]);

      if (i % 5 == 0) {
        var result = await compute(
            updateDatesFromInfo, [infoFromFiles, filesNotUpdated]);
        global.setOfDates = result[0];
        global.setOfDatetimes = result[1];
        global.dates = result[2];
        global.datetimes = result[3];

        //update the summaryOflocation only on the specific date.
        global.summaryOfPhotoData = await compute(updateSummaryOfPhotoFromInfo,
            [global.setOfDates, global.summaryOfPhotoData]);

        await writeInfoAsJson(null, true);
        await writeSummaryOfPhoto2(null, true);
      }
      if (i % 10 == 0) {
        global.summaryOfLocationData = await compute(
            updateSummaryOfLocationDataFromInfo2_compute, [infoFromFiles]);

        await writeSummaryOfLocation2(null, true);
      }
    }
    //update the summaryOflocation only on the specific date.
    global.summaryOfPhotoData = await compute(updateSummaryOfPhotoFromInfo,
        [global.setOfDates, global.summaryOfPhotoData]);

    global.summaryOfLocationData = await compute(
        updateSummaryOfLocationDataFromInfo_compute,
        [global.setOfDates, global.summaryOfLocationData, infoFromFiles]);

    // await writeInfo(null, true);
    await writeInfoAsJson(null, true);
    await writeSummaryOfLocation2(null, true);
    await writeSummaryOfPhoto2(null, true);

    print("executeSlowProcesses done,executed in ${stopwatch.elapsed}");
  }

  Future<List<String>> getAllFiles() async {
    List<String> files = [];
    List newFiles = [];
    for (int i = 0; i < Directories.selectedDirectories.length; i++) {
      String path = Directories.selectedDirectories.elementAt(i);

      newFiles = Glob("$path/*.jpg").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));

      newFiles = Glob("$path/*.png").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));
    }
    files = files.where((element) => !element.contains('thumbnail')).toList();
    files.sort((a, b) => a.compareTo(b));
    // dataStateProvider.setFiles(files);
    return files;
  }

  // i) check whether this file is contained in Info
  // ii) check whether this file is saved previously.
  Future<List<String>?> matchFilesAndInfo() async {
    List<String>? filesNotUpdated = [];
    List<String> filenamesFromInfo = infoFromFiles.keys.toList();

    for (int i = 0; i < files.length; i++) {
      String filename = files.elementAt(i);
      if (i % 1000 == 0) print("matchFilesAndInfo : $i / ${files.length}");

      bool isContained = filenamesFromInfo.contains(filename);
      if (!isContained) {
        filesNotUpdated.add(filename);
        continue;
      }

      filenamesFromInfo.remove(filename);

      DateTime? dateTimeInInfo = infoFromFiles[filename]?.datetime;
      Coordinate? coordinateInInfo = infoFromFiles[filename]?.coordinate;

      if (dateTimeInInfo == null || coordinateInInfo?.latitude == null) {
        filesNotUpdated.add(filename);
        continue;
      }
    }
    if (filesNotUpdated == []) return null;
    return filesNotUpdated;
  }

  Future<List<String>?> matchFilesAndInfo2() async {
    List<String>? filesNotUpdated = [];
    List<String> filenamesFromInfo = infoFromFiles.keys.toList();
    filenamesFromInfo.sort((a, b) => a.compareTo(b));
    Map info = {...infoFromFiles};
    int j = 0;
    for (int i = 0; i < files.length; i++) {
      String filename = files.elementAt(i);
      int sublistIndex = j + 100 < filenamesFromInfo.length
          ? j + 100
          : filenamesFromInfo.length;
      bool isContained =
          filenamesFromInfo.sublist(j, sublistIndex).contains(filename);

      if (!isContained) {
        filesNotUpdated.add(filename);
        continue;
      }
      j += 1;

      bool? isUpdated = info[filename]?.isUpdated;

      if (!isUpdated!) {
        filesNotUpdated.add(filename);
        continue;
      }
    }
    if (filesNotUpdated == []) return null;
    return filesNotUpdated;
  }

  Future<void> addFilesToInfo(List<String>? filenames) async {
    if (filenames.runtimeType == null || filenames!.isEmpty) filenames = files;

    for (int i = 0; i < filenames.length; i++) {
      // if (i % 100 == 0) print("addFilesToInfo $i / ${filenames.length}");
      String filename = filenames.elementAt(i);
      if (infoFromFiles[filename] == null) {
        // print("info not found during addFilestoInfo");
        infoFromFiles[filename] = InfoFromFile(isUpdated: false);
      }
    }
  }

  static Future<List> updateDatesFromInfo(List input) async {
    Stopwatch stopwatch = Stopwatch()..start();
    List filesNotUpdated = [];
    Map<String, InfoFromFile> infoFromFiles = {};
    if (input.isNotEmpty) {
      infoFromFiles = input[0];
      filesNotUpdated = input[1];
    }

    print("updateDatesFromInfo aa: ${stopwatch.elapsed}");
    List<String?> dates = [];
    List<DateTime?> datetimes = [];

    List<InfoFromFile> values = infoFromFiles.values.toList();

    print("updateDatesFromInfo0 : ${stopwatch.elapsed}");

    for (int i = 0; i < values.length; i++) {
      dates.add(values.elementAt(i).date);
      datetimes.add(values.elementAt(i).datetime);
    }
    print("updateDatesFromInfo 1: ${stopwatch.elapsed}");

    global.dates = [...dates];
    global.datetimes = [...datetimes];
    // print("date during init, ${dates.length}");
    dates.removeWhere((i) => i == null);
    datetimes.removeWhere((i) => i == null);
    global.setOfDates = dates;
    global.setOfDatetimes = datetimes;
    print("updateDatesFromInfo 2: ${stopwatch.elapsed}");
    return [
      global.setOfDates,
      global.setOfDatetimes,
      global.dates,
      global.datetimes
    ];
  }

  Future<void> updateDateOnInfo(List<String>? filenames) async {
    if (filenames == null || filenames.isEmpty)
      filenames = infoFromFiles.keys.toList();

    for (int i = 0; i < filenames.length; i++) {
      String filename = filenames.elementAt(i);
      String? inferredDatetime = inferDatetimeFromFilename(filename);
      // print(inferredDatetime);
      if (inferredDatetime != null) {
        infoFromFiles[filename]?.datetime = DateTime.parse(inferredDatetime);
        infoFromFiles[filename]?.date = inferredDatetime.substring(0, 8);

        // if (i % 1000 == 0)
        //   print("updateDateOnInfo : $i / ${filenames.length},"
        //       "$filename, ${infoFromFiles[filename].toString()}");
      }
      // print("updateDateOnInfo : $i / ${filenames.length},"
      //     "$filename, ${infoFromFiles[filename].toString()}");
    }
  }

  Future<void> updateExifOnInfo(List<String>? filenames) async {
    if (filenames == null) filenames = infoFromFiles.keys.toList();

    for (int i = 0; i < filenames.length; i++) {
      String filename = filenames.elementAt(i);
      List ExifData = await getExifInfoOfFile(filename);
      if (i % 100 == 0)
        print(
            "updateExifOninfo : $i / ${filenames.length}, $filename, ${ExifData[0]}, ${ExifData[1]}");
      infoFromFiles[filename]?.coordinate = ExifData[1];

      if (ExifData[1] != null) {
        infoFromFiles[filename]?.distance = calculateDistanceToRef(ExifData[1]);
      }

      //if datetime is updated from filename, then does not overwrite with exif
      if (infoFromFiles[filename]?.datetime != null) continue;

      //update the datetime of EXif if there is datetime is null from filename
      // print("filename : $filename, ExifData : ${ExifData[0]}");
      if ((ExifData[0] != null) &
          (ExifData[0] != "") &
          (ExifData[0] != "null")) {
        infoFromFiles[filename]?.datetime = DateTime.parse(ExifData[0]);
        infoFromFiles[filename]?.date = ExifData[0].substring(0, 8);
        continue;
      }

      //if there is no info from filename and exif, then use changed datetime.
      DateTime datetime =
          DateTime.parse(formatDatetime(FileStat.statSync(filename).changed));
      infoFromFiles[filename]?.datetime = datetime;
      infoFromFiles[filename]?.date = formatDate(datetime);
    }
  }

  //input : [filenames, infoFromFiles]
  Future<Map<String, InfoFromFile>> updateExifOnInfo_compute(List input) async {
    List<String> filenames = input[0];
    infoFromFiles = input[1];
    if (filenames == null) filenames = infoFromFiles.keys.toList();

    for (int i = 0; i < filenames.length; i++) {
      String filename = filenames.elementAt(i);
      List ExifData = await getExifInfoOfFile(filename);

      if (i % 100 == 0)
        print(
            "updateExifOninfo : $i / ${filenames.length}, $filename, ${ExifData[0]}, ${ExifData[1]}");
      infoFromFiles[filename]?.coordinate = ExifData[1];

      if (ExifData[1] != null) {
        infoFromFiles[filename]?.distance = calculateDistanceToRef(ExifData[1]);
      }

      infoFromFiles[filename]?.isUpdated = true;
      //if datetime is updated from filename, then does not overwrite with exif
      if (infoFromFiles[filename]?.datetime != null) continue;

      //update the datetime of EXif if there is datetime is null from filename
      // print("filename : $filename, ExifData : ${ExifData[0]}");
      if ((ExifData[0] != null) &
          (ExifData[0] != "") &
          (ExifData[0] != "null")) {
        infoFromFiles[filename]?.datetime = DateTime.parse(ExifData[0]);
        infoFromFiles[filename]?.date = ExifData[0].substring(0, 8);
        continue;
      }

      //if there is no info from filename and exif, then use changed datetime.
      DateTime datetime =
          DateTime.parse(formatDatetime(FileStat.statSync(filename).changed));
      infoFromFiles[filename]?.datetime = datetime;
      infoFromFiles[filename]?.date = formatDate(datetime);
    }
    return infoFromFiles;
  }

  static Future<Map<String, int>> updateSummaryOfPhotoFromInfo(
      List input) async {
    List dates = global.dates;
    if (input.isNotEmpty) {
      dates = input[0];
      global.summaryOfPhotoData = input[1];
    }
    // dates.removeWhere((i) => i == null);
    Map<String, int> counts = {};

    // dates.map((e) => counts.containsKey(e) ? counts[e]++ : counts[e] = 1);
    for (int i = 0; i < dates.length; i++) {
      String? date = dates[i];
      if (date == null) continue;
      bool isContained = counts.containsKey(date);
      if (isContained) {
        counts[date] = counts[date]! + 1;
        continue;
      }
      counts[date] = 1;
    }

    global.summaryOfPhotoData = counts;
    return counts;
  }

  Future<Map<String, double>> updateSummaryOfLocationDataFromInfo2_compute(
      List input) async {
    Map<String, InfoFromFile> infoFromFiles = input[0];
    var infoFromFiles2 = [...infoFromFiles.values];
    Map<String, double> distances = {};

    // dates.map((e) => counts.containsKey(e) ? counts[e]++ : counts[e] = 1);
    for (int i = 0; i < infoFromFiles2.length; i++) {
      InfoFromFile infoFromFile = infoFromFiles2.elementAt(i);
      String? date = infoFromFile.date;
      if (date == null) continue;

      bool isContained = distances.containsKey(date);
      bool isNull = infoFromFile.distance == null ? true : false;

      if (isNull) {
        continue;
      }

      if (isContained) {
        distances[date] = (distances[date]! > infoFromFile.distance!
            ? distances[date]
            : infoFromFile.distance)!;
        continue;
      }
      distances[date] = infoFromFile.distance!;
    }
    return distances;
  }

  Future<Map> updateSummaryOfLocationDataFromInfo(
      List<String>? datesOutOfDate) async {
    List listOfDates = [];
    listOfDates =
        (datesOutOfDate == null) ? global.setOfDates.toList() : datesOutOfDate!;

    print("updateSummaryOfLocationData..");

    Set setOfDates = listOfDates.toSet();
    for (int i = 0; i < setOfDates.length; i++) {
      if (i % 100 == 0)
        print("updateSummaryOfLocationData.. $i / ${setOfDates.length}");
      String date = setOfDates.elementAt(i);
      global.summaryOfLocationData[date] =
          locationDataManager.getMaxDistanceOfDate(date);
    }
    return global.summaryOfPhotoData;
  }

  //input : [global.dates, global.summaryOfPhotoData, infoFromFiles]
  static Future<Map<String, double>>
      updateSummaryOfLocationDataFromInfo_compute(List input) async {
    List listOfDates = input[0].toList();
    Map<String, InfoFromFile> infoFromFiles = input[2];

    global.setOfDates = input[0];
    print("updateSummaryOfLocationData..");
    LocationDataManager locationDataManager = LocationDataManager();
    Set setOfDates = listOfDates.toSet();
    // Stopwatch stopwatch = new Stopwatch();
    for (int i = 0; i < setOfDates.length; i++) {
      if (i % 100 == 0) {
        // stopwatch..start();
        print("updateSummaryOfLocationData.. $i / ${setOfDates.length}");
      }
      String date = setOfDates.elementAt(i);
      input[1][date] = locationDataManager.getMaxDistanceOfDate(date);
    }
    return input[1];
  }

  Future<List<String>> resetInfoFromFiles() async {
    List<String> files = [];
    List newFiles = [];
    for (int i = 0; i < Directories.selectedDirectories.length; i++) {
      String path = Directories.selectedDirectories.elementAt(i);

      newFiles = Glob("$path/*.jpg").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));

      newFiles = Glob("$path/*.png").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));
    }

    files = files.where((element) => !element.contains('thumbnail')).toList();

    infoFromFiles = {};
    infoFromFiles.addAll(
        Map.fromIterable(files, key: (v) => v, value: (v) => InfoFromFile()));

    return files;
  }

  Future<void> writeInfoAsJson(List<String>? filenames, bool overwrite) async {
    if (overwrite == null) overwrite = false;
    if (filenames == null) filenames = infoFromFiles.keys.toList();

    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/InfoOfFiles.json');

    // await file.writeAsString(jsonEncode(input));
    var test = {};
    for (int i = 0; i < filenames.length; i++) {
      String filename = filenames.elementAt(i);
      Map mapOfInfo = infoFromFiles[filename]!.toMap();
      test[filename] = mapOfInfo;
    }
    file.writeAsString(jsonEncode(test));
  }

  Future<void> writeInfo(List<String>? filenames, bool overwrite) async {
    if (overwrite == null) overwrite = false;
    if (filenames == null) filenames = infoFromFiles.keys.toList();

    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/InfoOfFiles.csv');

    if (!((await file.exists())) || overwrite) {
      print("overwritting");
      await file.writeAsString(
          'filename,datetime,date,latitude,longitude,distance,isUpdated\n',
          mode: FileMode.write);
    }
    String stringToWrite = "";
    for (int i = 0; i < filenames.length; i++) {
      String filename = filenames.elementAt(i);
      stringToWrite += '${filename},'
          '${infoFromFiles[filename]!.datetime},'
          '${infoFromFiles[filename]!.date},'
          '${infoFromFiles[filename]!.coordinate?.latitude},'
          '${infoFromFiles[filename]!.coordinate?.longitude},'
          '${infoFromFiles[filename]!.distance},'
          '${infoFromFiles[filename]!.isUpdated}\n';

      if (i % 100 == 0) {
        await file.writeAsString(stringToWrite, mode: FileMode.append);
        stringToWrite = "";
        print("writingInfo.. $i/${filenames.length}");
      }
      ;
    }
    await file.writeAsString(stringToWrite, mode: FileMode.append);
  }

  Future<Map<String, InfoFromFile>> readInfoFromJson() async {
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/InfoOfFiles.json');

    bool isFileExist = await file.exists();
    if (!isFileExist) return {};
    var data = await file.readAsString();
    Map mapFromJson = jsonDecode(data);

    Map<String, InfoFromFile> test = {};
    List filenames = mapFromJson.keys.toList();
    for (int i = 0; i < mapFromJson.length; i++) {
      String filename = filenames.elementAt(i);
      test[filename] = InfoFromFile(map: mapFromJson[filename]);
    }
    infoFromFiles = test;
    infoFromFiles = test;

    return test;
  }

  Future<Map<String, InfoFromFile>> readInfo(List input) async {
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/InfoOfFiles.csv');

    bool isFileExist = await file.exists();
    if (!isFileExist) return {};

    var data = await openFile(file.path);
    // Stopwatch stopwatch2 = Stopwatch()..start();
    for (int i = 1; i < data.length; i++) {
      // for (int i = 1; i < 100; i++) {
      if (data[i].length < 2) return {};
      // if (i % 1000 == 0)
      // print("readInfo.. $i / ${data.length}, ${data[i]}");
      // Stopwatch stopwatch = Stopwatch()..start();
      InfoFromFile infoFromFile = InfoFromFile();
      var data_temp = data[i];
      int lengthOfData = data_temp.length;

      // print("$i, time elapsed : ${stopwatch.elapsed}");
      infoFromFile.datetime = parseToDatetime(data_temp[lengthOfData - 6]);
      // print("$i, time elapsed : ${stopwatch.elapsed}");

      infoFromFile.date = parseToString(data_temp[lengthOfData - 5]);

      // print("$i, time elapsed : ${stopwatch.elapsed}");
      infoFromFile.coordinate = Coordinate(
          parseToDouble(data_temp[lengthOfData - 4]),
          parseToDouble(data_temp[lengthOfData - 3]));
      // print("$i, time elapsed : ${stopwatch.elapsed}");

      infoFromFile.distance = data_temp[lengthOfData - 2] == "null"
          ? null
          : parseToDouble(data_temp[lengthOfData - 2]);
      // print("$i, time elapsed : ${stopwatch.elapsed}");
      // print(data_temp['lengthOfData']);
      infoFromFile.isUpdated =
          data_temp[lengthOfData - 1].toLowerCase() == 'true';

      String filename = data_temp[0];
      // print("$i, time elapsed : ${stopwatch.elapsed}");

      if (lengthOfData > 6) {
        filename = "";
        for (int j = 0; j < lengthOfData - 6; j++) {
          filename += data_temp[j] + ',';
        }
        filename = filename.substring(0, filename.length - 1);
      }
      // print("$i, time elapsed : ${stopwatch.elapsed}");

      infoFromFiles[filename] = infoFromFile;
      infoFromFiles[filename] = infoFromFile;
      // print("$i, time elapsed : ${stopwatch.elapsed}");
    }
    // print(" time elapsed : ${stopwatch2.elapsed}");
    return infoFromFiles;
  }

  Future<void> writeSummaryOfLocation2(
      List<String>? datesOutOfDate, bool overwrite) async {
    Set setOfDates = global.setOfDates.toSet();
    if (overwrite == null) overwrite = false;
    if (datesOutOfDate != null) {
      setOfDates = datesOutOfDate.toSet();
    }
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/summaryOfLocation.csv');

    if (!((await file.exists())) || overwrite) {
      print("overwritting");
      await file.writeAsString('date,distance\n', mode: FileMode.write);
    }

    var summaryOfLocation = global.summaryOfLocationData;
    String stringToWrite = "";
    for (int i = 0; i < setOfDates.length; i++) {
      if (i % 100 == 0)
        print("writingSummaryOfLocation.. $i/${setOfDates.length}");

      String date = setOfDates.elementAt(i);
      stringToWrite += '${date},${summaryOfLocation[date]}\n';
    }
    await file.writeAsString(stringToWrite, mode: FileMode.append);
  }

  Future<void> readSummaryOfLocation() async {
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/summaryOfLocation.csv');

    bool isFileExist = await file.exists();
    if (!isFileExist) return;

    var data = await openFile(file.path);
    for (int i = 1; i < data.length; i++) {
      if (data[i].length < 2) return;
      // if (i % 100 == 0)
      //   print("readSummaryOfLocation.. $i / ${data.length}, ${data[i]}");
      if ([null, "null"].contains(data[i][1])) {
        global.summaryOfLocationData[data[i][0].toString()] = 0.0;
        continue;
      }
      global.summaryOfLocationData[data[i][0].toString()] = data[i][1];
    }
    summaryOfLocationData = global.summaryOfLocationData;
    // dataStateProvider.setSummaryOfLocationData(global.summaryOfLocationData);
  }

  Future<void> writeSummaryOfPhoto2(
      List<String>? datesOutOfDate, bool overwrite) async {
    Set setOfDates = global.setOfDates.toSet();
    if (overwrite == null) overwrite = false;
    if (datesOutOfDate != null) {
      setOfDates = datesOutOfDate.toSet();
    }
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/summaryOfPhoto.csv');

    if (!((await file.exists())) || overwrite) {
      print("overwritting");
      await file.writeAsString('date,numberOfPhoto\n', mode: FileMode.write);
    }

    var summaryOfPhoto = global.summaryOfPhotoData;
    String stringToWrite = "";
    for (int i = 0; i < setOfDates.length; i++) {
      if (i % 100 == 0) print("writingInfo.. $i/${setOfDates.length}");
      String date = setOfDates.elementAt(i);
      stringToWrite += '${date},${summaryOfPhoto[date]}\n';
    }
    await file.writeAsString(stringToWrite, mode: FileMode.append);
  }

  Future<void> readSummaryOfPhoto() async {
    final Directory? directory = await getApplicationDocumentsDirectory();
    final File file = File('${directory?.path}/summaryOfPhoto.csv');

    bool isFileExist = await file.exists();
    if (!isFileExist) return;

    var data = await openFile(file.path);
    for (int i = 1; i < data.length; i++) {
      if (data[i].length < 2) return;
      // if (i % 100 == 0)
      //   print("readSummaryOfPhoto.. $i / ${data.length}, ${data[i]}");
      global.summaryOfPhotoData[data[i][0].toString()] = data[i][1];
    }
    summaryOfPhotoData = global.summaryOfPhotoData;
    // dataStateProvider.setSummaryOfPhotoData(global.summaryOfPhotoData);
  }
}

DateTime? parseToDatetime(input) {
  if (input == null) return null;
  if (input.runtimeType == String) {
    try {
      return DateTime.parse(input);
    } catch (e) {
      print("error in parseToDatetime, invalid format? $e");
      return null;
    }
  }
  return input;
}

String? parseToString(input) {
  if (input == "null") return null;
  if (input == null) return null;
  return input.toString();
}

double? parseToDouble(input) {
  if (input == "null") return null;
  if (input == null) return null;
  if (input.runtimeType == "String") return double.parse(input);
  if (input.runtimeType == double) return input;
  if (input.runtimeType == int) return input.toDouble();
  return double.parse(input);
}
