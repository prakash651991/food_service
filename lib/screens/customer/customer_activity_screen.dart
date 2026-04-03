import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import 'pause_meal_screen.dart';
import 'transaction_screen.dart';
import 'plans_history_screen.dart';

class CustomerActivityScreen extends StatelessWidget {
  const CustomerActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'My SAAPADU BOX',
          bottom: TabBar(
            labelColor: Colors.orange.shade900,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.orange.shade900,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.list_alt), text: 'Plans'),
              Tab(icon: Icon(Icons.history), text: 'Transactions'),
              Tab(icon: Icon(Icons.pause_circle_outline), text: 'Pause Meal'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
             CustomerPlansHistoryScreen(hideAppBar: true),
             CustomerTransactionScreen(hideAppBar: true),
             CustomerPauseMealScreen(hideAppBar: true),
          ],
        ),
      ),
    );
  }
}
