import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../globals.dart' as globals;

// ----------------------------------------------------
// 1. MODÈLE DE DONNÉES UTILISATEUR (MATCH PHP)
// ----------------------------------------------------
class User {
  final String id; // user_id
  final String nom;
  final String email;
  final String role; // e.g., 'Admin', 'Client'

  User({
    required this.id,
    required this.nom,
    required this.email,
    required this.role,
  });

  // Factory constructor pour créer un User à partir d'un map JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id:
          json['user_id']?.toString() ??
          '', // Convertit l'ID en String, ou vide si null
      nom: json['nom'] ?? 'Nom Inconnu',
      email: json['email'] ?? 'email@inconnu.com',
      role: json['role'] ?? 'Client',
    );
  }
}

// ----------------------------------------------------
// 2. WIDGET D'ÉTAT
// ----------------------------------------------------
class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;

  final Uri _apiUrl = Uri.parse("${globals.baseUrl}user_api.php");

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // --- LOGIQUE DE CHARGEMENT (GET) ---
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
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
            _users = data.map((item) => User.fromJson(item)).toList();
          });
        } else {
          setState(() {
            _error =
                responseBody['message'] ??
                'Erreur inconnue lors du chargement des données.';
          });
        }
      } else {
        setState(() {
          _error = 'Échec du chargement. Statut: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion : $e';
      });
      debugPrint('Erreur lors du fetch: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- LOGIQUE DE SUPPRESSION (DELETE) ---
  Future<void> _deleteUser(String id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer cet utilisateur ? Cette action est irréversible.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        final response = await http.delete(
          _apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': id}),
        );

        final Map<String, dynamic> responseBody = json.decode(response.body);

        if (response.statusCode == 200 && responseBody['status'] == 'success') {
          // Afficher le message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody['message'] ?? 'Utilisateur supprimé avec succès.',
              ),
            ),
          );
          _fetchUsers(); // Rafraîchir la liste après suppression
        } else {
          // Afficher le message d'erreur de l'API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur de suppression: ${response.statusCode} - ${responseBody['message']}',
              ),
            ),
          );
        }
      } catch (e) {
        // Erreur de connexion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion lors de la suppression: $e'),
          ),
        );
      }
    }
  }

  // --- LOGIQUE DE MODIFICATION ET D'AJOUT (Navigation) ---
  void _editUser(User? user) {
    // Crée un objet User par défaut si user est null (pour un ajout)
    final User userToPass =
        user ?? User(id: '', nom: '', email: '', role: 'Client');

    Navigator.pushNamed(context, '/user_form', arguments: userToPass).then((
      result,
    ) {
      // Si le formulaire revient avec 'true', on rafraîchit la liste
      if (result == true) {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Utilisateur ${user == null ? "ajouté" : "mis à jour"} avec succès. Actualisation de la liste.',
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste et Gestion des Utilisateurs'),
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
            tooltip: 'Ajouter un nouvel utilisateur',
            onPressed:
                () => _editUser(null), // Appel sans argument pour l'ajout
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualiser la liste',
            onPressed: _fetchUsers,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 10),
              Text('Erreur: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchUsers,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Text('Aucun utilisateur disponible pour le moment.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          elevation: 3,
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.blueGrey),
            title: Text(
              user.nom,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${user.email} | Rôle: ${user.role}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouton Modifier
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editUser(user),
                  tooltip: 'Modifier',
                ),
                // Bouton Supprimer
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteUser(user.id),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
