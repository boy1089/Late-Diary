




import 'package:intl/intl.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
DateTime selectedDate = DateTime(2022, 1, 1);

int mainPageSelectionIndex = 0;

Map summaryOfPhotoData = {};

//Colors
Color kBackGroundColor = Colors.white;
Color kMainColor_warm = Colors.deepOrangeAccent;
// Color kMainColor_warm = Colors.red;

// Color kMainColor_cool = Colors.lightBlueAccent;
Color kMainColor_cool = Colors.white;
int indexForZoomInImage = -1;
bool isImageClicked = false;

Color kMainColor_option =Colors.green;

int animationTime = 200;
double monthPageScrollOffset = 0.0;

int startYear = 2013;

double kMinimumTimeDifferenceBetweenImages = 0.05; //unit is hour

GoogleSignInAccount? currentUser;

List<List<dynamic>> dummyData = [
  [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  [0.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [2.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [3.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [4.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [5.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [6.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [7.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [8.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [9.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [10.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [11.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [12.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [13.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [14.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [15.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [16.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [17.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [18.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [19.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [20.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [21.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [22.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [23.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
  [24.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0],
];