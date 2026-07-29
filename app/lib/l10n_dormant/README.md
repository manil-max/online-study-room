# Dormant localization sources

German (`app_de.arb`) and Arabic (`app_ar.arb`) are preserved here for a
future localization release. This directory is intentionally outside
`l10n.yaml`'s `arb-dir`, so the first store runtime generates and advertises
only English and Turkish.

Do not copy these files back into `lib/l10n` without restoring the complete
runtime, picker, native-resource, and localization test contract for the
language at the same time.
