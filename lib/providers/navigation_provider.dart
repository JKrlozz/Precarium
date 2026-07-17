import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  int _tabIndex = 0;
  int get tabIndex => _tabIndex;

  void switchToTab(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }
}
