import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/subscription_gate.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _FeatureCard(
                icon: Icons.backup,
                title: 'Backup & Restore',
                showComingSoon: true,
                description:
                    'Subscription feature. Export your database for safekeeping or import a previously saved backup.',
                actions: [
                  _ActionButton(
                    icon: Icons.download,
                    label: 'Export Data',
                    onPressed: () => showSubscriptionRequiredDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.upload,
                    label: 'Import Data',
                    onPressed: () => showSubscriptionRequiredDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FeatureCard(
                icon: Icons.restaurant_menu,
                title: 'Import & Export Menu',
                showComingSoon: true,
                description:
                    'Subscription feature. Export your categories and products as a menu file, or import a menu when setting up a new device.',
                actions: [
                  _ActionButton(
                    icon: Icons.download,
                    label: 'Export Menu',
                    onPressed: () => showSubscriptionRequiredDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _ActionButton(
                    icon: Icons.upload,
                    label: 'Import Menu',
                    onPressed: () => showSubscriptionRequiredDialog(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actions,
    this.showComingSoon = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> actions;
  final bool showComingSoon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            if (showComingSoon) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Coming soon',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
