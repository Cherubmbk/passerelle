# Base de données Passerelle (Supabase)

Projet : **passerelle-paris** (région Paris, `eu-west-3`), organisation « Passerelle-Dev ».

Les fichiers de `migrations/` recréent toute la structure de la base, dans l'ordre :

1. `20261107000001_schema_tables.sql` : types, 23 tables, clés, contrôles et index ;
2. `20261107000002_schema_fonctions.sql` : fonctions et droits d'exécution ;
3. `20261107000003_schema_regles.sql` : déclencheurs, droits sur les tables, règles d'accès (RLS) et stockage des documents.

4. `20261107000004_option_a_situations_sensibles.sql` : la base retire d'elle-même la RQTH, le RSA et l'arrivée récente en France si elles lui étaient envoyées.

Fonction serveur `delete-account` (`functions/delete-account/index.ts`) : supprime le compte de la personne connectée, ses fichiers et toutes ses données.

Les fichiers 1 à 3 ont été copiés le 7 novembre 2026 depuis le premier projet (Irlande), puis appliqués au projet de Paris.
La copie a été vérifiée : mêmes tables, colonnes, contrôles, index, fonctions, déclencheurs et règles d'accès.
Seule différence volontaire : les utilisateurs connectés n'ont plus le droit `TRUNCATE` sur les tables.

Données sensibles (choix « option A ») : la RQTH et les situations délicates restent sur l'appareil de la personne
et ne sont jamais envoyées dans cette base.
