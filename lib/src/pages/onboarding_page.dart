import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

import '../core/widgets/app_shell_widgets.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: buildGradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 94,
                    height: 94,
                    padding: const EdgeInsets.all(8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x180D5C63),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logos/logo-my-signal.png',
                      fit: BoxFit.contain,
                      width: 78,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Une expérience partenaire claire, rapide et premium.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 26,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Scannez les cartes de réduction, vérifiez l éligibilité et validez les remises au comptoir.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                const PremiumSection(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _FeatureRow(
                        icon: Icons.verified_user_outlined,
                        title: 'Vérification instantanee',
                        description:
                            'Controlez la validité de la carte et de l’abonnement en quelques secondes.',
                      ),
                      SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.local_offer_outlined,
                        title: 'Validation de réduction',
                        description:
                            'Appliquez l’offre partenaire avec les montants traces côté API.',
                      ),
                      SizedBox(height: 12),
                      _FeatureRow(
                        icon: Icons.insights_outlined,
                        title: 'Pilotage de l activite',
                        description:
                            'Suivez les stats et l’historique personnel de chaque agent partenaire.',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: FilledButton(
                      onPressed: onContinue,
                      child: const Text('Commencer'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'MySignal Scan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 14.5),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
