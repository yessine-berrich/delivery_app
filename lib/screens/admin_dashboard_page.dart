import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  // Widget utilitaire pour créer les boutons d'action de l'administrateur
  Widget _buildAdminButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 30, color: Colors.indigo),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.indigo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer l'ID utilisateur passé par la route (si nécessaire)
    // final userId = ModalRoute.of(context)?.settings.arguments;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de Bord Administrateur'),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // En-tête de bienvenue
            Text(
              'Bienvenue Admin',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Gestion complète du Restaurant',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Divider(height: 40, thickness: 2),

            // 1. Bouton : Gestion du Menu
            _buildAdminButton(
              context,
              icon: Icons.restaurant_menu,
              text: 'Gérer le Menu',
              description:
                  'Voir la liste de tous les plats existants pour édition, suppression ou ajout de nouveaux plats.',
              onPressed: () {
                // Pointe vers la page de liste qui inclut le bouton d'ajout
                Navigator.pushNamed(context, '/plat_list');
              },
            ),
            const SizedBox(height: 15),

            // 2. Bouton : Gestion des Utilisateurs (NOUVEAU)
            _buildAdminButton(
              context,
              icon: Icons.people,
              text: 'Gérer les Utilisateurs',
              description:
                  'Afficher la liste des clients, modifier leurs rôles ou gérer les permissions.',
              onPressed: () {
                // TODO: Créer la page '/user_management'
                // Pour l'instant, on affiche une simple boîte de dialogue
                Navigator.pushNamed(context, '/user_management');
              },
            ),
            const SizedBox(height: 15),

            // 3. Bouton : Gestion des Commandes
            _buildAdminButton(
              context,
              icon: Icons.receipt_long,
              text: 'Suivi et Gestion des Commandes',
              description:
                  'Voir les commandes en cours, les statuts et l\'historique.',
              onPressed: () {
                Navigator.pushNamed(context, '/orders_management');
              },
            ),
            const SizedBox(height: 40),

            // Bouton de Déconnexion (Action principale de sortie)
            ElevatedButton.icon(
              onPressed: () {
                // Déconnexion complète, retour à l'écran d'accueil
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 5,
              ),
            ),

            const SizedBox(height: 15),

            // Bouton de Retour (pour l'expérience client)
            // TextButton.icon(
            //   onPressed: () {
            //     // Retour au menu principal (pour tester l'expérience client)
            //     Navigator.pop(context);
            //   },
            //   icon: const Icon(Icons.arrow_back, color: Colors.blueAccent),
            //   label: const Text('Retour au Menu Client'),
            // ),
          ],
        ),
      ),
    );
  }
}
