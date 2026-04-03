import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class CustomerPauseMealScreen extends StatefulWidget {
  final bool hideAppBar;
  const CustomerPauseMealScreen({super.key, this.hideAppBar = false});

  @override
  State<CustomerPauseMealScreen> createState() => _CustomerPauseMealScreenState();
}

class _CustomerPauseMealScreenState extends State<CustomerPauseMealScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _subscriptions = [];
  List<dynamic> _pauseLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) return;

      final subsFuture = await _supabase.from('subscriptions').select().eq('customer_id', user.id).order('created_at', ascending: false);
      
      _subscriptions = subsFuture as List<dynamic>;
      
      List<String> subIds = _subscriptions.map((s) => s['id'] as String).toList();
      if (subIds.isNotEmpty) {
        _pauseLogs = await _supabase.from('pause_logs')
            .select()
            .filter('subscription_id', 'in', subIds)
            .order('created_at', ascending: false);
      } else {
        _pauseLogs = [];
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openPauseDialog(Map<String, dynamic> subscription) {
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // Determine which meals are active and valid to pause
    List<String> validMeals = [];
    if (subscription['has_breakfast'] == true && subscription['breakfast_expiry'] != null) {
      if (!DateTime.parse(subscription['breakfast_expiry']).isBefore(today)) validMeals.add('breakfast');
    }
    if (subscription['has_lunch'] == true && subscription['lunch_expiry'] != null) {
      if (!DateTime.parse(subscription['lunch_expiry']).isBefore(today)) validMeals.add('lunch');
    }
    if (subscription['has_dinner'] == true && subscription['dinner_expiry'] != null) {
      if (!DateTime.parse(subscription['dinner_expiry']).isBefore(today)) validMeals.add('dinner');
    }

    if (validMeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active meals available to pause.')));
      return;
    }

    String selectedMeal = validMeals.first;
    
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Meal Pause', style: TextStyle(color: Colors.orange)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedMeal,
                  items: validMeals.map((meal) => DropdownMenuItem(
                    value: meal,
                    child: Text(meal[0].toUpperCase() + meal.substring(1)),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedMeal = val!),
                  decoration: const InputDecoration(labelText: 'Meal Type', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(startDate == null ? 'Select Start Date' : "Start: ${startDate?.toLocal().toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_today, color: Colors.orange),
                  onTap: () async {
                    DateTime? d = await showDatePicker(
                      context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    setDialogState(() => startDate = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(endDate == null ? 'Select End Date' : "End: ${endDate?.toLocal().toString().split(' ')[0]}"),
                  trailing: const Icon(Icons.calendar_today, color: Colors.orange),
                  onTap: () async {
                    DateTime? d = await showDatePicker(
                      context: context, initialDate: startDate ?? DateTime.now(), firstDate: startDate ?? DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                    setDialogState(() => endDate = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                onPressed: () {
                  if (startDate != null && endDate != null) {
                    String expiryKey = '${selectedMeal}_expiry';
                    DateTime currentExpiry = DateTime.parse(subscription[expiryKey]);
                    if (startDate!.isAfter(currentExpiry)) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Start date cannot be after the current $selectedMeal expiry date.')));
                       return;
                    }
                    Navigator.pop(context);
                    _applyPause(subscription['id'], selectedMeal, startDate!, endDate!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select both start and end dates')));
                  }
                },
                child: const Text('Confirm Pause'),
              )
            ],
          );
        }
      ),
    );
  }

  Future<void> _applyPause(String subscriptionId, String mealType, DateTime start, DateTime end) async {
    final user = context.read<AuthProvider>().user;
    int days = end.difference(start).inDays + 1;
    String startStr = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    String endStr = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";

    setState(() => _isLoading = true);
    try {
      // Find current expiry
      final sub = _subscriptions.firstWhere((s) => s['id'] == subscriptionId);
      String column = '${mealType}_expiry';
      dynamic currentExpiry = sub[column];
      
      DateTime nextExpiry;
      if (currentExpiry != null) {
        DateTime parsed = DateTime.parse(currentExpiry);
        if (parsed.isAfter(DateTime.now()) || parsed.isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
             nextExpiry = parsed.add(Duration(days: days));
        } else {
             throw Exception("Cannot pause an expired meal.");
        }
      } else {
        throw Exception("Invalid meal expiry.");
      }
      String nextExpiryStr = "${nextExpiry.year}-${nextExpiry.month.toString().padLeft(2, '0')}-${nextExpiry.day.toString().padLeft(2, '0')}";

      // Record pause log
      await _supabase.from('pause_logs').insert({
        'subscription_id': subscriptionId,
        'meal_type': mealType,
        'pause_start_date': startStr,
        'pause_end_date': endStr,
        'days_paused': days,
      });

      // Add audit transaction line showing 0 amount for pause adjust
      await _supabase.from('transactions').insert({
        'subscription_id': subscriptionId,
        'customer_id': user?.id,
        'amount': 0,
        'type': 'pause_adjustment',
        'status': 'success',
      });

      // Update expiry dates
      await _supabase.from('subscriptions').update({column: nextExpiryStr}).eq('id', subscriptionId);

      _fetchData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully paused $mealType for $days days. Expiry extended to $nextExpiryStr!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error applying pause: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> activeSubs = _subscriptions
        .where((s) => s['status'] == 'active' || s['status'] == 'paused')
        .map((s) => Map<String, dynamic>.from(s as Map))
        .toList();

    return Scaffold(
      appBar: widget.hideAppBar ? null : const CustomAppBar(title: 'My SAAPADU BOX'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Active Plan Controls', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 12),
                  if (activeSubs.isEmpty)
                    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("You do not have any active plans to pause right now.")))
                  else
                    ...activeSubs.map((activeSub) => Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Plan: ${(activeSub['plan_type'] ?? '').toString().toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Status: ${(activeSub['status'] ?? '').toString().toUpperCase()}', style: TextStyle(color: activeSub['status'] == 'active' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                            Text('Sub ID: ${activeSub['id'] != null ? (activeSub['id'].toString().length > 20 ? activeSub['id'].toString().substring(0,8).toUpperCase() : activeSub['id'].toString().toUpperCase()) : '-'}'),
                            Text('Cust ID: ${activeSub['customer_id'] != null ? (activeSub['customer_id'].toString().length > 20 ? activeSub['customer_id'].toString().substring(0,8).toUpperCase() : activeSub['customer_id'].toString().toUpperCase()) : '-'}'),
                            const SizedBox(height: 8),
                            const Divider(),
                            if (activeSub['has_breakfast'] == true) Text('Breakfast Expiry: ${activeSub['breakfast_expiry'] ?? 'N/A'}'),
                            if (activeSub['has_lunch'] == true) Text('Lunch Expiry: ${activeSub['lunch_expiry'] ?? 'N/A'}'),
                            if (activeSub['has_dinner'] == true) Text('Dinner Expiry: ${activeSub['dinner_expiry'] ?? 'N/A'}'),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton.icon(
                                onPressed: () => _openPauseDialog(activeSub),
                                icon: const Icon(Icons.pause),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                label: const Text('ADD TEMPORARY PAUSE'),
                              ),
                            )
                          ],
                        ),
                      ),
                    )).toList(),
                  const SizedBox(height: 32),
                  const Text('Your Pause History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 12),
                  _pauseLogs.isEmpty 
                    ? const Center(child: Padding(padding: EdgeInsets.only(top: 20), child: Text('No paused meals in your history.')))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _pauseLogs.length,
                        itemBuilder: (context, i) {
                          final log = _pauseLogs[i];
                          
                          Map<String, dynamic>? subLinked;
                          try {
                            subLinked = _subscriptions.firstWhere((s) => s['id'] == log['subscription_id']);
                          } catch (e) {
                            subLinked = null;
                          }
                          
                          String subId = log['subscription_id']?.toString() ?? '-';
                          String subStr = subId.length > 20 && !subId.startsWith('pay_') ? subId.substring(0,8).toUpperCase() : subId.toUpperCase();
                          String status = subLinked != null ? (subLinked['status'] ?? 'unknown').toString().toUpperCase() : 'UNKNOWN';
                          String custId = subLinked != null ? subLinked['customer_id']?.toString() ?? '-' : '-';
                          String custStr = custId.length > 20 ? custId.substring(0,8).toUpperCase() : custId.toUpperCase();

                          String subText = '${log['pause_start_date']} to ${log['pause_end_date']}\nDuration: ${log['days_paused']} days credited to expiry';
                          subText += '\nSub ID: $subStr | Status: $status\nCust ID: $custStr';

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: const Icon(Icons.pause_circle_filled, color: Colors.blue, size: 30),
                              title: Text('${(log['meal_type'] ?? '').toString().toUpperCase()} Paused', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(subText),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                ],
              ),
            ),
    );
  }
}
