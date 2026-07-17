import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../repositories/data_export_repository.dart';
import '../repositories/in_memory/in_memory_data_export_repository.dart';
import '../repositories/supabase/supabase_data_export_repository.dart';

final dataExportRepositoryProvider = Provider<DataExportRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseDataExportRepository(Supabase.instance.client);
  }
  return InMemoryDataExportRepository();
});
