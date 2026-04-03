import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class CustomerTransactionScreen extends StatefulWidget {
  final bool hideAppBar;
  const CustomerTransactionScreen({super.key, this.hideAppBar = false});

  @override
  State<CustomerTransactionScreen> createState() => _CustomerTransactionScreenState();
}

class _CustomerTransactionScreenState extends State<CustomerTransactionScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      final res = await _supabase.from('transactions')
          .select()
          .eq('customer_id', user.id)
          .neq('type', 'pause_adjustment')
          .order('transaction_date', ascending: false);
          
      _transactions = (res as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading transactions: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    String type = (tx['type'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    String amountStr = '₹${tx['amount']}';
    String txDate = tx['transaction_date']?.substring(0, 10) ?? '';
    String status = (tx['status'] ?? 'unknown').toString().toUpperCase();
    
    String txnId = tx['razorpay_payment_id'] ?? tx['id']?.toString() ?? '-';
    String txnStr = txnId.length > 20 && !txnId.startsWith('pay_') ? txnId.substring(0,8).toUpperCase() : txnId.toUpperCase();
    
    String subId = tx['subscription_id']?.toString() ?? '-';
    String subStr = subId.length > 20 && !subId.startsWith('pay_') ? subId.substring(0,8).toUpperCase() : subId.toUpperCase();

    Color statusColor;
    IconData statusIcon;
    if (status == 'SUCCESS') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'FAILED') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                     child: Icon(statusIcon, color: statusColor, size: 24),
                   ),
                   const SizedBox(width: 12),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(type, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
                       const SizedBox(height: 4),
                       Text(txDate, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                     ],
                   ),
                ],
              ),
              Text(
                amountStr,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: statusColor),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transaction ID', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(txnStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subscription ID', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF5E5),
      appBar: widget.hideAppBar ? null : const CustomAppBar(title: 'My SAAPADU BOX'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text("No transactions found.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          ],
                        ),
                      )
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _transactions.length,
                        itemBuilder: (context, i) {
                          return _buildTransactionCard(_transactions[i]);
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
