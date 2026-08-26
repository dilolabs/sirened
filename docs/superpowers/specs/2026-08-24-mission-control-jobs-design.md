# Mission Control Jobs — Design

**Date :** 2026-08-24
**Statut :** Approuvé (design présenté et validé en session)

## Contexte

Sirene as API est une application Rails 8 API-only utilisant Solid Queue
(`config.active_job.queue_adapter = :solid_queue`, `config/queue.yml`,
`config/recurring.yml`). Aucune interface n'existe pour observer les jobs
(en cours, échecs, retries, files d'attente).

L'app n'a aucun système d'authentification utilisateur ; elle sert
uniquement des endpoints JSON publics.

## Objectif

Ajouter le gem [mission_control-jobs](https://github.com/rails/mission_control-jobs)
pour disposer d'une UI de supervision de Solid Queue.

## Décisions

### 1. Protection de l'accès

L'UI permet de voir **et manipuler** les jobs (suppression, retry,
discard) : elle ne doit pas être exposée publiquement.

Décision retenue : **accès libre en dev/test, Basic Auth en production.**

- Initializer `config/initializers/mission_control_jobs.rb` qui active la
  Basic Auth du gem uniquement si les variables d'environnement
  `MISSION_CONTROL_JOBS_USER` et `MISSION_CONTROL_JOBS_PASSWORD`
  sont définies.
- dev/test : variables non définies → accès libre.
- production : variables définies via l'environnement de déploiement
  (Kamal) → 401 sans identifiants valides.

### 2. Montage

Montage à `/jobs` dans `config/routes.rb` :

```ruby
mount MissionControl::Jobs::Engine, at: "/jobs"
```

Le gem embarque ses vues, assets et son importmap ; il est autonome par
rapport à l'application hôte.

### 3. Compatibilité API-only

L'app est en `config.api_only = true`. Si le boot ou le rendu des pages
de l'engine échoue faute de middleware session/cookies, on ré-ajoutera
manuellement `ActionDispatch::Cookies` +
`ActionDispatch::Session::CookieStore` dans
`config/application.rb` (scopé au strict nécessaire). À vérifier
empiriquement au boot et via le test ci-dessous.

## Tests

Un test d'intégration Minitest (`test/integration/mission_control_jobs_test.rb`) :

1. `GET /jobs` répond `200` dans l'environnement test (Basic Auth
   désactivée).
2. Avec la Basic Auth activée (stub des variables d'environnement),
   `GET /jobs` sans identifiants répond `401`.

## Hors périmètre

- Configuration Kamal des secrets (fait côté déploiement, documenté ici).
- Dashboard alternatif type Sidekiq Web.
- Monitoring avancé (alerting, métriques).
