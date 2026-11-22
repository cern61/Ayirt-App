import 'package:supabase_flutter/supabase_flutter.dart';

/// Her yerde kısa yoldan kullanmak için: supabase.from('...')
SupabaseClient get supabase => Supabase.instance.client;
