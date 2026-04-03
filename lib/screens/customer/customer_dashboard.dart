import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  List<Map<String, dynamic>> _activeSubscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscription();
  }

  Future<void> _fetchSubscription() async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        // Fetch subscriptions separated from transactions to avoid complex relational errors blockages
        final subsRes = await Supabase.instance.client
            .from('subscriptions')
            .select()
            .eq('customer_id', user.id)
            .order('created_at', ascending: true);

        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        List<Map<String, dynamic>> finalActiveSubs = [];

        for (var sub in List<Map<String, dynamic>>.from(subsRes)) {
            // Self-Healing Status Checker
            if (['active', 'paused'].contains(sub['status'])) {
                DateTime getDt(dynamic d) => d != null ? DateTime.parse(d) : DateTime(2000);
                DateTime maxExp = getDt(sub['breakfast_expiry']);
                if (getDt(sub['lunch_expiry']).isAfter(maxExp)) maxExp = getDt(sub['lunch_expiry']);
                if (getDt(sub['dinner_expiry']).isAfter(maxExp)) maxExp = getDt(sub['dinner_expiry']);
                
                if (maxExp.year > 2000 && maxExp.isBefore(today)) {
                    // Plan expired: silently update the database
                    await Supabase.instance.client.from('subscriptions').update({'status': 'expired'}).eq('id', sub['id']);
                    sub['status'] = 'expired';
                }
            }
            
            if (['active', 'pending_approval', 'payment_pending', 'paused'].contains(sub['status'])) {
               finalActiveSubs.add(sub);
            }
        }

        if (finalActiveSubs.isNotEmpty) {
           final subIds = finalActiveSubs.map((s) => s['id']).toList();
           
           // Fetch amount related to these subscriptions
           final txnsRes = await Supabase.instance.client
               .from('transactions')
               .select('subscription_id, amount')
               .filter('subscription_id', 'in', subIds)
               .neq('type', 'pause_adjustment');
               
           // Map transaction amounts back to the parsed subscriptions
           for (var sub in finalActiveSubs) {
              final subTxns = (txnsRes as List).where((tx) => tx['subscription_id'] == sub['id']).toList();
              sub['transactions'] = subTxns;
           }
        }

        _activeSubscriptions = finalActiveSubs;
      }
    } catch (e) {
      debugPrint("Error fetching sub: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySubscriptionCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No Active Plan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Subscribe to start receiving delicious food!', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.push('/subscribe');
              _fetchSubscription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> sub) {
    String subTitle;
    String btnText;
    Color btnColor;
    Color cardStartColor;
    Color cardEndColor;
    IconData icon;

    final status = sub['status'];
    String planType = sub['plan_type'] ?? 'monthly';
    
    if (status == 'pending_approval') {
      subTitle = 'Pending Approval';
      btnText = 'View Status';
      btnColor = Colors.blue.shade900;
      cardStartColor = Colors.blue.shade400;
      cardEndColor = Colors.blue.shade700;
      icon = Icons.hourglass_top_rounded;
    } else if (status == 'payment_pending') {
      subTitle = 'Payment Required';
      btnText = 'Pay Now';
      btnColor = Colors.orange.shade900;
      cardStartColor = Colors.orange.shade400;
      cardEndColor = Colors.deepOrange.shade600;
      icon = Icons.payment;
    } else if (status == 'paused') {
      subTitle = 'Plan Paused (${planType.toUpperCase()})';
      btnText = 'Manage Plan';
      btnColor = Colors.purple.shade900;
      cardStartColor = Colors.purple.shade400;
      cardEndColor = Colors.purple.shade700;
      icon = Icons.pause_circle_filled;
    } else {
      subTitle = 'Active Plan (${planType.toUpperCase()})';
      btnText = 'Manage Plan';
      btnColor = Colors.green.shade900;
      cardStartColor = Colors.green.shade500;
      cardEndColor = Colors.teal.shade700;
      icon = Icons.check_circle_rounded;
    }

    // Extract Plan Details
    final createdAtStr = sub['created_at']?.toString().substring(0, 10) ?? 'N/A';
    
    List<DateTime> expiries = [];
    if (sub['breakfast_expiry'] != null) expiries.add(DateTime.parse(sub['breakfast_expiry']));
    if (sub['lunch_expiry'] != null) expiries.add(DateTime.parse(sub['lunch_expiry']));
    if (sub['dinner_expiry'] != null) expiries.add(DateTime.parse(sub['dinner_expiry']));
    
    String expiryStr = 'N/A';
    if (expiries.isNotEmpty) {
      expiries.sort();
      expiryStr = expiries.last.toString().substring(0, 10);
    }
    
    String amountStr = 'N/A';
    if (sub['transactions'] != null && (sub['transactions'] as List).isNotEmpty) {
       var txns = sub['transactions'] as List;
       // Find the first non-null amount
       for (var tx in txns) {
         if (tx['amount'] != null) {
           amountStr = '₹${tx['amount']}';
           break;
         }
       }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardStartColor, cardEndColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardEndColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  subTitle, 
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Details Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               _buildDetailItem('Start Date', createdAtStr),
               _buildDetailItem('Expiry Date', expiryStr),
               _buildDetailItem('Amount', amountStr),
            ]
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: ${sub['id'].toString().substring(0, 8).toUpperCase()}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w700),
              ),
              ElevatedButton(
                onPressed: () async {
                  await context.push('/subscribe');
                  _fetchSubscription();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: btnColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCarousel() {
    if (_activeSubscriptions.isEmpty) {
      return _buildEmptySubscriptionCard();
    }

    return SizedBox(
      height: 220,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.93),
        padEnds: false,
        itemCount: _activeSubscriptions.length,
        itemBuilder: (context, index) {
          return _buildSubscriptionCard(_activeSubscriptions[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF5E5),
      appBar: const CustomAppBar(title: 'My SAAPADU BOX'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 5)),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${context.watch<AuthProvider>().profile?['full_name'] ?? 'Guest'}!',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _activeSubscriptions.isNotEmpty
                                ? 'Your Current Subscriptions'
                                : 'Subscription Status',
                            style: TextStyle(fontSize: 14, color: Colors.orange.shade800, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 16),
                          _buildSubscriptionCarousel(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                        Icon(Icons.flash_on, color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Column(
                      children: [
                        _buildActionCard(
                          title: 'Pause Meal',
                          subtitle: 'Going out? Pause specific meals temporarily.',
                          icon: Icons.pause_circle_outline,
                          iconColor: Colors.blue,
                          borderColor: Colors.blue.shade100,
                          onTap: () => context.push('/pause-meal'),
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          title: 'Transaction & Audit',
                          subtitle: 'View your payment and refund history instantly.',
                          icon: Icons.history,
                          iconColor: Colors.green,
                          borderColor: Colors.green.shade100,
                          onTap: () => context.push('/transactions'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }
}
