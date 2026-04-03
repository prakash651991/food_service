import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

enum DateFilter { all, today, thisMonth, lastMonth, custom }

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  DateFilter _selectedFilter = DateFilter.all;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      var query = _supabase
          .from('transactions')
          .select('*, profiles(full_name), subscriptions(has_breakfast, has_lunch, has_dinner)');
          
      if (_selectedFilter != DateFilter.all) {
        DateTime now = DateTime.now();
        DateTime? start;
        DateTime? end;
        
        switch (_selectedFilter) {
          case DateFilter.today:
            start = DateTime(now.year, now.month, now.day);
            end = DateTime(now.year, now.month, now.day, 23, 59, 59);
            break;
          case DateFilter.thisMonth:
            start = DateTime(now.year, now.month, 1);
            end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
            break;
          case DateFilter.lastMonth:
            start = DateTime(now.year, now.month - 1, 1);
            end = DateTime(now.year, now.month, 0, 23, 59, 59);
            break;
          case DateFilter.custom:
            if (_customDateRange != null) {
              start = _customDateRange!.start;
              end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
            }
            break;
          default:
            break;
        }

        if (start != null && end != null) {
          query = query.gte('transaction_date', start.toIso8601String())
                       .lte('transaction_date', end.toIso8601String());
        }
      }

      final res = await query.order('transaction_date', ascending: false);
      
      if (mounted) {
        setState(() {
          _transactions = List<Map<String, dynamic>>.from(res);
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_selectedFilter == DateFilter.custom && _customDateRange != null)
            Expanded(
               child: Text(
                 '${_formatDate(_customDateRange!.start)} to ${_formatDate(_customDateRange!.end)}',
                 style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                 overflow: TextOverflow.ellipsis,
               ),
            )
          else
            const Text(
              'Filter by Date:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateFilter>(
                value: _selectedFilter,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: DateFilter.all, child: Text('All Time')),
                  DropdownMenuItem(value: DateFilter.today, child: Text('Today')),
                  DropdownMenuItem(value: DateFilter.thisMonth, child: Text('This Month')),
                  DropdownMenuItem(value: DateFilter.lastMonth, child: Text('Last Month')),
                  DropdownMenuItem(value: DateFilter.custom, child: Text('Custom Range')),
                ],
                onChanged: (val) async {
                  if (val == DateFilter.custom) {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Colors.orange,
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedFilter = val!;
                        _customDateRange = picked;
                      });
                      _fetchTransactions();
                    } else if (_customDateRange == null) {
                      setState(() => _selectedFilter = DateFilter.all);
                      _fetchTransactions();
                    }
                  } else if (val != null) {
                    setState(() {
                      _selectedFilter = val;
                      _customDateRange = null;
                    });
                    _fetchTransactions();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'All Transactions'),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    child: _transactions.isEmpty
                        ? const Center(child: Text("No transactions available."))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transactions.length,
                            itemBuilder: (context, i) {
                              final tx = _transactions[i];
                              final customerName = tx['profiles']?['full_name'] ?? 'Unknown Customer';
                              bool isSuccess = tx['status'] == 'success';
                              
                              String subIdShort = (tx['subscription_id'] ?? '').toString();
                              if (subIdShort.length > 8) subIdShort = subIdShort.substring(0, 8).toUpperCase();
                              
                              String customerIdShort = (tx['customer_id'] ?? '').toString();
                              if (customerIdShort.length > 8) customerIdShort = customerIdShort.substring(0, 8).toUpperCase();

                              String txIdShort = (tx['id'] ?? '').toString();
                              if (txIdShort.length > 8) txIdShort = txIdShort.substring(0, 8).toUpperCase();

                              List<String> meals = [];
                              if (tx['subscriptions'] != null) {
                                  if (tx['subscriptions']['has_breakfast'] == true) meals.add('Breakfast');
                                  if (tx['subscriptions']['has_lunch'] == true) meals.add('Lunch');
                                  if (tx['subscriptions']['has_dinner'] == true) meals.add('Dinner');
                              }
                              String mealsStr = meals.isNotEmpty ? meals.join(', ') : 'N/A';

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isSuccess ? Colors.green.shade100 : Colors.red.shade100,
                                    child: Icon(Icons.currency_rupee, color: isSuccess ? Colors.green : Colors.red),
                                  ),
                                  title: Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text('${(tx['type']??'').toString().toUpperCase()} • $mealsStr', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                      const SizedBox(height: 4),
                                      Text('Date: ${DateTime.parse(tx['transaction_date']).toLocal().toString().split('.')[0]}'),
                                      const SizedBox(height: 2),
                                      Text('Cust ID: $customerIdShort | Sub ID: $subIdShort', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      Text('Tx ID: $txIdShort', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                                  isThreeLine: true,
                                  trailing: Text(
                                    '₹${tx['amount']}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSuccess ? Colors.green : Colors.red),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
