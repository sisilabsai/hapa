import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authStateProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.hasToken();
});
