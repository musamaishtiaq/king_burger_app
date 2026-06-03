import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  String _appVersion = '';

  static const List<String> _freeFeatures = [
    'Reporting access for the last 30 days only',
    'No reporting sent to your email',
    'No business analysis report',
    'No database backups',
    'No import & export menu when switching to a new mobile app',
  ];

  static const List<String> _subscriptionFeatures = [
    'Reporting access for the last 1 year',
    'Reporting sent to your email',
    'Business analysis report included',
    'Database backups included',
    'Import & export menu when switching to a new mobile app (coming soon)',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _appVersion = packageInfo.version);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalScreenPadding(context),
              12,
              horizontalScreenPadding(context),
              rootTabBodyBottomScrollPadding(context),
            ),
            children: [
              Text(
                'Choose the plan that fits your business',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              const _PlanCard(
                title: 'Free',
                icon: Icons.person_outline,
                accentColor: null,
                features: _freeFeatures,
                showComingSoon: false,
              ),
              const SizedBox(height: 12),
              const _PlanCard(
                title: 'Subscription',
                icon: Icons.workspace_premium_outlined,
                accentColor: AppColors.primary,
                features: _subscriptionFeatures,
                showComingSoon: true,
              ),
              if (_appVersion.isNotEmpty) ...[
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Version $_appVersion',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.features,
    required this.showComingSoon,
  });

  final String title;
  final IconData icon;
  final Color? accentColor;
  final List<String> features;
  final bool showComingSoon;

  @override
  Widget build(BuildContext context) {
    final color =
        accentColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (showComingSoon) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Coming soon',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
