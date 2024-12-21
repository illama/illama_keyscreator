Illama Keys Creator est conçu pour gérer les clés des véhicules sur un serveur FiveM sous ESX. Ce script permet une gestion avancée des véhicules en combinant la distribution des clés, la protection contre les vols, et des fonctionnalités intégrées avec Illama Garages Creator.

Fonctionnalités Principales
- Distribution automatique des clés lors de l'achat ou du spawn d'un véhicule (Illama_garagescreator).
- Clés temporaires pour les véhicules de service.
- Gestion de multiples clés pour un même véhicule.
- Système d'alarme activé lors des tentatives de vol.
- Alertes au propriétaire en cas de vol.
- Verrouillage/déverrouillage avec feedback visuel et sonore.
- Synchronisation de l'état des portes pour tous les joueurs.
- PNJ pour la gestion des clés et la duplication (avec coût configurable).
- Notifications dynamiques pour guider les joueurs.

Installation
- Téléchargez et placez le script dans votre dossier resources.
- Ajoutez la ressource à votre fichier server.cfg :
- ensure illama_keyscreator

Créez les tables MySQL nécessaires en exécutant la requête suivante :

    CREATE TABLE `illama_keys` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `plate` VARCHAR(50) NOT NULL,
        `owner` VARCHAR(50) NOT NULL,
        `has_key` TINYINT(1) DEFAULT 0,
        `locked` TINYINT(1) DEFAULT 0,
        `first_key_used` TINYINT(1) DEFAULT 0
    );

    Redémarrez votre serveur FiveM.

Commandes
- Touche U : Verrouille/déverrouille un véhicule.
- PNJ : Accès au menu de gestion des clés via l'interface ox_target.

Configuration
- Coût des clés : Configurez le coût des doubles clés.
- Temps d'alarme : Durée et fréquence des alarmes.
- PNJ : Position et modèle du PNJ.

Prérequis
- ESX Legacy (ou compatible).
- MySQL-Async pour la gestion des bases de données.
- ox_inventory pour gérer les objets clés.

Crédits
- Développé par Illama.
