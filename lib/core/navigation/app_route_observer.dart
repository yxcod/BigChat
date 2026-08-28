import 'package:flutter/widgets.dart';

/// Shared route observer used by conversation pages to distinguish a mounted
/// page from the route that is actually visible to the user.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
