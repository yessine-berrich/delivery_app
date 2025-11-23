import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Configuration de l'API : Assurez-vous que cette URL est accessible depuis votre appareil/émulateur.
// Utilisez 10.0.2.2 si vous exécutez sur un émulateur Android pointant vers localhost.
const String _apiUrl =
    'http://192.168.56.1/api_livraison/admin_commandes_api.php';

// Liste des statuts valides pour le menu déroulant
const List<String> statusOptions = [
  'En attente',
  'En préparation',
  'En livraison',
  'Livrée',
  'Annulée',
];

// Modèle de données pour une Commande
class Commande {
  final int id;
  final String date;
  final double total;
  String statut; // Non final car nous le modifions dans l'UI
  final int userId;
  final String platsDetails;

  Commande({
    required this.id,
    required this.date,
    required this.total,
    required this.statut,
    required this.userId,
    required this.platsDetails,
  });

  factory Commande.fromJson(Map<String, dynamic> json) {
    // Gestion des types potentiellement différents venant de PHP/MySQL
    return Commande(
      id: int.tryParse(json['commande_id']?.toString() ?? '0') ?? 0,
      date: json['date_commande'] as String? ?? 'N/A',
      total: double.tryParse(json['total']?.toString() ?? '0.0') ?? 0.0,
      statut: json['statut'] as String? ?? 'Inconnu',
      userId: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      platsDetails: json['plats_details'] as String? ?? 'Aucun plat.',
    );
  }
}

class OrdersManagementPage extends StatefulWidget {
  const OrdersManagementPage({super.key});

  @override
  State<OrdersManagementPage> createState() => _OrdersManagementPageState();
}

class _OrdersManagementPageState extends State<OrdersManagementPage> {
  List<Commande> _commandes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  // --- LOGIQUE API ---

  // 1. Récupérer toutes les commandes (GET)
  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _commandes =
                (data['data'] as List)
                    .map((json) => Commande.fromJson(json))
                    .toList();
          });
        } else {
          _error =
              data['message'] ?? 'Erreur lors du chargement des commandes.';
        }
      } else {
        _error =
            'Échec de la récupération des commandes (Code: ${response.statusCode}).';
      }
    } on SocketException {
      _error =
          'Erreur de connexion : L\'API est inaccessible ou l\'URL est incorrecte. (Vérifiez si l\'API PHP est active).';
    } catch (e) {
      _error = 'Erreur inattendue : $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 2. Mettre à jour le statut d'une commande (PUT)
  Future<void> _updateOrderStatus(int commandeId, String nouveauStatut) async {
    // Afficher une barre de progression locale (dans le corps)
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'commande_id': commandeId, 'statut': nouveauStatut}),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        _showSnackbar(result['message'], isError: false);
        // Rafraîchir la liste après une mise à jour réussie
        await _fetchOrders();
      } else {
        _showSnackbar(
          result['message'] ?? 'Échec de la mise à jour.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Erreur de connexion lors de la mise à jour.',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- UI ET RENDU ---

  void _showSnackbar(String message, {bool isError = false}) {
    // S'assurer que le Scaffold est disponible via le context
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En attente':
        return Colors.yellow.shade700;
      case 'En préparation':
        return Colors.blue.shade700;
      case 'En livraison':
        return Colors.indigo.shade700;
      case 'Livrée':
        return Colors.green.shade700;
      case 'Annulée':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildOrderCard(Commande commande, int index) {
    // Utiliser un StatefulWidget local pour gérer la sélection du statut sans setState global
    // Cependant, dans ce cas précis, on gère la modification du statut via le modèle Commande (commande.statut)
    // et on appelle setState sur la page parente si le statut est mis à jour localement.

    // Garder une référence locale pour le statut avant la mise à jour
    String currentSelectedStatus = commande.statut;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getStatusColor(commande.statut), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête et total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Commande #${commande.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${commande.total.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: _getStatusColor(commande.statut),
                  ),
                ),
              ],
            ),
            const Divider(height: 10, thickness: 1),

            // Infos de base
            Text(
              'Utilisateur ID: ${commande.userId}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${commande.date.split(' ')[0]} à ${commande.date.split(' ')[1]}', // Formattage simple de la date
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Détails des plats
            const Text(
              'Plats commandés:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 4, bottom: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Text(
                // Remplace ' | ' par des retours à la ligne pour une meilleure lisibilité
                commande.platsDetails.replaceAll(' | ', '\n'),
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),

            // Mise à jour du statut
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Key pour forcer la mise à jour du Dropdown quand la liste est rechargée
                    key: ValueKey('${commande.id}-${commande.statut}'),
                    value: commande.statut,
                    decoration: InputDecoration(
                      labelText: 'Statut Actuel',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                      labelStyle: TextStyle(
                        color: _getStatusColor(commande.statut),
                      ),
                    ),
                    items:
                        statusOptions.map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        // Mise à jour du statut dans le modèle de données local
                        // pour l'afficher avant l'appel API
                        currentSelectedStatus = newValue;
                        commande.statut = newValue;
                        setState(
                          () {},
                        ); // Rafraîchir pour mettre à jour l'UI locale
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Utiliser le statut potentiellement mis à jour localement
                    _updateOrderStatus(commande.id, currentSelectedStatus);
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commandes'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _fetchOrders,
          ),
        ],
      ),
      body:
          _isLoading && _commandes.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 60),
                      const SizedBox(height: 15),
                      Text(
                        'Erreur de Connexion: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _fetchOrders,
                        icon: const Icon(Icons.replay),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
              : _commandes.isEmpty
              ? const Center(
                child: Text(
                  'Aucune commande en cours.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const LinearProgressIndicator(color: Colors.indigo),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _commandes.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(_commandes[index], index);
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
