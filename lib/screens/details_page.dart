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
      _showPopUp('Erreur', 'Veuillez vous connecter pour ajouter cet article au panier.', Colors.red);
      return;
    }
    
    setState(() {
      _isAddingToCart = true;
    });

    final int platId = int.tryParse(_plat!['plat_id']?.toString() ?? '') ?? 0;
    final String platNom = _plat!['nom'] ?? 'Article inconnu';
    const int quantite = 1; 

    if (platId == 0) {
      _showPopUp('Erreur', 'ID de plat invalide.', Colors.red);
      setState(() { _isAddingToCart = false; });
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
            Colors.green
        );
      } else {
        throw Exception(data['message'] ?? "Erreur lors de l'ajout au panier.");
      }
    } catch (e) {
      _showPopUp(
          'Erreur d\'ajout', 
          e.toString().replaceFirst('Exception: ', ''), 
          Colors.red
      );
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
          title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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
    if (_plat == null || _currentUserId == null) {
      // Afficher un message d'erreur si l'ID utilisateur ou le plat manque
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
                const Text('Erreur: Session ou détails du plat manquants.', 
                    style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                // Bouton pour forcer le retour à l'accueil
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false),
                  child: const Text('Retour à l\'Accueil'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Récupération sécurisée des données du plat (maintenant que _plat n'est pas null)
    final String nom = _plat!['nom'] ?? 'Nom inconnu';
    final String description = _plat!['description'] ?? 'Aucune description fournie.';
    final String categorie = _plat!['categorie'] ?? 'N/A';
    final double prix = double.tryParse(_plat!['prix']?.toString() ?? '0.0') ?? 0.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(nom),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image/Icône
            Center(
              child: Icon(
                Icons.restaurant_menu,
                size: 150,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 30),

            // Nom du Plat
            Text(
              nom,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Prix
            Text(
              '${prix.toStringAsFixed(2)} €',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.green.shade700,
              ),
            ),
            const Divider(height: 30, thickness: 2),

            // Catégorie
            _buildDetailRow(
              icon: Icons.category,
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
            const SizedBox(height: 30),

            // NOUVEAU BOUTON : AJOUTER AU PANIER
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAddingToCart ? null : _addToCart,
                icon: _isAddingToCart 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) 
                    : const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: Text(
                  _isAddingToCart ? 'Ajout en cours...' : 'Ajouter au Panier', 
                  style: const TextStyle(fontSize: 18)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 18),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}