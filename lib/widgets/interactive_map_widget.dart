// lib/widgets/interactive_map_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/models/setor.dart';

class InteractiveMapWidget extends StatefulWidget {
  final List<Setor> setores;
  final Position? currentPosition;
  final List<List<double>>? initialPolygon;
  final Function(List<List<double>>)? onPolygonChanged;
  final Function(Setor?)? onSetorSelected;
  final bool showSetores;
  final bool allowDrawing;
  final bool showControls;

  const InteractiveMapWidget({
    Key? key,
    required this.setores,
    this.currentPosition,
    this.initialPolygon,
    this.onPolygonChanged,
    this.onSetorSelected,
    this.showSetores = true,
    this.allowDrawing = true,
    this.showControls = true,
  }) : super(key: key);

  @override
  State<InteractiveMapWidget> createState() => _InteractiveMapWidgetState();
}

class _InteractiveMapWidgetState extends State<InteractiveMapWidget> {
  late WebViewController _controller;
  bool _isMapReady = false;
  List<List<double>> _currentPolygon = [];
  Setor? _selectedSetor;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    if (widget.initialPolygon != null) {
      _currentPolygon = List.from(widget.initialPolygon!);
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isMapReady = true;
            });
            _initializeMap();
          },
        ),
      )
      ..loadHtmlString(_getMapHTML());
  }

  String _getMapHTML() {
    final currentLat = widget.currentPosition?.latitude ?? -23.5505;
    final currentLon = widget.currentPosition?.longitude ?? -46.6333;
    
    final setoresJson = widget.setores.map((setor) => {
      'id': setor.id,
      'nome': setor.nome,
      'lat': setor.latitude ?? currentLat,
      'lon': setor.longitude ?? currentLon,
      'raio': setor.raio ?? 500,
    }).toList();

    final initialPolygonJson = _currentPolygon.map((point) => [point[0], point[1]]).toList();

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mapa Interativo</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        body { margin: 0; padding: 0; }
        #map { height: 100vh; width: 100%; }
        .leaflet-control-draw { display: none !important; }
    </style>
</head>
<body>
    <div id="map"></div>
    
    <script>
        let map;
        let drawnItems;
        let currentPolygon;
        let setores = ${setoresJson.map((s) => '{id: ${s['id']}, nome: "${s['nome']}", lat: ${s['lat']}, lon: ${s['lon']}, raio: ${s['raio']}}').join(',')};
        let initialPolygon = ${initialPolygonJson.isNotEmpty ? '[' + initialPolygonJson.map((p) => '[${p[0]}, ${p[1]}]').join(',') + ']' : '[]'};
        
        function initMap() {
            // Inicializa o mapa
            map = L.map('map').setView([$currentLat, $currentLon], 13);
            
            // Adiciona camada do OpenStreetMap
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                attribution: '© OpenStreetMap contributors'
            }).addTo(map);
            
            // Inicializa camada para desenhar
            drawnItems = new L.FeatureGroup();
            map.addLayer(drawnItems);
            
            // Adiciona setores se habilitado
            if (${widget.showSetores}) {
                addSetores();
            }
            
            // Adiciona polígono inicial se existir
            if (initialPolygon.length > 0) {
                addInitialPolygon();
            }
            
            // Adiciona marcador da posição atual
            if (${widget.currentPosition != null}) {
                L.marker([$currentLat, $currentLon])
                    .addTo(map)
                    .bindPopup('Sua localização atual')
                    .openPopup();
            }
            
            // Configura eventos de desenho
            setupDrawingEvents();
            
            // Notifica que o mapa está pronto
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('mapReady');
            }
        }
        
        function addSetores() {
            setores.forEach(setor => {
                // Adiciona marcador do setor
                const marker = L.marker([setor.lat, setor.lon])
                    .addTo(map)
                    .bindPopup(\`<b>\${setor.nome}</b><br>Raio: \${setor.raio}m\`);
                
                // Adiciona círculo do setor
                L.circle([setor.lat, setor.lon], {
                    color: 'blue',
                    fillColor: 'lightblue',
                    fillOpacity: 0.2,
                    radius: setor.raio
                }).addTo(map);
            });
        }
        
        function addInitialPolygon() {
            if (initialPolygon.length > 0) {
                currentPolygon = L.polygon(initialPolygon, {
                    color: 'green',
                    fillColor: 'lightgreen',
                    fillOpacity: 0.3
                }).addTo(drawnItems);
                
                map.fitBounds(currentPolygon.getBounds());
            }
        }
        
        function setupDrawingEvents() {
            let isDrawing = false;
            let tempPolygon = [];
            
            // Evento de clique no mapa
            map.on('click', function(e) {
                if (!${widget.allowDrawing}) return;
                
                if (!isDrawing) {
                    // Inicia novo polígono
                    isDrawing = true;
                    tempPolygon = [];
                    drawnItems.clearLayers();
                }
                
                // Adiciona ponto ao polígono temporário
                tempPolygon.push([e.latlng.lat, e.latlng.lng]);
                
                // Adiciona marcador do ponto
                L.marker([e.latlng.lat, e.latlng.lng])
                    .addTo(drawnItems)
                    .bindPopup(\`Ponto \${tempPolygon.length}\`);
                
                // Se tem pelo menos 3 pontos, desenha o polígono
                if (tempPolygon.length >= 3) {
                    if (currentPolygon) {
                        drawnItems.removeLayer(currentPolygon);
                    }
                    
                    currentPolygon = L.polygon(tempPolygon, {
                        color: 'green',
                        fillColor: 'lightgreen',
                        fillOpacity: 0.3
                    }).addTo(drawnItems);
                    
                    // Notifica mudança
                    notifyPolygonChange(tempPolygon);
                }
            });
            
            // Evento de duplo clique para finalizar
            map.on('dblclick', function(e) {
                if (isDrawing && tempPolygon.length >= 3) {
                    isDrawing = false;
                    // Polígono já foi criado no evento de clique
                }
            });
        }
        
        function notifyPolygonChange(polygon) {
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('polygonChanged', polygon);
            }
        }
        
        function clearPolygon() {
            drawnItems.clearLayers();
            currentPolygon = null;
            if (window.flutter_inappwebview) {
                window.flutter_inappwebview.callHandler('polygonChanged', []);
            }
        }
        
        function setPolygon(polygon) {
            drawnItems.clearLayers();
            if (polygon && polygon.length > 0) {
                currentPolygon = L.polygon(polygon, {
                    color: 'green',
                    fillColor: 'lightgreen',
                    fillOpacity: 0.3
                }).addTo(drawnItems);
                map.fitBounds(currentPolygon.getBounds());
            }
        }
        
        function getCurrentPolygon() {
            return currentPolygon ? currentPolygon.getLatLngs()[0].map(latlng => [latlng.lat, latlng.lng]) : [];
        }
        
        // Inicializa o mapa quando a página carrega
        document.addEventListener('DOMContentLoaded', initMap);
    </script>
</body>
</html>
    ''';
  }

  void _initializeMap() {
    if (_isMapReady) {
      _controller.runJavaScript('initMap();');
    }
  }

  void _clearPolygon() {
    if (_isMapReady) {
      _controller.runJavaScript('clearPolygon();');
      setState(() {
        _currentPolygon.clear();
      });
      widget.onPolygonChanged?.call([]);
    }
  }

  void _setPolygon(List<List<double>> polygon) {
    if (_isMapReady) {
      final polygonJson = polygon.map((point) => '[${point[0]}, ${point[1]}]').join(',');
      _controller.runJavaScript('setPolygon([$polygonJson]);');
      setState(() {
        _currentPolygon = List.from(polygon);
      });
    }
  }

  Future<List<List<double>>> _getCurrentPolygon() async {
    if (_isMapReady) {
      final result = await _controller.runJavaScriptReturningResult('getCurrentPolygon();');
      if (result != null && result.toString() != 'null') {
        // Parse do resultado JavaScript
        return [];
      }
    }
    return _currentPolygon;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showControls) _buildControls(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: WebViewWidget(controller: _controller),
            ),
          ),
        ),
        if (widget.showControls) _buildInfoPanel(),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isMapReady ? _clearPolygon : null,
              icon: const Icon(Icons.clear),
              label: const Text('Limpar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isMapReady ? () => _setPolygon(_currentPolygon) : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Atualizar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _currentPolygon.isNotEmpty ? () => widget.onPolygonChanged?.call(_currentPolygon) : null,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instruções:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          const Text('• Clique no mapa para adicionar pontos ao polígono'),
          const Text('• Clique duplo para finalizar o polígono'),
          const Text('• Use os controles para limpar ou confirmar'),
          if (_currentPolygon.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Área: ${SetorLocationService.calculatePolygonArea(_currentPolygon).toStringAsFixed(2)} m²',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Perímetro: ${SetorLocationService.calculatePolygonPerimeter(_currentPolygon).toStringAsFixed(2)} m',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}
