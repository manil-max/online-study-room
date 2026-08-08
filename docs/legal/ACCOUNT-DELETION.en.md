# Account and Data Deletion — Odak Kampı (Focus Camp)

**Version:** 2026-08-08 · **App:** Odak Kampı (`com.manilmax.online_study_room`)

This page explains how to delete your account and your data.

## Deleting from the app

1. Go to **Settings → Manage my account → Delete account**.
2. Your password is requested again for safety.
3. The request is recorded and a **14-day cooling-off window** starts.
4. If you sign in again during those 14 days, the request is **cancelled** and
   your account continues unchanged.
5. When the window ends, your account and personal data are permanently
   removed from the server. A scheduled server job performs the deletion; it
   does not wait for a manual approval.

## If you cannot open the app

If you cannot access the app, you can send your deletion request to the
developer e-mail address shown on the store listing. We need to verify the
e-mail address of your account before acting on the request.

## Data that is deleted

- Account record and authentication data (e-mail)
- Profile: display name, avatar, camp animal, preferences
- Study sessions and the statistics/XP records attached to them
- Group memberships
- Avatar files

## Data that is kept in pseudonymised form

Some records remain after the account is deleted, but are **detached from your
identity**. The reason is the safety of other users: if the author of a
moderation decision or a support record disappeared entirely, the abuse
history would disappear with it.

- Moderation and administrative audit records: the identity column is cleared
  and replaced by an **irreversible digest (hash)**. The raw identity is gone.
- Support/feedback records: detached from identity the same way.
- Group chat messages: the sender identity is dropped; the message stays in the
  group history without an author.
- Records that must be retained by law are kept for as long as required.

Your identity cannot be reconstructed from these records.

## Timing

The cooling-off window is **14 days**. After it ends, permanent deletion is
carried out by a scheduled job.

## Contact

In-app **Settings → Feedback**, or the developer e-mail address on the store
listing.
