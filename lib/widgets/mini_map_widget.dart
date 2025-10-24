// lib/widgets/mini_map_widget.dart

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:logger/logger.dart';
import 'package:dc_app/models/setor.dart';

class MiniMapWidget extends StatefulWidget {
  final Position? currentPosition;
  final List<List<double>>? initialPolygon;
  final Function(List<List<double>>)? onPolygonChanged;
  final bool allowDrawing;
  final double height;

  const MiniMapWidget({
    Key? key,
    this.currentPosition,
    this.initialPolygon,
    this.onPolygonChanged,
    this.allowDrawing = true,
    this.height = 300,
  }) : super(key: key);

  @override
  State<MiniMapWidget> createState() => _MiniMapWidgetState();
}

class _MiniMapWidgetState extends State<MiniMapWidget> {
  late WebViewController _controller;
  bool _isMapReady = false;
  bool _hasError = false;
  String? _errorMessage;
  List<List<double>> _currentPolygon = [];
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    if (widget.initialPolygon != null) {
      _currentPolygon = List.from(widget.initialPolygon!);
    }
  }

  void _initializeWebView() {
    try {
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
              if (mounted) {
                setState(() {
                  _isMapReady = true;
                  _hasError = false;
                });
                _initializeMap();
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Erro ao carregar mapa: ${error.description}';
                });
              }
            },
          ),
        )
        ..loadHtmlString(_getMapHTML());
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erro ao inicializar WebView: $e';
        });
      }
    }
  }

  void _handleJavaScriptMessage(String message) {
    try {
      final parts = message.split('|');
      final type = parts[0];
      
      if (type == 'polygonChanged' && parts.length > 1) {
        final coords = parts[1];
        if (coords.isNotEmpty) {
          final points = coords.split(';').map((point) {
            final latLon = point.split(',');
            return [double.parse(latLon[0]), double.parse(latLon[1])];
          }).toList();
          
          if (mounted) {
            setState(() {
              _currentPolygon = points;
            });
            widget.onPolygonChanged?.call(points);
          }
        } else {
          if (mounted) {
            setState(() {
              _currentPolygon.clear();
            });
            widget.onPolygonChanged?.call([]);
          }
        }
      }
    } catch (e) {
      _logger.e('Erro ao processar mensagem JavaScript', error: e);
    }
  }

  String _getMapHTML() {
    final currentLat = widget.currentPosition?.latitude ?? -23.5505;
    final currentLon = widget.currentPosition?.longitude ?? -46.6333;
    
    final initialPolygonJson = _currentPolygon.map((point) => [point[0], point[1]]).toList();

    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mini Mapa</title>
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        body { 
            margin: 0; 
            padding: 0; 
            font-family: Arial, sans-serif; 
            background: #f0f0f0;
        }
        #map { 
            height: 100vh; 
            width: 100%; 
        }
        .control-panel {
            position: absolute;
            bottom: 10px;
            left: 10px;
            background: white;
            padding: 8px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            z-index: 1000;
        }
        .btn {
            background: #007bff;
            color: white;
            border: none;
            padding: 4px 8px;
            margin: 2px;
            border-radius: 3px;
            cursor: pointer;
            font-size: 10px;
        }
        .btn:hover { background: #0056b3; }
        .btn.danger { background: #dc3545; }
        .btn.danger:hover { background: #c82333; }
        .btn.success { background: #28a745; }
        .btn.success:hover { background: #218838; }
        .info-panel {
            position: absolute;
            top: 10px;
            right: 10px;
            background: white;
            padding: 8px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            z-index: 1000;
            max-width: 150px;
            font-size: 10px;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    
    <div class="info-panel" id="info-panel">
        <div id="info-content">
            <strong>Carregando...</strong>
        </div>
    </div>
    
    <div class="control-panel">
        <button class="btn" onclick="clearPolygon()">Limpar</button>
        <button class="btn success" onclick="confirmPolygon()">Confirmar</button>
    </div>
    
    <script>
        let map;
        let drawnItems;
        let currentPolygon;
        let initialPolygon = ${initialPolygonJson.isNotEmpty ? '[' + initialPolygonJson.map((p) => '[${p[0]}, ${p[1]}]').join(',') + ']' : '[]'};
        let isInitialized = false;
        
        function initMap() {
            try {
                // Inicializa o mapa
                map = L.map('map').setView([$currentLat, $currentLon], 15);
                
                // Adiciona camada do OpenStreetMap
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: '© OpenStreetMap contributors',
                    maxZoom: 18,
                }).addTo(map);
                
                // Inicializa camada para desenhar
                drawnItems = new L.FeatureGroup();
                map.addLayer(drawnItems);
                
                // Adiciona polígono inicial se existir
                if (initialPolygon.length > 0) {
                    addInitialPolygon();
                }
                
                // Configura eventos de desenho
                setupDrawingEvents();
                
                // Atualiza painel de informações
                updateInfoPanel();
                
                isInitialized = true;
                
            } catch (error) {
                console.error('Erro ao inicializar mapa:', error);
                document.getElementById('info-content').innerHTML = 
                    '<strong>Erro ao carregar mapa</strong>';
            }
        }
        
        function addInitialPolygon() {
            try {
                if (initialPolygon.length > 0) {
                    currentPolygon = L.polygon(initialPolygon, {
                        color: 'green',
                        fillColor: 'lightgreen',
                        fillOpacity: 0.3
                    }).addTo(drawnItems);
                    
                    map.fitBounds(currentPolygon.getBounds());
                    updateInfoPanel();
                }
            } catch (error) {
                console.error('Erro ao adicionar polígono inicial:', error);
            }
        }
        
        function setupDrawingEvents() {
            try {
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
                    }
                });
            } catch (error) {
                console.error('Erro ao configurar eventos de desenho:', error);
            }
        }
        
        function notifyPolygonChange(polygon) {
            try {
                const coords = polygon.map(p => p[0] + ',' + p[1]).join(';');
                FlutterChannel.postMessage('polygonChanged|' + coords);
            } catch (error) {
                console.error('Erro ao notificar mudança de polígono:', error);
            }
        }
        
        function clearPolygon() {
            try {
                if (drawnItems) {
                    drawnItems.clearLayers();
                }
                currentPolygon = null;
                FlutterChannel.postMessage('polygonChanged|');
                updateInfoPanel();
            } catch (error) {
                console.error('Erro ao limpar polígono:', error);
            }
        }
        
        function confirmPolygon() {
            try {
                if (currentPolygon) {
                    const coords = currentPolygon.getLatLngs()[0].map(latlng => [latlng.lat, latlng.lng]);
                    notifyPolygonChange(coords);
                }
            } catch (error) {
                console.error('Erro ao confirmar polígono:', error);
            }
        }
        
        function updateInfoPanel() {
            try {
                const infoDiv = document.getElementById('info-content');
                if (currentPolygon) {
                    const coords = currentPolygon.getLatLngs()[0];
                    const area = calculatePolygonArea(coords);
                    const perimeter = calculatePolygonPerimeter(coords);
                    
                    infoDiv.innerHTML = \`
                        <strong>Área:</strong><br>
                        Pontos: \${coords.length}<br>
                        Área: \${area.toFixed(0)} m²<br>
                        Perímetro: \${perimeter.toFixed(0)} m
                    \`;
                } else {
                    infoDiv.innerHTML = \`
                        <strong>Instruções:</strong><br>
                        • Clique para adicionar pontos<br>
                        • Duplo clique para finalizar
                    \`;
                }
            } catch (error) {
                console.error('Erro ao atualizar painel de informações:', error);
            }
        }
        
        function calculatePolygonArea(coords) {
            try {
                let area = 0;
                for (let i = 0; i < coords.length; i++) {
                    const j = (i + 1) % coords.length;
                    area += coords[i].lng * coords[j].lat;
                    area -= coords[j].lng * coords[i].lat;
                }
                return Math.abs(area) / 2 * 111320 * 111320;
            } catch (error) {
                console.error('Erro ao calcular área:', error);
                return 0;
            }
        }
        
        function calculatePolygonPerimeter(coords) {
            try {
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
                    
                    perimeter += 6371000 * c;
                }
                return perimeter;
            } catch (error) {
                console.error('Erro ao calcular perímetro:', error);
                return 0;
            }
        }
        
        // Inicializa o mapa quando a página carrega
        document.addEventListener('DOMContentLoaded', function() {
            setTimeout(initMap, 100);
        });
    </script>
</body>
</html>
    ''';
  }

  void _initializeMap() {
    if (_isMapReady && !_hasError) {
      try {
        _controller.runJavaScript('initMap();');
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Erro ao inicializar mapa: $e';
          });
        }
      }
    }
  }

  void _retryMap() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _isMapReady = false;
    });
    _initializeWebView();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 32,
                color: Colors.red.shade300,
              ),
              const SizedBox(height: 8),
              Text(
                'Erro no Mapa',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                _errorMessage ?? 'Erro desconhecido',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _retryMap,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tentar Novamente'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (!_isMapReady)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Carregando mapa...'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
