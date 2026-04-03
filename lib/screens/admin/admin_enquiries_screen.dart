import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminEnquiriesScreen extends StatefulWidget {
  const AdminEnquiriesScreen({super.key});

  @override
  State<AdminEnquiriesScreen> createState() => _AdminEnquiriesScreenState();
}

class _AdminEnquiriesScreenState extends State<AdminEnquiriesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _enquiries = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchEnquiries();
  }

  Future<void> _fetchEnquiries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final settingsRes = await _supabase.from('app_settings').select().eq('id', 1).maybeSingle();
      
      final res = await _supabase
          .from('subscriptions')
          .select('*, profiles(id, full_name, phone, address, landmark)')
          .eq('status', 'pending_approval')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _settings = settingsRes;
          _enquiries = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching enquiries: $e')));
      }
    }
  }

  Future<void> _updateEnquiryStatus(String subscriptionId, String newStatus) async {
    try {
      await _supabase
          .from('subscriptions')
          .update({'status': newStatus})
          .eq('id', subscriptionId);
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enquiry status updated to $newStatus')));
      }
      _fetchEnquiries(); // Refresh the list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  String _formatMeals(Map<String, dynamic> enquiry) {
    List<String> meals = [];
    if (enquiry['has_breakfast'] == true) meals.add('Breakfast');
    if (enquiry['has_lunch'] == true) meals.add('Lunch');
    if (enquiry['has_dinner'] == true) meals.add('Dinner');
    return meals.join(', ');
  }

  double _calculateAmount(Map<String, dynamic> enquiry) {
    if (_settings == null) return 0.0;
    
    String planType = enquiry['plan_type'] ?? 'monthly';
    bool hasBreakfast = enquiry['has_breakfast'] == true;
    bool hasLunch = enquiry['has_lunch'] == true;
    bool hasDinner = enquiry['has_dinner'] == true;

    double bFastPrice = planType == 'monthly' ? (_settings!['breakfast_price_monthly'] ?? 1500).toDouble() : (_settings!['breakfast_price_yearly'] ?? 15000).toDouble();
    double lunchPrice = planType == 'monthly' ? (_settings!['lunch_price_monthly'] ?? 2000).toDouble() : (_settings!['lunch_price_yearly'] ?? 20000).toDouble();
    double dinnerPrice = planType == 'monthly' ? (_settings!['dinner_price_monthly'] ?? 2000).toDouble() : (_settings!['dinner_price_yearly'] ?? 20000).toDouble();

    double total = 0;
    if (hasBreakfast) total += bFastPrice;
    if (hasLunch) total += lunchPrice;
    if (hasDinner) total += dinnerPrice;

    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Pending Enquiries'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchEnquiries,
              child: _enquiries.isEmpty
                  ? const Center(child: Text('No pending enquiries at the moment.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _enquiries.length,
                      itemBuilder: (context, index) {
                        final enquiry = _enquiries[index];
                        final profile = enquiry['profiles'] ?? {};
                        final meals = _formatMeals(enquiry);
                        final planType = (enquiry['plan_type'] as String?)?.toUpperCase() ?? 'UNKNOWN';

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                        profile['full_name'] ?? 'Unknown User',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(planType, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(profile['phone'] ?? 'No phone'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(profile['address'] ?? 'No address'),
                                          if ((profile['landmark'] ?? '').isNotEmpty)
                                            Text('Landmark: ${profile['landmark']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.restaurant_menu, size: 16, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text('Requested Meals: $meals', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.currency_rupee, size: 16, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text('Amount to Pay: ₹${_calculateAmount(enquiry).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _updateEnquiryStatus(enquiry['id'], 'rejected'),
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: () => _updateEnquiryStatus(enquiry['id'], 'payment_pending'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                      child: const Text('Approve'),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
