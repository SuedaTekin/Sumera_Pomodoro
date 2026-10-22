import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/brand.dart';
import 'src/controller.dart';
import 'src/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Brand.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  if (NotificationService.isSupported) {
    try {
      await NotificationService.initialize();
    } catch (error) {
      debugPrint('Notification setup failed: $error');
    }
  }

  final storage = await AppStorage.open();
  runApp(SumeraApp(controller: PomodoroController(storage)));
}
