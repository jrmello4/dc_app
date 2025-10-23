// lib/screens/ocorrencias_list_screen.dart

import 'package:flutter/material.dart';
import 'package:dc_app/screens/map_drawing_screen.dart';
import 'package:dc_app/screens/create_ocorrencia_screen.dart';

class OcorrenciasListScreen extends StatelessWidget {
  const OcorrenciasListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ocorrências'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card para criar ocorrência normal
          Card(
            child: ListTile(
              leading: const Icon(Icons.add_alert, color: Colors.blue),
              title: const Text('Nova Ocorrência'),
              subtitle: const Text('Criar ocorrência com formulário'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateOcorrenciaScreen(),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Card para criar ocorrência com mapa
          Card(
            child: ListTile(
              leading: const Icon(Icons.map, color: Colors.green),
              title: const Text('Ocorrência com Área'),
              subtitle: const Text('Desenhar área no mapa'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapDrawingScreen(),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Card para visualizar ocorrências existentes
          Card(
            child: ListTile(
              leading: const Icon(Icons.list, color: Colors.orange),
              title: const Text('Minhas Ocorrências'),
              subtitle: const Text('Ver ocorrências criadas'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // Aqui você pode navegar para a tela de ocorrências do usuário
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Funcionalidade em desenvolvimento'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
