# Uygulamayı uzaktan değiştirme

Yayındaki tüm uygulamalar bu klasördeki **`config.json`** dosyasını okur:

```
https://raw.githubusercontent.com/SuedaTekin/pomodoro/main/remote/config.json
```

Dosyayı GitHub'da düzenleyip kaydettiğinizde (commit), değişiklik yaklaşık **5–30 dakika** içinde
kullanıcılara ulaşır. Uygulama dosyayı açılışta ve her ön plana gelişinde (en fazla 30 dakikada bir)
indirir, son geçerli hâlini cihazda saklar. İnternet yoksa veya dosya bozuksa son geçerli ayarlarla
çalışmaya devam eder; yani hatalı bir düzenleme uygulamayı bozmaz.

## GitHub'da düzenleme

1. https://github.com/SuedaTekin/pomodoro/blob/main/remote/config.json adresini açın.
2. Sağ üstteki kalem simgesine (Edit) basın.
3. Değişikliği yapın, **Commit changes** ile kaydedin.

> JSON'da virgül ve tırnaklara dikkat edin. Emin değilseniz metni https://jsonlint.com adresinde
> kontrol edin. Bozuk dosya uygulamayı bozmaz ama değişikliğiniz de uygulanmaz.

## Neler değiştirilebilir?

### Duyuru (`announcement`)

Ana ekranın en üstünde bir kart gösterir. Kampanya, yeni özellik, bakım haberi vb. için.

| Alan | Açıklama |
|---|---|
| `enabled` | `true` gösterir, `false` gizler |
| `id` | **Her yeni duyuruda değiştirin** (ör. `"kampanya-2026-11"`). Kullanıcı kartı kapatınca aynı id bir daha gösterilmez |
| `style` | `"info"` (mavi), `"success"` (yeşil), `"warning"` (sarı) |
| `title`, `message` | `tr` ve `en` metinleri |
| `buttonText`, `url` | İsteğe bağlı düğme; `url` `https://` ile başlamalı |
| `dismissible` | `false` ise kullanıcı kartı kapatamaz |

### Güncelleme (`update`)

Play Store'a yeni sürüm yükledikten sonra:

- `latestVersion` → yeni sürüm numarası (ör. `"1.1.0"`). Eski sürümdekilere **"Yeni sürüm hazır"** kartı çıkar.
- `minVersion` → bunun altındaki sürümler **kapatılamayan "Güncelleme gerekli"** penceresiyle engellenir.
  Yalnızca ciddi bir hata olduğunda kullanın.
- `message` → kartta/pencerede gösterilecek metin.

Sürüm numarası `pubspec.yaml` içindeki `version:` satırının `+` öncesi kısmıdır.

### Günün sözü (`quotes`)

Ana ekrandaki "Günün sözü" kartı listeden her gün bir sonrakini gösterir. Söz ekleyip çıkarabilirsiniz.

### Varsayılan ayarlar (`defaults`)

Ayarlarını **hiç değiştirmemiş** kullanıcıların süreleri ve günlük hedefi. Ayarlarını değiştirmiş
kullanıcıları etkilemez. Alanlar: `workMinutes`, `shortBreakMinutes`, `longBreakMinutes`,
`longBreakInterval`, `dailyGoal`.

### Özellikleri açma/kapama (`features`)

`false` yapılan özellik uygulamada gizlenir:

| Anahtar | Özellik |
|---|---|
| `fullscreen` | Tam ekran sayaç düğmesi |
| `heatmap` | İstatistikteki 16 haftalık takvim |
| `taskBreakdown` | İstatistikteki görev dağılımı |
| `quotes` | Günün sözü kartı |

### Uygulamadaki metinler (`strings`)

Uygulamadaki **herhangi bir metni** değiştirebilirsiniz. Anahtarlar `lib/src/strings.dart`
dosyasındadır. Örnek:

```json
"strings": {
  "tr": { "start": "Hadi başla", "goalReached": "Bugünkü hedef tamam, tebrikler!" },
  "en": { "start": "Let's go" }
}
```

### Bulut yedekleme (`cloud`)

Boş bırakıldığında bulut yedekleme kapalıdır ve Ayarlar'da görünmez. Supabase projenizin bilgilerini
yazdığınızda yayındaki uygulamalarda yedekleme kendiliğinden açılır (uygulama bir sonraki açılışta bağlanır):

```json
"cloud": {
  "url": "https://PROJE-KODU.supabase.co",
  "publishableKey": "sb_publishable_... veya eyJ... ile başlayan anon anahtar"
}
```

Bu anahtar herkese açık olacak şekilde tasarlanmıştır; güvenliği `supabase/schema.sql` içindeki
satır düzeyi güvenlik (RLS) kuralları sağlar. **`service_role` / secret anahtarını asla buraya yazmayın.**
Kurulum adımları ana `README.md` dosyasında.

### Bağlantılar (`links`)

- `store` – "Güncelle" ve "Uygulamayı değerlendir" düğmelerinin açtığı adres
- `privacyPolicy` – Gizlilik politikası sayfası
- `feedbackEmail` – Doluysa Ayarlar'da **"Geri bildirim gönder"** seçeneği çıkar

## Neler uzaktan değiştirilemez?

Yeni ekranlar, yeni özellikler, hata düzeltmeleri ve tasarım değişiklikleri kod değişikliğidir.
Bunlar için yeni sürüm derleyip Play Store'a yükleyin (bkz. ana `README.md`), ardından burada
`latestVersion` değerini artırarak kullanıcılara haber verin.
