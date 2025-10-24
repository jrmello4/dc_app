// lib/screens/register_screen.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dc_app/config/api_config.dart'; // Import corrigido
import 'package:dc_app/services/auth_service.dart'; // Import corrigido
import 'package:url_launcher/url_launcher.dart'; // Import para abrir URL

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    // Valida o formulário
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Verifica se os termos foram aceites
    if (!_agreedToTerms) {
      _showError('Você precisa aceitar os Termos de Uso para continuar.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Chama o AuthService para fazer o registo real
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(), // Telefone incluído
        password: _passwordController.text.trim(),
      ); //
      if (mounted) {
        // Exibe mensagem de sucesso e volta para a tela de login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso! Você já pode fazer o login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } on AuthServiceException catch (e) {
      // Exibe erro vindo do AuthService (ex: e-mail já existe)
      _showError(e.message);
    } catch (e) {
      // Exibe erro genérico
      _showError('Ocorreu um erro desconhecido. Tente novamente.');
    } finally {
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

  // Função para abrir a URL dos Termos de Uso
  void _launchURL() async {
    final Uri url = Uri.parse(ApiConfig.termsOfUseUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) { // Abre no browser externo
      _showError('Não foi possível abrir o link dos Termos de Uso.');
    }
  }

  @override
  void dispose() {
    // Libera os controladores de texto
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Conta'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (v) => v!.trim().isEmpty ? 'O nome é obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Sobrenome'),
                validator: (v) => v!.trim().isEmpty ? 'O sobrenome é obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'O e-mail é obrigatório';
                  // Validação simples de formato de e-mail
                  if (!RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$").hasMatch(v)) {
                    return 'Por favor, insira um e-mail válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telefone (Opcional)'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'A senha é obrigatória';
                  if (v.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirmar Senha'),
                obscureText: !_isPasswordVisible,
                validator: (v) {
                  if (v != _passwordController.text) return 'As senhas não coincidem';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Checkbox e Link para Termos de Uso
              FormField<bool>(
                builder: (state) {
                  return Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Checkbox(
                            value: _agreedToTerms,
                            onChanged: (value) {
                              setState(() {
                                _agreedToTerms = value!;
                                state.didChange(value); // Notifica o FormField sobre a mudança
                              });
                            },
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium, // Estilo de texto padrão
                                children: [
                                  const TextSpan(text: 'Eu li e concordo com os '),
                                  TextSpan(
                                    text: 'Termos de Uso',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary, // Usa cor primária do tema
                                      decoration: TextDecoration.underline,
                                    ),
                                    // Reconhecedor de toque para abrir o link
                                    recognizer: TapGestureRecognizer()..onTap = _launchURL,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Exibe mensagem de erro se o checkbox não for marcado
                      if (state.hasError)
                        Padding(
                          padding: const EdgeInsets.only(left: 10.0, top: 5.0),
                          child: Text(
                            state.errorText!,
                            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                          ),
                        )
                    ],
                  );
                },
                // Validador para o FormField (garante que o checkbox seja marcado)
                validator: (value) {
                  if (!_agreedToTerms) {
                    return 'Você precisa aceitar os termos.';
                  }
                  return null;
                },
              ), //
              const SizedBox(height: 24),
              // Botão de Cadastrar com indicador de carregamento
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _register,
                child: const Text('CADASTRAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}