import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() => runApp(DroneApp());

class DroneApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contrôle Drone Surveillance',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DroneControlPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DroneControlPage extends StatefulWidget {
  @override
  _DroneControlPageState createState() => _DroneControlPageState();
}

class _DroneControlPageState extends State<DroneControlPage> {
  Socket? _socket;
  String _connectionStatus = 'Déconnecté';
  Map<String, double> sensorData = {
    'TEMP': 0,
    'HUM': 0,
    'GAZ': 0,
    'AX': 0,
    'AY': 0,
    'AZ': 0,
    'GX': 0,
    'GY': 0,
    'GZ': 0,
  };

  @override
  void initState() {
    super.initState();
    _connectToDrone();
  }

  void _connectToDrone() async {
    try {
      setState(() => _connectionStatus = 'Connexion...');
      _socket = await Socket.connect('192.168.4.1', 1234, timeout: Duration(seconds: 10));
      setState(() => _connectionStatus = 'Connecté');

      _socket!.listen(
            (List<int> data) {
          final message = String.fromCharCodes(data);
          _processData(message);
        },
        onError: (error) {
          setState(() => _connectionStatus = 'Erreur: $error');
        },
        onDone: () {
          setState(() => _connectionStatus = 'Déconnecté');
        },
      );
    } catch (e) {
      setState(() => _connectionStatus = 'Échec connexion: $e');
    }
  }

  void _processData(String data) {
    try {
      // Example format expected: "TEMP:23.4,HUM:45.0,GAZ:0,AX:0,AY:0,AZ:0,GX:0,GY:0,GZ:0"
      List<String> parts = data.split(',');
      for (String part in parts) {
        List<String> keyValue = part.split(':');
        if (keyValue.length == 2) {
          String key = keyValue[0].trim();
          double value = double.tryParse(keyValue[1].trim()) ?? 0;
          if (mounted) {
            setState(() {
              sensorData[key] = value;
            });
          }
        }
      }
    } catch (e) {
      print('Erreur traitement données: $e');
    }
  }

  void _sendCommand(String command) {
    if (_socket != null) {
      try {
        _socket!.write('$command\n');
      } catch (e) {
        print('Erreur envoi commande: $e');
      }
    } else {
      print('Socket non connecté — commande non envoyée: $command');
    }
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs proches de l'image: fond bleu clair + carte bleu foncé
    const Color backgroundBlue = Color(0xFF00AEEF); // fond général
    const Color cardBlue = Color(0xFF0078C8); // bloc d'info
    const double buttonSize = 92.0; // taille des boutons circulaires

    return Scaffold(
      backgroundColor: backgroundBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: Column(
            children: [
              // Bloc d'information en haut (carte)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                decoration: BoxDecoration(
                  color: cardBlue,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre + statut connexion (semblable à l'image)
                    Text(
                      'Contrôl-e Drone - $_connectionStatus',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Ligne température / humidité
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Température: ${sensorData['TEMP']?.toStringAsFixed(1)}°C',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          'Humidite: ${sensorData['HUM']?.toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'GaZ: ${sensorData['GAZ']?.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Accélération - X:${sensorData['AX']?.toStringAsFixed(0)} Y:${sensorData['AY']?.toStringAsFixed(0)} Z:${sensorData['AZ']?.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gyroscope - X:${sensorData['GX']?.toStringAsFixed(0)} Y:${sensorData['GY']?.toStringAsFixed(0)} Z:${sensorData['GZ']?.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),

              // Espace entre la carte et le D-pad (ajustable)
              const SizedBox(height: 60),

              // D-Pad : boutons directionnels centrés
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Bouton haut
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: ElevatedButton(
                          onPressed: () => _sendCommand('AVANT'),
                          onLongPress: () => _sendCommand('STOP'),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.all(0),
                            backgroundColor: cardBlue,
                            elevation: 6,
                          ),
                          child: const Icon(Icons.arrow_upward, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Ligne gauche - stop - droite
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gauche
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: ElevatedButton(
                              onPressed: () => _sendCommand('GAUCHE'),
                              onLongPress: () => _sendCommand('STOP'),
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.all(0),
                                backgroundColor: cardBlue,
                                elevation: 6,
                              ),
                              child: const Icon(Icons.arrow_back, size: 40, color: Colors.white),
                            ),
                          ),

                          const SizedBox(width: 28),

                          // STOP (bouton central rouge carré dans un cercle)
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: ElevatedButton(
                              onPressed: () => _sendCommand('STOP'),
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.all(0),
                                backgroundColor: cardBlue,
                                elevation: 6,
                              ),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.rectangle,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 28),

                          // Droite
                          SizedBox(
                            width: buttonSize,
                            height: buttonSize,
                            child: ElevatedButton(
                              onPressed: () => _sendCommand('DROITE'),
                              onLongPress: () => _sendCommand('STOP'),
                              style: ElevatedButton.styleFrom(
                                shape: const CircleBorder(),
                                padding: EdgeInsets.all(0),
                                backgroundColor: cardBlue,
                                elevation: 6,
                              ),
                              child: const Icon(Icons.arrow_forward, size: 40, color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Bouton bas
                      SizedBox(
                        width: buttonSize,
                        height: buttonSize,
                        child: ElevatedButton(
                          onPressed: () => _sendCommand('ARRIERE'),
                          onLongPress: () => _sendCommand('STOP'),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.all(0),
                            backgroundColor: cardBlue,
                            elevation: 6,
                          ),
                          child: const Icon(Icons.arrow_downward, size: 40, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
