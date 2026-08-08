# Account and Data Deletion — Focus Camp / Odak Kampı

**Version:** 2026-08-08 · **App:** Focus Camp (shown as **Odak Kampı** on Turkish devices)
· Package name: `com.manilmax.online_study_room`

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
- The support tickets you opened, the questions you asked and the reports you
  submitted
- Every file you uploaded: your profile photo (`avatars`), the photos you
  attached to support and feedback tickets (`feedback_attachments`) and the
  photos you attached when reporting content (`report_attachments`)
- The photos of groups that are left without members after you and are
  therefore deleted (`group-avatars`)

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
- The photo of a group that continues to exist (`group-avatars`): even if you
  were the one who uploaded it, that file belongs to the **group**, not to
  you. If the group continues with its other members after your account is
  deleted, its photo stays as well and remains until the group itself is
  deleted. That file path does not carry your identity, it carries the
  group's. If the group is left without members after you, both the group and
  its photo are deleted.
- Records that must be retained by law are kept for as long as required.

Your identity cannot be reconstructed from these records.

## Timing

The cooling-off window is **14 days**. After it ends, permanent deletion is
carried out by a scheduled job.

## Contact

In-app **Settings → Feedback**, or the developer e-mail address on the store
listing.
