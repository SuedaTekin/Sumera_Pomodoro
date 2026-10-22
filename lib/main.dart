import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/app.dart';
import 'src/brand.dart';
import 'src/controller.dart';
import 'src/remote_config.dart';
import 'src/services.dart';
import 'src/sync.dart';

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
  final controller = PomodoroController(
    storage,
    remote: remote,
    sync: SyncService(storage.prefs),
  );
  runApp(SumeraApp(controller: controller));

  // Optional build-time project; otherwise it comes from the remote config.
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    unawaited(
      controller.sync!.connect(url, key).then((ok) {
        if (ok) controller.syncNow();
      }),
    );
  }
  // Picks up announcements and changes published after this build.
  unawaited(remote.refresh(force: true));
  unawaited(controller.syncNow());
}
