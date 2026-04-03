import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_app_bar.dart';
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _hasBreakfast = false;
  bool _hasLunch = false;
  bool _hasDinner = false;
  String _planType = 'monthly';
  bool _isLoading = true;
  bool _isRenewalMode = true;
  DateTime? _startDate = DateTime.now().add(const Duration(days: 1));
  
  List<dynamic> _pauseLogs = [];
  
  Map<String, dynamic>? _settings;
  Map<String, dynamic>? _latestTxn;
  List<Map<String, dynamic>> _activeSubs = [];
  int _currentCardIndex = 0;
  Map<String, dynamic>? _activeSub;
  Map<String, dynamic>? _latestSub;
  bool _hasApprovedAddress = false;
  double _discountAmount = 0.0;
  int _creditDaysBreakfast = 0;
  int _creditDaysLunch = 0;
  int _creditDaysDinner = 0;

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // Fetch settings
      final settings = await supabase.from('app_settings').select().eq('id', 1).maybeSingle();
      
      if (user != null) {
        final subs = await supabase.from('subscriptions')
          .select()
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

        final txns = await supabase.from('transactions')
          .select()
          .eq('customer_id', user.id)
          .order('transaction_date', ascending: false)
          .limit(1);

        List<dynamic> fetchedPauseLogs = [];
        List<Map<String, dynamic>> loadedActiveSubs = [];
        Map<String, dynamic>? currentActiveSub;
        
        if (subs.isNotEmpty) {
          loadedActiveSubs = subs.where((s) => s['status'] == 'active').toList().cast<Map<String, dynamic>>().reversed.toList();
          if (loadedActiveSubs.isNotEmpty) {
             currentActiveSub = loadedActiveSubs.first;
             fetchedPauseLogs = await supabase.from('pause_logs').select().eq('subscription_id', currentActiveSub['id']);
          }
        }

        if (mounted) {
          setState(() {
            _settings = settings;
            _activeSubs = loadedActiveSubs;
            _activeSub = currentActiveSub;
            _pauseLogs = fetchedPauseLogs;
            if (txns.isNotEmpty) _latestTxn = txns.first;
            
            if (subs.isNotEmpty) {
              _latestSub = subs.first;
              bool hasApprovedSub = subs.any((s) => s['status'] != 'pending_approval' && s['status'] != 'rejected');
              bool isProfileActive = context.read<AuthProvider>().profile?['status'] == 'active';
              _hasApprovedAddress = hasApprovedSub || isProfileActive;
            } else {
              _hasApprovedAddress = context.read<AuthProvider>().profile?['status'] == 'active';
            }

            if (_latestSub != null && (_latestSub!['status'] == 'payment_pending' || _latestSub!['status'] == 'pending_approval')) {
              _planType = _latestSub!['plan_type'] ?? 'monthly';
              _hasBreakfast = _latestSub!['has_breakfast'] ?? false;
              _hasLunch = _latestSub!['has_lunch'] ?? false;
              _hasDinner = _latestSub!['has_dinner'] ?? false;
              _isRenewalMode = false;
              _calculateCredits();
            } else if (_activeSub != null) {
              _planType = _activeSub!['plan_type'] ?? 'monthly';
              _hasBreakfast = _activeSub!['has_breakfast'] ?? false;
              _hasLunch = _activeSub!['has_lunch'] ?? false;
              _hasDinner = _activeSub!['has_dinner'] ?? false;
              _isRenewalMode = true;
              _calculateCredits();
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  void _calculateCredits() {
    if (_activeSub == null || !_isRenewalMode) {
      _creditDaysBreakfast = 0;
      _creditDaysLunch = 0;
      _creditDaysDinner = 0;
      _calculateTotalAndDiscount();
      return;
    }
    
    _creditDaysBreakfast = 0;
    _creditDaysLunch = 0;
    _creditDaysDinner = 0;
    
    for (var log in _pauseLogs) {
      int days = log['days_paused'] ?? 0;
      if (log['meal_type'] == 'breakfast') _creditDaysBreakfast += days;
      if (log['meal_type'] == 'lunch') _creditDaysLunch += days;
      if (log['meal_type'] == 'dinner') _creditDaysDinner += days;
    }
    
    _calculateTotalAndDiscount();
  }

  int _getCreditDays(dynamic expiryStr, DateTime today) {
    return 0; 
  }

  double _baseAmount = 0.0;
  
  void _calculateTotalAndDiscount() {
    double bFastPrice = _planType == 'monthly' ? (_settings?['breakfast_price_monthly'] ?? 1500).toDouble() : (_settings?['breakfast_price_yearly'] ?? 15000).toDouble();
    double lunchPrice = _planType == 'monthly' ? (_settings?['lunch_price_monthly'] ?? 2000).toDouble() : (_settings?['lunch_price_yearly'] ?? 20000).toDouble();
    double dinnerPrice = _planType == 'monthly' ? (_settings?['dinner_price_monthly'] ?? 2000).toDouble() : (_settings?['dinner_price_yearly'] ?? 20000).toDouble();

    _baseAmount = 0;
    if (_hasBreakfast) _baseAmount += bFastPrice;
    if (_hasLunch) _baseAmount += lunchPrice;
    if (_hasDinner) _baseAmount += dinnerPrice;

    double bFastDaily = bFastPrice / (_planType == 'monthly' ? 30 : 365);
    double lunchDaily = lunchPrice / (_planType == 'monthly' ? 30 : 365);
    double dinnerDaily = dinnerPrice / (_planType == 'monthly' ? 30 : 365);

    _discountAmount = 0;
    _discountAmount += (_creditDaysBreakfast * bFastDaily);
    _discountAmount += (_creditDaysLunch * lunchDaily);
    _discountAmount += (_creditDaysDinner * dinnerDaily);
  }

  double get _finalAmount {
    double total = _baseAmount - _discountAmount;
    return total > 0 ? total : 0;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _processPaymentSuccess(response.paymentId ?? '', response.orderId ?? '');
  }

  void _handleWebPaymentSuccess(String paymentId, String orderId) {
    _processPaymentSuccess(paymentId, orderId);
  }

  void _processPaymentSuccess(String paymentId, String orderId) async {
    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      final supabase = Supabase.instance.client;

      // Calculate expiries
      final now = DateTime.now();
      final days = _planType == 'monthly' ? 30 : 365;
      
      DateTime calcStartDate = _startDate ?? now.add(const Duration(days: 1));
      if (_activeSub != null && _isRenewalMode) {
        DateTime maxExpiry = now;
        for (String key in ['breakfast_expiry', 'lunch_expiry', 'dinner_expiry']) {
          if (_activeSub![key] != null) {
            try {
              DateTime exp = DateTime.parse(_activeSub![key]);
              if (exp.isAfter(maxExpiry)) {
                maxExpiry = exp;
              }
            } catch (e) {}
          }
        }
        if (maxExpiry.isAfter(now)) {
          // Renewal starts the next day of the previous plan end date
          calcStartDate = maxExpiry.add(const Duration(days: 1));
        }
      }

      String? getNewExpiry(bool hasMeal) {
        if (!hasMeal) return null;
        // Adding (days - 1) to start date correctly gives inclusive expiry date
        return calcStartDate.add(Duration(days: days - 1)).toIso8601String().split('T')[0];
      }

      String? breakfastExpiryDateStr = getNewExpiry(_hasBreakfast);
      String? lunchExpiryDateStr = getNewExpiry(_hasLunch);
      String? dinnerExpiryDateStr = getNewExpiry(_hasDinner);

      String subId;

      if (_latestSub != null && _latestSub!['status'] == 'payment_pending') {
        subId = _latestSub!['id'];
        await supabase.from('subscriptions').update({
          'status': 'active',
          'start_date': calcStartDate.toIso8601String().split('T')[0],
          'breakfast_expiry': breakfastExpiryDateStr,
          'lunch_expiry': lunchExpiryDateStr,
          'dinner_expiry': dinnerExpiryDateStr,
        }).eq('id', subId);
      } else {
        final Map<String, dynamic> insertData = {
          'customer_id': user?.id,
          'plan_type': _planType,
          'has_breakfast': _hasBreakfast,
          'has_lunch': _hasLunch,
          'has_dinner': _hasDinner,
          'start_date': calcStartDate.toIso8601String().split('T')[0],
          'breakfast_expiry': breakfastExpiryDateStr,
          'lunch_expiry': lunchExpiryDateStr,
          'dinner_expiry': dinnerExpiryDateStr,
          'status': 'active'
        };
        
        if (_activeSub != null && _isRenewalMode) {
          insertData['parent_subscription_id'] = _activeSub!['id'];
        }

        final subResponse = await supabase.from('subscriptions').insert(insertData).select().single();
        subId = subResponse['id'];
      }

      // Insert transaction
      await supabase.from('transactions').insert({
        'subscription_id': subId,
        'customer_id': user?.id,
        'amount': _finalAmount,
        'type': (_activeSub != null && _isRenewalMode) ? 'renewal' : 'new_subscription',
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'status': 'success',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful! Subscription is now Active.')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving subscription: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed: ${response.message}')));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('External Wallet Selected: ${response.walletName}')));
  }

  Future<void> _sendEnquiry() async {
    if (_activeSubs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already have the maximum allowed active/renewal plans (2).')));
      return;
    }
    
    _calculateTotalAndDiscount();
    if (_finalAmount <= 0 && _baseAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one meal')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = context.read<AuthProvider>().user;
      final supabase = Supabase.instance.client;

      final now = DateTime.now();
      final days = _planType == 'monthly' ? 30 : 365;

      // Calculate explicit start_date
      DateTime calcStartDate = _startDate ?? now.add(const Duration(days: 1)); // Default: tomorrow
      if (_activeSub != null && _isRenewalMode) {
        DateTime maxExpiry = now;
        for (String key in ['breakfast_expiry', 'lunch_expiry', 'dinner_expiry']) {
          if (_activeSub![key] != null) {
            try {
              DateTime exp = DateTime.parse(_activeSub![key]);
              if (exp.isAfter(maxExpiry)) {
                maxExpiry = exp;
              }
            } catch (e) {}
          }
        }
        if (maxExpiry.isAfter(now)) {
          // Renewal starts the next day of the previous plan end date
          calcStartDate = maxExpiry.add(const Duration(days: 1));
        }
      }

      String? getNewExpiry(bool hasMeal) {
        if (!hasMeal) return null;
        return calcStartDate.add(Duration(days: days - 1)).toIso8601String().split('T')[0];
      }

      String? breakfastExpiryDateStr = getNewExpiry(_hasBreakfast);
      String? lunchExpiryDateStr = getNewExpiry(_hasLunch);
      String? dinnerExpiryDateStr = getNewExpiry(_hasDinner);

      final Map<String, dynamic> insertData = {
        'customer_id': user?.id,
        'plan_type': _planType,
        'has_breakfast': _hasBreakfast,
        'has_lunch': _hasLunch,
        'has_dinner': _hasDinner,
        'start_date': calcStartDate.toIso8601String().split('T')[0],
        'breakfast_expiry': breakfastExpiryDateStr,
        'lunch_expiry': lunchExpiryDateStr,
        'dinner_expiry': dinnerExpiryDateStr,
        'status': 'pending_approval'
      };

      if (_activeSub != null && _isRenewalMode) {
        insertData['parent_subscription_id'] = _activeSub!['id'];
      }

      await supabase.from('subscriptions').insert(insertData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enquiry Sent! Pending Admin Approval.')));
        context.pop();
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processPayment() {
    if (_activeSubs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already have the maximum allowed active/renewal plans (2).')));
      return;
    }

    _calculateTotalAndDiscount();
    if (_finalAmount <= 0 && _baseAmount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one meal')));
      return;
    }

    if (_finalAmount <= 0 && _baseAmount > 0) {
      // Amount fully covered by pause credit discount
      _processPaymentSuccess('PAUSE_CREDIT_DISCOUNT', 'PAUSE_CREDIT_DISCOUNT');
      return;
    }

    final keyId = dotenv.env['RAZORPAY_KEY_ID'] ?? '';
    final profile = context.read<AuthProvider>().profile;

    // Razorpay expect amount in paise
    final int amountInPaise = (_finalAmount * 100).toInt();

    if (kIsWeb) {
      try {
        var webOptions = {
          'key': keyId,
          'amount': amountInPaise,
          'name': 'SAAPADU BOX',
          'description': '$_planType Meal Subscription',
          'handler': js.allowInterop((response) {
            _handleWebPaymentSuccess(
              response['razorpay_payment_id'] ?? '',
              response['razorpay_order_id'] ?? ''
            );
          }),
          'prefill': {
            'contact': profile?['phone'] ?? '',
            'email': context.read<AuthProvider>().user?.email ?? '',
          }
        };
        var rzp = js.context.callMethod('Razorpay', [js.JsObject.jsify(webOptions)]);
        rzp.callMethod('on', ['payment.failed', js.allowInterop((response) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment Failed (Web): ${response['error']['description']}')));
        })]);
        rzp.callMethod('open');
      } catch (e) {
        debugPrint('Error opening Web Razorpay: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open Web Razorpay: $e')));
      }
    } else {
      var options = {
        'key': keyId,
        'amount': amountInPaise,
        'name': 'SAAPADU BOX',
        'description': '$_planType Meal Subscription',
        'prefill': {
          'contact': profile?['phone'] ?? '',
          'email': context.read<AuthProvider>().user?.email ?? '',
        }
      };
      
      try {
        _razorpay.open(options);
      } catch (e) {
        debugPrint('Error opening Razorpay: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open Razorpay: $e')));
      }
    }
  }

  Future<void> _onCardSwiped(int index) async {
    final newActiveSub = _activeSubs[index];
    setState(() {
      _currentCardIndex = index;
      _activeSub = newActiveSub;
      _isRenewalMode = true;
      // Also update the form to match this plan's meals whenever they select it
      _planType = newActiveSub['plan_type'] ?? 'monthly';
      _hasBreakfast = newActiveSub['has_breakfast'] ?? false;
      _hasLunch = newActiveSub['has_lunch'] ?? false;
      _hasDinner = newActiveSub['has_dinner'] ?? false;
    });

    try {
      final supabase = Supabase.instance.client;
      final fetchedLogs = await supabase.from('pause_logs').select().eq('subscription_id', newActiveSub['id']);
      if (mounted) {
        setState(() {
          _pauseLogs = fetchedLogs;
          _calculateCredits();
        });
      }
    } catch (e) {
      debugPrint("Error fetching logs for swiped sub: $e");
    }
  }

  Widget _buildMealBadge(IconData icon, String label, dynamic expiry) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(expiry?.toString().substring(0, 10) ?? 'N/A', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildSingleSubCard(Map<String, dynamic> sub) {
    String subId = sub['id']?.toString() ?? '-';
    String displaySubId = subId.length > 8 ? subId.substring(0, 8).toUpperCase() : subId.toUpperCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.deepOrange.shade600,
          ],
        ),
        boxShadow: [
          BoxShadow(color: Colors.deepOrange.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned(
              left: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15)),
              ),
            ),
            Positioned(
              right: -60,
              bottom: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.yellow.withOpacity(0.1)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Premium Plan', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: Text('ID: $displaySubId', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          (sub['plan_type'] ?? '').toString().toUpperCase(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.deepOrange.shade600, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sub['has_breakfast'] == true) Expanded(child: Padding(padding: const EdgeInsets.only(right: 6), child: _buildMealBadge(Icons.breakfast_dining, 'Breakfast', sub['breakfast_expiry']))),
                      if (sub['has_lunch'] == true) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: _buildMealBadge(Icons.lunch_dining, 'Lunch', sub['lunch_expiry']))),
                      if (sub['has_dinner'] == true) Expanded(child: Padding(padding: const EdgeInsets.only(left: 6), child: _buildMealBadge(Icons.dinner_dining, 'Dinner', sub['dinner_expiry']))),
                    ],
                  ),
                  const Spacer(),
                  if (_latestTxn != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paid ₹${_latestTxn!['amount']} • ${_latestTxn!['transaction_date']?.toString().substring(0, 10) ?? ''}', 
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 6),
                                Text('Txn ID: ${_latestTxn!['razorpay_payment_id'] ?? 'Manual/None'}', 
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ]
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionInfo() {
    if (_activeSubs.isEmpty) return const SizedBox();
    
    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            itemCount: _activeSubs.length,
            onPageChanged: _onCardSwiped,
            itemBuilder: (context, index) {
              return _buildSingleSubCard(_activeSubs[index]);
            },
          ),
        ),
        if (_activeSubs.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_activeSubs.length, (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentCardIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _currentCardIndex == index ? Colors.deepOrange : Colors.grey.shade300,
                ),
              )),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isReadOnly = _latestSub != null && (_latestSub!['status'] == 'pending_approval' || _latestSub!['status'] == 'payment_pending');

    List<DateTime> expiries = [];
    if (_activeSub?['breakfast_expiry'] != null) expiries.add(DateTime.parse(_activeSub!['breakfast_expiry']));
    if (_activeSub?['lunch_expiry'] != null) expiries.add(DateTime.parse(_activeSub!['lunch_expiry']));
    if (_activeSub?['dinner_expiry'] != null) expiries.add(DateTime.parse(_activeSub!['dinner_expiry']));
    DateTime? maxExpiry;
    if (expiries.isNotEmpty) {
      expiries.sort();
      maxExpiry = expiries.last;
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'My SAAPADU BOX'),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_activeSub != null) _buildActiveSubscriptionInfo(),
            
            if (!isReadOnly && _activeSub != null) ...[
               const Text('Action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               RadioListTile<bool>(
                 title: const Text('Renew Current Plan'),
                 subtitle: const Text('Keeps same meals and applies pause credits'),
                 value: true,
                 groupValue: _isRenewalMode,
                 onChanged: (val) {
                   setState(() {
                     _isRenewalMode = true;
                     _planType = _activeSub!['plan_type'] ?? 'monthly';
                     _hasBreakfast = _activeSub!['has_breakfast'] == true;
                     _hasLunch = _activeSub!['has_lunch'] == true;
                     _hasDinner = _activeSub!['has_dinner'] == true;
                     _calculateCredits();
                   });
                 },
               ),
               RadioListTile<bool>(
                 title: const Text('Start New Plan'),
                 subtitle: const Text('Choose different meals (No pause credit carry-over)'),
                 value: false,
                 groupValue: _isRenewalMode,
                 onChanged: (val) {
                   setState(() {
                     _isRenewalMode = false;
                     _calculateCredits();
                   });
                 },
               ),
               const Divider(),
               const SizedBox(height: 12),
            ],
            
             Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isReadOnly && (_activeSub == null || !_isRenewalMode)) ...[
                  const Text('Plan Start Date', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month, color: Colors.orange),
                    title: Text('Starts on ${_startDate?.toLocal().toString().split(' ')[0] ?? 'Today'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: maxExpiry != null 
                        ? Text('Note: Your current plan runs until ${maxExpiry.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w600))
                        : const Text('Pick when you want the delivery to begin'),
                    trailing: TextButton.icon(
                      onPressed: () async {
                        DateTime initial = _startDate ?? DateTime.now();
                        if (maxExpiry != null && initial.isBefore(maxExpiry)) {
                           initial = maxExpiry.add(const Duration(days: 1));
                        }
                        DateTime? d = await showDatePicker(
                          context: context,
                          initialDate: initial,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) {
                          setState(() => _startDate = d);
                        }
                      },
                      icon: const Icon(Icons.edit_calendar),
                      label: const Text('Change'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                if (_activeSub == null) const Text('Select Plan Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Monthly (30 Days)'),
                        value: 'monthly',
                        groupValue: _planType,
                        onChanged: isReadOnly || (_activeSub != null && _isRenewalMode) ? null : (value) {
                          setState(() => _planType = value!);
                          _calculateCredits();
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Yearly (365 Days)'),
                        value: 'yearly',
                        groupValue: _planType,
                        onChanged: isReadOnly || (_activeSub != null && _isRenewalMode) ? null : (value) {
                          setState(() => _planType = value!);
                          _calculateCredits();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_activeSub == null) const Text('Select Meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                CheckboxListTile(
                  title: const Text('Breakfast'),
                  value: _hasBreakfast,
                  onChanged: isReadOnly || (_activeSub != null && _isRenewalMode) ? null : (value) {
                    setState(() => _hasBreakfast = value ?? false);
                    _calculateCredits();
                  },
                ),
                CheckboxListTile(
                  title: const Text('Lunch'),
                  value: _hasLunch,
                  onChanged: isReadOnly || (_activeSub != null && _isRenewalMode) ? null : (value) {
                    setState(() => _hasLunch = value ?? false);
                    _calculateCredits();
                  },
                ),
                CheckboxListTile(
                  title: const Text('Dinner'),
                  value: _hasDinner,
                  onChanged: isReadOnly || (_activeSub != null && _isRenewalMode) ? null : (value) {
                    setState(() => _hasDinner = value ?? false);
                    _calculateCredits();
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Base Amount:', style: TextStyle(fontSize: 16)),
                        Text('₹${_baseAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                    if (_discountAmount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Pause Credit Discount:', style: TextStyle(fontSize: 16, color: Colors.green)),
                                Text('- ₹${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Colors.green)),
                              ],
                            ),
                            if (_creditDaysBreakfast > 0)
                              Text('  • $_creditDaysBreakfast Days Breakfast', style: const TextStyle(fontSize: 12, color: Colors.green)),
                            if (_creditDaysLunch > 0)
                              Text('  • $_creditDaysLunch Days Lunch', style: const TextStyle(fontSize: 12, color: Colors.green)),
                            if (_creditDaysDinner > 0)
                              Text('  • $_creditDaysDinner Days Dinner', style: const TextStyle(fontSize: 12, color: Colors.green)),
                          ],
                        ),
                      ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Payable:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('₹${_finalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (_latestSub != null && _latestSub!['status'] == 'pending_approval')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Your enquiry is pending admin approval. You will be notified once we verify serviceability to your address.', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
              )
            else if (_latestSub != null && _latestSub!['status'] == 'payment_pending')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: _processPayment,
                  child: const Text('Approved! Pay Now', style: TextStyle(fontSize: 18)),
                ),
              )
            else if (_hasApprovedAddress)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: _processPayment,
                  child: Text(_activeSub != null ? 'Pay & Renew Plan' : 'Pay with Razorpay', style: const TextStyle(fontSize: 18)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: _sendEnquiry,
                  child: const Text('Send Enquiry', style: TextStyle(fontSize: 18)),
                ),
              )
          ],
        ),
      ),
    );
  }
}
