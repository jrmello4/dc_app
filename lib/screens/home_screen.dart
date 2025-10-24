// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:dc_app/screens/assigned_ocorrencias_screen.dart'; // Import corrigido
import 'package:dc_app/screens/create_ocorrencia_screen.dart';   // Import corrigido
import 'package:dc_app/screens/login_screen.dart';                // Import corrigido
import 'package:dc_app/screens/ocorrencia_list_screen.dart';    // Import corrigido
import 'package:dc_app/services/auth_service.dart';              // Import corrigido
import 'package:dc_app/screens/user_profile_screen.dart';         // Import corrigido

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final _logger = Logger();

  // Função para fazer logout
  Future<void> _logout() async {
    _logger.i('Iniciando processo de logout.');
    final authService = Provider.of<AuthService>(context, listen: false);
    // Limpa os dados de autenticação armazenados
    await authService.clearAuthData();
    _logger.i('Dados de autenticação limpos.');
    // O Consumer no main.dart vai automaticamente navegar para LoginScreen
  }

  // Função para navegar para a tela de perfil
  Future<void> _navigateToProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const UserProfileScreen()), //
    );
    // Se o perfil foi atualizado (retornou true), recarrega a tela Home
    // para exibir a nova foto, se houver.
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Busca os dados do usuário atual do AuthService
    final photoUrl = AuthService.photoUrl; //
    final isTecnico = AuthService.isTecnico; //

    return Scaffold(
      appBar: AppBar(
        title: const Text('Defesa Civil'),
        actions: [
          // Menu de opções (Perfil, Sair)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                _navigateToProfile();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('Meu Perfil')),
              const PopupMenuItem(value: 'logout', child: Text('Sair')),
            ],
            // Ícone do menu é a foto do perfil ou um ícone padrão
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.white70, // Fundo claro para contraste
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                // Exibe ícone de pessoa se não houver foto
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Icon(Icons.person, color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0), // Espaçamento interno
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centraliza os botões
            crossAxisAlignment: CrossAxisAlignment.stretch, // Estica os botões
            children: [
              // Botão visível apenas para técnicos
              if (isTecnico) ...[ //
                ElevatedButton.icon(
                  icon: const Icon(Icons.assignment_ind_outlined),
                  label: const Text('Ocorrências Atribuídas'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AssignedOcorrenciasScreen())), //
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20), // Botão maior
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Botão para ver as ocorrências do usuário
              ElevatedButton.icon(
                icon: const Icon(Icons.article_outlined),
                label: const Text('Minhas Ocorrências'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OcorrenciaListScreen())), //
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
              const SizedBox(height: 16),
              // Botão para criar uma nova ocorrência
              ElevatedButton.icon(
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Registar Nova Ocorrência'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CreateOcorrenciaScreen())), //
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}