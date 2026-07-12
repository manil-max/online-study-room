import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/main.dart';

class V8TestDeviceIntegrationService extends DeviceIntegrationService {
  @override
  Future<String?> getInitialAction() async => null;
}

class V8TestWidgetGateway implements AndroidWidgetGateway {
  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

Future<InMemoryAuthRepository> signedInV8AuthRepository() async {
  final repository = InMemoryAuthRepository();
  await repository.signUp(
    email: 'v8-qa@ornek.com',
    password: '123456',
    displayName: 'V8 QA',
  );
  return repository;
}

Future<SharedPreferences> v8SharedPreferences() async {
  SharedPreferences.setMockInitialValues({
    // Sayaç kartının periyodik tick'i integration navigasyon testini açık
    // bırakmasın; timer davranışı cihaz QA matrisinde ayrı ölçülür.
    'dashboard_layout': ['today', 'leaderboard'],
  });
  return SharedPreferences.getInstance();
}

Widget buildV8TestApp({
  required InMemoryAuthRepository authRepository,
  required SharedPreferences preferences,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      sharedPreferencesProvider.overrideWithValue(preferences),
      deviceIntegrationServiceProvider.overrideWithValue(
        V8TestDeviceIntegrationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
    ],
    child: const OnlineStudyRoomApp(),
  );
}
