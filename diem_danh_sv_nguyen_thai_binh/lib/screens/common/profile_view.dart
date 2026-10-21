import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/config_url.dart';
import '../../core/ui.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

// Tab "Tài khoản" dùng chung cho sinh viên, giảng viên và quản trị viên.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final ok = await confirmAction(
      context,
      title: 'Đăng xuất?',
      message: 'Bạn sẽ cần mật khẩu và mã OTP để đăng nhập lại.',
      confirmLabel: 'Đăng xuất',
      destructive: true,
    );
    if (ok) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = auth.fullName ?? '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                InitialsAvatar(name: name, size: 80),
                const SizedBox(height: 16),
                Text(name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                StatusChip(label: roleLabel(auth.role ?? ''), icon: Icons.verified_user_outlined, tone: StatusTone.info),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Máy chủ'),
                subtitle: Text(Config_URL.baseUrl),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Phiên bản'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error)),
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Đăng xuất'),
        ),
      ],
    );
  }
}
