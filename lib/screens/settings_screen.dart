import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/settings_service.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Map<String, String> _languages = {
    'fr': 'Français',
    'en': 'English',
    'es': 'Español',
    'pt': 'Português',
    'it': 'Italiano',
    'de': 'Deutsch',
  };

  void _wipeData() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            AppLocalizations.t('wipeWarning'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: Text(AppLocalizations.t('wipeConfirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                AppLocalizations.t('cancel'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(
                AppLocalizations.t('delete'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await SettingsService.clearAllData();
      // We don't wipe internal OSM data since it's shipped, but we wipe preferences, favorites, location.
      // Exit gracefully or just reflect empty state.
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentLang = AppLocalizations.localeNotifier.value;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(
              AppLocalizations.t('language'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: DropdownButton<String>(
              value: currentLang,
              underline: const SizedBox(),
              items: _languages.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  SettingsService.setLanguage(val);
                  AppLocalizations.localeNotifier.value = val;
                  setState(() {});
                }
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: Text(
              AppLocalizations.t('useCloud'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(AppLocalizations.t('useCloudDesc')),
            activeThumbColor: const Color(0xFFFF5F1F),
            value: SettingsService.useCloudApi,
            onChanged: (val) async {
              await SettingsService.setUseCloudApi(val);
              setState(() {});
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          _buildAboutSection(),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _wipeData,
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            label: Text(
              AppLocalizations.t('wipeDataBtn'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF1A2F25)),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.t('about'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.t('aboutDisclaimer'),
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(AppLocalizations.t('version'), '1.0.0+5'),
          _buildInfoRow(AppLocalizations.t('developer'), 'Clement Foissard'),
          const SizedBox(height: 20),
          Center(
            child: InkWell(
              onTap: () async {
                // Generic placeholder for Buy Me a Coffee
                final url = Uri.parse(
                  'https://www.buymeacoffee.com/clementfoissard',
                );
                // if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
                // }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDD00),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://cdn.buymeacoffee.com/buttons/bmc-new-btn-logo.svg',
                      height: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.coffee, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.t('buyMeCoffee'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
