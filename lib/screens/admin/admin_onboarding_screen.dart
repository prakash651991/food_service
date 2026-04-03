import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../widgets/custom_app_bar.dart';

class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Customer Details
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _landmarkCtl = TextEditingController();
  final _pincodeCtl = TextEditingController();
  final _areaCtl = TextEditingController();

  // Subscription Details
  String _planType = 'monthly'; // monthly, yearly
  bool _hasBreakfast = false;
  bool _hasLunch = false;
  bool _hasDinner = false;
  bool _isLoading = false;
  
  Map<String, dynamic>? _settings;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await Supabase.instance.client.from('app_settings').select().eq('id', 1).maybeSingle();
      if (mounted && res != null) {
        setState(() {
          _settings = res;
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    }
  }

  Future<void> _fetchAreaFromPincode(String pincode) async {
    if (pincode.length != 6) return;
    try {
      final response = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOfficeList = data[0]['PostOffice'] as List;
          if (postOfficeList.isNotEmpty) {
            String areaName = postOfficeList[0]['Name'];
            setState(() {
              _areaCtl.text = areaName;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching area: $e");
    }
  }

  double _calculateTotalAmount() {
    double bFastPrice = _planType == 'monthly' ? (_settings?['breakfast_price_monthly'] ?? 1500).toDouble() : (_settings?['breakfast_price_yearly'] ?? 15000).toDouble();
    double lunchPrice = _planType == 'monthly' ? (_settings?['lunch_price_monthly'] ?? 2000).toDouble() : (_settings?['lunch_price_yearly'] ?? 20000).toDouble();
    double dinnerPrice = _planType == 'monthly' ? (_settings?['dinner_price_monthly'] ?? 2000).toDouble() : (_settings?['dinner_price_yearly'] ?? 20000).toDouble();

    double total = 0;
    if (_hasBreakfast) total += bFastPrice;
    if (_hasLunch) total += lunchPrice;
    if (_hasDinner) total += dinnerPrice;

    return total;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasBreakfast && !_hasLunch && !_hasDinner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one meal')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tempClient = SupabaseClient(
        dotenv.env['SUPABASE_URL']!,
        dotenv.env['SUPABASE_ANON_KEY']!,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );

      final response = await tempClient.auth.signUp(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text,
        data: {
          'full_name': _nameCtl.text.trim(),
          'phone': _phoneCtl.text.trim(),
          'address': _addressCtl.text.trim(),
          'landmark': _landmarkCtl.text.trim(),
          'pincode': _pincodeCtl.text.trim(),
          'area': _areaCtl.text.trim(),
        },
      );

      if (response.user != null) {
        String newUserId = response.user!.id;

        // Calculate Expiry Dates
        int days = _planType == 'monthly' ? 30 : 365;
        DateTime expiry = DateTime.now().add(Duration(days: days));
        String expiryStr = "${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}";

        // Add subscription directly via main client (admin has permissions)
        final mainSupabase = Supabase.instance.client;
        await mainSupabase.from('subscriptions').insert({
          'customer_id': newUserId,
          'plan_type': _planType,
          'has_breakfast': _hasBreakfast,
          'has_lunch': _hasLunch,
          'has_dinner': _hasDinner,
          'breakfast_expiry': _hasBreakfast ? expiryStr : null,
          'lunch_expiry': _hasLunch ? expiryStr : null,
          'dinner_expiry': _hasDinner ? expiryStr : null,
          'status': 'payment_pending', // Assuming admin will collect payment/set active
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer onboarded successfully.')));
          Navigator.pop(context); // Go back after success
        }
      } else {
        throw Exception("User creation failed: No user returned.");
      }
      
      tempClient.dispose();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error onboarding customer: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _landmarkCtl.dispose();
    _pincodeCtl.dispose();
    _areaCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double totalPayable = _calculateTotalAmount();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Manual Customer Onboarding'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Customer Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtl,
                      decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (val) => val == null || !val.contains('@') ? 'Enter valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtl,
                      decoration: const InputDecoration(labelText: 'Temporary Password', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressCtl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _landmarkCtl,
                      decoration: const InputDecoration(labelText: 'Landmark', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _pincodeCtl,
                      decoration: const InputDecoration(labelText: 'Pincode (6 digits)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onChanged: (val) {
                        if (val.length == 6) {
                          _fetchAreaFromPincode(val);
                        }
                      },
                      validator: (val) => val == null || val.isEmpty || val.length != 6 ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _areaCtl,
                      decoration: const InputDecoration(labelText: 'Area / Location', border: OutlineInputBorder()),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 32),
                    
                    const Text('Subscription Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _planType,
                      decoration: const InputDecoration(labelText: 'Plan Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'monthly', child: Text('Monthly (30 Days)')),
                        DropdownMenuItem(value: 'yearly', child: Text('Yearly (365 Days)')),
                      ],
                      onChanged: (val) => setState(() => _planType = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Meals:', style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      title: const Text('Breakfast'),
                      value: _hasBreakfast,
                      onChanged: (val) => setState(() => _hasBreakfast = val!),
                    ),
                    CheckboxListTile(
                      title: const Text('Lunch'),
                      value: _hasLunch,
                      onChanged: (val) => setState(() => _hasLunch = val!),
                    ),
                    CheckboxListTile(
                      title: const Text('Dinner'),
                      value: _hasDinner,
                      onChanged: (val) => setState(() => _hasDinner = val!),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Payable Amount:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${totalPayable.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Onboard Customer & Create Subscription', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
