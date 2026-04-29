import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell_widgets.dart';
import 'pages/history_page.dart';
import 'pages/login_page.dart';
import 'pages/notifications_page.dart';
import 'pages/onboarding_page.dart';
import 'pages/qr_scanner_page.dart';
import 'pages/settings_page.dart';
import 'pages/verify_discount_page.dart';
import 'pages/dashboard_page.dart';
import 'state/session_controller.dart';

class PartnerScanApp extends StatefulWidget {
  const PartnerScanApp({super.key});

  @override
  State<PartnerScanApp> createState() => _PartnerScanAppState();
}

class _PartnerScanAppState extends State<PartnerScanApp> {
  late final PartnerSessionController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PartnerSessionController();
    _controller.restoreSession();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Partner Scan',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: switch (_controller.stage) {
            AppStage.bootstrapping => const StartupPage(),
            AppStage.onboarding => OnboardingPage(
              onContinue: () => _controller.completeOnboarding(),
            ),
            AppStage.unauthenticated => LoginPage(controller: _controller),
            AppStage.authenticated => AuthenticatedShell(
              controller: _controller,
            ),
          },
        );
      },
    );
  }
}

class StartupPage extends StatelessWidget {
  const StartupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildGradientBackground(
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class AuthenticatedShell extends StatefulWidget {
  const AuthenticatedShell({super.key, required this.controller});

  final PartnerSessionController controller;

  @override
  State<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends State<AuthenticatedShell> {
  int _selectedIndex = 0;
  String? _scannedCardUuid;

  Future<void> _openScannerFromDashboard() async {
    final scannedValue = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QrScannerPage()),
    );

    if (!mounted || scannedValue == null || scannedValue.trim().isEmpty) {
      return;
    }

    setState(() {
      _scannedCardUuid = scannedValue.trim();
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        controller: widget.controller,
        onStartScan: _openScannerFromDashboard,
        onOpenHistory: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
        onOpenNotifications: () => _openNotificationsPage(),
      ),
      VerifyDiscountPage(
        controller: widget.controller,
        scannedCardUuid: _scannedCardUuid,
        onScannedCardConsumed: () {
          _scannedCardUuid = null;
        },
      ),
      HistoryPage(controller: widget.controller),
      SettingsPage(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified_rounded),
            label: 'Vérification',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Historique',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Future<void> _openNotificationsPage() {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationsPage(controller: widget.controller),
      ),
    );
  }
}
