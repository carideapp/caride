import 'package:flutter/material.dart';

class Responsive {
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  static bool isSmallTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 900;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  static double width(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  static double height(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }
  
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}
