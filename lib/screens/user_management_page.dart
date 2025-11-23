import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Configuration de l'API pour la gestion des utilisateurs
// ASSUREZ-VOUS de changer VOTRE_SERVEUR par l'adresse IP correcte (ex: 10.0.2.2 pour Android Emulator)
const String _apiUrl = 'http://192.168.56.1/api_livraison/admin_users_api.php';

// Liste des rôles valides pour le menu déroulant
const List<String> roleOptions = ['client', 'admin'];

// Modèle de données pour un Utilisateur
class Utilisateur {
  final int id;
  final String nom;
  final String email;
  final String adresse;
  String role; // Non final car il peut être mis à jour

  Utilisateur({
    required this.id,
    required this.nom,
    required this.email,
    required this.adresse,
    required this.role,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      id: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      nom: json['nom'] as String? ?? 'N/A',
      email: json['email'] as String? ?? 'N/A',
      adresse: json['adresse'] as String? ?? 'N/A',
      role: json['role'] as String? ?? 'client',
    );
  }
}

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  List<Utilisateur> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // --- LOGIQUE API ---

  // 1. Récupérer tous les utilisateurs (GET)
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          setState(() {
            _users =
                (data['data'] as List)
                    .map((json) => Utilisateur.fromJson(json))
                    .toList();
          });
        } else {
          _error =
              data['message'] ?? 'Erreur lors du chargement des utilisateurs.';
        }
      } else {
        _error =
            'Échec de la récupération des utilisateurs (Code: ${response.statusCode}).';
      }
    } on SocketException {
      _error =
          'Erreur de connexion : L\'API est inaccessible ou l\'URL est incorrecte.';
    } catch (e) {
      _error = 'Erreur inattendue : $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 2. Mettre à jour le rôle d'un utilisateur (PUT)
  Future<void> _updateUserRole(int userId, String nouveauRole) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.put(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'role': nouveauRole}),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        _showSnackbar(result['message'], isError: false);
        await _fetchUsers();
      } else {
        _showSnackbar(
          result['message'] ?? 'Échec de la mise à jour du rôle.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackbar(
        'Erreur de connexion lors de la mise à jour du rôle.',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 3. Supprimer un utilisateur (DELETE)
  Future<void> _deleteUser(int userId, String userName) async {
    // Afficher le dialogue de confirmation AVANT l'appel API
    final bool? confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmation de suppression'),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer l\'utilisateur "$userName" (ID: $userId) ? Cette action est irréversible.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await http.delete(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId}),
        );

        final result = json.decode(response.body);

        if (response.statusCode == 200 && result['status'] == 'success') {
          _showSnackbar(result['message'], isError: false);
          // Rafraîchir la liste après suppression
          await _fetchUsers();
        } else {
          _showSnackbar(
            result['message'] ?? 'Échec de la suppression de l\'utilisateur.',
            isError: true,
          );
        }
      } catch (e) {
        _showSnackbar(
          'Erreur de connexion lors de la suppression.',
          isError: true,
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- UI ET RENDU ---

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Color _getRoleColor(String role) {
    return role == 'admin' ? Colors.red.shade700 : Colors.indigo.shade500;
  }

  Widget _buildUserCard(Utilisateur user) {
    String currentSelectedRole = user.role;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _getRoleColor(user.role), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom et Rôle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  user.role == 'admin' ? Icons.security : Icons.person_outline,
                  color: _getRoleColor(user.role),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user.nom,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.role.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(user.role),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 15, thickness: 1),

            // Email, ID, Adresse
            Text(
              'Email: ${user.email}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'ID: ${user.id}',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              'Adresse: ${user.adresse}',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 15),

            // Gestion du Rôle et Suppression
            Row(
              children: [
                // Dropdown pour le Rôle
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('${user.id}-${user.role}'),
                    value: user.role,
                    decoration: const InputDecoration(
                      labelText: 'Changer le Rôle',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    items:
                        roleOptions.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role,
                              style: TextStyle(
                                color: _getRoleColor(role),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        currentSelectedRole = newValue;
                        user.role = newValue;
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Bouton Modifier le Rôle
                ElevatedButton.icon(
                  onPressed:
                      () => _updateUserRole(user.id, currentSelectedRole),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 5,
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Supprimer l'Utilisateur
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  tooltip: 'Supprimer l\'utilisateur',
                  onPressed: () => _deleteUser(user.id, user.nom),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Utilisateurs'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _fetchUsers,
          ),
        ],
      ),
      body:
          _isLoading && _users.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 60),
                      const SizedBox(height: 15),
                      Text(
                        'Erreur de Connexion: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _fetchUsers,
                        icon: const Icon(Icons.replay),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
              : _users.isEmpty
              ? const Center(
                child: Text(
                  'Aucun utilisateur trouvé.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLoading)
                    const LinearProgressIndicator(color: Colors.indigo),

                  Expanded(
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        return _buildUserCard(_users[index]);
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
