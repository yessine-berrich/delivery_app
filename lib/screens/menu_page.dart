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
      _currentUserId = args['userId'] as int?;
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
      _showPopUp('Erreur de réseau', 'Impossible de se connecter à l\'API: $e');
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
          '$platNom a été ajouté(e) à votre panier. (${data['message']})',
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
        'Impossible d\'ajouter au panier: $e',
        Colors.red,
      );
    }
  }

  // --------------------------------------------------------------------------
  // Utilitaire : Fenêtre Pop-up
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, [Color? color]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: color ?? Colors.blueAccent,
              fontWeight: FontWeight.bold,
            ),
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
        automaticallyImplyLeading: false,
        title: const Text('Catalogue des Plats'),
        actions: [
          // Bouton Panier
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // Navigation vers le panier, on passe l'ID utilisateur
              Navigator.pushNamed(context, '/cart', arguments: _currentUserId);
            },
          ),
          // Bouton Historique
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Navigation vers l'historique, on passe l'ID utilisateur
              Navigator.pushNamed(
                context,
                '/history',
                arguments: _currentUserId,
              );
            },
          ),
          // NOUVEAU: Bouton de Déconnexion
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: _logout, // Appel de la nouvelle fonction
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentUserId == null) {
      // Message si l'ID utilisateur manque
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 50, color: Colors.red),
            const SizedBox(height: 10),
            const Text(
              'Session expirée. Veuillez vous connecter.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                    (route) => false,
                  ),
              child: const Text('Aller à l\'Accueil'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_plats.isEmpty) {
      return const Center(child: Text('Aucun plat disponible pour le moment.'));
    }

    // Style épuré : Utilisation directe de ListView.builder avec des ListTiles simples
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      itemCount: _plats.length,
      separatorBuilder:
          (context, index) => const Divider(height: 1), // Séparateur subtil
      itemBuilder: (context, index) {
        final plat = _plats[index];
        final String nom = plat['nom'] ?? 'Plat inconnu';
        final String description =
            plat['description'] ?? 'Description non disponible.';
        final double prix =
            double.tryParse(plat['prix']?.toString() ?? '0.0') ?? 0.0;

        return ListTile(
          // Icône pour le visuel
          leading: const Icon(Icons.fastfood, color: Colors.deepOrange),

          title: Text(
            nom,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),

          // Sous-titre avec description courte et prix
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              Text(
                'Prix: ${prix.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          onTap: () {
            // Envoi du Map contenant le plat ET l'ID utilisateur
            Navigator.pushNamed(
              context,
              '/details',
              arguments: {
                'plat': plat,
                'userId': _currentUserId, // ARGUMENT CRUCIAL
              },
            );
          },

          // Bouton d'action: Ajouter au panier
          trailing: IconButton(
            icon: const Icon(Icons.add_shopping_cart, color: Colors.blueAccent),
            onPressed: () => _addToCart(plat),
          ),
        );
      },
    );
  }
}
