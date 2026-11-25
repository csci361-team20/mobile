import 'api_client.dart';

Future<void> logoutSession() => ApiClient.instance.logout();
