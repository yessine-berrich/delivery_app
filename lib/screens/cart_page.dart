import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals;

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int? _currentUserId;
  double _totalAmount = 0.0;
  bool _didInit =
      false; // Flag pour s'assurer que l'initialisation ne se fait qu'une fois

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Récupérer l'ID utilisateur passé par ModalRoute
    final userId = ModalRoute.of(context)?.settings.arguments as int?;

    if (!_didInit && userId != null) {
      _currentUserId = userId;
      _didInit = true;
      _fetchCart();
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
  // 1. READ : Récupérer le contenu du panier
  // --------------------------------------------------------------------------
  Future<void> _fetchCart() async {
    if (_currentUserId == null) {
      setState(() {
        _errorMessage = 'ID utilisateur manquant.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _totalAmount = 0.0;
      _cartItems = []; // Vider la liste avant un nouvel appel
    });

    var url = Uri.parse(
      "${globals.baseUrl}panier_api.php?user_id=$_currentUserId",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['status'] == 'success' && data['data'] is List) {
          final List<Map<String, dynamic>> items =
              List<Map<String, dynamic>>.from(data['data']);
          double calculatedTotal = 0.0;

          // Calculer le total
          for (var item in items) {
            final double sousTotal =
                double.tryParse(item['sous_total']?.toString() ?? '0.0') ?? 0.0;
            calculatedTotal += sousTotal;
          }

          setState(() {
            _cartItems = items;
            _totalAmount = calculatedTotal;
            _isLoading = false;
          });
        } else {
          // Gérer le cas où le panier est vide (l'API devrait renvoyer une liste vide, mais gérons l'erreur aussi)
          setState(() {
            _isLoading = false;
            _cartItems = [];
          });
          //throw Exception(data['message'] ?? 'Erreur lors du chargement du panier.');
        }
      } else {
        throw Exception('Erreur de serveur: Code ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Erreur de chargement: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
      _showPopUp('Erreur Serveur', _errorMessage, Colors.red);
    }
  }

  // --------------------------------------------------------------------------
  // 2. UPDATE : Modifier la quantité
  // --------------------------------------------------------------------------
  Future<void> _updateQuantity(int platId, int newQuantity) async {
    if (_currentUserId == null || platId == 0) return;

    // Si la nouvelle quantité est 0, on appelle la suppression
    if (newQuantity <= 0) {
      // Nous ne confirmons pas ici, _deleteItem s'en charge.
      _deleteItem(platId);
      return;
    }

    // Mettre à jour l'état local immédiatement pour une meilleure réactivité (Optimistic UI update)
    final index = _cartItems.indexWhere(
      (item) => int.tryParse(item['plat_id']?.toString() ?? '0') == platId,
    );
    if (index != -1) {
      // Sauvegarder l'ancienne quantité en cas d'échec
      final oldQuantity =
          int.tryParse(_cartItems[index]['quantite']?.toString() ?? '1') ?? 1;

      setState(() {
        _cartItems[index]['quantite'] =
            newQuantity.toString(); // Mettre à jour l'affichage
      });

      var url = Uri.parse("${globals.baseUrl}panier_api.php");

      try {
        final response = await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            "user_id": _currentUserId,
            "plat_id": platId,
            "quantite": newQuantity,
          }),
        );

        final Map<String, dynamic> data = jsonDecode(response.body);

        if (response.statusCode == 200 && data['status'] == 'success') {
          _fetchCart(); // Recharger pour mettre à jour le total et le sous_total exacts
        } else {
          // Annuler l'optimistic update en cas d'erreur
          setState(() {
            _cartItems[index]['quantite'] = oldQuantity.toString();
          });
          throw Exception(data['message'] ?? "Erreur lors de la mise à jour.");
        }
      } catch (e) {
        // Annuler l'optimistic update en cas d'échec
        setState(() {
          _cartItems[index]['quantite'] = oldQuantity.toString();
        });
        _showPopUp(
          'Erreur de Mise à Jour',
          e.toString().replaceFirst('Exception: ', ''),
          Colors.red,
        );
        _fetchCart(); // Recharger pour synchroniser
      }
    }
  }

  // --------------------------------------------------------------------------
  // 3. DELETE : Supprimer un article
  // --------------------------------------------------------------------------
  Future<void> _deleteItem(int platId) async {
    if (_currentUserId == null || platId == 0) return;

    // Demander confirmation avant suppression (Exigence Pop-up)
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmation'),
            content: const Text(
              'Voulez-vous vraiment retirer cet article du panier ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirmer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return; // Si l'utilisateur annule

    var url = Uri.parse("${globals.baseUrl}panier_api.php");

    try {
      // Mettre à jour l'UI de manière optimiste pour un feedback rapide
      final index = _cartItems.indexWhere(
        (item) => int.tryParse(item['plat_id']?.toString() ?? '0') == platId,
      );
      final Map<String, dynamic>? deletedItem =
          index != -1 ? _cartItems[index] : null;
      if (deletedItem != null) {
        setState(() {
          _cartItems.removeAt(index);
        });
      }

      final response = await http.delete(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_id": _currentUserId, "plat_id": platId}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _showPopUp(
          'Supprimé',
          'L\'article a été retiré du panier.',
          Colors.green,
        );
        _fetchCart(); // Recharger le panier pour s'assurer que le total est correct
      } else {
        // Annuler l'optimistic update en cas d'erreur
        if (deletedItem != null) {
          setState(() {
            _cartItems.insert(index, deletedItem);
          });
        }
        throw Exception(data['message'] ?? "Erreur lors de la suppression.");
      }
    } catch (e) {
      // Annuler l'optimistic update en cas d'échec
      _showPopUp(
        'Erreur de Suppression',
        e.toString().replaceFirst('Exception: ', ''),
        Colors.red,
      );
      _fetchCart(); // Recharger pour synchroniser
    }
  }

  // --------------------------------------------------------------------------
  // 4. CREATE (Commande) : Passer la commande
  // --------------------------------------------------------------------------
  Future<void> _checkout() async {
    if (_currentUserId == null || _cartItems.isEmpty || _isLoading) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Passer la Commande'),
            content: Text(
              'Confirmez-vous la commande pour un total de ${_totalAmount.toStringAsFixed(2)} € ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirmer',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    }); // Afficher le loader pendant le checkout

    // Envoi de l'ID utilisateur à commande_api.php pour finaliser
    var url = Uri.parse("${globals.baseUrl}commande_api.php");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_id": _currentUserId}),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == 'success') {
        _showPopUp(
          'Commande Passée!',
          data['message'] ??
              'Votre commande a été enregistrée et le panier est vide.',
          Colors.green,
        );
        _fetchCart(); // Le panier doit être vide après la commande
      } else {
        throw Exception(
          data['message'] ?? "Échec de l'enregistrement de la commande.",
        );
      }
    } catch (e) {
      _showPopUp(
        'Erreur de Commande',
        e.toString().replaceFirst('Exception: ', ''),
        Colors.red,
      );
    } finally {
      setState(() {
        _isLoading = false;
      }); // Arrêter le loader
    }
  }

  // --------------------------------------------------------------------------
  // Fenêtre Pop-up (Utilitaire)
  // --------------------------------------------------------------------------
  void _showPopUp(String title, String message, Color color) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Panier'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
      );
    }

    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_basket_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 10),
            const Text(
              'Votre panier est vide.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour au Menu'),
            ),
          ],
        ),
      );
    }

    // Liste des articles du panier
    return ListView.builder(
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        final String nom = item['nom'] ?? 'Article inconnu';
        final double prixUnitaire =
            double.tryParse(item['prix']?.toString() ?? '0.0') ?? 0.0;
        final int quantite =
            int.tryParse(item['quantite']?.toString() ?? '1') ?? 1;
        final int platId =
            int.tryParse(item['plat_id']?.toString() ?? '0') ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.fastfood, color: Colors.blueGrey),
            title: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Prix Unitaire: ${prixUnitaire.toStringAsFixed(2)} €',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton de décrémentation
                IconButton(
                  icon: const Icon(Icons.remove, size: 20),
                  onPressed: () => _updateQuantity(platId, quantite - 1),
                ),
                Text(
                  '$quantite',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Bouton d'incrémentation
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _updateQuantity(platId, quantite + 1),
                ),
                // Bouton de suppression directe (X)
                IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.red,
                  ), // Assurer la couleur rouge
                  onPressed: () => _deleteItem(platId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (_cartItems.isEmpty || _isLoading) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ligne Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total à Payer:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_totalAmount.toStringAsFixed(2)} €',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Bouton Passer la Commande
          ElevatedButton.icon(
            onPressed: _checkout,
            icon: const Icon(Icons.payment, color: Colors.white),
            label: const Text(
              'Passer la Commande',
              style: TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(
                    context,
                  ).primaryColor, // Utiliser la couleur primaire du thème
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
