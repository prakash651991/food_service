import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  String _selectedPeriod = 'Current Month'; // Today, Current Month, All Time

  int _customersCount = 0;
  int _subscriptionsCount = 0;
  double _totalRevenue = 0.0;
  
  int _todaysBreakfast = 0;
  int _todaysLunch = 0;
  int _todaysDinner = 0;

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      DateTime now = DateTime.now();
      String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      DateTime periodStart;
      if (_selectedPeriod == 'Today') {
        periodStart = DateTime(now.year, now.month, now.day);
      } else if (_selectedPeriod == 'Current Month') {
        periodStart = DateTime(now.year, now.month, 1);
      } else {
        periodStart = DateTime(2000); // All time
      }

      // 1. Customers map to period
      final customersRes = await _supabase.from('profiles').select('created_at').eq('role', 'customer');
      _customersCount = customersRes.where((p) {
        if (p['created_at'] == null) return false;
        return DateTime.parse(p['created_at']).toLocal().isAfter(periodStart);
      }).length;

      // 2. Subscriptions map to period
      final subsResAll = await _supabase.from('subscriptions').select('created_at, status, id, has_breakfast, has_lunch, has_dinner, breakfast_expiry, lunch_expiry, dinner_expiry');
      _subscriptionsCount = subsResAll.where((s) {
        if (s['created_at'] == null) return false;
        return DateTime.parse(s['created_at']).toLocal().isAfter(periodStart);
      }).length;

      // 3. Today's Actual Completed Deliveries (Based on daily_deliveries table)
      final deliveriesRes = await _supabase.from('daily_deliveries')
          .select('meal_type')
          .eq('delivery_date', todayStr)
          .eq('status', 'delivered');

      int bCount = 0; int lCount = 0; int dCount = 0;
      for (var delivery in deliveriesRes) {
        if (delivery['meal_type'] == 'breakfast') bCount++;
        else if (delivery['meal_type'] == 'lunch') lCount++;
        else if (delivery['meal_type'] == 'dinner') dCount++;
      }
      
      _todaysBreakfast = bCount;
      _todaysLunch = lCount;
      _todaysDinner = dCount;

      // 4. Total revenue for period
      final txRes = await _supabase.from('transactions').select('amount, transaction_date').eq('status', 'success');
      double total = 0;
      for (var tx in txRes) {
        if (tx['transaction_date'] != null) {
           DateTime txDate = DateTime.parse(tx['transaction_date']).toLocal();
           if (txDate.isAfter(periodStart)) {
             total += (tx['amount'] ?? 0).toDouble();
           }
        }
      }
      _totalRevenue = total;

      if (mounted) setState(() => _isLoading = false);

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Analytics Overview'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchAnalytics,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Business Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                      underline: Container(height: 2, color: Colors.orange),
                      items: const [
                        DropdownMenuItem(value: 'Today', child: Text('Today')),
                        DropdownMenuItem(value: 'Current Month', child: Text('Current Month')),
                        DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                      ],
                      onChanged: (val) {
                        if (val != null && val != _selectedPeriod) {
                          setState(() => _selectedPeriod = val);
                          _fetchAnalytics();
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Revenue', '₹${_totalRevenue.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.green)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard('New Customers', '$_customersCount', Icons.people, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricCard('New Subscriptions', '$_subscriptionsCount', Icons.card_membership, Colors.purple),
                
                const SizedBox(height: 32),
                const Text('Today\'s Deliveries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 16),
                _buildMealStatCard('Breakfasts', _todaysBreakfast, Icons.breakfast_dining, Colors.orange.shade300),
                const SizedBox(height: 12),
                _buildMealStatCard('Lunches', _todaysLunch, Icons.lunch_dining, Colors.orange.shade500),
                const SizedBox(height: 12),
                _buildMealStatCard('Dinners', _todaysDinner, Icons.dinner_dining, Colors.orange.shade700),
              ],
            ),
          )
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(count.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
