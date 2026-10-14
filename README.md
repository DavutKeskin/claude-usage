# claude-usage

Claude Code kullanımınızı bu makinedeki yerel kayıtlardan çıkarır: hangi hesap, hangi gün,
hangi proje ve hangi oturum ne kadar token harcamış, bunun 5 saatlik, haftalık ve Fable'a
özel haftalık limitin ne kadarına denk geldiğini gösterir. Tek dosya, yalnızca Python
standart kütüphanesi, yapılandırma gerektirmez.

## Kurulum

```bash
git clone <depo> && cd claude-usage     # veya klasörü kopyalayın
./install.sh                             # ~/.local/bin/claude-usage
./install.sh --timer                     # + her sabah 09:00'da rapor (systemd)
```

Gereksinim: Python 3.8+, Linux veya macOS. Rapor dizini `CLAUDE_USAGE_DIR` ile değişir
(varsayılan `~/claude-usage`).

## Kullanım

```bash
claude-usage                  # dün + bugün
claude-usage -d 7             # son 7 gün
claude-usage -s 20            # hesap/gün başına 20 oturum (0 = oturum tablosu yok)
claude-usage -o ~/claude-usage    # dosyaya yaz: YYYY-MM-DD.md + latest.md
claude-usage --no-live        # ağa çıkma, limit yüzdelerini önbellekten al
claude-usage --no-titles      # oturum adlarını gizle (raporu paylaşacaksanız)
claude-usage --json           # ham veri
```

Çıktı Markdown'dır; terminalde okunur, `glow` veya bir editörle tablo olarak görünür.

## Örnek çıktı (kısaltılmış)

```
## Canlı limitler
| Hesap            | 5 saatlik | Sıfırlanma | Haftalık | Fable haftalık | Haftalık sıfırlanma | Kaynak |
| ali@ornek.com    | %57       | 19:20      | %31      | %49            | 24 Eyl 22:00        | canlı  |

## Bugün (2026-09-21)
**ali@ornek.com** — tahmini $89 → haftalık limitin %14.1'i, Fable limitinin %34.3'ü
| Proje              | Input | Output  | Cache yazma | Cache okuma | Toplam     | Maliyet | Haftalık pay | Fable pay |
| ~/Git/mobil-uygulama | 5.226 | 267.389 | 1.092.361   | 49.207.873  | 50.572.849 | $39     | %6.2         | %21.1     |

Oturumlar (en pahalı 2/10):
| Oturum                       | Proje                | Output  | Toplam     | Mesaj | Maliyet | Haftalık pay | Fable pay |
| Ödeme ekranı `c962f2a1`      | ~/Git/mobil-uygulama | 267.389 | 50.572.849 | 182   | $39     | %6.2         | %21.1     |
```

## Nasıl çalışır

| Veri | Kaynak |
|---|---|
| Token sayıları | `<config>/projects/**/*.jsonl` transcript'leri (alt ajanlar dahil). Bir yanıt içerik bloğu başına ayrı satıra yazılır ve ilk satırların output sayısı eksik olabilir; yanıt başına en tam satır alınır. Advisor (danışman) alt çağrıları üst düzey `usage`'da yoktur, `usage.iterations` içinden advisor modeliyle ayrıca sayılır (model satırında `(advisor)`) |
| Oturum → hesap | `<config>/history.jsonl`; her yanıt, o oturumda kendisinden önceki son istemi gönderen hesaba yazılır. Oturumun ortasında hesap değiştirip `--resume` yaparsanız kullanım doğru bölünür |
| Oturum adı | transcript'teki `ai-title` kaydı, yoksa ilk istem |
| Limit yüzdeleri | `https://api.anthropic.com/api/oauth/usage` (Claude Code'un `/usage` ekranının kullandığı uç nokta). Token süresi dolmuşsa `.claude.json` içindeki önbellek kullanılır ve yaşı belirtilir |

**Hesap keşfi.** `$CLAUDE_CONFIG_DIR`, `~/.claude` ve `~/.claude-*` dizinleri taranır. Etiket
hesabın e-postası, plan çarpanı (Max 5x → 5, Max 20x → 20, diğer → 1) credentials'taki
`rateLimitTier` değeridir. Birden çok hesabınız varsa hepsi ayrı raporlanır.

**Maliyet.** API liste fiyatıyla tahmindir (betiğin başındaki `PRICE` tablosu, model adının en
uzun eşleşen önekiyle). Cache yazma TTL'e göre fiyatlanır: 5 dakikalık 1.25 × input, 1 saatlik
2 × input (Claude Code çoğunlukla 1 saatlik yazar). Abonelikte bu parayı ödemezsiniz; maliyet,
farklı token türlerini tek ölçüye indirmek için kullanılır. Toplam tokenın büyük kısmı ucuz
cache okumasıdır, limiti asıl tüketen output ve cache yazmadır.

**Kalibrasyon (limit payı).** Anthropic limitin proje kırılımını vermez. Betik, pencere
içindeki yerel maliyeti canlı yüzdeye bölerek planın kapasitesini tahmin eder ve her gün,
proje ve oturumun payını buna göre hesaplar. Claude'da günlük limit yoktur; pencereler
5 saatlik ve 7 günlüktür.

> **Paylaşılan hesap uyarısı.** Hesabı başkaları da kullanıyorsa yerel kullanım yüzdenin
> tamamını açıklamaz ve paylar olduğundan yüksek çıkar. Bu durumda 1x plan kapasitesini
> elle verin. Ekim 2026'da tek kullanıcılı bir Max 5x hesapta ölçülen değerler (liste
> fiyatıyla, 1x başına): haftalık ≈ 118 $, Fable haftalık ≈ 37 $, 5 saatlik ≈ 16 $ (5 saatlik
> değer küçük örnekten, kaba). Eylül'deki 126 / 37 / 10 $ eski fiyat modeliyle ölçülmüştü.
> Birden çok hesabınız varsa betik en güvenilir hesabı kendisi seçer ve paylaşılan hesabı
> "⚠ hesabın %N'i başka makine/kişiden" diye işaretler.

## Yapılandırma (isteğe bağlı)

`~/.config/claude-usage/config.json`:

```json
{
  "capacity_1x": {"week": 118, "fable": 37, "five": 16},
  "accounts": [
    {"dir": "~/.claude", "label": "İş", "multiplier": 20},
    {"dir": "~/.claude-kisisel", "label": "Kişisel", "multiplier": 5}
  ],
  "prices": {"claude-yeni-model": [5, 25, 6.25, 0.5]}
}
```

Tüm anahtarlar isteğe bağlıdır. `accounts` verilirse otomatik keşif kapanır. `prices`
değerleri sırasıyla input, output, 5 dakikalık cache yazma, cache okuma ($/M token; 1 saatlik
yazma 2 × input alınır); anahtar model adının önekidir, en uzun eşleşen önek kullanılır.

## Sınırlar

- Yalnızca **bu makinedeki** kullanımı görür. Başka bilgisayarda veya uzak sunucuda yaptığınız
  işi görmek için betiği orada da çalıştırın.
- OAuth token'ı yenilemez (yenilemek Claude Code oturumunuzu bozabilir). Sabah raporunda
  token süresi dolmuşsa yüzdeler önbellekten gelir; token tabloları her zaman tamdır.
- `claude -p` gibi etkileşimsiz çağrılar `history.jsonl`'a yazılmaz; bunlar oturumdaki son
  istemin hesabına sayılır.
- macOS'ta token anahtar zincirinden okunur (yalnızca varsayılan `~/.claude` için).
- Limit payları tahmindir, resmi bir kırılım değildir. Kalibrasyonda taze (≤ 60 dk) yüzde
  varsa eski önbellekteki yüzdeler kullanılmaz.
- Advisor alt çağrılarının abonelik limitinden nasıl düştüğü resmi olarak belgelenmiş değil;
  betik onları advisor modelinin (çoğunlukla Fable) maliyetine ve Fable payına katar.

## Gizlilik

Her şey yerelde kalır. Ağa yalnızca limit yüzdeleri için, kendi OAuth token'ınızla
`api.anthropic.com` adresine gidilir; `--no-live` bunu da kapatır. Raporlar oturum
başlıklarınızı içerir, başkasıyla paylaşırken `--no-titles` kullanın.
