import 'dart:async';

import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

final StreamController<void> refreshStreamController =
    StreamController<void>.broadcast();
