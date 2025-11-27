import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals; // Assurez-vous que ce fichier existe

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
  bool _didInit =
      false; // Flag pour s'assurer que l'initialisation ne se fait qu'une fois

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
        _errorMessage =
            'ID utilisateur non fourni. Impossible de charger l\'historique.';
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
      if (mounted) {
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
    // Utiliser la couleur primaire du thème si elle est définie, sinon une couleur par défaut
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Commandes'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0, // Enlever l'ombre pour un look plus plat
      ),
      body: _buildBody(primaryColor),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded, // Icône d'erreur plus amicale
                size: 70,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              // Bouton pour réessayer
              ElevatedButton.icon(
                onPressed: _fetchHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer de charger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_commandes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fastfood_outlined,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 15),
            const Text(
              'Aucune commande trouvée.',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'C\'est le moment de vous faire plaisir !',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Naviguer vers la page d'accueil ou de menu
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Explorer le Menu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _commandes.length,
      itemBuilder: (context, index) {
        final commande = _commandes[index];
        final String statut = commande['statut'] ?? 'Inconnu';
        final String id = commande['commande_id']?.toString() ?? 'N/A';
        final double total =
            double.tryParse(commande['total']?.toString() ?? '0.0') ?? 0.0;
        final String address =
            commande['adresse_livraison'] ?? 'Adresse non fournie';
        final String dateFull = commande['date_commande']?.toString() ?? 'N/A';
        final String date =
            dateFull.length >= 10 ? dateFull.substring(0, 10) : dateFull;
        final String details =
            commande['plats_details'] ?? 'Détails non disponibles';

        // Logique de couleur et icône du statut (améliorée)
        Color statusColor;
        IconData statusIcon;
        switch (statut) {
          case 'Livrée':
            statusColor = Colors.green.shade600;
            statusIcon = Icons.check_circle;
            break;
          case 'En attente':
            statusColor = Colors.orange.shade600; // Plus vif que l'ambre
            statusIcon = Icons.access_time_filled;
            break;
          case 'Annulée':
            statusColor = Colors.red.shade600;
            statusIcon = Icons.cancel;
            break;
          case 'En cours':
            statusColor = Colors.blue.shade600;
            statusIcon = Icons.directions_bike;
            break;
          default:
            statusColor = Colors.grey.shade600;
            statusIcon = Icons.help_outline;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: InkWell(
            // Ajouter un effet de ripple pour l'interactivité
            onTap: () {
              // TODO: Afficher les détails complets de la commande (ex: dans un BottomSheet)
            },
            borderRadius: BorderRadius.circular(15),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(
                  color: statusColor.withOpacity(0.3),
                  width: 2,
                ), // Bordure légère
              ),
              elevation: 8, // Ombre plus prononcée pour un effet de profondeur
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : Statut, ID et Date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Statut de la commande (avec icône et fond)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 16, color: statusColor),
                              const SizedBox(width: 6),
                              Text(
                                statut,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ID de la commande
                        Text(
                          '#$id',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Passée le $date',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    const Divider(
                      height: 25,
                      thickness: 1,
                      color: Colors.black12,
                    ),

                    // Ligne 2 : Détails des plats
                    const Text(
                      'Articles Commandés:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Liste des plats (formatage plus lisible)
                    Text(
                      details.replaceAll(' | ', '\n'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),

                    const Divider(
                      height: 25,
                      thickness: 1,
                      color: Colors.black12,
                    ),

                    // Ligne 3 : Adresse et Total (MIS EN BAS)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 15),
                        // Total de la commande (met en évidence le prix)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${total.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
