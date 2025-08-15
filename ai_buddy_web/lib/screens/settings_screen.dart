 import 'package:flutter/material.dart';
import '../widgets/app_back_button.dart';
import '../widgets/safety_legal_sheet.dart';
import './legal/legal_screen.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart' show logAnalyticsEvent;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loadingConsent = true;
  bool _analyticsEnabled = false;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final enabled = await _api.isAnalyticsEnabled();
    if (mounted) {
      setState(() {
        _analyticsEnabled = enabled;
        _loadingConsent = false;
      });
    }
  }

  Future<void> _toggleConsent(bool value) async {
    setState(() => _analyticsEnabled = value);
    await _api.setAnalyticsConsent(value);
    // Log consent change (only if enabling; backend will enforce header)
    if (value) {
      await logAnalyticsEvent('consent_changed', metadata: {
        'action': 'enable_analytics',
        'screen': 'settings',
        'success': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
        leading: Builder(
          builder: (ctx) {
            final canPop = Navigator.of(ctx).canPop();
            final route = ModalRoute.of(ctx);
            final isModal = route is PageRoute && route.fullscreenDialog == true;
            if (canPop) {
              return AppBackButton(isModal: isModal);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          // Analytics consent toggle
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.analytics_outlined),
            title: const Text('Share Anonymous Analytics'),
            subtitle: const Text(
              'Help us improve by sending minimal, anonymous usage events. No personal data is collected.'
            ),
            value: _loadingConsent ? false : _analyticsEnabled,
            onChanged: _loadingConsent ? null : _toggleConsent,
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Safety & Legal'),
            subtitle: const Text('View safety notice and disclaimers'),
            onTap: () async {
              await showSafetyLegalSheet(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(
                    title: 'Terms of Service',
                    assetPath: 'assets/legal/terms.md',
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(
                    title: 'Privacy Policy',
                    assetPath: 'assets/legal/privacy.md',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
