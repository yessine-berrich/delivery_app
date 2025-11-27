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
    // S'assurer que le rôle est en minuscules pour la cohérence
    String roleValue = (json['role'] as String? ?? 'client').toLowerCase();

    // S'assurer que le rôle est dans les options valides, sinon par défaut 'client'
    if (!roleOptions.contains(roleValue)) {
      roleValue = 'client';
    }

    return Utilisateur(
      id: int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      nom: json['nom'] as String? ?? 'N/A',
      email: json['email'] as String? ?? 'N/A',
      adresse: json['adresse'] as String? ?? 'N/A',
      role: roleValue,
    );
  }
}

// ----------------------------------------------------------------------
// WIDGET D'ÉTAT PRINCIPAL
// ----------------------------------------------------------------------
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
    // Ne pas afficher le chargement si ce n'est qu'un rafraîchissement rapide
    if (_users.isEmpty) {
      setState(() => _isLoading = true);
    }
    setState(() => _error = null);

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
          if (_users.isEmpty) {
            _showSnackbar('Liste des utilisateurs vide.', isError: false);
          }
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
          'Erreur de connexion : L\'API est inaccessible (Vérifiez l\'URL et la connexion).';
    } on FormatException {
      _error = 'Erreur de format de réponse de l\'API (JSON invalide).';
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
    // Si l'utilisateur est déjà en train de charger, on ignore
    if (_isLoading) return;

    // Définir le chargement localisé (sur le bouton ou la liste) est préférable
    // Ici on met l'état global pour simplifier.
    setState(() => _isLoading = true);

    try {
      final response = await http.put(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'role': nouveauRole}),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['status'] == 'success') {
        _showSnackbar(
          result['message'] ?? 'Rôle mis à jour avec succès.',
          isError: false,
        );
        // Mise à jour de l'état local pour refléter le changement immédiatement
        final userIndex = _users.indexWhere((u) => u.id == userId);
        if (userIndex != -1) {
          setState(() {
            _users[userIndex].role = nouveauRole;
          });
        }
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
      setState(() => _isLoading = false);
    }
  }

  // 3. Supprimer un utilisateur (DELETE)
  Future<void> _deleteUser(int userId, String userName) async {
    if (_isLoading) return;

    final bool? confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Supprimer $userName ?',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir supprimer cet utilisateur (ID: $userId) ? Cette action est irréversible.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red,
              ),
              child: const Text('Supprimer Définitivement'),
            ),
          ],
        );
      },
    );

    if (confirmation == true) {
      setState(() => _isLoading = true);

      try {
        final response = await http.delete(
          Uri.parse(_apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId}),
        );

        final result = json.decode(response.body);

        if (response.statusCode == 200 && result['status'] == 'success') {
          _showSnackbar(
            result['message'] ?? 'Utilisateur supprimé avec succès.',
            isError: false,
          );
          // Retirer l'utilisateur de la liste sans refetch
          setState(() {
            _users.removeWhere((u) => u.id == userId);
          });
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
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI ET RENDU ---

  void _showSnackbar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor:
              isError ? Colors.red.shade700 : Colors.green.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Définir les couleurs de manière centralisée
  Color _getRoleColor(String role) {
    return role == 'admin' ? Colors.deepOrange.shade600 : Colors.blue.shade600;
  }

  Widget _buildUserCard(Utilisateur user) {
    // Pour garantir l'état du DropdownButtonFormField, on utilise une fonction locale
    // plutôt que de modifier directement l'objet 'user' dans l'itérateur du build.
    String currentSelectedRole = user.role;

    return Card(
      elevation: 4,
      // Design Material 3 avec coins arrondis et bordure colorée par rôle
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: _getRoleColor(user.role).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // LIGNE 1: NOM et BADGE DE RÔLE
            // ----------------------------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    user.nom,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge de Rôle
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(user.role).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
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
            const Divider(height: 20, thickness: 0.5),

            // ----------------------------------------------------
            // LIGNE 2: ID, EMAIL, ADRESSE
            // ----------------------------------------------------
            _buildDetailRow(Icons.email_outlined, user.email),
            _buildDetailRow(Icons.location_on_outlined, user.adresse),
            _buildDetailRow(Icons.fingerprint_rounded, 'ID: ${user.id}'),

            const SizedBox(height: 15),

            // ----------------------------------------------------
            // LIGNE 3: ACTIONS (Dropdown Rôle + Boutons)
            // ----------------------------------------------------
            Row(
              children: [
                // Dropdown pour le Rôle
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // Utiliser une clé pour forcer la reconstruction si le rôle change
                    key: ValueKey('${user.id}-${user.role}'),
                    value: user.role,
                    decoration: InputDecoration(
                      labelText: 'Rôle Actuel',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    items:
                        roleOptions.map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                color: _getRoleColor(role),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      // Mettre à jour la variable temporaire et l'état de l'utilisateur
                      if (newValue != null) {
                        currentSelectedRole = newValue;
                        user.role =
                            newValue; // On met à jour l'objet pour refléter le choix dans l'UI
                        setState(() {});
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Bouton Modifier le Rôle
                Tooltip(
                  message: 'Appliquer le rôle sélectionné',
                  child: FilledButton.icon(
                    onPressed: () {
                      // Ne pas appeler si le rôle n'a pas changé
                      if (user.role != currentSelectedRole) {
                        _updateUserRole(user.id, currentSelectedRole);
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Appliquer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Bouton Supprimer l'Utilisateur
                Tooltip(
                  message: 'Supprimer définitivement l\'utilisateur',
                  child: IconButton.filledTonal(
                    icon: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.red,
                    ),
                    onPressed: () => _deleteUser(user.id, user.nom),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget utilitaire pour les lignes de détails
  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Utilisateurs',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 10,
        shadowColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser la liste',
            onPressed: _isLoading ? null : _fetchUsers,
          ),
        ],
      ),
      body: _buildBodyContent(),
    );
  }

  Widget _buildBodyContent() {
    // État de chargement initial ou complet
    if (_isLoading && _users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.indigo),
            const SizedBox(height: 15),
            Text(
              'Chargement des données utilisateurs...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // État d'erreur
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 70,
              ),
              const SizedBox(height: 20),
              Text(
                'Problème de connexion ou d\'API : $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _fetchUsers,
                icon: const Icon(Icons.cached_rounded),
                label: const Text('Réessayer la Connexion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // État de liste vide (pas d'erreur, mais pas de données)
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_alt_outlined,
              color: Colors.indigo,
              size: 70,
            ),
            const SizedBox(height: 15),
            Text(
              'Aucun utilisateur à gérer pour le moment.',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
            ),
          ],
        ),
      );
    }

    // État normal (Liste des utilisateurs)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicateur de chargement linéaire pour les rafraîchissements
        if (_isLoading) const LinearProgressIndicator(color: Colors.indigo),

        Expanded(
          child: ListView.builder(
            itemCount: _users.length,
            itemBuilder: (context, index) {
              return _buildUserCard(_users[index]);
            },
          ),
        ),
      ],
    );
  }
}
