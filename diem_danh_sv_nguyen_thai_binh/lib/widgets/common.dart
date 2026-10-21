import 'package:flutter/material.dart';

import '../services/api_service.dart';

// ---------- Nhãn trạng thái (luôn có icon + chữ, không chỉ dựa vào màu) ----------

enum StatusTone { success, warning, danger, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.icon, this.tone = StatusTone.neutral});

  final String label;
  final IconData icon;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      StatusTone.success => dark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
      StatusTone.warning => dark ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
      StatusTone.danger => scheme.error,
      StatusTone.info => scheme.primary,
      StatusTone.neutral => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

StatusChip leaveStatusChip(String status) {
  switch (status) {
    case 'Approved':
      return const StatusChip(label: 'Được duyệt', icon: Icons.check_circle_rounded, tone: StatusTone.success);
    case 'Rejected':
      return const StatusChip(label: 'Từ chối', icon: Icons.cancel_rounded, tone: StatusTone.danger);
    default:
      return const StatusChip(label: 'Chờ duyệt', icon: Icons.hourglass_top_rounded, tone: StatusTone.warning);
  }
}

// ---------- Avatar chữ cái đầu ----------

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // Tên tiếng Việt: lấy chữ cái đầu của tên (từ cuối cùng).
    final initial = words.isEmpty ? '?' : words.last.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: size * 0.4),
        ),
      ),
    );
  }
}

// ---------- Trạng thái rỗng / lỗi / đang tải ----------

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dữ liệu',
        message: message,
        action: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Thử lại')),
      ),
    );
  }
}

// Khung xương khi đang tải. Tắt hiệu ứng nhấp nháy nếu người dùng bật giảm chuyển động.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.4, upperBound: 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.7;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        );
    return Semantics(
      label: 'Đang tải',
      child: FadeTransition(
        opacity: _controller,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color),
            ),
            child: Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(160, 14), const SizedBox(height: 8), bar(100, 12)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Danh sách tải từ API: xử lý đang tải, lỗi, rỗng, kéo để làm mới ----------

class AsyncListView extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.headerBuilder,
    this.bottomPadding = 24,
  });

  final Future<List<Json>> future;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, Json item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;
  final Widget Function(List<Json> items)? headerBuilder;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Json>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SkeletonList();
        if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: () => onRefresh());
        final items = snap.data!;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
            children: [
              if (headerBuilder != null) ...[headerBuilder!(items), const SizedBox(height: 16)],
              if (items.isEmpty)
                EmptyState(icon: emptyIcon, title: emptyTitle, message: emptyMessage)
              else
                for (final item in items)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: itemBuilder(context, item)),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Thẻ bấm được ----------

class TapCard extends StatelessWidget {
  const TapCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

// Một dòng thông tin nhỏ có icon, dùng trong thẻ.
class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color))),
        ],
      ),
    );
  }
}

// ---------- Hộp thoại dùng chung ----------

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError) : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

// Hiện hộp thoại chờ trong lúc chạy tác vụ, tự đóng khi xong (kể cả khi lỗi).
Future<T> runWithProgress<T>(BuildContext context, String message, Future<T> Function() task) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}

Future<void> showResultDialog(BuildContext context, {required bool success, required String title, required String message}) {
  final scheme = Theme.of(context).colorScheme;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        success ? Icons.check_circle_rounded : Icons.error_rounded,
        size: 56,
        color: success ? const Color(0xFF16A34A) : scheme.error,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
        ),
      ],
    ),
  );
}
