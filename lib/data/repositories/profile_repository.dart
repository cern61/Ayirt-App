import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

class ProfileRepository {
  Future<void> updateProfile({required String fullName, String? phone}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    }).eq('id', uid);
  }

  /// Fotoğrafı avatars/<kullanici_id>/<ad>.jpg yoluna yükler ve herkese açık URL'yi döndürür.
  /// [fileName]: profil için 'avatar', işletme logosu için 'logo'
  Future<String> uploadImage(Uint8List bytes, {required String fileName}) async {
    final uid = supabase.auth.currentUser!.id;
    final path = '$uid/$fileName.jpg';
    await supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
    final url = supabase.storage.from('avatars').getPublicUrl(path);
    // Aynı adla yüklendiği için önbelleği kırmak adına sürüm parametresi ekliyoruz
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> setAvatarUrl(String url) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
  }

  Future<void> changePassword(String newPassword) async {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  }
}
