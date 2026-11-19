import 'package:flutter/material.dart';

/// The app's root navigator, for opening a screen from outside the widget
/// tree — a tapped notification, a password-recovery link, an expired
/// session.
final appNavigatorKey = GlobalKey<NavigatorState>();

/// The root ScaffoldMessenger, for a message from outside the widget tree
/// (a sign-in link that didn't work).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Which named routes the root navigator has open, so something opening a
/// screen from outside the tree can tell whether it's already there.
final appRoutes = AppRouteTracker();

/// Tells a screen when a page opened on top of it is closed again, so it
/// can show what changed there: Home, after a practice or a booking.
/// Pages only; a sheet or a dialog closing doesn't count.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();

class AppRouteTracker extends NavigatorObserver {
  final _stack = <Route<dynamic>>[];

  bool isOpen(String name) =>
      _stack.any((route) => route.settings.name == name);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _stack.remove(oldRoute);
    if (newRoute != null) _stack.add(newRoute);
  }
}
