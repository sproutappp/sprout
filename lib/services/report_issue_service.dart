import 'package:supabase_flutter/supabase_flutter.dart';

class ReportIssueService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> submit({
    required String subject,
    required String message,
  }) async {
    final response = await _client.functions.invoke(
      'submit-report',
      body: {
        'subject': subject.trim(),
        'message': message.trim(),
      },
    );

    if (response.status < 200 || response.status >= 300) {
      final data = response.data;
      final error = data is Map ? data['error']?.toString() : null;
      throw Exception(error ?? 'Unable to submit report');
    }
  }
}
