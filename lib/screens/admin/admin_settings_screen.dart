import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;

  final _brandNameCtl = TextEditingController();
  final _tagLineCtl = TextEditingController();
  final _logoUrlCtl = TextEditingController();

  final _bFastMonthlyCtl = TextEditingController();
  final _lunchMonthlyCtl = TextEditingController();
  final _dinnerMonthlyCtl = TextEditingController();

  final _bFastYearlyCtl = TextEditingController();
  final _lunchYearlyCtl = TextEditingController();
  final _dinnerYearlyCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('app_settings').select().eq('id', 1).maybeSingle();
      if (data != null) {
        _brandNameCtl.text = data['brand_name'] ?? 'SAAPADU BOX';
        _tagLineCtl.text = data['tag_line'] ?? 'Taste of Home. In Every Bite.';
        _logoUrlCtl.text = data['logo_url'] ?? '';
        
        _bFastMonthlyCtl.text = (data['breakfast_price_monthly'] ?? 1500).toString();
        _lunchMonthlyCtl.text = (data['lunch_price_monthly'] ?? 2000).toString();
        _dinnerMonthlyCtl.text = (data['dinner_price_monthly'] ?? 2000).toString();
        
        _bFastYearlyCtl.text = (data['breakfast_price_yearly'] ?? 15000).toString();
        _lunchYearlyCtl.text = (data['lunch_price_yearly'] ?? 20000).toString();
        _dinnerYearlyCtl.text = (data['dinner_price_yearly'] ?? 20000).toString();
      } else {
        // Init row if missing
        await _supabase.from('app_settings').insert({'id': 1});
        _fetchSettings(); // re-fetch
        return;
      }
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _supabase.from('app_settings').update({
        'brand_name': _brandNameCtl.text.trim(),
        'tag_line': _tagLineCtl.text.trim(),
        'logo_url': _logoUrlCtl.text.trim(),
        'breakfast_price_monthly': double.tryParse(_bFastMonthlyCtl.text) ?? 1500,
        'lunch_price_monthly': double.tryParse(_lunchMonthlyCtl.text) ?? 2000,
        'dinner_price_monthly': double.tryParse(_dinnerMonthlyCtl.text) ?? 2000,
        'breakfast_price_yearly': double.tryParse(_bFastYearlyCtl.text) ?? 15000,
        'lunch_price_yearly': double.tryParse(_lunchYearlyCtl.text) ?? 20000,
        'dinner_price_yearly': double.tryParse(_dinnerYearlyCtl.text) ?? 20000,
      }).eq('id', 1);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'App Settings & Configurations'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Branding Details'),
              const SizedBox(height: 16),
              TextField(controller: _brandNameCtl, decoration: const InputDecoration(labelText: 'Brand Name', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _tagLineCtl, decoration: const InputDecoration(labelText: 'Tag Line', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _logoUrlCtl, decoration: const InputDecoration(labelText: 'Logo URL', border: OutlineInputBorder())),
              const SizedBox(height: 32),

              _buildSectionTitle('Monthly Prices (30 Days)'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _bFastMonthlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Breakfast', border: OutlineInputBorder(), prefixText: '₹'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _lunchMonthlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lunch', border: OutlineInputBorder(), prefixText: '₹'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _dinnerMonthlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dinner', border: OutlineInputBorder(), prefixText: '₹'))),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('Yearly Prices (365 Days)'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextField(controller: _bFastYearlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Breakfast', border: OutlineInputBorder(), prefixText: '₹'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _lunchYearlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Lunch', border: OutlineInputBorder(), prefixText: '₹'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _dinnerYearlyCtl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dinner', border: OutlineInputBorder(), prefixText: '₹'))),
                ],
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('Save Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              )
            ],
          )
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
        const Divider(),
      ],
    );
  }
}
