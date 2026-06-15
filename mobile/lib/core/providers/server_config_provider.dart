import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

class ServerConfigNotifier extends StateNotifier<AsyncValue<String>> {
  ServerConfigNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  static const _prefsKey = AppConfig.prefsServerUrlKey;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      state = AsyncValue.data(AppConfig.resolveServerUrl(saved));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setServerUrl(String url) async {
    final normalized = AppConfig.resolveServerUrl(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    state = AsyncValue.data(normalized);
  }

  String get currentUrl {
    return state.maybeWhen(data: (url) => url, orElse: () => AppConfig.emulatorDefault);
  }
}

final serverConfigProvider =
    StateNotifierProvider<ServerConfigNotifier, AsyncValue<String>>((ref) {
  return ServerConfigNotifier();
});

final serverUrlProvider = Provider<String>((ref) {
  return ref.watch(serverConfigProvider).maybeWhen(
        data: (url) => url,
        orElse: () => AppConfig.resolveServerUrl(null),
      );
});
