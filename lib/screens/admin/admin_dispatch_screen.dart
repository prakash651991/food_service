import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_app_bar.dart';

class AdminDispatchScreen extends StatefulWidget {
  const AdminDispatchScreen({super.key});

  @override
  State<AdminDispatchScreen> createState() => _AdminDispatchScreenState();
}

class _AdminDispatchScreenState extends State<AdminDispatchScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _selectedMeal = 'breakfast';
  bool _isLoading = false;
  List<Map<String, dynamic>> _deliveries = [];

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  String get _todayStr {
    DateTime now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDeliveries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch any explicit statuses from daily_deliveries table
      final deliveryRes = await _supabase.from('daily_deliveries')
          .select()
          .eq('delivery_date', _todayStr)
          .eq('meal_type', _selectedMeal);
          
      Map<String, String> existingStatusMap = {};
      for (var row in deliveryRes) {
        existingStatusMap[row['customer_id'] as String] = row['status'] as String;
      }

      // 2. Fetch active subscriptions for this meal along with profile info
      List<dynamic> activeSubs = [];
      if (_selectedMeal == 'breakfast') {
        activeSubs = await _supabase.from('subscriptions')
          .select('id, profiles(id, full_name, phone, address, landmark)')
          .eq('status', 'active')
          .eq('has_breakfast', true)
          .gte('breakfast_expiry', _todayStr);
      } else if (_selectedMeal == 'lunch') {
        activeSubs = await _supabase.from('subscriptions')
          .select('id, profiles(id, full_name, phone, address, landmark)')
          .eq('status', 'active')
          .eq('has_lunch', true)
          .gte('lunch_expiry', _todayStr);
      } else {
        activeSubs = await _supabase.from('subscriptions')
          .select('id, profiles(id, full_name, phone, address, landmark)')
          .eq('status', 'active')
          .eq('has_dinner', true)
          .gte('dinner_expiry', _todayStr);
      }

      // 3. Filter pauses active for today and this meal
      final activePausesRes = await _supabase.from('pause_logs')
          .select('subscription_id')
          .eq('meal_type', _selectedMeal)
          .lte('pause_start_date', _todayStr)
          .gte('pause_end_date', _todayStr);
          
      Set<String> pausedSubIds = activePausesRes.map((p) => p['subscription_id'] as String).toSet();

      // 4. Construct merged list
      List<Map<String, dynamic>> resultingDeliveries = [];
      Set<String> addedCustomerIds = {};

      for (var sub in activeSubs) {
        String subId = sub['id'] as String;
        if (pausedSubIds.contains(subId)) continue; // Paused today

        final profile = sub['profiles'];
        if (profile == null) continue;
        
        String cId = profile['id'] as String;
        
        // Deduplicate: Don't add the same customer twice for the same meal type today
        if (addedCustomerIds.contains(cId)) continue;
        
        String status = existingStatusMap[cId] ?? 'pending';

        resultingDeliveries.add({
          'customer_id': cId,
          'full_name': profile['full_name'] ?? 'Unknown',
          'phone': profile['phone'] ?? '',
          'address': profile['address'] ?? '',
          'landmark': profile['landmark'] ?? '',
          'status': status,
        });
        
        addedCustomerIds.add(cId);
      }

      if (mounted) {
        setState(() {
          _deliveries = resultingDeliveries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateStatus(String customerId, String newStatus) async {
    try {
      await _supabase.from('daily_deliveries').upsert({
        'customer_id': customerId,
        'delivery_date': _todayStr,
        'meal_type': _selectedMeal,
        'status': newStatus,
      }, onConflict: 'customer_id, delivery_date, meal_type');

      // Update state locally
      int index = _deliveries.indexWhere((element) => element['customer_id'] == customerId);
      if (index != -1) {
        setState(() {
          _deliveries[index]['status'] = newStatus;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _callCustomer(String phone) async {
    final Uri url = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open phone dialer.')));
      }
    }
  }

  Widget _buildAnalyticsBanner() {
    int total = _deliveries.length;
    if (total == 0) return const SizedBox.shrink();

    int pending = _deliveries.where((d) => d['status'] == 'pending').length;
    int dispatched = _deliveries.where((d) => d['status'] == 'dispatched').length;
    int delivered = _deliveries.where((d) => d['status'] == 'delivered').length;
    int unable = _deliveries.where((d) => d['status'] == 'unable_to_deliver').length;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Text('$_selectedMeal Analytics Overview', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCircular('Pending', pending, total, Colors.orange),
              _buildStatCircular('Dispatched', dispatched, total, Colors.blue),
              _buildStatCircular('Delivered', delivered, total, Colors.green),
              _buildStatCircular('Failed', unable, total, Colors.red),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatCircular(String label, int count, int total, Color color) {
    double percentage = (count / total) * 100;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: count / total,
                strokeWidth: 4,
                color: color,
                backgroundColor: color.withOpacity(0.2),
              ),
            ),
            Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
        Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Dispatch Details'),
      body: Column(
        children: [
          // Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMealTab('Breakfast', 'breakfast'),
                _buildMealTab('Lunch', 'lunch'),
                _buildMealTab('Dinner', 'dinner'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchDeliveries,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAnalyticsBanner(),
                          if (_deliveries.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text('No active deliveries found for this meal today.'),
                              ),
                            )
                          else
                            ..._deliveries.map((delivery) => _buildDeliveryCard(delivery)),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTab(String title, String mealType) {
    bool isSelected = _selectedMeal == mealType;
    return InkWell(
      onTap: () {
        if (_selectedMeal != mealType) {
          setState(() {
            _selectedMeal = mealType;
            _deliveries = []; // clear old before loading
          });
          _fetchDeliveries();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    Color statusColor = Colors.orange;
    if (delivery['status'] == 'dispatched') statusColor = Colors.blue;
    if (delivery['status'] == 'delivered') statusColor = Colors.green;
    if (delivery['status'] == 'unable_to_deliver') statusColor = Colors.red;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    delivery['full_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: delivery['status'],
                      isDense: true,
                      style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(value: 'dispatched', child: Text('Dispatched')),
                        DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                        DropdownMenuItem(value: 'unable_to_deliver', child: Text('Failed')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _updateStatus(delivery['customer_id'], val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(delivery['address'], style: const TextStyle(fontSize: 14)),
                      if ((delivery['landmark'] ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text('Landmark: ${delivery['landmark']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(delivery['phone'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if ((delivery['phone'] ?? '').isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () => _callCustomer(delivery['phone']),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: const Size(0, 0),
                    ),
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
