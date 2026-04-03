import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class CustomerPlansHistoryScreen extends StatefulWidget {
  final bool hideAppBar;
  const CustomerPlansHistoryScreen({super.key, this.hideAppBar = false});

  @override
  State<CustomerPlansHistoryScreen> createState() => _CustomerPlansHistoryScreenState();
}

class _CustomerPlansHistoryScreenState extends State<CustomerPlansHistoryScreen> {
  List<Map<String, dynamic>> _allPlans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('subscriptions')
            .select()
            .eq('customer_id', user.id)
            .order('created_at', ascending: false);
        
        if (mounted) {
          setState(() {
            _allPlans = List<Map<String, dynamic>>.from(data);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Error fetching plans: $e");
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active': color = Colors.green; break;
      case 'pending_approval': color = Colors.blue; break;
      case 'payment_pending': color = Colors.orange; break;
      case 'paused': color = Colors.purple; break;
      case 'expired': color = Colors.red; break;
      case 'rejected': color = Colors.grey; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _allPlans.isEmpty
            ? const Center(child: Text("No plans found.", style: TextStyle(fontSize: 16, color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allPlans.length,
                itemBuilder: (context, index) {
                  final plan = _allPlans[index];
                  final createdAt = plan['created_at']?.toString().substring(0, 10) ?? '';
                  final planType = (plan['plan_type'] ?? '').toString().toUpperCase();
                  final subId = plan['id']?.toString().substring(0, 8).toUpperCase() ?? '';
                  
                  return Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$planType PLAN', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              _buildStatusBadge(plan['status'] ?? ''),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('ID: $subId', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (plan['has_breakfast'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.breakfast_dining, color: Colors.orange, size: 20)),
                              if (plan['has_lunch'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.lunch_dining, color: Colors.orange, size: 20)),
                              if (plan['has_dinner'] == true) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.dinner_dining, color: Colors.orange, size: 20)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Created On', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(createdAt, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (plan['lunch_expiry'] != null) ...[
                                    const Text('Expiring (Lunch)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(plan['lunch_expiry']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ] else if (plan['breakfast_expiry'] != null) ...[
                                    const Text('Expiring (Breakfast)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(plan['breakfast_expiry']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ] else if (plan['dinner_expiry'] != null) ...[
                                    const Text('Expiring (Dinner)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text(plan['dinner_expiry']?.toString().substring(0, 10) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ]
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );

    return Scaffold(
      backgroundColor: const Color(0xFFFEF5E5),
      appBar: widget.hideAppBar ? null : const CustomAppBar(title: 'My SAAPADU BOX'),
      body: content,
    );
  }
}
