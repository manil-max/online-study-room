import re

with open('progress.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Delete WP-30 block
wp30_match = re.search(r'(### WP-30:.*?)(?=\n---|\n### |\Z)', content, re.DOTALL)
if wp30_match:
    content = content.replace(wp30_match.group(1), '')

# Add summary
summary_30 = '''### WP-30: Version History, Release Notes Popup & Update Notification 📝 — 2026-07-11 ✅
- **Değişen dosyalar:** `app/lib/features/updater/release_notes_service.dart`, `app/lib/features/updater/release_notes_screen.dart`, `app/lib/core/notifications/update_notification_service.dart`, `app/lib/features/updater/updater_service.dart`, `app/lib/features/updater/updater_dialog.dart`, `app/lib/features/auth/auth_gate.dart`, `app/lib/features/profile/settings_screen.dart`, `app/pubspec.yaml`, `app/assets/release_notes.json`, `CHANGELOG.md`, `docs/VERSIONS.md`, `.github/workflows/release.yml`, `app/test/features/release_notes_test.dart`.
- **Ne yapıldı:** GitHub Release body'sine fallback olarak uygulama içi `release_notes.json` sistemi kuruldu. Kullanıcıların güncellemeleri uygulama içinden görebilmesi için Ayarlar ekranına "Sürüm ve güncellemeler" sekmesi eklendi. Yeni sürüme ilk kez geçen kullanıcılara "Yenilikler" pop-up'ı gösteriliyor. Bildirim izni olanlara update çıktığında local push notification gönderiliyor. GitHub Actions release workflow'u changelog'dan doğru sürüm notunu çekecek şekilde güncellendi.
- **Test:** Release notes mantığı ve UI (yükleme durumu vs.) için testler yazıldı. `flutter test` başarıyla geçti.
'''

target = '## ✅ Son Tamamlananlar (ajan bağlamı için)\n'
content = content.replace(target, target + '\n' + summary_30 + '\n')

with open('progress.md', 'w', encoding='utf-8') as f:
    f.write(content)
