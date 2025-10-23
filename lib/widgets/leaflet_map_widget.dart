// lib/widgets/leaflet_map_widget.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dc_app/services/setor_location_service.dart';
import 'package:dc_app/models/setor.dart';

class LeafletMapWidget extends StatefulWidget {
  final List<Setor> setores;
  final Position? currentPosition;
  final List<List<double>>? initialPolygon;
  final Function(List<List<double>>)? onPolygonChanged;
  final Function(Setor?)? onSetorSelected;
  final bool showSetores;
  final bool allowDrawing;
  final bool showControls;

  const LeafletMapWidget({
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
  State<LeafletMapWidget> createState() => _LeafletMapWidgetState();
}

class _LeafletMapWidgetState extends State<LeafletMapWidget> {
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
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message.message);
        },
      )
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

  void _handleJavaScriptMessage(String message) {
    try {
      final parts = message.split('|');
      final type = parts[0];
      
      switch (type) {
        case 'polygonChanged':
          if (parts.length > 1) {
            final coords = parts[1];
            if (coords.isNotEmpty) {
              final points = coords.split(';').map((point) {
                final latLon = point.split(',');
                return [double.parse(latLon[0]), double.parse(latLon[1])];
              }).toList();
              
              setState(() {
                _currentPolygon = points;
              });
              widget.onPolygonChanged?.call(points);
            } else {
              setState(() {
                _currentPolygon.clear();
              });
              widget.onPolygonChanged?.call([]);
            }
          }
          break;
        case 'setorSelected':
          if (parts.length > 1) {
            final setorId = int.parse(parts[1]);
            final setor = widget.setores.firstWhere(
              (s) => s.id == setorId,
              orElse: () => widget.setores.first,
            );
            setState(() {
              _selectedSetor = setor;
            });
            widget.onSetorSelected?.call(setor);
          }
          break;
      }
    } catch (e) {
      print('Erro ao processar mensagem JavaScript: $e');
    }
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
        body { margin: 0; padding: 0; font-family: Arial, sans-serif; }
        #map { height: 100vh; width: 100%; }
        .info-panel {
            position: absolute;
            top: 10px;
            right: 10px;
            background: white;
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            z-index: 1000;
            max-width: 200px;
        }
        .control-panel {
            position: absolute;
            bottom: 10px;
            left: 10px;
            background: white;
            padding: 10px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            z-index: 1000;
        }
        .btn {
            background: #007bff;
            color: white;
            border: none;
            padding: 8px 12px;
            margin: 2px;
            border-radius: 3px;
            cursor: pointer;
        }
        .btn:hover { background: #0056b3; }
        .btn.danger { background: #dc3545; }
        .btn.danger:hover { background: #c82333; }
        .btn.success { background: #28a745; }
        .btn.success:hover { background: #218838; }
    </style>
</head>
<body>
    <div id="map"></div>
    
    <div class="info-panel">
        <div id="info-content">
            <strong>Instruções:</strong><br>
            • Clique para adicionar pontos<br>
            • Duplo clique para finalizar<br>
            • Use os controles abaixo
        </div>
    </div>
    
    <div class="control-panel">
        <button class="btn" onclick="clearPolygon()">Limpar</button>
        <button class="btn success" onclick="confirmPolygon()">Confirmar</button>
        <button class="btn" onclick="toggleSetores()">Setores</button>
    </div>
    
    <script>
        let map;
        let drawnItems;
        let currentPolygon;
        let setores = ${setoresJson.map((s) => '{id: ${s['id']}, nome: "${s['nome']}", lat: ${s['lat']}, lon: ${s['lon']}, raio: ${s['raio']}}').join(',')};
        let initialPolygon = ${initialPolygonJson.isNotEmpty ? '[' + initialPolygonJson.map((p) => '[${p[0]}, ${p[1]}]').join(',') + ']' : '[]'};
        let setorLayers = [];
        let showSetores = ${widget.showSetores};
        
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
            if (showSetores) {
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
            
            // Atualiza painel de informações
            updateInfoPanel();
        }
        
        function addSetores() {
            setores.forEach(setor => {
                // Adiciona marcador do setor
                const marker = L.marker([setor.lat, setor.lon])
                    .addTo(map)
                    .bindPopup(\`<b>\${setor.nome}</b><br>Raio: \${setor.raio}m\`);
                
                // Adiciona círculo do setor
                const circle = L.circle([setor.lat, setor.lon], {
                    color: 'blue',
                    fillColor: 'lightblue',
                    fillOpacity: 0.2,
                    radius: setor.raio
                }).addTo(map);
                
                // Adiciona evento de clique no setor
                marker.on('click', function() {
                    FlutterChannel.postMessage('setorSelected|' + setor.id);
                });
                
                setorLayers.push(marker, circle);
            });
        }
        
        function toggleSetores() {
            if (showSetores) {
                setorLayers.forEach(layer => map.removeLayer(layer));
                showSetores = false;
            } else {
                addSetores();
                showSetores = true;
            }
        }
        
        function addInitialPolygon() {
            if (initialPolygon.length > 0) {
                currentPolygon = L.polygon(initialPolygon, {
                    color: 'green',
                    fillColor: 'lightgreen',
                    fillOpacity: 0.3
                }).addTo(drawnItems);
                
                map.fitBounds(currentPolygon.getBounds());
                updateInfoPanel();
            }
        }
        
        function setupDrawingEvents() {
            let isDrawing = false;
            let tempPolygon = [];
            let tempMarkers = [];
            
            // Evento de clique no mapa
            map.on('click', function(e) {
                if (!${widget.allowDrawing}) return;
                
                if (!isDrawing) {
                    // Inicia novo polígono
                    isDrawing = true;
                    tempPolygon = [];
                    tempMarkers = [];
                    drawnItems.clearLayers();
                }
                
                // Adiciona ponto ao polígono temporário
                tempPolygon.push([e.latlng.lat, e.latlng.lng]);
                
                // Adiciona marcador do ponto
                const marker = L.marker([e.latlng.lat, e.latlng.lng])
                    .addTo(drawnItems)
                    .bindPopup(\`Ponto \${tempPolygon.length}\`);
                tempMarkers.push(marker);
                
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
                    updateInfoPanel();
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
            const coords = polygon.map(p => p[0] + ',' + p[1]).join(';');
            FlutterChannel.postMessage('polygonChanged|' + coords);
        }
        
        function clearPolygon() {
            drawnItems.clearLayers();
            currentPolygon = null;
            FlutterChannel.postMessage('polygonChanged|');
            updateInfoPanel();
        }
        
        function confirmPolygon() {
            if (currentPolygon) {
                const coords = currentPolygon.getLatLngs()[0].map(latlng => [latlng.lat, latlng.lng]);
                notifyPolygonChange(coords);
            }
        }
        
        function updateInfoPanel() {
            const infoDiv = document.getElementById('info-content');
            if (currentPolygon) {
                const coords = currentPolygon.getLatLngs()[0];
                const area = calculatePolygonArea(coords);
                const perimeter = calculatePolygonPerimeter(coords);
                
                infoDiv.innerHTML = \`
                    <strong>Polígono Ativo:</strong><br>
                    Pontos: \${coords.length}<br>
                    Área: \${area.toFixed(2)} m²<br>
                    Perímetro: \${perimeter.toFixed(2)} m
                \`;
            } else {
                infoDiv.innerHTML = \`
                    <strong>Instruções:</strong><br>
                    • Clique para adicionar pontos<br>
                    • Duplo clique para finalizar<br>
                    • Use os controles abaixo
                \`;
            }
        }
        
        function calculatePolygonArea(coords) {
            // Cálculo simplificado da área
            let area = 0;
            for (let i = 0; i < coords.length; i++) {
                const j = (i + 1) % coords.length;
                area += coords[i].lng * coords[j].lat;
                area -= coords[j].lng * coords[i].lat;
            }
            return Math.abs(area) / 2 * 111320 * 111320; // Aproximação para metros quadrados
        }
        
        function calculatePolygonPerimeter(coords) {
            let perimeter = 0;
            for (let i = 0; i < coords.length; i++) {
                const j = (i + 1) % coords.length;
                const lat1 = coords[i].lat * Math.PI / 180;
                const lat2 = coords[j].lat * Math.PI / 180;
                const dLat = (coords[j].lat - coords[i].lat) * Math.PI / 180;
                const dLng = (coords[j].lng - coords[i].lng) * Math.PI / 180;
                
                const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                         Math.cos(lat1) * Math.cos(lat2) *
                         Math.sin(dLng/2) * Math.sin(dLng/2);
                const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
                
                perimeter += 6371000 * c; // Raio da Terra em metros
            }
            return perimeter;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
