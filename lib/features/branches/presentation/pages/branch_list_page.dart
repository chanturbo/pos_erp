// branch_list_page.dart — Week 7: Branch Management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/branch_provider.dart';
import '../../data/models/branch_model.dart';
import 'branch_form_page.dart';
import 'sync_status_page.dart';

class BranchListPage extends ConsumerWidget {
  const BranchListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchListProvider);
    final syncAsync = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการสาขา'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Sync status badge
          syncAsync.when(
            data: (sync) => IconButton(
              icon: Stack(
                children: [
                  Icon(sync.isOnline ? Icons.sync : Icons.sync_disabled,
                      color: sync.isOnline ? Colors.white : Colors.red[200]),
                  if (sync.hasPending)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              tooltip: sync.pendingCount > 0
                  ? 'รอ Sync ${sync.pendingCount} รายการ'
                  : 'Sync สถานะ',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const SyncStatusPage())),
            ),
            loading: () => const SizedBox(
                width: 48,
                child: Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)))),
            error: (_, _) => const Icon(Icons.sync_problem),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(branchListProvider.notifier).refresh();
              ref.invalidate(syncStatusProvider);
            },
          ),
        ],
      ),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (branches) {
          if (branches.isEmpty) {
            return _buildEmpty(context);
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(branchListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: branches.length,
              itemBuilder: (ctx, i) =>
                  _buildBranchCard(ctx, ref, branches[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, null),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มสาขา'),
      ),
    );
  }

  Widget _buildBranchCard(
      BuildContext context, WidgetRef ref, BranchModel branch) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openForm(context, ref, branch),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store, color: Colors.indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(branch.branchName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(branch.branchCode,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: branch.isActive
                          ? Colors.green.withValues(alpha:0.12)
                          : Colors.grey.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      branch.isActive ? 'เปิดใช้งาน' : 'ปิด',
                      style: TextStyle(
                          fontSize: 12,
                          color: branch.isActive
                              ? Colors.green
                              : Colors.grey,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (branch.address != null || branch.phone != null) ...[
                const SizedBox(height: 8),
                if (branch.address != null)
                  Row(children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(branch.address!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis)),
                  ]),
                if (branch.phone != null)
                  Row(children: [
                    Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(branch.phone!,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ]),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warehouse, size: 14, color: Colors.indigo[300]),
                  const SizedBox(width: 4),
                  Text(
                    '${branch.warehouseCount ?? 0} คลังสินค้า',
                    style: TextStyle(
                        fontSize: 12, color: Colors.indigo[400]),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openForm(context, ref, branch),
                    icon: const Icon(Icons.edit, size: 14,
                        color: Colors.blue),
                    label: const Text('แก้ไข',
                        style: TextStyle(color: Colors.blue)),
                  ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, branch),
                    icon: const Icon(Icons.delete, size: 14,
                        color: Colors.red),
                    label: const Text('ลบ',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('ยังไม่มีสาขา',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text('สร้างสาขาแรกเพื่อเริ่มใช้งาน',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }

  void _openForm(
      BuildContext context, WidgetRef ref, BranchModel? branch) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BranchFormPage(branch: branch)),
    );
    ref.read(branchListProvider.notifier).refresh();
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, BranchModel branch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบสาขา "${branch.branchName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(branchListProvider.notifier)
                  .deleteBranch(branch.branchId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลบสาขาแล้ว')));
              }
            },
            child:
                const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}