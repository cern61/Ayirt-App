import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session_controller.dart';
import '../../core/supabase_client.dart';
import '../../data/models/category.dart';
import '../../data/models/profile.dart';
import '../../shared/widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();

  UserRole _role = UserRole.customer;
  int? _categoryId;
  List<BusinessCategory> _categories = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await supabase.from('categories').select().order('sort_order');
      if (!mounted) return;
      setState(() => _categories = rows.map(BusinessCategory.fromMap).toList());
    } catch (e) {
      if (mounted) showMessage(context, 'Kategoriler yüklenemedi: ${friendlyError(e)}', error: true);
    }
  }

  @override
  void dispose() {
    for (final c in [_fullName, _email, _phone, _password, _businessName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final session = SessionScope.of(context);
    try {
      final loggedIn = await session.signUp(
        email: _email.text,
        password: _password.text,
        fullName: _fullName.text,
        phone: _phone.text,
        role: _role,
        businessName: _role == UserRole.business ? _businessName.text : null,
        categoryId: _role == UserRole.business ? _categoryId : null,
      );
      if (!mounted) return;
      if (!loggedIn) {
        // Supabase'de "Confirm email" açıksa buraya düşer
        showMessage(context, 'Kayıt tamam! E-postana gelen onay linkine tıklayıp giriş yap.');
        context.go('/login');
      }
      // loggedIn ise router rolüne göre otomatik yönlendirir
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusiness = _role == UserRole.business;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıt ol'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Rol seçimi: Müşteri / İşletme (admin kayıtla oluşturulamaz)
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(value: UserRole.customer, label: Text('Müşteri'), icon: Icon(Icons.person_outline)),
                        ButtonSegment(value: UserRole.business, label: Text('İşletme'), icon: Icon(Icons.storefront_outlined)),
                      ],
                      selected: {_role},
                      onSelectionChanged: (s) => setState(() => _role = s.first),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fullName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: isBusiness ? 'Yetkili adı soyadı' : 'Ad soyad',
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => Validators.notEmpty(v, 'Ad soyad'),
                    ),
                    if (isBusiness) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _businessName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'İşletme adı', prefixIcon: Icon(Icons.store_outlined)),
                        validator: (v) => Validators.notEmpty(v, 'İşletme adı'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Kategori', prefixIcon: Icon(Icons.category_outlined)),
                        items: [
                          for (final c in _categories)
                            DropdownMenuItem(
                              value: c.id,
                              child: Row(children: [Icon(c.iconData, size: 20), const SizedBox(width: 8), Text(c.name)]),
                            ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                        validator: (v) => v == null ? 'Kategori seç' : null,
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.mail_outline)),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Telefon (isteğe bağlı)',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '05xx xxx xx xx',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre', prefixIcon: Icon(Icons.lock_outline)),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 24),
                    LoadingButton(
                      label: isBusiness ? 'İşletmemi oluştur' : 'Kayıt ol',
                      loading: _loading,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
