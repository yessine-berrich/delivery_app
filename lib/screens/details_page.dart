import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class DetailsPage extends StatefulWidget {
  const DetailsPage({super.key});

  @override
  State<DetailsPage> createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Map<String, dynamic>? _plat;
  int? _currentUserId; // ID utilisateur réel passé par la MenuPage
  bool _isAddingToCart = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Récupérer les arguments passés par MenuPage
    final args = ModalRoute.of(context)?.settings.arguments;

    // On s'attend à recevoir un Map contenant 'plat' et 'userId'
    if (args is Map<String, dynamic>) {
      _plat = args['plat'] as Map<String, dynamic>?;
      // L'ID est maintenant correctement récupéré
      _currentUserId = args['userId'] as int?;
    }
  }

  // --------------------------------------------------------------------------
  // 1. CREATE : Ajouter un plat au panier (CRUD)
  // --------------------------------------------------------------------------
  Future<void> _addToCart() async {
    // VÉRIFICATION CRUCIALE : L'utilisateur doit être authentifié et le plat doit exister
    if (_plat == null || _currentUserId == null) {
      _showPopUp(
        'Erreur',
        'Veuillez vous connecter pour ajouter cet article au panier.',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isAddingToCart = true;
    });

    // S'assurer que plat_id est un entier valide
    final int platId = int.tryParse(_plat!['plat_id']?.toString() ?? '') ?? 0;
    final String platNom = _plat!['nom'] ?? 'Article inconnu';
    const int quantite = 1;

    if (platId == 0) {
      _showPopUp('Erreur', 'ID de plat invalide.', Colors.red);
      setState(() {
        _isAddingToCart = false;
      });
      return;
    }

    var url = Uri.parse("${globals.baseUrl}panier_api.php");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_id": _currentUserId, // Utilisation de l'ID utilisateur réel
          "plat_id": platId,
          "quantite": quantite,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _showPopUp(
          'Ajouté au Panier',
          '$platNom a été ajouté(e) à votre panier. Vous pouvez le retrouver dans l\'onglet Panier.',
          Colors.green,
        );
      } else {
        // Gérer les erreurs de l'API (e.g., plat déjà dans le panier, stock insuffisant)
        final String errorMessage =
            data['message'] ?? "Erreur lors de l'ajout au panier.";
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Gérer les erreurs de connexion HTTP ou autres exceptions
      String cleanMessage =
          e.toString().contains('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : "Connexion impossible. Vérifiez l'URL de l'API.";

      _showPopUp('Erreur d\'ajout', cleanMessage, Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  // --------------------------------------------------------------------------
  // Fenêtre Pop-up (Utilitaire)
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, Color color) {
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
    // Écran d'erreur de base si les arguments sont manquants
    if (_plat == null || _currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détails')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.red),
                const SizedBox(height: 10),
                const Text(
                  'Erreur: Session ou détails du plat manquants. Redirection nécessaire.',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context), // Retour simple
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Récupération sécurisée des données du plat (maintenant que _plat n'est pas null)
    final String nom = _plat!['nom'] ?? 'Nom inconnu';
    final String description =
        _plat!['description'] ?? 'Aucune description fournie.';
    final String categorie = _plat!['categorie'] ?? 'N/A';
    final double prix =
        double.tryParse(_plat!['prix']?.toString() ?? '0.0') ?? 0.0;
    final String imageName = _plat!['image'] ?? '';
    final String _fullImageUrl =
        imageName.isNotEmpty ? "${globals.baseUrl}uploads/$imageName" : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
        backgroundColor: Colors.blueAccent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image/Icône avec gestion des erreurs
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Container(
                  width: double.infinity,
                  height: 250,
                  color: Colors.grey.shade200,
                  child:
                      _fullImageUrl.isNotEmpty
                          ? Image.network(
                            _fullImageUrl,
                            height: 250,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // En cas d'échec du chargement, affichez une icône de plat par défaut.
                              return Icon(
                                Icons.fastfood,
                                size: 100,
                                color: Colors.grey.shade500,
                              );
                            },
                          )
                          : Icon(
                            Icons.fastfood,
                            size: 100,
                            color: Colors.grey.shade500,
                          ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Nom du Plat
            Text(
              nom,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Prix
            Text(
              '${prix.toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(height: 30, thickness: 2, color: Colors.blueGrey),

            // Catégorie
            _buildDetailRow(
              icon: Icons.label_important_outline,
              label: 'Catégorie',
              value: categorie,
            ),
            const SizedBox(height: 15),

            // Description
            const Text(
              'Description du Plat :',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 40),

            // Bouton AJOUTER AU PANIER
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAddingToCart ? null : _addToCart,
                icon:
                    _isAddingToCart
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                        ),
                label: Text(
                  _isAddingToCart ? 'Ajout en cours...' : 'Ajouter au Panier',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Bouton de retour
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
                label: const Text('Retour au Menu'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(color: Colors.blueAccent.shade200, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour afficher les détails en ligne
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color iconColor = Colors.blueAccent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 18))),
      ],
    );
  }
}
