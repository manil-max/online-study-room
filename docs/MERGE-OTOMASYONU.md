# Merge Otomasyonu (A)

Bu depo, `main` dalına yalnızca pull request (PR) üzerinden ve Flutter kalite
kontrolü geçtikten sonra girecek şekilde tasarlanmıştır. CI işinin görünen adı
**Flutter kalite kontrolü**dür; `main` koruma kuralında zorunlu kontrol olarak
bu ad seçilir.

> İlk kurulum istisnadır: Bu dosyayı ekleyen WP-39 PR'ı, CI kontrolü henüz
> `main` üzerinde tanınmadığı için kullanıcı tarafından elle squash-merge
> edilmelidir. Sonraki PR'lar aşağıdaki otomasyonu kullanır.

## Bir defalık GitHub ayarları

Depo yöneticisi GitHub'da aşağıdaki ayarları yapar:

1. **Settings → Actions → General → Workflow permissions** altında varsayılan
   izinleri gereksiz yere genişletmeyin. Bu CI yalnızca `contents: read`
   izniyle çalışır.
2. **Settings → Secrets and variables → Actions** altında `SUPABASE_URL` ve
   `SUPABASE_ANON_KEY` repository secret'larını ekleyin. Değerleri issue, PR,
   commit mesajı veya Actions çıktısına yazmayın.
3. **Settings → General → Pull Requests** altında yalnızca **Allow squash
   merging** seçeneğini açık bırakın, **Allow auto-merge** ve **Automatically
   delete head branches** seçeneklerini açın. Ekip özellikle başka bir merge
   türüne ihtiyaç duymuyorsa merge commit ve rebase seçeneklerini kapatın.
4. **Settings → Branches → Add branch protection rule** ile `main` için kural
   oluşturun:
   - **Require a pull request before merging** açık olsun. Tek geliştirici
     akışında zorunlu onay sayısını `0` bırakın; aksi halde bir gözden geçiren
     gerekir.
   - **Require status checks to pass before merging** açık olsun ve ilk CI
     çalıştıktan sonra **Flutter kalite kontrolü** işini seçin. Mümkünse
     **Require branches to be up to date before merging** seçeneğini de açın.
   - Force-push ve dal silmeyi engelli bırakın. Yöneticilerin de bu kurala
     uymasını istiyorsanız bypass iznini kapatın.

Auto-merge, gerekli kontroller ve varsa incelemeler tamamlanınca PR'ı
birleştirir. Fork'tan gelen PR'lara Actions secret'ları aktarılmaz; bu nedenle
bu otomasyon için çalışma dallarını aynı depoda oluşturun veya fork PR'ları için
ayrı, secretsız bir CI politikası belirleyin.

GitHub belgeleri: [auto-merge](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/automatically-merging-a-pull-request), [branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule), [Actions secrets](https://docs.github.com/en/actions/concepts/security/secrets).

## Ajan / geliştirici akışı

Her WP kendi dalında, temiz testlerle ve tek commit olarak hazırlanır:

```bash
git switch -c wpNN-kisa-ad
# değişiklikleri doğrula ve commit oluştur
git push -u origin wpNN-kisa-ad
gh pr create --base main --head wpNN-kisa-ad --fill
gh pr merge --auto --squash
```

`gh pr merge --auto --squash` komutu PR'a auto-merge isteğini koyar; PR ancak
**Flutter kalite kontrolü** başarılı olduğunda (ve yapılandırılmış başka kural
varsa onlar da sağlandığında) birleşir. CI kırmızıysa `main` korunur; hata
düzeltilip aynı dala yeni commit gönderildiğinde CI yeniden çalışır.

PR açıldıktan sonra Actions sayfasında şu sıralama görünmelidir: bağımlılık
yükleme → `flutter analyze` → `flutter test`. Analiz bayraksız çalışır;
testlere Supabase değerleri yalnızca çalışma anında Dart define olarak verilir.
