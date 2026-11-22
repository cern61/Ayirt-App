import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/session_controller.dart';
import '../data/repositories/profile_repository.dart';
import 'widgets.dart';

/// Galeriden fotoğraf seçip Supabase Storage'a yükler, URL'yi döndürür.
/// Kullanıcı vazgeçerse ya da hata olursa null döner.
/// [fileName]: 'avatar' (profil) veya 'logo' (işletme)
Future<String?> pickAndUploadImage(BuildContext context, {required String fileName}) async {
  try {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
    if (file == null) return null; // vazgeçti
    final bytes = await file.readAsBytes();
    return await ProfileRepository().uploadImage(bytes, fileName: fileName);
  } catch (e) {
    if (context.mounted) showMessage(context, 'Fotoğraf yüklenemedi: ${friendlyError(e)}', error: true);
    return null;
  }
}
