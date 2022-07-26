import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'DayPageView.dart';
import 'package:provider/provider.dart';
import 'package:lateDiary/StateProvider/DayPageStateProvider.dart';
import 'package:lateDiary/StateProvider/NavigationIndexStateProvider.dart';

class DayPage extends StatelessWidget {
  DayPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var navigation =
        Provider.of<NavigationIndexProvider>(context, listen: false);
    return Scaffold(
        body: Consumer<DayPageStateProvider>(
          builder : (context, product, chile) => PageView.builder(
              dragStartBehavior: DragStartBehavior.down,
              physics: product.isZoomIn
                  ? NeverScrollableScrollPhysics()
                  : BouncingScrollPhysics(),
              controller: PageController(
                  initialPage: product.availableDates
                      .indexOf(navigation.date)),
              itemCount: product.availableDates.length,
              reverse: false,
              itemBuilder: (BuildContext context, int index) {
                String date = product.availableDates[index];
                return DayPageView(date, product);

              }),
        ));
  }


}
