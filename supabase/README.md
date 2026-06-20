# Supabase Kurulumu

Bu klasör veritabanı şemasını (migrations) içerir. Aşağıdaki adımlar bir kez yapılır.

## 1. Hesap ve proje
1. https://supabase.com → **Start your project** → GitHub veya e-posta ile ücretsiz kayıt.
2. **New project** → bir ad ver (ör. `online-study-room`), güçlü bir **Database Password** belirle
   (bir yere kaydet), **Region** olarak Avrupa'ya yakın birini seç (ör. *Frankfurt*).
3. Proje hazırlanınca açılır (1-2 dk).

## 2. Şemayı kur
1. Sol menü → **SQL Editor** → **New query**.
2. `migrations/0001_initial_schema.sql` dosyasının tamamını yapıştır → **Run**.
3. "Success" görmelisin. (Tablolar, trigger ve RLS kurulur.)

## 2.1 Profil fotoğrafı deposu (Storage)
1. Yine **SQL Editor** → **New query**.
2. `migrations/0002_avatars_storage.sql` dosyasının tamamını yapıştır → **Run**.
3. Bu, herkese açık (public) bir **`avatars`** bucket'ı oluşturur ve kullanıcıların
   yalnızca kendi klasörlerine yazmasına izin verir. (Profil fotoğrafı yükleme bunu kullanır.)

## 3. E-posta doğrulamasını kapat (küçük grup için pratiklik)
- Sol menü → **Authentication** → **Sign In / Providers** → **Email** →
  **Confirm email** seçeneğini **kapat** → Save.
- Böylece kayıt olunca anında giriş yapılır (doğrulama e-postası beklenmez).

## 4. Anahtarları uygulamaya ver
1. Sol menü → **Project Settings** → **API**.
2. **Project URL** ve **anon public** (yeni adıyla *publishable*) anahtarını kopyala.
3. `app/env.example.json` dosyasını `app/env.json` olarak kopyala ve değerleri yapıştır.
   - `env.json` repoya commit EDİLMEZ (.gitignore'da).
4. Uygulamayı şu şekilde çalıştır:
   ```
   flutter run -d chrome --dart-define-from-file=env.json
   ```

> Not: `anon public` anahtarı istemcide bulunması güvenlidir; veriyi RLS korur
> (project.md §7). `service_role` anahtarı ASLA uygulamaya/repoya konmaz.
