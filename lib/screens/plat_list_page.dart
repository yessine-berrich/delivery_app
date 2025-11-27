import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../globals.dart' as globals;

// ----------------------------------------------------
// 1. MODÈLE DE DONNÉES (MATCH PHP)
// ----------------------------------------------------
class Plat {
  final String id; // plat_id
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final String? image; // URL ou chemin de l'image

  Plat({
    required this.id,
    required this.nom,
    required this.description,
    required this.prix,
    required this.categorie,
    required this.image,
  });

  // Factory constructor pour créer un Plat à partir d'un map JSON
  factory Plat.fromJson(Map<String, dynamic> json) {
    return Plat(
      id: json['plat_id']?.toString() ?? '',
      nom: json['nom'] ?? 'Nom Inconnu',
      description: json['description'] ?? '',
      prix: double.tryParse(json['prix']?.toString() ?? '0.0') ?? 0.0,
      categorie: json['categorie'] ?? 'Divers',
      image: json['image'] ?? null,
    );
  }
}

// ----------------------------------------------------
// 2. WIDGET D'ÉTAT
// ----------------------------------------------------
class PlatListPage extends StatefulWidget {
  const PlatListPage({super.key});

  @override
  State<PlatListPage> createState() => _PlatListPageState();
}

class _PlatListPageState extends State<PlatListPage> {
  List<Plat> _plats = [];
  bool _isLoading = true;
  String? _error;

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}plat_api.php");

  @override
  void initState() {
    super.initState();
    _fetchPlats();
  }

  // --- LOGIQUE DE CHARGEMENT ---
  Future<void> _fetchPlats() async {
    setState(() {
      if (_plats.isEmpty) _isLoading = true; // Afficher le loader initial
      _error = null;
    });

    try {
      final response = await http.get(_apiUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (responseBody['status'] == 'success' &&
            responseBody['data'] is List) {
          final List data = responseBody['data'];
          setState(() {
            _plats = data.map((item) => Plat.fromJson(item)).toList();
          });
        } else {
          setState(() {
            _error = responseBody['message'] ??
                'Erreur inconnue lors du chargement des données.';
          });
        }
      } else {
        setState(() {
          _error = 'Échec du chargement. Statut: ${response.statusCode}';
        });
      }
    } on SocketException {
      setState(() {
        _error =
            'Erreur de connexion réseau. Vérifiez que l\'API PHP est accessible.';
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur inattendue : $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- LOGIQUE DE SUPPRESSION ---
  Future<void> _deletePlat(String id) async {
    // 1. Afficher la boîte de dialogue de confirmation
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Text('Confirmer la suppression',
              style: TextStyle(color: Colors.red)),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer définitivement ce plat ?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      // 2. Supprimer via API
      try {
        final response = await http.delete(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'plat_id': id}),
        );

        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (response.statusCode == 200 && responseBody['status'] == 'success') {
          // Mise à jour de l'UI locale immédiatement avant le rafraîchissement
          setState(() {
            _plats.removeWhere((plat) => plat.id == id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['message'] ?? 'Plat supprimé avec succès.',
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur de suppression: ${responseBody['message'] ?? 'Erreur inconnue'}',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion lors de la suppression: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } else {
      // Si l'utilisateur annule, assurez-vous que la carte ne disparaît pas
      _fetchPlats(); 
    }
  }

  // --- LOGIQUE DE MODIFICATION ET D'AJOUT (Navigation) ---
  void _editPlat(Plat? plat) {
    final Plat platToPass = plat ??
        Plat(
            id: '',
            nom: '',
            description: '',
            prix: 0.0,
            categorie: '',
            image: null);

    // Naviguer vers la page de formulaire
    Navigator.pushNamed(context, '/plat_form', arguments: platToPass).then((
      result,
    ) {
      // Si le formulaire revient avec 'true', on rafraîchit la liste
      if (result == true) {
        _fetchPlats();
      }
    });
  }

  // --- WIDGET DE CARTE (DESIGN) ---
  Widget _buildPlatCard(Plat plat) {
    // Construction de l'URL de l'image
    final imageUrl =
        plat.image != null ? "${globals.baseUrl}uploads/${plat.image}" : null;

    return Dismissible(
      key: ValueKey(plat.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        color: Colors.red.shade600,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      confirmDismiss: (direction) async {
        return await _deletePlat(plat.id)
            .then((_) => _plats.any((p) => p.id == plat.id) ? false : true);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: () => _editPlat(plat), // Clic pour modifier
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Image ou Placeholder
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey),
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                          )
                        : const Icon(Icons.fastfood,
                            size: 50, color: Colors.indigo),
                  ),
                ),
                const SizedBox(width: 15),

                // 2. Détails du plat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plat.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plat.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              plat.categorie,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                          ),
                          Text(
                            '${plat.prix.toStringAsFixed(2)} €',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. Boutons d'action (Modifier)
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 24),
                      onPressed: () => _editPlat(plat),
                      tooltip: 'Modifier',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET PRINCIPAL ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Admin'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualiser la liste',
            onPressed: _fetchPlats,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Contenu principal (Chargement, Erreur, Liste)
          _buildBody(),

          // 2. Indicateur de progression linéaire pour les rafraîchissements
          if (_isLoading && _plats.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: Colors.indigo),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editPlat(null),
        label: const Text('Ajouter un plat'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.pink.shade400,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 8,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _plats.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.indigo));
    }

    if (_error != null) {
      return Center(
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
                    color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _fetchPlats,
                icon: const Icon(Icons.replay),
                label: const Text('Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_plats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ramen_dining, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'Aucun plat n\'a été ajouté au menu.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _editPlat(null),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter le premier plat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink.shade400,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Liste des plats
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      itemCount: _plats.length,
      itemBuilder: (context, index) {
        return _buildPlatCard(_plats[index]);
      },
    );
  }
}