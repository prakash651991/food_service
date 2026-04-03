import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminCustomerManagementScreen extends StatefulWidget {
  const AdminCustomerManagementScreen({super.key});

  @override
  State<AdminCustomerManagementScreen> createState() => _AdminCustomerManagementScreenState();
}

class _AdminCustomerManagementScreenState extends State<AdminCustomerManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  bool _isLoading = false;
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchCtl.addListener(_filterCustomers);
  }

  Future<void> _fetchCustomers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'customer')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(res);
          _filteredCustomers = _customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching customers: $e')));
      }
    }
  }

  void _filterCustomers() {
    String query = _searchCtl.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((c) {
        final name = (c['full_name'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Customer Management'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/onboarding');
          _fetchCustomers(); // Refresh on pop
        },
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.person_add),
        label: const Text('Manual Onboard'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                labelText: 'Search by Name or Phone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchCustomers,
                    child: _filteredCustomers.isEmpty
                        ? const Center(child: Text('No customers found.'))
                        : ListView.builder(
                            itemCount: _filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = _filteredCustomers[index];
                              final idShort = customer['id']?.toString().substring(0, 8).toUpperCase() ?? '';
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.orange,
                                  child: Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(customer['full_name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer['phone'] ?? 'No phone'),
                                    const SizedBox(height: 2),
                                    Text('ID: $idShort', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  context.push('/admin/customer-details', extra: customer['id']);
                                },
                                shape: const Border(bottom: BorderSide(color: Colors.black12)),
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
