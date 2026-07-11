import 'package:flutter/material.dart';

import '../../../data/models/study_group.dart';
import 'class_chat_card.dart';

import '../../../core/widgets/safe_screen_padding.dart';

class ClassChatScreen extends StatelessWidget {
  const ClassChatScreen({super.key, required this.group});

  final StudyGroup group;

  @override
  Widget build(BuildContext context) {
    final messageListHeight = (MediaQuery.sizeOf(context).height - 260).clamp(
      300.0,
      560.0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sohbet')),
      body: ListView(
        padding: getSafeVerticalPadding(context),
        children: [
          Text(group.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ClassChatCard(
            group: group,
            messageListHeight: messageListHeight.toDouble(),
          ),
        ],
      ),
    );
  }
}
