import 'api_client.dart';

Future<String?> refreshSession() => ApiClient.instance.refresh();
