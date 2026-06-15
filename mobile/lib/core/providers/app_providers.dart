import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import 'server_config_provider.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final baseUrl = ref.watch(serverUrlProvider);
  final service = ApiService(baseUrl: baseUrl);
  ref.onDispose(service.dispose);
  return service;
});

final socketServiceProvider = Provider<SocketService>((ref) {
  final serverUrl = ref.watch(serverUrlProvider);
  final service = SocketService(serverUrl: serverUrl);
  ref.onDispose(service.disconnect);
  return service;
});
