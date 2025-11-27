import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Couleur principale pour le thème
    const Color primaryColor = Color(
      0xFF1E88E5,
    ); // Blue 600 - plus vif et professionnel
    const Color secondaryColor = Color(0xFF4FC3F7); // Light Blue 300

    return Scaffold(
      // Pas d'AppBar pour un look plein écran de page d'accueil
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 30.0,
              vertical: 50.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Section d'icône et d'introduction ---
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(
                        0.1,
                      ), // Arrière-plan subtil pour l'icône
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons
                          .local_shipping_outlined, // Icône plus spécifique à la livraison
                      size: 90,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Titre principal
                const Text(
                  "Livraison Rapide, Partout.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // Sous-titre descriptif
                Text(
                  "Connectez-vous pour suivre vos colis, gérer vos expéditions et plus encore.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 80),

                // --- Boutons d'Action ---

                // 1. Bouton de Connexion (Principal)
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigue vers la route nommée '/login'
                    Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login, size: 20),
                  label: const Text(
                    "Se Connecter",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        12,
                      ), // Coins plus arrondis
                    ),
                    elevation: 5, // Ombre pour un effet 3D subtil
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Bouton d'Inscription (Secondaire)
                OutlinedButton.icon(
                  onPressed: () {
                    // Navigue vers la route nommée '/register'
                    Navigator.pushNamed(context, '/register');
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                  label: const Text(
                    "Créer un Compte",
                    style: TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
