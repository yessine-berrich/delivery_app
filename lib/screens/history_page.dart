import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _commandes = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _currentUserId;
  bool _didInit = false; // Flag pour s'assurer que l'initialisation ne se fait qu'une fois

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupérer l'ID utilisateur passé par ModalRoute
    final userId = ModalRoute.of(context)?.settings.arguments as int?;
    
    // S'assurer que l'initialisation se fait une seule fois et que l'ID est valide
    if (!_didInit && userId != null) {
      _currentUserId = userId;
      _didInit = true; // Empêche les appels multiples lors des rebuilds
      _fetchHistory();
    }
    // Si l'utilisateur n'est pas passé, on affiche l'erreur immédiatement.
    if (userId == null && !_didInit) {
       _didInit = true;
       setState(() {
         _errorMessage = 'ID utilisateur non fourni. Veuillez vous reconnecter.';
         _isLoading = false;
       });
    }
  }

  // --------------------------------------------------------------------------
  // READ : Récupérer l'historique des commandes
  // --------------------------------------------------------------------------
  Future<void> _fetchHistory() async {
    if (_currentUserId == null) {
      setState(() {
        _errorMessage = 'ID utilisateur non fourni. Impossible de charger l\'historique.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _commandes = []; // Vider la liste avant un nouvel appel
    });

    // Utilisation de la méthode GET avec l'ID utilisateur dans l'URL
    var url = Uri.parse(
      "${globals.baseUrl}commande_api.php?user_id=$_currentUserId",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          // Si 'data' est une liste (même vide, c'est OK)
          if (data['data'] is List) {
            setState(() {
              _commandes = List<Map<String, dynamic>>.from(data['data']);
              _isLoading = false;
            });
          } else {
            // Si le statut est 'success' mais les données sont mal formées (devrait être une liste)
            throw Exception(
              'Réponse de l\'API invalide: le champ data n\'est pas une liste.',
            );
          }
        } else if (response.statusCode == 404) {
             // Cas spécifique où l'API retourne 404 (implémenté dans la correction PHP)
             setState(() {
               _isLoading = false;
               _commandes = []; // S'assurer que la liste est vide
             });
        } else {
          // Si l'API retourne un statut 'error'
          throw Exception(
            data['message'] ?? 'Erreur inconnue de l\'API lors du chargement.',
          );
        }
      } else {
        // Erreur de communication HTTP (e.g., 500 Server Error)
        throw Exception('Erreur de serveur: Code ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        // Afficher le message d'erreur de manière conviviale
        _errorMessage =
            'Erreur: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
      // Affichage d'une Pop-up en cas d'échec
      _showPopUp('Erreur Serveur', _errorMessage, Colors.red);
    }
  }

  // --------------------------------------------------------------------------
  // Fenêtre Pop-up (Utilitaire)
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, Color color) {
    // S'assurer que le widget est encore monté avant d'afficher le dialogue
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Construction de l'interface
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Commandes'),
        backgroundColor:
            Theme.of(context).primaryColor, // Couleur d'application
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 15),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Bouton pour réessayer
              ElevatedButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_commandes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 80, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              'Aucune commande trouvée.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 5),
            Text(
              'C\'est le moment de vous faire plaisir !',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _commandes.length,
      itemBuilder: (context, index) {
        final commande = _commandes[index];
        final String statut = commande['statut'] ?? 'Inconnu';
        final String id = commande['commande_id']?.toString() ?? 'N/A';
        
        // Utiliser la conversion sûre pour double
        final double total =
            double.tryParse(commande['total']?.toString() ?? '0.0') ?? 0.0;
        // Gérer le cas où 'date_commande' est null ou vide
        final String dateFull = commande['date_commande']?.toString() ?? 'N/A';
        final String date = dateFull.length >= 10 ? dateFull.substring(0, 10) : dateFull;
        
        final String details =
            commande['plats_details'] ?? 'Détails non disponibles';

        // Choisir une couleur en fonction du statut (UX)
        Color statusColor;
        switch (statut) {
          case 'Livrée':
            statusColor = Colors.green.shade700;
            break;
          case 'En attente':
            statusColor = Colors.amber.shade700;
            break;
          case 'Annulée':
            statusColor = Colors.red.shade700;
            break;
          default:
            statusColor = Colors.grey;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne Statut et Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Statut de la commande
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        statut,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: statusColor,
                        ),
                      ),
                    ),
                    // Total de la commande
                    Text(
                      'Total: ${total.toStringAsFixed(2)} €',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, thickness: 1),
                // Ligne Date et ID
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID Commande: $id',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Date: $date',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // Détails des plats
                const Text(
                  'Articles:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  details.replaceAll(
                    ' | ',
                    '\n',
                  ), // Afficher chaque plat sur une ligne
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}