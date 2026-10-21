# SS OIL Stok Kontrol – Flutter kaynak proje

Bu dosya **APK değildir**. Flutter SDK ve Android build ortamında derlenebilir kaynak projedir.

## Özellikler
- Telefon kamerasından barkod tarama, elle barkod/ürün kodu arama
- Ürün kodu, adı, barkod, fiyat ve sistem stoku görüntüleme
- Sayılan miktarı girerek Eksik / Fazla kaydı (fark otomatik hesaplanır)
- Yanlış Barkod, Yanlış Fiyat, Etiket Yok: tek dokunuşla kayıt
- Sipariş: miktarsız, kod/ad/barkod
- Aynı ürün koduyla mükerrer kayıt yerine güncelleme; farklı sorunlar aynı kayıtta korunur
- Stok Kontrol + Siparis Listesi olmak üzere iki sayfalı XLSX
- Kayıtları temizle (önceki Excel dosyalarını silmez), yerel kalıcı saklama
- Listelerden yanlış kayıt silme

## Kritik bağlantı sınırlaması
Orijinal Popis uygulamasının QR bağlantı protokolü ve veri alma uç noktaları doğrulanmadı. Bu sürüm **Popis QR koduna bağlanmaz**. Ürünleri CSV'den içe aktarır. Aynı Wi-Fi / QR bağlantısının eklenmesi için protokolün ayrıca incelenmesi gerekir.

## CSV biçimi
UTF-8 CSV, ilk satır başlık: `code;name;barcode;price;stock` (virgül ayracı da desteklenir). Barkodlarda baştaki sıfırların kaybolmaması için CSV metin olarak üretilmelidir.

Örnek:
```
code;name;barcode;price;stock
1066;SIJALICA H-4 12V/60-55W P43T;0123456789012;5.00;8
```

## Derleme
1. Flutter SDK + Android SDK yükleyin.
2. `flutter create --platforms android .` (proje klasöründe)
3. AndroidManifest.xml dosyasına `<uses-permission android:name="android.permission.CAMERA" />` ekleyin.
4. `flutter pub get`
5. `flutter build apk --release`

Not: Bu ortamda Flutter/Android SDK bulunmadığı için APK oluşturulamadı ve kod cihaz üzerinde test edilemedi.
