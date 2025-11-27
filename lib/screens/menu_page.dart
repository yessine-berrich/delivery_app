import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  // Définition des couleurs pour la cohérence du thème
  static const Color primaryColor = Color(0xFF1E88E5); // Blue 600
  static const Color accentColor = Color(0xFF4FC3F7); // Light Blue 300
  static const Color priceColor = Color(0xFF43A047); // Green 600

  List<Map<String, dynamic>> _plats = [];
  bool _isLoading = true;
  int? _currentUserId; // ID de l'utilisateur connecté, essentiel pour le Panier

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Récupération de l'ID utilisateur passé par LoginPage (via la route /menu)
    final args = ModalRoute.of(context)?.settings.arguments;

    // Tentative de récupération de l'ID, qu'il soit dans un Map ou directement l'entier.
    if (args is Map<String, dynamic> && args.containsKey('userId')) {
      // S'assurer que 'userId' est bien un int ou peut être converti
      final dynamic userIdValue = args['userId'];
      if (userIdValue is int) {
        _currentUserId = userIdValue;
      } else if (userIdValue is String) {
        _currentUserId = int.tryParse(userIdValue);
      }
    } else if (args is int) {
      _currentUserId = args;
    }

    // Si un ID valide est trouvé et que le menu n'est pas encore chargé, on le charge.
    if (_currentUserId != null && _plats.isEmpty) {
      _fetchMenu();
    }
  }

  // Fonction de déconnexion ajoutée
  void _logout() {
    setState(() {
      _currentUserId = null;
    });
    // Retourne à la page d'accueil (HomePage) et supprime toutes les routes précédentes
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (Route<dynamic> route) => false,
    );
  }

  // --------------------------------------------------------------------------
  // LECTURE : Récupérer les plats depuis l'API (CRUD Read)
  // --------------------------------------------------------------------------
  Future<void> _fetchMenu() async {
    setState(() {
      _isLoading = true;
    });

    var url = Uri.parse("${globals.baseUrl}plat_api.php");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'success' && data['data'] is List) {
          setState(() {
            _plats =
                (data['data'] as List)
                    .map((item) => item as Map<String, dynamic>)
                    .toList();
          });
        } else {
          _showPopUp(
            'Erreur',
            data['message'] ?? 'Erreur lors du chargement des données.',
          );
        }
      } else {
        throw Exception(
          'Erreur de connexion au serveur (Code: ${response.statusCode})',
        );
      }
    } catch (e) {
      _showPopUp(
        'Erreur de réseau',
        'Impossible de se connecter à l\'API: $e',
        Colors.red,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --------------------------------------------------------------------------
  // CRÉATION : Ajouter un plat au panier (CRUD Create)
  // --------------------------------------------------------------------------
  Future<void> _addToCart(Map<String, dynamic> plat) async {
    if (_currentUserId == null) {
      _showPopUp(
        'Erreur de session',
        'Veuillez vous reconnecter pour ajouter un article.',
        Colors.red,
      );
      return;
    }

    final int platId = int.tryParse(plat['plat_id']?.toString() ?? '') ?? 0;
    final String platNom = plat['nom'] ?? 'Article inconnu';

    if (platId == 0) {
      _showPopUp('Erreur', 'ID de plat invalide.', Colors.red);
      return;
    }

    var url = Uri.parse("${globals.baseUrl}panier_api.php");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_id": _currentUserId,
          "plat_id": platId,
          "quantite": 1, // Ajout d'une seule unité
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _showPopUp(
          'Ajouté au Panier',
          '$platNom a été ajouté(e) à votre panier !',
          Colors.green,
        );
      } else {
        _showPopUp(
          'Erreur d\'ajout',
          data['message'] ?? "Échec de l'ajout au panier.",
          Colors.red,
        );
      }
    } catch (e) {
      _showPopUp(
        'Erreur de réseau',
        'Impossible d\'ajouter au panier. Vérifiez votre connexion.',
        Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // Utilitaire : Fenêtre Pop-up (Améliorée)
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, [Color? color]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: color ?? primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: primaryColor)),
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
        automaticallyImplyLeading: false,
        title: const Text(
          'Catalogue des Plats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          // Bouton Panier
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Mon Panier',
            onPressed: () {
              // Navigation vers le panier, on passe l'ID utilisateur
              Navigator.pushNamed(context, '/cart', arguments: _currentUserId);
            },
          ),
          // Bouton Historique
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Historique des Commandes',
            onPressed: () {
              // Navigation vers l'historique, on passe l'ID utilisateur
              Navigator.pushNamed(
                context,
                '/history',
                arguments: _currentUserId,
              );
            },
          ),
          // Bouton de Déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentUserId == null) {
      // Message si l'ID utilisateur manque (sécurité)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 60, color: Colors.redAccent),
              const SizedBox(height: 20),
              const Text(
                'Session expirée ou non démarrée. Veuillez vous connecter pour voir le menu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed:
                    _logout, // Force la déconnexion et redirection vers /home
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Se Connecter',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    if (_plats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'Aucun plat disponible pour le moment.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Affichage des plats avec des Cards modernes
    return RefreshIndicator(
      onRefresh: _fetchMenu,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: _plats.length,
        itemBuilder: (context, index) {
          final plat = _plats[index];
          final String nom = plat['nom'] ?? 'Plat inconnu';
          final String description =
              plat['description'] ?? 'Description non disponible.';
          final double prix =
              double.tryParse(plat['prix']?.toString() ?? '0.0') ?? 0.0;
          final String? imageFileName = plat['image'];

          // Construction de l'URL de l'image (à adapter si l'IP change !)
          final String imageUrl =
              imageFileName != null && imageFileName.isNotEmpty
                  ? "${globals.baseUrl}uploads/$imageFileName"
                  : "https://placehold.co/100x100/A0A0A0/FFFFFF?text=Plat";

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  // Navigation vers les détails du plat
                  Navigator.pushNamed(
                    context,
                    '/details',
                    arguments: {
                      'plat': plat,
                      'userId': _currentUserId, // ARGUMENT CRUCIAL
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image du plat
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 15),

                      // Détails du plat
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Prix et Bouton d'ajout
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${prix.toStringAsFixed(2)} €',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: priceColor,
                                    fontSize: 18,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_shopping_cart,
                                    color: primaryColor,
                                  ),
                                  tooltip: 'Ajouter au Panier',
                                  onPressed: () => _addToCart(plat),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
