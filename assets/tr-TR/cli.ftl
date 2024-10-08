help-description =
  CaSILE avadanlığı için komut satırı arayüzü, SILE ve benzer
  sihirbazlığından faydılanan bir yayınlama işi akışı.

help-flag-passthrough =
  Tüm kullanıcı arayüzü çıktılarından vazgeçin ve sadece alt işlem çıktısını verin

help-subcommand-run =
  CaSILE ortamı içinde yardımcı komut dosyasını çalıştırın

help-subcommand-run-name =
  CaSILE, araç seti veya proje tarafından sağlanan komut dosyası adı

help-subcommand-run-arguments =
  Komut dosyasına iletilecek bağımsız değişkenler

welcome =
  CaSILE { $version } sürümüne hoş geldiniz!

farewell =
  CaSILE çalışması { $duration } içinde tamamlandı.

make-header =
  ‘make’ aracılığıyla hedef(ler) oluşturuluyor.

make-good =
  Tüm hedef(ler) başarıyla oluşturuldu.

make-bad =
  Bazı veya tüm hedef(ler) oluşturulamadı.

make-report-start =
  İşlem başlatıldı: { $target }

make-report-pass =
  İşlem bittirildi: { $target }

make-report-fail =
  Hedef { $target } için tarife çıkış kodu { $code } ile başarsız oldu.

make-backlog-start =
  Hedef { $target } için ‘make’in yakalanan çıktısı dökülüyor:

make-backlog-end =
  Çıktı döcülmesinin sonu.

run-header =
  CaSILE ortamı içinde komut dosyası çalıştırılıyor.

run-good =
  Komut dosyası başarıyla çalıştırıldı.

run-bad =
  Komut dosyası başarılı bir şekilde çalıştılmadı.

setup-header =
  Depoyu CaSILE ile kullanılmak üzere yapılandırılıyor.

setup-good =
  Depoyu CaSILE ile kullanılmak üzere tamamen yapılandırılmıştır.

setup-bad =
  Depoyu CaSILE ile kullanılmak üzere yapılandırılamadı.

setup-true =
  Evet

setup-false =
  Hayır

setup-is-repo =
  Dizin yolu bir Git deposu mudur?

setup-is-deep =
  Git deposu derin klonlanmış mıdır?

setup-is-not-casile =
  CaSILE kaynak deposu üzerinden başka yerde miyiz?

setup-is-writable =
  Projenin kök klasöründe yazma izinimiz var mıdır?

setup-is-make-executable =
  Sistemin ‘make’i, yürütülebilir durumda mıdır?

setup-is-make-gnu =
  Sistemin ‘make’i, desteklenen GNU Make sürümü müdür?

setup-dotfiles-committing =
  Güncellenmiş proje dotfile dosyaları işleniyor

setup-dotfiles-fresh =
  Mevcut proje dotfile dosyaları güncel

setup-short-shas =
  Depodaki kısa SHA karmalarının varsayılan uzunluğunu ayarlanıyor

setup-warp-time =
  İzlenen dosyaların son etkileme zamanı, etkilenen son işleme döndürülüyor

setup-warp-time-file =
  Dosya { $path } geçmişine göre döndürüldü

is-setup-header =
  { setup-header }

is-setup-good =
  { status-good }

is-setup-bad =
  { status-bad }

status-header =
  Proje durum inceleniyor

status-good =
  Her şey yerinde gibi gözüküyor, presleri ısıtın!

status-bad =
  Presleri durdurun, bir eksiklik varmış, 'casile setup' çalıştırın.

status-is-gha =
  GitHub Action olarak mı çalıştırıldık?

status-is-glc =
  GitLab CI iş olarak mı çalıştırıldık?
