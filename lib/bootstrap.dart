import 'dart:async';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'app.dart';
import 'package:provider/provider.dart';
import 'package:lateDiary/StateProvider/YearPageStateProvider.dart';
import 'package:lateDiary/StateProvider/DayPageStateProvider.dart';
import 'package:lateDiary/StateProvider/NavigationIndexStateProvider.dart';
import 'package:flutter/material.dart';
import 'package:lateDiary/Data/DataManagerInterface.dart';
import 'package:lateDiary/Util/global.dart' as global;

void bootstrap(int i) {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  YearPageStateProvider yearPageStateProvider =
      YearPageStateProvider(DataManagerInterface(global.kOs));
  DayPageStateProvider dayPageStateProvider =
      DayPageStateProvider(DataManagerInterface(global.kOs));

  runZonedGuarded(
    () => runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DataManagerInterface>(
            create: (context) {
              return DataManagerInterface(global.kOs);
            },
          ),
          ChangeNotifierProvider<NavigationIndexProvider>(
            create: (context) {
              return NavigationIndexProvider();
            },
          ),
          ChangeNotifierProxyProvider<DataManagerInterface,
              YearPageStateProvider>(
            update: (context, dataManager, a) {
              print("on update, $a");
              return yearPageStateProvider
                ..update(DataManagerInterface(global.kOs));
            },
            create: (context) => yearPageStateProvider,
          ),
          ChangeNotifierProxyProvider<DataManagerInterface, DayPageStateProvider>(
            update: (context, dataManager, a) => dayPageStateProvider,
            // update : (context, dataManager, a) =>DayPageStateProvider(dataManager),
            create: (context) {
              return dayPageStateProvider;
            }
          )   ],
        child: App(),
      ),
    ),
    (error, stackTrace) => log(error.toString(), stackTrace: stackTrace),
  );
}
