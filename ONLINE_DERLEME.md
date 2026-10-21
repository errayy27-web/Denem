# Codemagic ile online derleme

Bu paket, **Codemagic Git repository build** için düzenlenmiştir. ZIP dosyasını GitHub'da yeni bir özel depoya yükleyip dosyaların depo kökünde olduğundan emin olun (`codemagic.yaml`, `pubspec.yaml`, `lib/`, `android/`). Codemagic'te depoyu seçin, `android-debug` workflow'unu çalıştırın. Çıkan `app-debug.apk` dosyasını Artifacts bölümünden indirin.

**Önemli:** Bu bir **test APK'sı** üretme yapılandırmasıdır. Popis'ten otomatik ürün aktarma, kendiliğinden öne açılma ve Popis'in Çıkış düğmesine otomatik basma henüz uygulanmış/değerlendirilmiş değildir. Erişilebilirlik servisi sadece Popis ekranındaki ham metni yerel tanılama için toplamaya çalışır; Popis Verisini Dene işlevi henüz ürün ayrıştırması yapmaz. Bu özellikleri çalışıyor gibi göstermeyin.

Flutter ve Android SDK bu çalışma ortamında bulunmadığından burada gerçek APK derlemesi doğrulanamadı. Codemagic'te derleme hatası olursa build logunu paylaşın. Telefon ayarlarında erişilebilirlik izni yalnızca uygulamaya güveniyorsanız verin.
