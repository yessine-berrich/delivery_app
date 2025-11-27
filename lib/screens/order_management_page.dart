import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Configuration de l'API : Assurez-vous que cette URL est accessible depuis votre appareil/émulateur.
// Utilisez 10.0.2.2 si vous exécutez sur un émulateur Android pointant vers localhost.
// NOTE: L'URL doit être ajustée par l'utilisateur pour correspondre à son environnement (IP locale).
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
  final String address;
  String statut; // Non final car nous le modifions dans l'UI
  final int userId;
  final String platsDetails;

  Commande({
    required this.id,
    required this.date,
    required this.total,
    required this.address,
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
      address: json['adresse_livraison'] as String? ?? 'Adresse non fournie',
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
  // Le statut sélectionné est géré par l'objet Commande lui-même
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
      // Afficher l'indicateur de chargement uniquement si la liste est vide (pour ne pas perturber l'utilisateur)
      if (_commandes.isEmpty) _isLoading = true;
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
    // Afficher une barre de progression locale
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
        _showSnackbar(
          result['message'] ?? 'Statut mis à jour avec succès.',
          isError: false,
        );
        // Rafraîchir la liste après une mise à jour réussie pour recharger le statut du serveur
        await _fetchOrders();
      } else {
        _showSnackbar(
          result['message'] ?? 'Échec de la mise à jour du statut.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Erreur de connexion lors de la mise à jour du statut.',
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
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'En attente':
        return Colors.orange.shade700;
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

  // Crée un badge pour le statut
  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildOrderCard(Commande commande) {
    // Garder une référence locale pour le statut avant la mise à jour
    String currentSelectedStatus = commande.statut;
    final statusColor = _getStatusColor(commande.statut);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        // Bordure qui met en évidence le statut
        side: BorderSide(color: statusColor.withOpacity(0.7), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entête et total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande n°${commande.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _buildStatusBadge(commande.statut, statusColor),
                  ],
                ),
                Text(
                  '${commande.total.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const Divider(height: 25, thickness: 1),

            // Infos de base
            _buildDetailRow(
              icon: Icons.person_outline,
              label: 'Client ID',
              value: '${commande.userId}',
              color: Colors.grey.shade600,
            ),
            _buildDetailRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value:
                  '${commande.date.split(' ')[0]} à ${commande.date.split(' ')[1].substring(0, 5)}',
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 15),

            // Adresse de livraison
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Colors.indigo.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Adresse : ${commande.address}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 15,
                      height: 1.3,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Détails des plats
            const Text(
              'Plats commandés :',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200, width: 1),
              ),
              child: Text(
                // Remplace ' | ' par des retours à la ligne pour une meilleure lisibilité
                commande.platsDetails.replaceAll(' | ', '\n'),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                  fontFamily:
                      'monospace', // Utilisation d'une police plus lisible pour la liste
                ),
                softWrap: true,
              ),
            ),

            // Mise à jour du statut (Barre d'action)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('${commande.id}-${commande.statut}'),
                    value: commande.statut,
                    decoration: InputDecoration(
                      labelText: 'Changer le statut',
                      labelStyle: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: statusColor, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: statusColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    items:
                        statusOptions.map((String status) {
                          final itemColor = _getStatusColor(status);
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status,
                              style: TextStyle(
                                color: itemColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        // Mise à jour du statut dans le modèle de données local
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
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: const Text('Valider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  // Widget utilitaire pour les lignes de détail
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label : ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Commandes'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _fetchOrders,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Gérer les états de chargement, d'erreur et de liste vide
          if (_isLoading && _commandes.isEmpty)
            const Center(child: CircularProgressIndicator(color: Colors.indigo))
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      'Erreur de Connexion :',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _fetchOrders,
                      icon: const Icon(Icons.replay),
                      label: const Text('Réessayer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_commandes.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Aucune commande en attente de traitement.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            // Affichage de la liste des commandes
            ListView.builder(
              itemCount: _commandes.length,
              itemBuilder: (context, index) {
                return _buildOrderCard(_commandes[index]);
              },
            ),

          // Indicateur de progression linéaire pour les mises à jour
          if (_isLoading && _commandes.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: Colors.indigo),
            ),
        ],
      ),
    );
  }
}
