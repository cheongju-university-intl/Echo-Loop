import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../analytics/analytics_providers.dart';
import '../onboarding_survey/providers/onboarding_survey_provider.dart';
import 'usage_counter_store.dart';
import 'usage_tracker.dart';

final usageCounterStoreProvider = Provider<UsageCounterStore>((ref) {
  try {
    return UsageCounterStore(ref.watch(sharedPreferencesProvider));
  } on UnimplementedError {
    return UsageCounterStore.memory();
  }
});

final usageTrackerProvider = Provider<UsageTracker>((ref) {
  return UsageTracker(
    store: ref.watch(usageCounterStoreProvider),
    analytics: ref.watch(analyticsServiceProvider),
  );
});
