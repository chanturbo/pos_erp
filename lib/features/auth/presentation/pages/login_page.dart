import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../routes/app_router.dart';
import '../providers/auth_provider.dart'; // ✅ เพิ่ม สำหรับ isCashierRole helper

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey           = GlobalKey<FormState>();
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _obscurePassword    = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      final user   = ref.read(authProvider).user;
      final roleId = user?.roleId?.toUpperCase() ?? '';

      // ── Role-based redirect ─────────────────────────────────
      // CASHIER / SALE / POS → เข้า POS โดยตรง (isCashierMode: true)
      // ADMIN / อื่นๆ         → เข้าหน้าหลัก
      if (AppRouter.isCashierRole(roleId)) {
        Navigator.of(context).pushReplacementNamed(
          AppRouter.pos,
          arguments: true, // isCashierMode = true
        );
      } else {
        Navigator.of(context).pushReplacementNamed(AppRouter.home);
      }
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'เข้าสู่ระบบไม่สำเร็จ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      const Icon(
                        Icons.point_of_sale,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'POS + ERP System',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'เข้าสู่ระบบ',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty)
                                ? 'กรุณากรอก Username'
                                : null,
                        enabled: !authState.isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty)
                                ? 'กรุณากรอก Password'
                                : null,
                        enabled: !authState.isLoading,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              authState.isLoading ? null : _handleLogin,
                          child: authState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Info box — รักษาจากไฟล์เดิม
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Admin: admin / admin123\nCashier: cashier / cashier123  (→ เข้า POS โดยตรง)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}