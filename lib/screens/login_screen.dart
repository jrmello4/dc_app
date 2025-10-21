// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/services/auth_service.dart'; // Import corrigido
import 'home_screen.dart';                          // Import corrigido
import 'register_screen.dart';                     // Import corrigido
import 'forgot_password_screen.dart';              // Import corrigido

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _logger = Logger();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    // Valida o formulário
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      // Chama o AuthService para fazer o login real
      await AuthService.login(_emailController.text.trim(), _passwordController.text.trim());
      if (mounted) {
        // Navega para a HomeScreen em caso de sucesso
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      // Exibe erro de autenticação (ex: senha incorreta)
      _showError(e.message);
    } catch (e) {
      // Exibe erro genérico (ex: falha de conexão)
      _logger.e('Erro inesperado durante o login', error: e);
      _showError('Ocorreu um erro de conexão. Tente novamente.');
    } finally {
      // Garante que o indicador de carregamento seja removido
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Função auxiliar para exibir mensagens de erro
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
    );
  }

  @override
  void dispose() {
    // Libera os controladores de texto quando a tela for destruída
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ícone representativo da Defesa Civil
                  Icon(
                    Icons.security_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Portal Defesa Civil",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email ou Usuário',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu email ou usuário' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _isPasswordVisible = !_isPasswordVisible);
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (v) => v == null || v.isEmpty ? 'Informe sua senha' : null,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
                      child: const Text('Esqueceu sua senha?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Botão de Entrar com indicador de carregamento
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _login,
                    child: const Text('ENTRAR'),
                  ),
                  const SizedBox(height: 12),
                  // Link para a tela de registro
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: const Text('Não tem uma conta? Cadastre-se'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}