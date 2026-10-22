import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/brand.dart';
import 'src/controller.dart';
import 'src/remote_config.dart';
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
  final remote = RemoteConfigService(storage.prefs);
  final controller = PomodoroController(storage, remote: remote);
  runApp(SumeraApp(controller: controller));
  // Picks up announcements and changes published after this build.
  unawaited(remote.refresh(force: true));
}
