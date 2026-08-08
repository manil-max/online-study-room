/// WP-517: görünen ad ve grup adı için karakter sınırları.
///
/// Sayılar sahip tarafından seçildi (2026-08-08, parametrik önizlemeden):
/// kişi adı **24**, grup adı **30**.
///
/// 🔴 Bu dosya tek kaynaktır ama tek KATMAN değildir. İstemci `maxLength`i
/// kozmetiktir: ad yazan üç yolun ikisi RPC bile değil, `profiles` ve `groups`
/// üzerinde **doğrudan `update`**. Gerçek zorlama sunucudadır —
/// `supabase/migrations/0122_name_length_limits.sql` (iki CHECK kısıtı +
/// `create_group_with_access` içindeki kontrol). Buradaki sayı değişirse
/// **migration da değişmelidir**; ikisi ayrışırsa kullanıcı ekranda
/// yazabildiği adı kaydedemez.
///
/// Sınır ekrana sığdırmak için değildir — üç dar yuvada (grup başlığı ~156 px,
/// üye satırı ~150 px, kamp ateşi etiketi ~72 px) ad zaten `…` ile kesiliyor.
/// Amaç saçma uzunluktaki adı engellemek ve
/// `0032_public_group_discovery.sql`'in 64 karakterlik ayrı sayısını tek
/// değere indirmektir.
library;

/// Profil görünen adı (`profiles.display_name`).
const int kDisplayNameMaxLength = 24;

/// Grup adı (`public.groups.name`).
const int kGroupNameMaxLength = 30;
