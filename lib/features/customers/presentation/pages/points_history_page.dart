// lib/features/customers/presentation/pages/points_history_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/client/api_client.dart';

// ─────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────
class _PointsTx {
  final String      transactionId;
  final String      type; // 'EARN' | 'REDEEM'
  final int         points;
  final String?     referenceNo;
  final String?     remark;
  final DateTime    createdAt;

  const _PointsTx({
    required this.transactionId,
    required this.type,
    required this.points,
    this.referenceNo,
    this.remark,
    required this.createdAt,
  });

  factory _PointsTx.fromJson(Map<String, dynamic> j) => _PointsTx(
        transactionId: j['transaction_id'] as String,
        type:          j['type']           as String,
        points:        j['points']         as int,
        referenceNo:   j['reference_no']   as String?,
        remark:        j['remark']         as String?,
        createdAt:     DateTime.parse(j['created_at'] as String),
      );
}

// ─────────────────────────────────────────────────────────────────
// PointsHistoryPage
// ─────────────────────────────────────────────────────────────────
class PointsHistoryPage extends ConsumerStatefulWidget {
  final String customerId;
  final String customerName;
  final int    currentPoints;

  const PointsHistoryPage({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.currentPoints,
  });

  @override
  ConsumerState<PointsHistoryPage> createState() =>
      _PointsHistoryPageState();
}

class _PointsHistoryPageState extends ConsumerState<PointsHistoryPage> {
  List<_PointsTx> _txs       = [];
  bool            _isLoading = true;
  String?         _error;

  final _dateFmt  = DateFormat('dd/MM/yyyy HH:mm');
  final _numFmt   = NumberFormat('#,##0', 'th_TH');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final client   = ref.read(apiClientProvider);
      final response =
          await client.get('/api/customers/${widget.customerId}/points-history');
      if (response.statusCode == 200) {
        final list = (response.data['data'] as List)
            .map((e) => _PointsTx.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _txs = list; _isLoading = false; });
      } else {
        if (mounted) setState(() { _error = 'โหลดข้อมูลไม่ได้'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'เกิดข้อผิดพลาด: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnTotal  = _txs.where((t) => t.type == 'EARN')
        .fold(0, (s, t) => s + t.points);
    final redeemTotal = _txs.where((t) => t.type == 'REDEEM')
        .fold(0, (s, t) => s + t.points);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('ประวัติแต้ม · ${widget.customerName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary bar ───────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            child: Row(
              children: [
                _SummaryTile(
                  label: 'แต้มคงเหลือ',
                  value: _numFmt.format(widget.currentPoints),
                  icon: Icons.stars,
                  color: Colors.amber[700]!,
                ),
                const _VSep(),
                _SummaryTile(
                  label: 'สะสมทั้งหมด',
                  value: '+${_numFmt.format(earnTotal)}',
                  icon: Icons.add_circle_outline,
                  color: Colors.green[700]!,
                ),
                const _VSep(),
                _SummaryTile(
                  label: 'แลกไปทั้งหมด',
                  value: '-${_numFmt.format(redeemTotal)}',
                  icon: Icons.redeem,
                  color: Colors.orange[700]!,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _txs.isEmpty
                        ? const Center(
                            child: Text('ยังไม่มีประวัติแต้ม',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: _txs.length,
                            separatorBuilder: (context, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _TxCard(tx: _txs[i], dateFmt: _dateFmt,
                                    numFmt: _numFmt),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// _TxCard
// ─────────────────────────────────────────────────────────────────
class _TxCard extends StatelessWidget {
  final _PointsTx    tx;
  final DateFormat   dateFmt;
  final NumberFormat numFmt;

  const _TxCard({
    required this.tx,
    required this.dateFmt,
    required this.numFmt,
  });

  @override
  Widget build(BuildContext context) {
    final isEarn     = tx.type == 'EARN';
    final color      = isEarn ? Colors.green[700]! : Colors.orange[700]!;
    final bgColor    = isEarn
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final icon       = isEarn ? Icons.add_circle : Icons.redeem;
    final sign       = isEarn ? '+' : '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ── Icon ────────────────────────────────────────────
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // ── Info ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEarn ? 'สะสมแต้ม' : 'แลกแต้ม',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  if (tx.remark != null && tx.remark!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tx.remark!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF555555)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (tx.referenceNo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'อ้างอิง: ${tx.referenceNo}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF888888)),
                    ),
                  ],
                ],
              ),
            ),

            // ── Points + Date ────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${numFmt.format(tx.points)} pt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFmt.format(tx.createdAt),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────
class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color  color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 44, color: const Color(0xFFE0E0E0));
}
