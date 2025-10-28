// lib/screens/forgot_password_screen.dart
import 'dart:convert'; // Necessário para json.decode na versão original

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http; // Necessário para a lógica original
import 'package:dc_app/config/api_config.dart'; // Import corrigido
import 'package:dc_app/services/auth_service.dart'; // Import corrigido

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  Future<void> _requestPasswordReset() async {
    // Valida o formulário
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      // Chama o AuthService para solicitar a redefinição real
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.requestPasswordReset(_emailController.text.trim()); //
      if (mounted) {
        setState(() {
          _isSuccess = true;
          // Mensagem padrão por segurança (não confirma existência do email)
          _feedbackMessage =
          'Se um usuário com este e-mail existir, um link para redefinição de senha foi enviado.'; //
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSuccess = false;
          // Exibe a mensagem de erro vinda do AuthService ou uma genérica
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
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // Usa cor de fundo do tema
      appBar: AppBar(
        title: const Text('Recuperar Senha'),
        elevation: 0.5, // Mantém elevação sutil
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
                  Icons.lock_reset_outlined, // Ícone mantido
                  size: 60,
                  color: colorScheme.secondary, // Usa cor secundária do tema
                ),
                const SizedBox(height: 24),
                Text(
                  'Esqueceu sua senha?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall, // Estilo do tema
                ),
                const SizedBox(height: 8),
                Text(
                  'Não se preocupe! Insira seu e-mail abaixo para receber um link de redefinição.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium, // Estilo do tema
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 'Seu e-mail de cadastro',
                    prefixIcon: Icon(Icons.person_outline), // Ícone de pessoa
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe seu e-mail.';
                    }
                    // Validação de formato de e-mail
                    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
                      return 'Por favor, insira um e-mail válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Botão de envio com indicador de carregamento
                if (_isLoading)
                  Center(child: CircularProgressIndicator(color: colorScheme.primary))
                else
                  ElevatedButton(
                    onPressed: _requestPasswordReset,
                    child: const Text('Enviar Link de Redefinição'),
                  ),
                // Exibição da mensagem de feedback
                if (_feedbackMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _feedbackMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      // Verde para sucesso, Vermelho (cor de erro do tema) para falha
                      color: _isSuccess ? Colors.green : colorScheme.error,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Botão para voltar para a tela de Login
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Volta para a tela anterior (LoginScreen)
                  },
                  child: Text(
                    'Voltar para o Login',
                    style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}