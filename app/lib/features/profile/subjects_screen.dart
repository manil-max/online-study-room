import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/subject_colors.dart';
import '../../data/models/subject.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/subject_providers.dart';

/// Derslerim: kullanıcının derslerini (ad + renk) ekleme/düzenleme/silme.
/// Bkz. project.md §3.7. Dersler kişiye özeldir; ders seçimi zorunlu değildir.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(userSubjectsProvider);
    final hasUser = ref.watch(authStateProvider).value != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Derslerim')),
      floatingActionButton: hasUser
          ? FloatingActionButton.extended(
              onPressed: () => _addSubject(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Ders ekle'),
            )
          : null,
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Dersler yüklenemedi: $e')),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Henüz dersin yok. "Ders ekle" ile başla.\n'
                  'Ders seçmek zorunlu değil — istersen "Genel" çalışabilirsin.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            children: [
              for (final s in subjects) _SubjectTile(subject: s),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSubject(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    final result = await showSubjectDialog(context);
    if (result == null) return;
    await ref.read(subjectRepositoryProvider).addSubject(
          Subject(
            id: _uuid.v4(),
            userId: user.id,
            name: result.name,
            color: result.color,
          ),
        );
  }
}

/// Tek bir ders satırı: renk noktası, ad, düzenle/sil menüsü.
class _SubjectTile extends ConsumerWidget {
  const _SubjectTile({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        radius: 10,
        backgroundColor: subjectColor(subject.color),
      ),
      title: Text(subject.name),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _edit(context, ref);
          } else if (v == 'delete') {
            _delete(context, ref);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
          PopupMenuItem(value: 'delete', child: Text('Sil')),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showSubjectDialog(
      context,
      initialName: subject.name,
      initialColor: subject.color,
    );
    if (result == null) return;
    await ref.read(subjectRepositoryProvider).updateSubject(
          subject.copyWith(name: result.name, color: result.color),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dersi sil'),
        content: Text(
          '"${subject.name}" dersi silinsin mi?\n'
          'Bu derse ait geçmiş kayıtların süresi korunur, sadece "Genel" olur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(subjectRepositoryProvider).deleteSubject(subject.id);
  }
}

/// Ders ekleme/düzenleme diyaloğunun sonucu.
class SubjectFormResult {
  const SubjectFormResult({required this.name, required this.color});
  final String name;
  final String color;
}

/// Ad + renk seçtiren diyalog. İptal/boş ad → null döner.
Future<SubjectFormResult?> showSubjectDialog(
  BuildContext context, {
  String? initialName,
  String? initialColor,
}) {
  return showDialog<SubjectFormResult>(
    context: context,
    builder: (_) => _SubjectDialog(
      initialName: initialName,
      initialColor: initialColor,
    ),
  );
}

class _SubjectDialog extends StatefulWidget {
  const _SubjectDialog({this.initialName, this.initialColor});

  final String? initialName;
  final String? initialColor;

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName ?? '');
  late String _color = widget.initialColor ?? kSubjectColorTokens.first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, SubjectFormResult(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialName != null;
    return AlertDialog(
      title: Text(isEdit ? 'Dersi düzenle' : 'Ders ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Ders adı'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          const Text('Renk'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final token in kSubjectColorTokens)
                _ColorDot(
                  color: subjectColor(token),
                  selected: token == _color,
                  onTap: () => setState(() => _color = token),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Seçilebilir renk dairesi (seçiliyse kenarlık + tik).
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: theme.colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 18)
            : null,
      ),
    );
  }
}
