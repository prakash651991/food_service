import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _pendingEnquiriesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    try {
      final res = await Supabase.instance.client
          .from('subscriptions')
          .select('id')
          .eq('status', 'pending_approval');
      
      if (mounted) {
        setState(() {
          _pendingEnquiriesCount = res.length;
        });
      }
    } catch (e) {
      debugPrint('Error fetching counts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Admin Dashboard - SAAPADU BOX'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello, Admin ${context.watch<AuthProvider>().profile?['full_name'] ?? ''}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildCard(context, Icons.analytics, 'Analytics', "Today's Deliveries", onTap: () => context.push('/admin/analytics')),
                  _buildCard(context, Icons.delivery_dining, 'Dispatch', 'Manage Daily Deliveries', onTap: () => context.push('/admin/dispatch')),
                  _buildCard(
                    context, 
                    Icons.approval, 
                    'Enquiries', 
                    _pendingEnquiriesCount > 0 ? '$_pendingEnquiriesCount Pending Enquiries' : 'No New Enquiries', 
                    badgeCount: _pendingEnquiriesCount,
                    onTap: () async {
                      await context.push('/admin/enquiries');
                      _fetchCounts(); // refresh count when returning
                    }
                  ),
                  _buildCard(context, Icons.people, 'Customers', 'Manage Users & Plans', onTap: () => context.go('/admin/customers')),
                  _buildCard(context, Icons.receipt, 'Transactions', 'View Payments', onTap: () => context.go('/admin/transactions')),
                  _buildCard(context, Icons.settings, 'Settings', 'App Configuration', onTap: () => context.push('/admin/settings')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, IconData icon, String title, String subtitle, {VoidCallback? onTap, int badgeCount = 0}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(icon, size: 48, color: Colors.orange),
                  ),
                  if (badgeCount > 0)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                subtitle, 
                textAlign: TextAlign.center, 
                style: TextStyle(
                  fontSize: 12, 
                  color: badgeCount > 0 ? Colors.red : Colors.grey,
                  fontWeight: badgeCount > 0 ? FontWeight.bold : FontWeight.normal
                )
              ),
            ],
          ),
        ),
      ),
    );
  }
}
