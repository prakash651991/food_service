import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final PreferredSizeWidget? bottom;
  
  const CustomAppBar({super.key, required this.title, this.bottom});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          Image.asset('assets/logo.png', width: 34, height: 34),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
        ],
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: Colors.black12,
      iconTheme: IconThemeData(color: Colors.orange.shade900),
      bottom: bottom,
      actions: [
        IconButton(
          icon: Icon(Icons.account_circle, size: 28, color: Colors.orange.shade900),
          onPressed: () => _showProfileBottomSheet(context),
        ),
      ],
    );
  }

  void _showProfileBottomSheet(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Consumer<AuthProvider>(
          builder: (context, auth, child) {
            final prof = auth.profile;
            final user = auth.user;
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 80, color: Colors.orange),
                  const SizedBox(height: 12),
                  Text(
                    prof?['full_name'] ?? 'User Profile',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const Divider(height: 30),
                  _buildDetailRow(Icons.badge, 'Customer ID', prof?['id'] ?? '-'),
                  _buildDetailRow(Icons.phone, 'Phone', prof?['phone'] ?? '-'),
                  _buildDetailRow(
                    Icons.location_on, 
                    'Address', 
                    prof?['address'] ?? '-',
                    onEdit: () => _showEditAddressDialog(parentContext, auth),
                  ),
                  _buildDetailRow(
                    Icons.map, 
                    'Landmark', 
                    prof?['landmark'] ?? '-',
                    onEdit: () => _showEditAddressDialog(parentContext, auth),
                  ),
                  _buildDetailRow(Icons.pin_drop, 'Pincode', prof?['pincode'] ?? '-'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext); // Close sheet
                        await auth.signOut();
                        if (parentContext.mounted) parentContext.go('/auth');
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.edit, size: 20, color: Colors.orange),
              ),
            ),
        ],
      ),
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
              title: const Text('Edit Address Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: landmarkController,
                    decoration: const InputDecoration(
                      labelText: 'Landmark',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address updated successfully')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to update address')),
                          );
                        }
                        setState(() => isSaving = false);
                      }
                    } else {
                      setState(() => isSaving = false);
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}
