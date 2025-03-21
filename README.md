# 🏢 SireneD

## Description

API REST pour accéder aux données de SIRENE (Système Informatique pour le Répertoire des ENtreprises et des Établissements).

L'application est développée en Ruby on Rails sous licence MIT. Elle permet le téléchargement et l'indexation de la base des unités légales et établissements de la base SIRENE tous les mois de façon automatisée.

La réutilisation permet de tester l'API pour accéder aux données de SIRENE, d'en demander un accès et de l'héberger sur sa propre infrastructure. Elle a été développée suite à la dépréciation de l'[API pour le fichier SIRENE d'Etalab](https://github.com/etalab/sirene_as_api).

## Essayer l'API

Vous pouvez essayer l'API en utilisant une instance hébergée chez OVHcloud :

    curl 'https://api.sirened.fr/api/v1/unites_legales/?q=Doctolib'

Si celle-ci ne répond pas, merci de bien vouloir nous écrire par mail à equipe+sirene-as-api@dilolabs.fr

## Installation en environnement de développement

Pré-requis :

- Ruby 3.3
- PostgreSQL

Cloner le dépôt :

    git clone git@github.com/dilolabs/sirened.git

Se déplacer dans le répertoire du projet :

    cd sirened

Installer les dépendances et créer la base de données :

    bin/setup

Peupler la base de données avec les données de SIRENE :

⚠️  Cela peut prendre un certain temps.

    bin/rails sirene:import_stock

Lancer le serveur :

    bin/dev

Requêter l'API avec le nom d'une entreprise :

    curl 'localhost:3000/api/v1/unites_legales/?q=Doctolib'

Requêter l'API avec le SIREN d'une entreprise :

    curl 'localhost:3000/api/v1/unites_legales/794598813'

## Déploiement en production

En production, le job d'import des données de SIRENE est automatiquement exécuté tous les mois.

Si vous souhaitez déployer SireneD en production et avez besoin d'assistance, merci de bien vouloir nous écrire par mail à equipe+sirened@dilolabs.fr

## Licence

MIT (voir [LICENSE](LICENSE)).

