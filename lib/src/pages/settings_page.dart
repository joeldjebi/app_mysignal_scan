import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import '../state/session_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final PartnerSessionController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.session?.user;

    return buildGradientBackground(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                const AppPageHeader(
                  title: 'Parametres',
                  subtitle:
                      'Gerer le profil, la securite et les infos du compte.',
                ),
                const SizedBox(height: 18),
                PremiumSection(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.blue],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            _initials(user?.name),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name.isNotEmpty == true
                                  ? user!.name
                                  : 'Compte partenaire',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              user?.organization?.name ??
                                  'Organisation partenaire',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumSection(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _SettingsMenuTile(
                        icon: Icons.person_outline_rounded,
                        tint: AppColors.primary,
                        title: 'Profil',
                        subtitle: 'Modifier le nom et le-mail',
                        onTap: () => _open(
                          context,
                          _ProfileSettingsPage(controller: controller),
                        ),
                      ),
                      _SettingsMenuTile(
                        icon: Icons.lock_reset_rounded,
                        tint: AppColors.orange,
                        title: 'Mise a jour de mot de passe',
                        subtitle: 'Changer le mot de passe de connexion',
                        onTap: () => _open(
                          context,
                          _PasswordSettingsPage(controller: controller),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: PremiumSection(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Se deconnecter'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final platform = Theme.of(context).platform;
    final bool? confirmed;

    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Confirmer la deconnexion'),
          content: const Text('Voulez vous vraiment fermer cette session ?'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Se deconnecter'),
            ),
          ],
        ),
      );
    } else {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmer la deconnexion'),
          content: const Text('Voulez vous vraiment fermer cette session ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Se deconnecter'),
            ),
          ],
        ),
      );
    }

    if (!context.mounted || confirmed != true) {
      return;
    }

    await controller.logout();
  }
}

class _ProfileSettingsPage extends StatefulWidget {
  const _ProfileSettingsPage({required this.controller});

  final PartnerSessionController controller;

  @override
  State<_ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<_ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _syncFromSession();
  }

  void _syncFromSession() {
    final user = widget.controller.session?.user;
    if (user == null) {
      return;
    }

    _nameController.text = user.name;
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _message = null;
      _error = null;
    });

    try {
      await widget.controller.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text.replaceAll(RegExp(r'\D+'), ''),
      );

      if (!mounted) {
        return;
      }

      setState(() => _message = 'Profil mis a jour avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'Profil',
      subtitle: 'Mettre a jour les informations visibles du partenaire.',
      children: [
        PremiumSection(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Renseigne le nom.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: Icon(Icons.alternate_email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Renseigne le-mail.';
                    }
                    if (!value.contains('@')) {
                      return 'E-mail invalide.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Telephone',
                    prefixIcon: Icon(Icons.phone_outlined),
                    helperText:
                        'Ce numero sert a la connexion et ne peut pas etre modifie.',
                  ),
                ),
                _FeedbackMessage(message: _message, error: _error),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.controller.isSavingProfile
                        ? null
                        : _saveProfile,
                    icon: widget.controller.isSavingProfile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      widget.controller.isSavingProfile
                          ? 'Enregistrement...'
                          : 'Enregistrer',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordSettingsPage extends StatefulWidget {
  const _PasswordSettingsPage({required this.controller});

  final PartnerSessionController controller;

  @override
  State<_PasswordSettingsPage> createState() => _PasswordSettingsPageState();
}

class _PasswordSettingsPageState extends State<_PasswordSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showPassword = false;
  bool _showConfirmation = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _message = null;
      _error = null;
    });

    try {
      await widget.controller.updatePassword(
        currentPassword: _currentPasswordController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmationController.text,
      );

      if (!mounted) {
        return;
      }

      _currentPasswordController.clear();
      _passwordController.clear();
      _passwordConfirmationController.clear();
      setState(() => _message = 'Mot de passe mis a jour avec succes.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsDetailScaffold(
      title: 'Mot de passe',
      subtitle: 'Securiser le compte partenaire avec un nouveau mot de passe.',
      children: [
        PremiumSection(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _PasswordField(
                  controller: _currentPasswordController,
                  label: 'Mot de passe actuel',
                  visible: _showCurrentPassword,
                  onToggleVisibility: () {
                    setState(
                      () => _showCurrentPassword = !_showCurrentPassword,
                    );
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Renseigne le mot de passe actuel.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _passwordController,
                  label: 'Nouveau mot de passe',
                  visible: _showPassword,
                  onToggleVisibility: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Renseigne le nouveau mot de passe.';
                    }
                    if (value.length < 8) {
                      return 'Minimum 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _PasswordField(
                  controller: _passwordConfirmationController,
                  label: 'Confirmer le mot de passe',
                  visible: _showConfirmation,
                  onToggleVisibility: () {
                    setState(() => _showConfirmation = !_showConfirmation);
                  },
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas.';
                    }
                    return null;
                  },
                ),
                _FeedbackMessage(message: _message, error: _error),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.controller.isUpdatingPassword
                        ? null
                        : _savePassword,
                    icon: widget.controller.isUpdatingPassword
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset_rounded),
                    label: Text(
                      widget.controller.isUpdatingPassword
                          ? 'Mise a jour...'
                          : 'Mettre a jour',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsDetailScaffold extends StatelessWidget {
  const _SettingsDetailScaffold({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: buildGradientBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 8),
              AppPageHeader(title: title, subtitle: subtitle),
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: tint),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.visible,
    required this.onToggleVisibility,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool visible;
  final VoidCallback onToggleVisibility;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
        ),
      ),
      validator: validator,
    );
  }
}

class _FeedbackMessage extends StatelessWidget {
  const _FeedbackMessage({required this.message, required this.error});

  final String? message;
  final String? error;

  @override
  Widget build(BuildContext context) {
    if (message == null && error == null) {
      return const SizedBox.shrink();
    }

    final hasError = error != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasError
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.08)
            : AppColors.mint.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Theme.of(context).colorScheme.error.withValues(alpha: 0.25)
              : AppColors.mint.withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        error ?? message!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: hasError
              ? Theme.of(context).colorScheme.error
              : AppColors.text,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'MS';
  }

  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
