<p align="center">
  <img src="assets/branding/emblem.png" width="128" alt="Sumera Pomodoro amblemi">
</p>

<h1 align="center">Sumera Pomodoro</h1>

<p align="center">Odaklan. Dinlen. İlerlemeni gör.</p>

<p align="center">
  <a href="https://github.com/SuedaTekin/pomodoro/releases/latest"><b>📲 Son sürümü indir (APK)</b></a>
</p>

## Ekran görüntüleri

<p align="center">
  <img src="store/screenshots/tr/1.png" width="260" alt="Zamanlayıcı">
  <img src="store/screenshots/tr/2.png" width="260" alt="Gökyüzüm">
  <img src="store/screenshots/tr/3.png" width="260" alt="İstatistikler">
</p>
<p align="center">
  <img src="store/screenshots/tr/4.png" width="260" alt="Rozetler">
  <img src="store/screenshots/tr/5.png" width="260" alt="Tam ekran">
  <img src="store/screenshots/tr/6.png" width="260" alt="Odak sesleri">
</p>

<details>
<summary>English screenshots</summary>
<p align="center">
  <img src="store/screenshots/en/1.png" width="260" alt="Timer">
  <img src="store/screenshots/en/2.png" width="260" alt="Sky">
  <img src="store/screenshots/en/3.png" width="260" alt="Stats">
  <img src="store/screenshots/en/4.png" width="260" alt="Badges">
  <img src="store/screenshots/en/5.png" width="260" alt="Full screen">
  <img src="store/screenshots/en/6.png" width="260" alt="Focus sounds">
</p>
</details>

## Özellikler

- **Gökyüzüm (Sumera'ya özgü):** her pomodoro kişisel gökyüzüne bir yıldız; her gün bir takımyıldız
- **14 rozet**, akıllı içgörüler (haftalık değişim, en verimli saat/gün), paylaşılabilir ilerleme kartı
- **Odak sesleri:** yağmur, okyanus, beyaz/pembe/kahverengi gürültü (programla üretilmiş, telifsiz)
- **İlk açılış tanıtımı** (ritim seçimi, bildirim izni) ve uygun anlarda uygulama içi puan isteği
- **6 dil:** Türkçe, English, Español, Deutsch, Français, Português (`lib/src/l10n/`)

- **Zamanlayıcı:** çalışma / kısa mola / uzun mola, ayarlanabilir süreler ve uzun mola sıklığı,
  otomatik geçiş ve otomatik başlatma, atlama ve sıfırlama
- **Doğru sayaç:** bitiş saatine göre çalışır; arka planda ya da uygulama kapatıldığında bile
  süre kaymaz, açıldığında kaldığı yerden devam eder
- **Bildirim:** süre bitince zamanlanmış bildirim (uygulama kapalıyken de gelir), titreşim
- **İstatistikler:** son 7 / 30 günün odak süresi grafiği, toplam ve ortalama süre,
  pomodoro sayısı, gün serisi, görevlere göre dağılım
- **Görevler:** odak görevi seçme, pomodoroların göreve yazılması, kaydırarak silme ve geri alma
- **Günlük hedef**, ekranı açık tutma, sistem/Türkçe/İngilizce dil seçimi
- **Bulut yedekleme (Supabase):** anonim hesapla görev ve oturum yedeği, çevrimdışı öncelikli
  eşitleme, kullanıcı tarafından buluttaki verileri silme
- **Uzaktan yönetim:** duyurular, günün sözü, metinler, varsayılan ayarlar, özellik açma/kapama ve
  güncelleme uyarıları mağaza güncellemesi olmadan değiştirilebilir (bkz. aşağıda)
- Kişisel veriler yalnızca cihazda saklanır; hesap ve reklam yoktur

## Proje yapısı

```
lib/
  main.dart                  Başlatma
  src/app.dart               MaterialApp ve alt gezinme çubuğu
  src/controller.dart        Sayaç, görevler, geçmiş ve istatistik hesapları
  src/models.dart            Ayarlar, görev ve oturum modelleri
  src/services.dart          Kalıcı depolama ve bildirimler
  src/remote_config.dart     GitHub'dan okunan uzaktan ayarlar
  src/sync.dart              Supabase bulut yedekleme
  src/strings.dart           Türkçe / İngilizce metinler
  src/brand.dart             Renkler ve tema
  src/widgets.dart           Grafik, zamanlayıcı halkası ve ortak bileşenler
  src/achievements.dart      Rozetler ve içgörüler
  src/sounds.dart            Odak sesleri
  src/review.dart            Uygulama içi puan isteği
  src/l10n/                  Dil dosyaları (anahtarlar en.dart ile aynı olmalı)
  src/screens/               Zamanlayıcı, Gökyüzü, İstatistik, Görevler, Ayarlar, Tanıtım
assets/sounds/               Odak sesleri (tool/make_sounds.py ile üretilir)
tool/                        İkon, ses ve mağaza görseli üreticileri
remote/config.json          Yayındaki uygulamaların okuduğu uzaktan ayar dosyası
supabase/schema.sql          Bulut yedekleme veritabanı şeması ve erişim kuralları
store/                       Play Store görselleri, mağaza metinleri, gizlilik politikası
```

## Geliştirme

```bash
flutter pub get
flutter test
flutter run
```

### Windows'ta Türkçe karakterli klasör yolu

Proje yolu `İ`, `ş`, `ğ` gibi karakterler içeriyorsa Flutter'ın shader derleyicisi
`Could not write file ... ink_sparkle.frag` hatası verir. Projeye ASCII bir sürücü harfi atayın:

```powershell
subst P: "C:\Users\SUEDA TEKİN\source\repos\pomodoro"
cd P:\
flutter run
```

İşiniz bitince `subst P: /D` ile eşlemeyi kaldırın.

## Yayından sonra değişiklik yapmak

İki yol vardır:

1. **Uzaktan ayar dosyası (anında, mağaza onayı yok):** `remote/config.json` dosyasını GitHub'da
   düzenleyin. Duyuru, günün sözü, uygulamadaki her metin, varsayılan süreler, özellikleri
   açma/kapama ve "güncelleme var / zorunlu güncelleme" uyarıları birkaç dakika içinde tüm
   kullanıcılara ulaşır. Ayrıntılar: [`remote/README.md`](remote/README.md)
2. **Yeni sürüm (kod değişiklikleri):** yeni ekran/özellik/hata düzeltmesi için `pubspec.yaml`
   ve `kAppVersion` sürümünü artırıp yeni `.aab` yükleyin. Ardından `remote/config.json` içinde
   `latestVersion` değerini yeni sürüme çekerek eski sürümdeki kullanıcılara "Güncelle" kartı gösterin.

## Bulut yedeklemeyi açmak (Supabase)

1. https://supabase.com adresinde ücretsiz bir proje oluşturun.
2. **Authentication > Sign In / Providers** altında **Allow anonymous sign-ins** seçeneğini açın.
3. **SQL Editor**'de `supabase/schema.sql` dosyasının tamamını çalıştırın.
4. **Project Settings > API Keys** sayfasından proje adresini ve *publishable* (ya da *anon*) anahtarı alın.
5. `remote/config.json` içindeki `cloud.url` ve `cloud.publishableKey` alanlarını doldurup GitHub'a kaydedin.

Uygulamalar bir sonraki açılışta bağlanır ve Ayarlar'da **Bulut yedekleme** bölümü görünür.
Gizlilik politikası bu durumu zaten kapsıyor; Play Console'daki **Veri güvenliği** formunu
`store/listing.md`'deki notlara göre güncelleyin.

## Play Store'a yayınlama

### 1. Yükleme anahtarı (bir kez)

```powershell
keytool -genkey -v -keystore C:\keys\sumera-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/key.properties` dosyasını oluşturun (bu dosya git'e eklenmez):

```properties
storePassword=<şifre>
keyPassword=<şifre>
keyAlias=upload
storeFile=C:/keys/sumera-upload.jks
```

> `.jks` dosyasını ve şifreleri güvenli bir yerde yedekleyin. Bu dosya olmadan
> `key.properties` yoksa release derlemeleri debug anahtarıyla imzalanır ve Play Console kabul etmez.

### 2. App Bundle oluşturma

Her yeni sürümde `pubspec.yaml` içindeki `version: 1.0.0+1` değerini artırın
(`+` sonrası sayı her yüklemede büyümelidir) ve `lib/src/brand.dart` içindeki `kAppVersion`'ı güncelleyin.

```powershell
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

### 3. Mağaza kaydı

`store/` klasöründe hazır olanlar:

- `icon-512.png` – mağaza simgesi
- `feature-graphic.png` – öne çıkan görsel (1024×500)
- `listing.md` – uygulama adı, kısa ve tam açıklama (TR/EN), kategori ve form önerileri
- `privacy-policy.md` – gizlilik politikası; herkese açık bir sayfada yayınlayıp bağlantısını girin

Uygulama kimliği: `com.sumera.pomodoro` (Play'e ilk yüklemeden sonra değiştirilemez).
