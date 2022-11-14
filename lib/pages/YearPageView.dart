import 'package:flutter/material.dart';
import 'package:test_location_2nd/StateProvider/StateProvider.dart';
import 'YearPage.dart';
import 'package:provider/provider.dart';

import 'package:test_location_2nd/StateProvider/YearPageStateProvider.dart';

class YearPageView extends StatelessWidget {
  YearPageView({Key? key}) : super(key: key) {}
  int year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Consumer<YearPageStateProvider>(
      builder: (context, product, child) => PageView.builder(
          physics:
              Provider.of<YearPageStateProvider>(context, listen: true).isZoomIn
                  ? NeverScrollableScrollPhysics()
                  : BouncingScrollPhysics(),
          controller: PageController(
              viewportFraction: 1.0,
              initialPage:
                  Provider.of<YearPageStateProvider>(context, listen: false)
                      .index),
          itemCount: 20,
          reverse: true,
          itemBuilder: (BuildContext context, int index) {
            year = DateTime.now().year - index;
            return YearPage(year);
          }),
    ));
  }
}
