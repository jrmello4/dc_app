// lib/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dc_app/services/auth_service.dart'; // Import corrigido
import 'login_screen.dart';                         // Import corrigido

class ResetPasswordScreen extends StatefulWidget {
  final String uidb64;
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.uidb64,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  // Variáveis para controlar a visibilidade das senhas
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _submitNewPassword() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      // Chama o AuthService para redefinir a senha na API real
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resetPassword(
        widget.uidb64,
        widget.token,
        _newPasswordController.text,
        _confirmPasswordController.text, // Passa ambas as senhas conforme API original
      ); //
      if (mounted) {
        setState(() {
          _isSuccess = true;
          _feedbackMessage = 'Senha redefinida com sucesso! Você será redirecionado para o login.';
        });
        // Redireciona para o login após 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSuccess = false;
          // Exibe a mensagem de erro vinda do AuthService
          _feedbackMessage = 'Erro: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Cor de fundo do tema
      appBar: AppBar(
        title: const Text('Definir Nova Senha'),
        elevation: 0.5,
        // Configurações herdadas do tema principal
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_reset_outlined,
                  size: 60,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Crie uma Nova Senha',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sua nova senha deve ser diferente das senhas usadas anteriormente.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                // Campo Nova Senha com visibilidade
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    hintText: 'Nova senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isNewPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isNewPasswordVisible = !_isNewPasswordVisible),
                    ),
                  ),
                  obscureText: !_isNewPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe a nova senha.';
                    }
                    if (value.length < 8) {
                      return 'A senha deve ter pelo menos 8 caracteres.'; //
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Campo Confirmar Senha com visibilidade
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    hintText: 'Confirmar nova senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, confirme a nova senha.';
                    }
                    if (value != _newPasswordController.text) {
                      return 'As senhas não coincidem.'; //
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Botão de submissão com indicador de carregamento
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
                else
                  ElevatedButton(
                    onPressed: _submitNewPassword,
                    child: const Text('Redefinir Senha'),
                  ),
                // Mensagem de feedback
                if (_feedbackMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isSuccess ? Colors.green : theme.colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
                // Botão "Ir para Login" que aparece apenas em caso de sucesso
                if (_isSuccess) ... [
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const LoginScreen()), //
                              (Route<dynamic> route) => false,
                        );
                      },
                      child: Text(
                        'Ir para Login',
                        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500, fontSize: 16),
                      )
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}