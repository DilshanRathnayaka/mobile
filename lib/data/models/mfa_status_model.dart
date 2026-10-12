import 'package:supabase_flutter/supabase_flutter.dart';

class MfaStatusModel {
  final bool isEnrolled;
  final bool isAal2;
  final List<Factor> factors;

  const MfaStatusModel({
    required this.isEnrolled,
    required this.isAal2,
    required this.factors,
  });

  Factor? get primaryTotpFactor => factors.isNotEmpty ? factors.first : null;
}
