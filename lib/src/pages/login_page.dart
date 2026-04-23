import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

import '../core/widgets/app_shell_widgets.dart';
import '../models/api_models.dart';
import '../state/session_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.controller});

  final PartnerSessionController controller;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  String _selectedDialCode = '+225';
  bool _isPasswordVisible = false;

  static const List<_DialCodeOption> _dialCodeOptions = [
    _DialCodeOption(code: '+225', label: 'CI'),
    _DialCodeOption(code: '+33', label: 'FR'),
    _DialCodeOption(code: '+221', label: 'SN'),
    _DialCodeOption(code: '+223', label: 'ML'),
    _DialCodeOption(code: '+226', label: 'BF'),
    _DialCodeOption(code: '+227', label: 'NE'),
    _DialCodeOption(code: '+228', label: 'TG'),
    _DialCodeOption(code: '+229', label: 'BJ'),
    _DialCodeOption(code: '+234', label: 'NG'),
    _DialCodeOption(code: '+1', label: 'US'),
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      await widget.controller.login(
        phoneOrEmail: _formatPhoneNumber(),
        password: _passwordController.text,
      );
    } on ApiException catch (error) {
      setState(() {
        _error = error.message;
      });
    }
  }

  String _formatPhoneNumber() {
    final normalized = _phoneController.text.trim().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalized.startsWith('+')) {
      return normalized;
    }

    if (digitsOnly.startsWith('00')) {
      return '+${digitsOnly.substring(2)}';
    }

    return '$_selectedDialCode$digitsOnly';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: buildGradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                18,
                24,
                18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: PremiumSection(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 82,
                            height: 82,
                            padding: const EdgeInsets.all(8),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
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
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Connexion partenaire',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 25,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Accedez au scan des cartes de réduction avec votre numéro et mot de passe.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mint.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Connexion sécurisée partenaire',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 112,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDialCode,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Indicatif',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                ),
                                selectedItemBuilder: (context) {
                                  return _dialCodeOptions.map((option) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        option.code,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    );
                                  }).toList();
                                },
                                items: _dialCodeOptions
                                    .map(
                                      (option) => DropdownMenuItem<String>(
                                        value: option.code,
                                        child: Text(
                                          '${option.label} ${option.code}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedDialCode = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Numéro',
                                  hintText: '07 58 75 46 62',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Renseigne ton numéro.';
                                  }

                                  final digits = value.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  );
                                  if (digits.length < 6) {
                                    return 'Numéro trop court.';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              tooltip: _isPasswordVisible
                                  ? 'Masquer le mot de passe'
                                  : 'Afficher le mot de passe',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Renseigne le mot de passe.';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: FilledButton.icon(
                              onPressed: widget.controller.isAuthenticating
                                  ? null
                                  : _submit,
                              icon: widget.controller.isAuthenticating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(
                                widget.controller.isAuthenticating
                                    ? 'Connexion...'
                                    : 'Se connectér',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialCodeOption {
  const _DialCodeOption({required this.code, required this.label});

  final String code;
  final String label;
}
