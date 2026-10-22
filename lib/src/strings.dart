import 'package:flutter/widgets.dart';

class AppStrings {
  static const List<Locale> supportedLocales = [Locale('tr'), Locale('en')];

  static const Map<String, Map<String, String>> _values = {
    'tr': {
      'timer': 'Zamanlayıcı',
      'stats': 'İstatistik',
      'tasks': 'Görevler',
      'settings': 'Ayarlar',
      'focusMode': 'Odak',
      'workMode': 'Çalışma',
      'shortBreakMode': 'Kısa Mola',
      'longBreakMode': 'Uzun Mola',
      'focusDescription': 'Konsantrasyonu koru',
      'shortBreakDescription': 'Kısa nefes al',
      'longBreakDescription': 'Daha uzun dinlen',
      'start': 'Başlat',
      'resume': 'Devam et',
      'pause': 'Duraklat',
      'reset': 'Sıfırla',
      'skip': 'Atla',
      'dailyGoal': 'Günlük hedef',
      'goalReached': 'Bugünkü hedefe ulaştın!',
      'activeTask': 'Odaklanılan görev',
      'noActiveTask': 'Görev seç (isteğe bağlı)',
      'chooseTask': 'Görev seç',
      'none': 'Görev yok',
      'cycle': 'Uzun molaya kalan',
      'sessionFinishWork': 'Çalışma süresi bitti. Mola zamanı!',
      'sessionFinishBreak': 'Mola bitti. Odak moduna dön!',
      'notificationTitleWork': 'Pomodoro tamamlandı',
      'notificationTitleBreak': 'Mola bitti',
      'notificationBodyWork': 'Harika iş! Şimdi kısa bir mola ver.',
      'notificationBodyBreak': 'Tekrar odaklanmaya hazır mısın?',
      'notificationChannel': 'Zamanlayıcı bildirimleri',
      'taskList': 'Görev listesi',
      'newTaskHint': 'Yeni görev ekle',
      'noTasks': 'Henüz görev yok. Üzerinde çalışacağın ilk işi ekle.',
      'addTask': 'Görev ekle',
      'deleteTask': 'Görevi sil',
      'taskDeleted': 'Görev silindi',
      'undo': 'Geri al',
      'clearDone': 'Tamamlananları temizle',
      'setActive': 'Odak görevi yap',
      'pomodoroCount': 'pomodoro',
      'openTasks': 'Açık',
      'doneTasks': 'Tamamlanan',
      'today': 'Bugün',
      'thisWeek': 'Bu hafta',
      'week': '7 gün',
      'month': '30 gün',
      'focusTime': 'Odak süresi',
      'totalFocus': 'Toplam odak',
      'dailyAverage': 'Günlük ortalama',
      'bestDay': 'En iyi gün',
      'streak': 'Seri',
      'days': 'gün',
      'pomodoros': 'Pomodoro',
      'focusByDay': 'Günlere göre odak süresi',
      'focusByTask': 'Görevlere göre odak',
      'noTaskData': 'Görevle ilişkilendirilmiş oturum yok.',
      'goal': 'Hedef',
      'tapBarHint': 'Ayrıntı için bir çubuğa dokun',
      'noStats':
          'İlk pomodoronu tamamladığında istatistiklerin burada görünecek.',
      'timerSection': 'Zamanlayıcı',
      'durations': 'Süreler',
      'longBreakEvery': 'Uzun mola sıklığı',
      'every': 'her',
      'goalSection': 'Hedef',
      'pomodorosPerDay': 'pomodoro / gün',
      'behavior': 'Davranış',
      'autoAdvance': 'Otomatik geçiş',
      'autoAdvanceSubtitle': 'Süre bitince sonraki moda geç',
      'autoStart': 'Otomatik başlat',
      'autoStartSubtitle': 'Sonraki süre kendiliğinden başlasın',
      'notifications': 'Bildirimler',
      'notificationsSubtitle': 'Süre bittiğinde uyarı göster',
      'keepScreenOn': 'Ekranı açık tut',
      'keepScreenOnSubtitle': 'Sayaç çalışırken ekran kapanmasın',
      'haptics': 'Titreşim',
      'hapticsSubtitle': 'Süre bitince kısa titreşim',
      'language': 'Dil',
      'systemLanguage': 'Sistem dili',
      'data': 'Veriler',
      'resetStats': 'İstatistikleri sıfırla',
      'resetStatsConfirm':
          'Tüm oturum geçmişi kalıcı olarak silinecek. Emin misin?',
      'cancel': 'Vazgeç',
      'delete': 'Sil',
      'statsReset': 'İstatistikler sıfırlandı',
      'about': 'Hakkında',
      'version': 'Sürüm',
      'privacyPolicy': 'Gizlilik politikası',
      'privacyText':
          'Sumera Pomodoro hiçbir kişisel veri toplamaz, paylaşmaz veya '
          'internete göndermez. Görevlerin, ayarların ve istatistiklerin '
          'yalnızca bu cihazda saklanır ve uygulamayı kaldırdığında silinir. '
          'Uygulama yalnızca duyuru ve ayar dosyasını indirmek için internete '
          'bağlanır; bu sırada senden hiçbir bilgi gönderilmez. Bildirim izni '
          'yalnızca süre bittiğinde seni uyarmak için kullanılır.',
      'licenses': 'Açık kaynak lisansları',
      'close': 'Kapat',
      'endsAt': 'Bitiş:',
      'ongoingChannel': 'Çalışan sayaç',
      'ongoingChannelDescription': 'Sayaç çalışırken kalan süreyi gösterir',
      'showOngoing': 'Bildirimde geri sayım',
      'showOngoingSubtitle': 'Kalan süre bildirim panelinde görünsün',
      'fullscreen': 'Tam ekran',
      'exitFullscreen': 'Tam ekrandan çık',
      'fullscreenHint': 'Kontroller için ekrana dokun',
      'editTask': 'Görevi düzenle',
      'taskTitle': 'Görev adı',
      'estimate': 'Tahmini pomodoro',
      'noEstimate': 'Yok',
      'save': 'Kaydet',
      'activity': 'Son 16 hafta',
      'less': 'Az',
      'more': 'Çok',
      'updateAvailable': 'Yeni sürüm hazır',
      'updateAvailableBody':
          'Yeni özellikler ve iyileştirmeler için uygulamayı güncelle.',
      'updateRequired': 'Güncelleme gerekli',
      'updateRequiredBody':
          'Bu sürüm artık desteklenmiyor. Devam etmek için uygulamayı güncelle.',
      'update': 'Güncelle',
      'dismiss': 'Kapat',
      'quoteOfDay': 'Günün sözü',
      'learnMore': 'Daha fazla',
      'rateApp': 'Uygulamayı değerlendir',
      'sendFeedback': 'Geri bildirim gönder',
      'minutesShort': 'dk',
      'hoursShort': 'sa',
    },
    'en': {
      'timer': 'Timer',
      'stats': 'Stats',
      'tasks': 'Tasks',
      'settings': 'Settings',
      'focusMode': 'Focus',
      'workMode': 'Focus',
      'shortBreakMode': 'Short Break',
      'longBreakMode': 'Long Break',
      'focusDescription': 'Stay in the zone',
      'shortBreakDescription': 'Take a quick breath',
      'longBreakDescription': 'Rest a bit longer',
      'start': 'Start',
      'resume': 'Resume',
      'pause': 'Pause',
      'reset': 'Reset',
      'skip': 'Skip',
      'dailyGoal': 'Daily goal',
      'goalReached': 'You reached today\'s goal!',
      'activeTask': 'Working on',
      'noActiveTask': 'Pick a task (optional)',
      'chooseTask': 'Choose a task',
      'none': 'No task',
      'cycle': 'Until long break',
      'sessionFinishWork': 'Focus session finished. Time for a break!',
      'sessionFinishBreak': 'Break finished. Back to focus!',
      'notificationTitleWork': 'Pomodoro complete',
      'notificationTitleBreak': 'Break finished',
      'notificationBodyWork': 'Great work! Take a short break now.',
      'notificationBodyBreak': 'Ready to focus again?',
      'notificationChannel': 'Timer notifications',
      'taskList': 'Task list',
      'newTaskHint': 'Add a new task',
      'noTasks': 'No tasks yet. Add the first thing you will work on.',
      'addTask': 'Add task',
      'deleteTask': 'Delete task',
      'taskDeleted': 'Task deleted',
      'undo': 'Undo',
      'clearDone': 'Clear completed',
      'setActive': 'Focus on this',
      'pomodoroCount': 'pomodoros',
      'openTasks': 'Open',
      'doneTasks': 'Completed',
      'today': 'Today',
      'thisWeek': 'This week',
      'week': '7 days',
      'month': '30 days',
      'focusTime': 'Focus time',
      'totalFocus': 'Total focus',
      'dailyAverage': 'Daily average',
      'bestDay': 'Best day',
      'streak': 'Streak',
      'days': 'days',
      'pomodoros': 'Pomodoros',
      'focusByDay': 'Focus time by day',
      'focusByTask': 'Focus by task',
      'noTaskData': 'No sessions linked to a task yet.',
      'goal': 'Goal',
      'tapBarHint': 'Tap a bar for details',
      'noStats': 'Your statistics will appear here after your first pomodoro.',
      'timerSection': 'Timer',
      'durations': 'Durations',
      'longBreakEvery': 'Long break interval',
      'every': 'every',
      'goalSection': 'Goal',
      'pomodorosPerDay': 'pomodoros / day',
      'behavior': 'Behavior',
      'autoAdvance': 'Auto advance',
      'autoAdvanceSubtitle': 'Switch to the next mode when time is up',
      'autoStart': 'Auto start',
      'autoStartSubtitle': 'Start the next session by itself',
      'notifications': 'Notifications',
      'notificationsSubtitle': 'Alert me when time is up',
      'keepScreenOn': 'Keep screen on',
      'keepScreenOnSubtitle': 'Prevent the screen from sleeping while running',
      'haptics': 'Vibration',
      'hapticsSubtitle': 'Short vibration when time is up',
      'language': 'Language',
      'systemLanguage': 'System language',
      'data': 'Data',
      'resetStats': 'Reset statistics',
      'resetStatsConfirm':
          'All session history will be permanently deleted. Are you sure?',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'statsReset': 'Statistics reset',
      'about': 'About',
      'version': 'Version',
      'privacyPolicy': 'Privacy policy',
      'privacyText':
          'Sumera Pomodoro does not collect, share or upload any personal data. '
          'Your tasks, settings and statistics are stored only on this '
          'device and are removed when you uninstall the app. The app '
          'connects to the internet only to download its announcement and '
          'settings file; no information about you is sent. The '
          'notification permission is used only to alert you when a '
          'session ends.',
      'licenses': 'Open source licenses',
      'close': 'Close',
      'endsAt': 'Ends at',
      'ongoingChannel': 'Running timer',
      'ongoingChannelDescription':
          'Shows the remaining time while the timer runs',
      'showOngoing': 'Countdown in notification',
      'showOngoingSubtitle':
          'Show the remaining time in the notification shade',
      'fullscreen': 'Full screen',
      'exitFullscreen': 'Exit full screen',
      'fullscreenHint': 'Tap the screen for controls',
      'editTask': 'Edit task',
      'taskTitle': 'Task name',
      'estimate': 'Estimated pomodoros',
      'noEstimate': 'None',
      'save': 'Save',
      'activity': 'Last 16 weeks',
      'less': 'Less',
      'more': 'More',
      'updateAvailable': 'A new version is ready',
      'updateAvailableBody':
          'Update the app to get new features and improvements.',
      'updateRequired': 'Update required',
      'updateRequiredBody':
          'This version is no longer supported. Please update to continue.',
      'update': 'Update',
      'dismiss': 'Dismiss',
      'quoteOfDay': 'Quote of the day',
      'learnMore': 'Learn more',
      'rateApp': 'Rate the app',
      'sendFeedback': 'Send feedback',
      'minutesShort': 'min',
      'hoursShort': 'h',
    },
  };

  /// Remote overrides from the live config (language -> key -> text).
  static Map<String, Map<String, String>> overrides = const {};

  static String forLanguage(String languageCode, String key) {
    return overrides[languageCode]?[key] ??
        _values[languageCode]?[key] ??
        _values['en']?[key] ??
        key;
  }

  static String of(BuildContext context, String key) {
    return forLanguage(Localizations.localeOf(context).languageCode, key);
  }

  /// "1 sa 25 dk" / "1 h 25 min"
  static String duration(BuildContext context, int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hs = of(context, 'hoursShort');
    final ms = of(context, 'minutesShort');
    if (h == 0) return '$m $ms';
    if (m == 0) return '$h $hs';
    return '$h $hs $m $ms';
  }
}

extension AppStringsContext on BuildContext {
  String tr(String key) => AppStrings.of(this, key);
}
