import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  // --------------------------------------------------------------------------
  // Widget pour les indicateurs clés de performance (KPI Cards)
  // Correction: Réduction du padding et de l'espacement pour donner plus de place au texte.
  // --------------------------------------------------------------------------
  Widget _buildKpiCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Réduction du padding de 16 à 12
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(width: 10), // Réduction de l'espace de 15 à 10
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    // Retrait de maxLines: 1 et overflow: TextOverflow.ellipsis pour permettre le retour à la ligne
                    // si le titre est long et pour qu'il soit affiché en entier.
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines:
                        1, // La valeur est courte et doit rester sur une ligne
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Widget utilitaire pour créer les boutons d'action de l'administrateur
  // --------------------------------------------------------------------------
  Widget _buildAdminButton(
    BuildContext context, {
    required IconData icon,
    required String text,
    required String description,
    required VoidCallback onPressed,
    Color color = Colors.indigo, // Couleur par défaut modifiée
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        // Utilisation d'un Padding avec animation subtile au tap
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.white,
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              // Conteneur d'icône plus visible
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
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
              // Icône de navigation
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: color.withOpacity(0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tableau de Bord Admin',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // En-tête de bienvenue
            Text(
              'Bienvenue, Gestionnaire !',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aperçu rapide de l\'activité du restaurant.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.left,
            ),
            const Divider(height: 30, thickness: 1),

            // -----------------------------------
            // Section KPI (Indicateurs Clés)
            // -----------------------------------
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildKpiCard(
                  icon: Icons.access_time_filled,
                  color: Colors.orange.shade700,
                  title: 'Commandes en Cours',
                  value: '4', // Donnée factice
                ),
                _buildKpiCard(
                  icon: Icons.attach_money,
                  color: Colors.green.shade700,
                  title: 'Revenu du Jour',
                  value: '345.50 €', // Donnée factice
                ),
                _buildKpiCard(
                  icon: Icons.people_alt,
                  color: Colors.blue.shade700,
                  title: 'Nouveaux Clients',
                  value: '12', // Donnée factice
                ),
                _buildKpiCard(
                  icon: Icons.food_bank,
                  color: Colors.pink.shade700,
                  title: 'Plats Actifs',
                  value: '54', // Donnée factice
                ),
              ],
            ),
            const Divider(height: 30, thickness: 1),

            // -----------------------------------
            // Section Actions Principales
            // -----------------------------------
            const Text(
              'Actions Principales',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),

            // 1. Bouton : Gestion des Commandes
            _buildAdminButton(
              context,
              icon: Icons.receipt_long,
              text: 'Suivi et Gestion des Commandes',
              description:
                  'Voir les commandes en cours, mettre à jour les statuts (préparation, livraison, etc.) et consulter l\'historique.',
              onPressed: () {
                // Naviguer vers la gestion des commandes
                Navigator.pushNamed(context, '/orders_management');
              },
              color: Colors.deepOrange.shade600, // Couleur accentuée
            ),
            const SizedBox(height: 15),

            // 2. Bouton : Gérer le Menu
            _buildAdminButton(
              context,
              icon: Icons.restaurant_menu,
              text: 'Gérer le Menu',
              description:
                  'Ajouter, modifier ou supprimer des plats, et gérer les catégories associées.',
              onPressed: () {
                // Naviguer vers la gestion du menu
                Navigator.pushNamed(context, '/plat_list');
              },
              color: Colors.indigo.shade600,
            ),
            const SizedBox(height: 15),

            // 3. Bouton : Gestion des Utilisateurs (NOUVEAU)
            _buildAdminButton(
              context,
              icon: Icons.people,
              text: 'Gérer les Utilisateurs',
              description:
                  'Afficher la liste des clients, modifier leurs rôles ou gérer les permissions d\'accès.',
              onPressed: () {
                // Naviguer vers la gestion des utilisateurs
                Navigator.pushNamed(context, '/user_management');
              },
              color: Colors.teal.shade600,
            ),
            const SizedBox(height: 40),

            // Bouton de Déconnexion (Action principale de sortie)
            OutlinedButton.icon(
              onPressed: () {
                // Déconnexion complète, retour à l'écran d'accueil
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion du Tableau de Bord'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade400, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 15),
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
}
