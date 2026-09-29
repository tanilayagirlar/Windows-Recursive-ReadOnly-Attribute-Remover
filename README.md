# Windows Recursive ReadOnly Attribute Remover

Windows dosya ve klasör ağacındaki **ReadOnly** özniteliğini tüm alt klasör ve dosyalardan kaldıran PowerShell scripti.

Script, büyük klasör yapılarında dosyaları bellekte biriktirmeden tek tek işler. Başarılı değişiklikleri ve hataları tarih-saat bilgisiyle CSV log dosyasına kaydeder.

> Bu araç yalnızca dosya sistemi ReadOnly özniteliğini kaldırır. NTFS veya paylaşım izinlerini değiştirmez.

## Özellikler

- Kök klasör, alt klasörler ve dosyalar üzerinde çalışır
- Gizli ve sistem öğelerini de tarar
- Bellekte tüm dosya listesini tutmaz
- Başarıları ve hataları CSV formatında loglar
- İşlem sonunda özet sayaç gösterir
- Erişilemeyen klasörleri veya yetki hatalarını kayda alır

## Gereksinimler

- Windows PowerShell 5.1 veya PowerShell 7+
- Hedef klasör ve dosyalarda öznitelik değiştirme yetkisi
- Log oluşturmak için yerel diskte yazma yetkisi

## Kullanım

1. Scripti indirin veya klonlayın.

2. `Remove-ReadOnly-Recursive.ps1` dosyasını bir metin editöründe açın.

3. Hedef klasörü belirtin:

```powershell
$root = "E:\Paylasim\EnUstKlasor"
