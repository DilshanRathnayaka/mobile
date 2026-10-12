class SupabaseConfig {
  // Supabase Project URL (WITHOUT /rest/v1/)
  static const String supabaseUrl = 'https://tigiztwcarhvimntpavn.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpZ2l6dHdjYXJodmltbnRwYXZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3MTQ2MDEsImV4cCI6MjEwNzI5MDYwMX0.DZ10Afma9htVNorhZRyYUNQLYtPp78Rixxyn3wenYZ0';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_URL') &&
      supabaseAnonKey.isNotEmpty;
}
