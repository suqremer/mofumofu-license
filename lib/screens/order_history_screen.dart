import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/order_record.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// 注文履歴画面（端末ローカルの控え）
///
/// [OrderStatus.pending]（写真未送信）の注文には「写真を送る」導線を出し、
/// 決済済みなのに写真を送り損ねた注文を救済できるようにする。
class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<OrderRecord>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _ordersFuture = DatabaseService().getAllOrders();
  }

  String _productLabel(String type) {
    switch (type) {
      case 'card':
        return 'カード';
      case 'tag':
        return 'タグ';
      case 'set':
        return 'カード＋タグセット';
      default:
        return '商品';
    }
  }

  String _formatPrice(int yen) => '¥${yen.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('注文履歴'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: FutureBuilder<List<OrderRecord>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          final orders = snapshot.data ?? [];
          if (orders.isEmpty) return _buildEmpty();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildOrderCard(orders[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.textLight),
            SizedBox(height: AppSpacing.md),
            Text(
              'まだ注文履歴がありません',
              style: TextStyle(fontSize: 16, color: AppColors.textMedium),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              '物理グッズを注文すると、ここに控えが表示されます',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderRecord order) {
    final isPending = order.status == OrderStatus.pending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              _buildStatusBadge(isPending),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_productLabel(order.productType)} × ${order.quantity}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          Text(
            order.petNames.join('・'),
            style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                _formatDate(order.createdAt),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const Spacer(),
              Text(
                _formatPrice(order.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentDark,
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'まだ写真が送信されていません。お支払い済みの場合は写真を送ってください。',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMedium, height: 1.4),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _goToUpload(order),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('写真を送る'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPending) {
    final color = isPending ? AppColors.warning : AppColors.success;
    final label = isPending ? '写真未送信' : '送信済み';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Future<void> _goToUpload(OrderRecord order) async {
    await context.push('/order/upload', extra: order);
    // 送信完了後に戻ってくる可能性があるので一覧を更新
    if (mounted) setState(_reload);
  }
}
