import 'package:exif/exif.dart';
import 'package:glob/list_local_fs.dart';
import 'package:test_location_2nd/Util/DateHandler.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:glob/glob.dart';
import 'package:test_location_2nd/Util/global.dart' as global;

List<String> pathsToPhoto = [
  "/storage/emulated/0/DCIM",
  "/storage/emulated/0/DCIM/Camera",
  "/storage/emulated/0/Pictures",
  "/storage/emulated/0/Pictures/*",
];

class PhotoDataManager {
  List datetimes = [];
  List dates = [];
  List<String> files = [];

  PhotoDataManager() {
    // init();
  }

  Future<void> init() async {
    files = await getAllFiles();
    datetimes = getDatetimesFromFilnames(files);
    print("localPHotoDataManager, datetime : $datetimes");
  }

  Future getAllFiles() async {
    List<String> files = [];
    List newFiles = [];
    for (int i = 0; i < pathsToPhoto.length; i++) {
      String path = pathsToPhoto.elementAt(i);

      newFiles = await Glob("$path/*.jpg").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));

      newFiles = await Glob("$path/*.png").listSync();
      files.addAll(List.generate(
          newFiles.length, (index) => newFiles.elementAt(index).path));
    }
    newFiles = newFiles.where((element)=>!element.path.contains('thumbnail')).toList();
    return files;
  }

  List getDatetimesFromFilnames(files) {
    print("getDatesFromFilenames : $files");
    List inferredDatetimesOfFiles = List.generate(files.length,
        (index) => inferDatetimeFromFilename(files.elementAt(index)));

    print("getDatesFromFilenames : $inferredDatetimesOfFiles");
    inferredDatetimesOfFiles = List.generate(
        inferredDatetimesOfFiles.length,
        (index) =>
            inferredDatetimesOfFiles.elementAt(index) ??
            formatDate(FileStat.statSync(files[index]).changed));

    print("getDatesFromFilenames : $inferredDatetimesOfFiles");
    this.datetimes = inferredDatetimesOfFiles;
    this.dates = List.generate(inferredDatetimesOfFiles.length,
        (i) => inferredDatetimesOfFiles.elementAt(i).substring(0, 8));
    print(dates);

    global.files = this.files;
    global.dates = this.dates;
    global.datetimes = this.datetimes;

    return inferredDatetimesOfFiles;
  }

  String? inferDatetimeFromFilename(filename) {
    //20221010*201020
    RegExp exp1 = RegExp(r"[0-9]{8}\D[0-9]{6}");
    //2022-10-10 20-20-10
    RegExp exp2 =
        RegExp(r"[0-9]{4}\D[0-9]{2}\D[0-9]{2}\D[0-9]{2}\D[0-9]{2}\D[0-9]{2}");
    //timestamp
    RegExp exp3 = RegExp(r"[0-9]{13}");

    if (filename.contains("thumbnail")) {
      return null;
    }

    //order if matching is important. 3->1->2.
    Iterable<RegExpMatch> matches = exp3.allMatches(filename);
    if (matches.length != 0) {
      var date = new DateTime.fromMicrosecondsSinceEpoch(
          int.parse(matches.first.group(0)!) * 1000);
      // print(formatDatetime(date));
      return formatDatetime(date);
    }

    matches = exp1.allMatches(filename);
    if (matches.length != 0) {
      // print(
      //     matches.first.group(0).toString().replaceAll(RegExp(r"[^0-9]"), "_"));
      return matches.first
          .group(0)
          .toString()
          .replaceAll(RegExp(r"[^0-9]"), "_");
    }

    matches = exp2.allMatches(filename);
    if (matches.length != 0) {
      // print(
      //     matches.first.group(0).toString().replaceAll(RegExp(r"[^0-9]"), ""));
      return matches.first
          .group(0)
          .toString()
          .replaceAll(RegExp(r"[^0-9]"), "");
    }
    return null;
  }

  List filterInvalidFiles(files){

    return files;
  }

  Future getPhotoOfDate(String date) async {
    Set indexOfDate = List.generate(
        datetimes.length,
        (i) => (datetimes.elementAt(i).substring(0, 8).contains(date) & (datetimes.elementAt(i).length>8))
            ? i
            : null).toSet();
    indexOfDate.remove(null);

    List filesOfDate = List.generate(
        indexOfDate.length, (i) => files.elementAt(indexOfDate.elementAt(i)));
    List dateOfDate = List.generate(indexOfDate.length,
        (i) => datetimes.elementAt(indexOfDate.elementAt(i)));

          for(int i = 0; i<indexOfDate.length; i++){
        print("${dateOfDate[i]}, ${filesOfDate[i]}");
    }

    return [dateOfDate, filesOfDate];
  }

  Future<String> getExifDateOfFile(String file) async {
    var bytes = await File(file).readAsBytes();
    var data = await readExifFromBytes(bytes);
    // print("date of photo : ${data['Image DateTime'].toString().replaceAll(":", "")}");
    String dateInExif = data['Image DateTime'].toString().replaceAll(":", "");
    return dateInExif;
  }
}

//
//
// String? inferDateFromFilename(filename) {
//   https: //soooprmx.com/%EC%A0%95%EA%B7%9C%ED%91%9C%ED%98%84%EC%8B%9D%EC%9D%98-%EA%B0%9C%EB%85%90%EA%B3%BC-%EA%B8%B0%EC%B4%88-%EB%AC%B8%EB%B2%95/
//   // RegExp exp = RegExp(r"[0-9]{8}\D?[0-9]{6}");
//   RegExp exp1 = RegExp(r"[0-9]{8}\D");
//   RegExp exp2 = RegExp(r"[0-9]{4}\D[0-9]{2}\D[0-9]{2}");
//   RegExp exp3 = RegExp(r"[0-9]{13}");
//
//   if (filename.contains("thumbnail")) {
//     return null;
//   }
//   //order if matching is important. 3->1->2.
//   Iterable<RegExpMatch> matches = exp3.allMatches(filename);
//   if (matches.length != 0) {
//     var date = new DateTime.fromMicrosecondsSinceEpoch(
//         int.parse(matches.first.group(0)!) * 1000);
//     print(formatDatetime(date));
//     return formatDatetime(date);
//   }
//
//   matches = exp1.allMatches(filename);
//   if (matches.length != 0) {
//     print(matches.first
//         .group(0)
//         .toString()
//         .replaceAll(RegExp(r"[^0-9]"), ""));
//     return matches.first
//         .group(0)
//         .toString()
//         .replaceAll(RegExp(r"[^0-9]"), "");
//   }
//
//   matches = exp2.allMatches(filename);
//   if (matches.length != 0) {
//     print(matches.first
//         .group(0)
//         .toString()
//         .replaceAll(RegExp(r"[^0-9]"), ""));
//     return matches.first
//         .group(0)
//         .toString()
//         .replaceAll(RegExp(r"[^0-9]"), "");
//   }
//   return null;
// }