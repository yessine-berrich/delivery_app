import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../globals.dart' as globals; // Assurez-vous que ce fichier existe

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

  // Contrôleur pour le champ de saisie de l'adresse de livraison dans le dialogue de commande
  final TextEditingController _addressController = TextEditingController();

  // Flag pour s'assurer que l'initialisation des données de l'utilisateur ne se fait qu'une seule fois
  bool _isDataInitialized = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialisation unique des données dépendant du contexte (comme les arguments de route)
    if (!_isDataInitialized) {
      _initializeData();
    }
  }

  // Méthode pour centraliser la logique d'initialisation
  void _initializeData() {
    _isDataInitialized = true;
    final userId = ModalRoute.of(context)?.settings.arguments as int?;

    if (userId != null) {
      _currentUserId = userId;
      _fetchCart();
    } else {
      // Si l'ID utilisateur est manquant, on ne peut pas charger le panier
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

          // Calculer le total en utilisant 'sous_total'
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
          // Panier vide ou API retourne un succès sans données
          setState(() {
            _isLoading = false;
            _cartItems = [];
          });
          // Note : Pas besoin de 'throw Exception' si le panier est simplement vide
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

    // Si la nouvelle quantité est 0 ou moins, on appelle la suppression
    if (newQuantity <= 0) {
      _deleteItem(platId);
      return;
    }

    // Trouver l'index de l'article pour la mise à jour optimiste
    final index = _cartItems.indexWhere(
      (item) => int.tryParse(item['plat_id']?.toString() ?? '0') == platId,
    );
    if (index == -1) return;

    // Sauvegarder l'ancienne quantité et l'ancien sous-total en cas d'échec
    final oldItem = Map<String, dynamic>.from(_cartItems[index]);

    // Optimistic UI update: mettre à jour la quantité localement
    setState(() {
      _cartItems[index]['quantite'] = newQuantity.toString();
      // On ne met pas à jour le sous-total ici, on attend la resynchronisation
      // pour que le calcul soit exact et basé sur le serveur.
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
        // Succès: resynchroniser pour obtenir le total et le sous-total exacts
        _fetchCart();
      } else {
        // Annuler l'optimistic update en cas d'erreur
        if (mounted) {
          setState(() {
            _cartItems[index] = oldItem;
          });
        }
        throw Exception(data['message'] ?? "Erreur lors de la mise à jour.");
      }
    } catch (e) {
      // Annuler l'optimistic update en cas d'échec de l'appel HTTP
      if (mounted) {
        setState(() {
          _cartItems[index] = oldItem;
        });
      }
      _showPopUp(
        'Erreur de Mise à Jour',
        e.toString().replaceFirst('Exception: ', ''),
        Colors.red,
      );
      // Recharger pour synchroniser l'état réel du serveur
      _fetchCart();
    }
  }

  // --------------------------------------------------------------------------
  // 3. DELETE : Supprimer un article
  // --------------------------------------------------------------------------
  Future<void> _deleteItem(int platId) async {
    if (_currentUserId == null || platId == 0) return;

    // Demander confirmation avant suppression
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
    final index = _cartItems.indexWhere(
      (item) => int.tryParse(item['plat_id']?.toString() ?? '0') == platId,
    );
    // Copie de l'élément avant suppression optimiste
    final Map<String, dynamic>? deletedItem =
        index != -1 ? Map<String, dynamic>.from(_cartItems[index]) : null;

    // Mettre à jour l'UI de manière optimiste
    if (deletedItem != null) {
      setState(() {
        _cartItems.removeAt(index);
      });
    }

    try {
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
        _fetchCart(); // Recharger le panier pour mettre à jour le total
      } else {
        // Annuler l'optimistic update en cas d'erreur
        if (deletedItem != null && mounted) {
          setState(() {
            _cartItems.insert(index, deletedItem);
          });
        }
        throw Exception(data['message'] ?? "Erreur lors de la suppression.");
      }
    } catch (e) {
      // Annuler l'optimistic update en cas d'échec de l'appel HTTP
      if (deletedItem != null && mounted) {
        setState(() {
          _cartItems.insert(index, deletedItem);
        });
      }
      _showPopUp(
        'Erreur de Suppression',
        e.toString().replaceFirst('Exception: ', ''),
        Colors.red,
      );
      _fetchCart(); // Recharger pour synchroniser l'état réel du serveur
    }
  }

  // --------------------------------------------------------------------------
  // 4. CREATE (Commande) : Passer la commande
  // --------------------------------------------------------------------------
  Future<void> _checkout() async {
    if (_currentUserId == null || _cartItems.isEmpty || _isLoading) return;

    // Réinitialiser le contrôleur d'adresse à chaque ouverture
    _addressController.clear();

    // Afficher le dialogue de confirmation AVEC champ de saisie d'adresse
    final String? deliveryAddress = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Passer la Commande'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Confirmez-vous la commande pour un total de ${_totalAmount.toStringAsFixed(2)} € ?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text('Veuillez saisir l\'adresse de livraison:'),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Adresse de Livraison',
                    hintText: 'Ex: 12 Rue de la Liberté, 75001 Paris',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  keyboardType: TextInputType.streetAddress,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, null); // Retourne null si annulé
              },
              child: const Text('Annuler'),
            ),
            // Utiliser Builder pour gérer la validation et le SnackBar
            Builder(
              builder:
                  (innerContext) => ElevatedButton(
                    onPressed: () {
                      final address = _addressController.text.trim();
                      if (address.isEmpty) {
                        // Afficher un SnackBar pour l'erreur de validation
                        ScaffoldMessenger.of(innerContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'L\'adresse de livraison est obligatoire.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {
                        // Ferme le dialogue et retourne l'adresse
                        Navigator.pop(context, address);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Confirmer & Payer'),
                  ),
            ),
          ],
        );
      },
    );

    if (deliveryAddress == null || deliveryAddress.isEmpty) {
      // L'utilisateur a annulé ou n'a pas réussi la validation d'adresse
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      }); // Afficher le loader pendant le checkout
    }

    // Envoi de l'ID utilisateur ET l'adresse à commande_api.php pour finaliser
    var url = Uri.parse("${globals.baseUrl}commande_api.php");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "user_id": _currentUserId,
          "adresse_livraison": deliveryAddress,
        }),
      );

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == 'success') {
        _showPopUp(
          'Commande Passée!',
          data['message'] ??
              'Votre commande a été enregistrée à l\'adresse: $deliveryAddress.',
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        }); // Arrêter le loader
      }
      // Le contrôleur est clair à la fin du dialogue, mais on le vide à nouveau
      // pour s'assurer qu'il est prêt pour la prochaine tentative si nécessaire.
      _addressController.clear();
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            leading: const Icon(Icons.fastfood, color: Colors.deepOrange),
            title: Text(
              nom,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prix Unitaire: ${prixUnitaire.toStringAsFixed(2)} €',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  'Sous-total: ${(prixUnitaire * quantite).toStringAsFixed(2)} €',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton de décrémentation
                IconButton(
                  icon: const Icon(Icons.remove, size: 20, color: Colors.red),
                  onPressed: () => _updateQuantity(platId, quantite - 1),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$quantite',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Bouton d'incrémentation
                IconButton(
                  icon: const Icon(Icons.add, size: 20, color: Colors.green),
                  onPressed: () => _updateQuantity(platId, quantite + 1),
                ),
                // Bouton de suppression directe (X)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
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
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
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
                  fontSize: 22,
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
                  Theme.of(context).primaryColor, // Couleur primaire
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 5,
            ),
          ),
        ],
      ),
    );
  }
}
