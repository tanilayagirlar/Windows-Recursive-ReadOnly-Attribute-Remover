# İşlem yapılacak en üst klasör.
# Script dosya sunucusunda çalışıyorsa yerel disk yolu kullanabilirsiniz.
$root = "E:\Paylasim\EnUstKlasor"


# Log dosyasının kaydedileceği yer.
# Klasör yoksa aşağıdaki komut oluşturur.
$logFolder = "C:\Temp"
New-Item -ItemType Directory -Path $logFolder -Force | Out-Null

# Her çalıştırmada tarih-saat içeren ayrı bir CSV log oluşturur.
$logPath = Join-Path $logFolder "remove-readonly-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"

# Log dosyasını açar. UTF-8 BOM sayesinde Excel Türkçe karakterleri düzgün açar.
$writer = [System.IO.StreamWriter]::new(
    $logPath,
    $false,
    [System.Text.UTF8Encoding]::new($true)
)


# İşlem sonunda ekrana yazdırılacak sayaçlar.
$counts = @{
    Degisen     = 0   # ReadOnly kaldırılan dosya/klasör sayısı
    ZatenNormal = 0   # Zaten ReadOnly olmayanların sayısı
    Hata        = 0   # İşlenemeyen veya taranırken hata alınan öğeler
}


function Convert-CsvField {
    param([object]$Value)

    # CSV içinde çift tırnak varsa Excel formatını bozmaması için çiftlenir.
    '"' + ([string]$Value).Replace('"', '""') + '"'
}


function Write-Log {
    param(
        [string]$Durum,
        [string]$Tur,
        [string]$Yol,
        [string]$OncekiAttr,
        [string]$Hata
    )

    # Her kaydı doğrudan diskteki CSV dosyasına yazar.
    # Sonuçları RAM'de biriktirmediği için çok büyük klasörlerde güvenlidir.
    $fields = @(
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),
        $Durum,
        $Tur,
        $Yol,
        $OncekiAttr,
        $Hata
    )

    $writer.WriteLine(
        ($fields | ForEach-Object { Convert-CsvField $_ }) -join ","
    )
}


function Process-Item {
    param($Item)

    # Dosya veya klasörün mevcut özniteliklerini saklar.
    # Örnek: Archive, Hidden, Directory, ReadOnly vb.
    $oldAttributes = $Item.Attributes

    # Sadece ReadOnly biti var mı kontrol edilir.
    $isReadOnly = [bool](
        $oldAttributes -band [IO.FileAttributes]::ReadOnly
    )

    # Logda anlaşılır görünmesi için tür belirlenir.
    $type = if ($Item.PSIsContainer) { "Klasör" } else { "Dosya" }

    # ReadOnly değilse değişiklik yapmadan sonraki öğeye geçer.
    if (-not $isReadOnly) {
        $counts.ZatenNormal++
        return
    }

    try {
        # Sadece ReadOnly özniteliğini kaldırır.
        # Hidden, Archive gibi diğer özniteliklere dokunmaz.
        $Item.Attributes = $oldAttributes -band (
            -bnot [IO.FileAttributes]::ReadOnly
        )

        # Başarılı işlemleri loga yazar.
        Write-Log `
            -Durum "ReadOnly kaldırıldı" `
            -Tur $type `
            -Yol $Item.FullName `
            -OncekiAttr $oldAttributes `
            -Hata ""

        $counts.Degisen++
    }
    catch {
        # Yetki, açık/kilitli dosya veya dosya sistemi sorunu varsa loga yazar.
        Write-Log `
            -Durum "HATA" `
            -Tur $type `
            -Yol $Item.FullName `
            -OncekiAttr $oldAttributes `
            -Hata $_.Exception.Message

        $counts.Hata++
    }
}


try {
    # CSV sütun başlıkları.
    $writer.WriteLine(
        '"Tarih","Durum","Tür","Yol","Önceki Öznitelik","Hata"'
    )

    # Get-ChildItem kök klasörü döndürmediği için kök klasör ayrıca işlenir.
    try {
        Process-Item (
            Get-Item -LiteralPath $root -Force -ErrorAction Stop
        )
    }
    catch {
        Write-Log `
            -Durum "KÖK KLASÖR HATASI" `
            -Tur "Klasör" `
            -Yol $root `
            -OncekiAttr "" `
            -Hata $_.Exception.Message

        $counts.Hata++
    }

    # -Recurse: tüm alt klasör ve dosyalara iner.
    # -Force: gizli ve sistem öğelerini de kapsar.
    # 2>&1: tarama hatalarını da yakalayıp CSV'ye yazabilmek içindir.
    #
    # Önemli: Öğeler tek tek işlenir; tamamı belleğe alınmaz.
    Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction Continue 2>&1 |
        ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                # Erişilemeyen klasör gibi tarama hatalarını loglar.
                Write-Log `
                    -Durum "TARAMA HATASI" `
                    -Tur "" `
                    -Yol "" `
                    -OncekiAttr "" `
                    -Hata $_.ToString()

                $counts.Hata++
            }
            else {
                # Dosya veya klasörü işler.
                Process-Item $_
            }
        }
}
finally {
    # Script hata alsa bile açık log dosyasını düzgün kapatır.
    $writer.Flush()
    $writer.Dispose()
}


# İşlem özeti ve log konumu.
Write-Host ""
Write-Host "Tamamlandı."
Write-Host "ReadOnly kaldırılan: $($counts.Degisen)"
Write-Host "Zaten normal olan:   $($counts.ZatenNormal)"
Write-Host "Hata:                 $($counts.Hata)"
Write-Host "Log: $logPath"
