import 'package:flutter/material.dart';
import 'package:matchunsa/app/theme/app_theme.dart';
import 'package:matchunsa/app/widgets/mu_motion.dart';
import 'package:matchunsa/app/widgets/mu_surface.dart';
import 'package:matchunsa/features/auth/domain/auth_repository.dart';
import 'package:matchunsa/features/auth/domain/auth_user.dart';
import 'package:matchunsa/features/auth/domain/institutional_account_required_exception.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.repository,
    required this.authenticatedBuilder,
  });

  final AuthRepository repository;
  final Widget Function(AuthUser user) authenticatedBuilder;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final Stream<AuthUser?> _authStateChanges;
  bool _isLoading = false;
  String? _operationError;

  @override
  void initState() {
    super.initState();
    _authStateChanges = widget.repository.authStateChanges;
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _operationError = null;
    });

    try {
      await widget.repository.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() {
          _operationError =
              'No se pudo iniciar sesión con Google. Inténtalo nuevamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthUser?>(
      stream: _authStateChanges,
      initialData: widget.repository.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.maroon),
            ),
          );
        }

        final user = snapshot.data;
        final authError = snapshot.error;

        if (user != null) {
          return widget.authenticatedBuilder(user);
        }

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8F7F6),
                  Color(0xFFF0F1F5),
                  Color(0xFFF7F0F1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 920;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1080,
                        maxHeight: 720,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(wide ? 28 : 16),
                        child: wide
                            ? Row(
                                children: [
                                  Expanded(
                                    flex: 11,
                                    child: MuFadeSlide(
                                      child: _BrandPanel(compact: false),
                                    ),
                                  ),
                                  const SizedBox(width: 22),
                                  Expanded(
                                    flex: 10,
                                    child: MuFadeSlide(
                                      delay: const Duration(milliseconds: 90),
                                      child: _SignInCard(
                                        isLoading: _isLoading,
                                        operationError: _operationError,
                                        authError: authError,
                                        onSignIn: _signInWithGoogle,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    MuFadeSlide(
                                      child: SizedBox(
                                        height: 220,
                                        child: _BrandPanel(compact: true),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    MuFadeSlide(
                                      delay: const Duration(milliseconds: 100),
                                      child: _SignInCard(
                                        isLoading: _isLoading,
                                        operationError: _operationError,
                                        authError: authError,
                                        onSignIn: _signInWithGoogle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: AppTheme.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: _decorativeCircle(180, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: _decorativeCircle(220, Colors.white.withValues(alpha: 0.04)),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 28 : 44),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Institutional logo badge with glass effect.
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                SizedBox(height: compact ? 18 : 28),
                Text(
                  'MatchUNSA',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Conecta tu talento con oportunidades laborales de la comunidad UNSA.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                ),
                if (!compact) ...[
                  const SizedBox(height: 28),
                  // Glass pill: institutional affiliation.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Universidad Nacional de San Agustín',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorativeCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.isLoading,
    required this.operationError,
    required this.authError,
    required this.onSignIn,
  });

  final bool isLoading;
  final String? operationError;
  final Object? authError;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return MuSurface(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Accede con tu cuenta institucional verificada @unsa.edu.pe para explorar convocatorias.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.navy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_rounded,
                        size: 18, color: AppTheme.navy),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo cuentas institucionales UNSA',
                        style: TextStyle(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Institutional email display (visual, Google OAuth).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mail_outline_rounded,
                        color: AppTheme.inkTertiary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Correo institucional',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.inkTertiary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '@unsa.edu.pe vía Google',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.lock_rounded,
                        size: 18, color: AppTheme.inkTertiary),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onSignIn,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.maroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      else
                        const _GoogleIcon(size: 20),
                      const SizedBox(width: 10),
                      Text(
                        isLoading
                            ? 'Conectando…'
                            : 'Continuar con Google',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (operationError != null) ...[
                const SizedBox(height: 16),
                _AuthMessage(message: operationError!),
              ],
              if (authError is InstitutionalAccountRequiredException) ...[
                const SizedBox(height: 16),
                const _AuthMessage(
                  message:
                      'Solo se permiten cuentas verificadas @unsa.edu.pe.',
                ),
              ],
              const SizedBox(height: 22),
              Text(
                'La autenticación se realiza de forma segura mediante Google. No almacenamos tu contraseña.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal white Google "G" glyph for the primary button.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon({this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.g_mobiledata_rounded, size: size + 8, color: Colors.white);
  }
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}
