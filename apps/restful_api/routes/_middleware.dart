import 'package:dart_frog/dart_frog.dart';

import '../lib/data/database.dart';
import '../lib/middleware/auth.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final token = extractToken(context.request);
    final user = findUserByToken(token);
    if (user != null) {
      context = context.provide<User>(() => User.fromMap(user));
    }
    final response = await handler(context);
    // Persist data after write operations (POST/PUT/DELETE) that succeeded
    final method = context.request.method;
    if (method == HttpMethod.post || method == HttpMethod.put || method == HttpMethod.delete) {
      persist();
    }
    return response;
  };
}