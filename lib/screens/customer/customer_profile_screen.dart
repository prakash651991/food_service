import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF5E5),
      appBar: const CustomAppBar(title: 'My SAAPADU BOX'),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final prof = auth.profile;
          final user = auth.user;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    prof?['full_name'] ?? 'User Profile',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow(context, Icons.badge, 'Customer ID', prof?['id'] ?? '-'),
                  const Divider(height: 24),
                  _buildDetailRow(context, Icons.phone, 'Phone Number', prof?['phone'] ?? '-'),
                  const Divider(height: 24),
                  _buildDetailRow(
                    context,
                    Icons.location_on, 
                    'Address', 
                    prof?['address'] ?? '-',
                    onEdit: () => _showEditAddressDialog(context, auth),
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(
                    context,
                    Icons.map, 
                    'Landmark', 
                    prof?['landmark'] ?? '-',
                    onEdit: () => _showEditAddressDialog(context, auth),
                  ),
                  const Divider(height: 24),
                  _buildDetailRow(context, Icons.pin_drop, 'Pincode', prof?['pincode'] ?? '-'),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) context.go('/auth');
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {VoidCallback? onEdit}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.orange.shade700, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (onEdit != null)
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.edit, size: 20, color: Colors.orange),
            ),
          ),
      ],
    );
  }

  void _showEditAddressDialog(BuildContext context, AuthProvider auth) {
    final addressController = TextEditingController(text: auth.profile?['address'] ?? '');
    final landmarkController = TextEditingController(text: auth.profile?['landmark'] ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Address Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: landmarkController,
                    decoration: const InputDecoration(labelText: 'Landmark', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setState(() => isSaving = true);
                    final newAddress = addressController.text.trim();
                    final newLandmark = landmarkController.text.trim();
                    
                    if (newAddress.isNotEmpty) {
                      try {
                        await auth.updateProfile(address: newAddress, landmark: newLandmark);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address updated successfully')));
                        }
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update address')));
                        setState(() => isSaving = false);
                      }
                    } else {
                      setState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
