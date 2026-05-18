import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseAdminService {
  static SupabaseClient? _adminClient;

  // IMPORTANT: Replace this with your actual Service Role Key from Supabase Dashboard
  // Settings -> API -> service_role (secret)
  static const String _serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqZWNjZ3RycXF3YnNyb3ZtcW5rIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDc4ODM4OSwiZXhwIjoyMDkwMzY0Mzg5fQ.erlk50RUMNO6FFli2xEOpBF7fwpIYZwRaradruALgLY';

  /// Inisialisasi Supabase Client khusus dengan hak akses Admin (bisa CRUD user).
  /// Hanya boleh dipanggil/digunakan oleh user yang role-nya benar-benar admin.
  static SupabaseClient get adminClient {
    if (_adminClient != null) return _adminClient!;

    // Karena SupabaseClient tidak mengekspos base URL secara publik di versi ini,
    // kita gunakan URL yang sama persis dengan yang ada di main.dart
    const url = 'https://vjeccgtrqqwbsrovmqnk.supabase.co';

    if (_serviceRoleKey == 'YOUR_SERVICE_ROLE_KEY_HERE') {
      debugPrint('WARNING: SERVICE ROLE KEY BELUM DISET!');
    }

    // Membuat instance klien baru khusus admin yang melewati RLS
    _adminClient = SupabaseClient(
      url,
      _serviceRoleKey,
      authOptions: const AuthClientOptions(
        autoRefreshToken: false, // Admin client tidak perlu refresh token
      ),
    );

    return _adminClient!;
  }
}
