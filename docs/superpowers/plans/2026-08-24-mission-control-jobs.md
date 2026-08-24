# Mission Control Jobs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter l'UI Mission Control – Jobs montée sur `/jobs` pour superviser Solid Queue : accès libre en dev/test, Basic Auth par variables d'environnement en production.

**Architecture:** Engine Rails monté à `/jobs`. Le gem gère lui-même les middlewares manquants des apps API-only (Flash, MethodOverride) et embarque ses assets. Le pipeline d'assets `propshaft` est requis : sans lui, l'initializer assets du gem crash au boot (`app.config.assets` inexistant). La Basic Auth du gem est *deny-by-default* : activée sans identifiants → 401 systématique.

**Tech Stack:** mission_control-jobs 1.1.0, propshaft (pipeline Rails 8), Solid Queue 1.7.0, Minitest + fixtures.

**Spec:** `docs/superpowers/specs/2026-08-24-mission-control-jobs-design.md`

---

## Faits vérifiés (source du gem inspectée)

1. **Auth (v1.1.0)** — `MissionControl::Jobs.http_basic_auth_enabled` vaut `true` par défaut. Comportement du filtre :
   - enabled + user/password présents → challenge Basic Auth classique ;
   - enabled + identifiants absents → `head :unauthorized` (**pas** d'accès libre) ;
   - disabled → accès ouvert.
2. **Ordre de chargement** — Les fichiers `config/environments/*.rb` sont chargés *avant* la boucle qui copie `config.mission_control.jobs.*` vers les attributs du module. Un fichier `config/initializers/*.rb` serait chargé **trop tard** : les credentials doivent donc être posés dans `config/environments/production.rb`.
3. **Fallback credentials** — Le gem lit aussi `Rails.application.credentials.dig(:mission_control, :http_basic_auth_*)` via `||=` ; nos env-vars ont priorité car posées plus tôt.
4. **Middleware API-only** — L'engine ajoute Flash + MethodOverride tout seul quand `config.api_only = true`. Rien à faire de notre côté.
5. **Vérifié empiriquement** en dev avec ces changements : `/jobs` → 200, CSS/JS servis (200), titre « Mission control - Queues ».
6. **Base de données de test** — `db/schema.rb` contient déjà les tables `solid_queue_*` ; `db:test:prepare` suffit.
7. **Modifs locales préexistantes hors périmètre** — `.ruby-version` et `Procfile.dev` sont modifiés localement par l'utilisateur : ne PAS les committer, ne PAS les restaurer.

## Structure de fichiers

| Fichier | Action | Responsabilité |
|---|---|---|
| `Gemfile`, `Gemfile.lock` | Déjà modifiés (recon) | gems `mission_control-jobs` + `propshaft` |
| `test/integration/mission_control_jobs_test.rb` | Créer | Tests d'intégration accès UI |
| `config/routes.rb` | Modifier | Montage engine à `/jobs` |
| `config/environments/development.rb` | Modifier | Désactivation Basic Auth en dev |
| `config/environments/test.rb` | Modifier | Désactivation Basic Auth en test |
| `config/environments/production.rb` | Modifier | Credentials Basic Auth via env vars |

---

### Task 1: Vérifier et committer les gems

**Files:**
- Verify: `Gemfile` (déjà modifié pendant la phase de recon)
- Verify: `Gemfile.lock`

- [ ] **Step 1: Vérifier la présence des deux gems**

Le Gemfile doit contenir, après `gem "solid_queue"` :

```ruby
gem "solid_queue"
gem "mission_control-jobs"
gem "propshaft"
```

Si absent, ajouter puis lancer `bundle install`.

- [ ] **Step 2: Vérifier que le bundle résout**

Run: `bundle check`
Expected: `The Gemfile's dependencies are satisfied`

- [ ] **Step 3: Vérifier que l'app boote (le moteur n'est pas encore monté)**

Run: `bundle exec rails runner 'puts MissionControl::Jobs.http_basic_auth_enabled'`
Expected: affiche `true` (défaut du gem), aucune erreur

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "build(deps): add mission_control-jobs and propshaft"
```

Ne PAS ajouter `.ruby-version` ni `Procfile.dev` (modifs locales préexistantes).

---

### Task 2: Tests d'intégration (rouge)

**Files:**
- Create: `test/integration/mission_control_jobs_test.rb`

- [ ] **Step 1: Écrire les tests**

```ruby
require "test_helper"

class MissionControlJobsTest < ActionDispatch::IntegrationTest
  test "GET /jobs is accessible when basic auth is disabled" do
    get "/jobs"
    assert_response :success
  end

  test "GET /jobs challenges with basic auth when enabled and configured" do
    with_basic_auth(user: "admin", password: "secret") do
      get "/jobs"
      assert_response :unauthorized

      get "/jobs", headers: basic_auth_header("admin", "secret")
      assert_response :success
    end
  end

  private

  # Active temporairement la Basic Auth avec des identifiants connus,
  # quelles que soient les valeurs des fichiers d'environnement.
  # Restaure l'état initial pour ne pas fuiter vers d'autres tests.
  def with_basic_auth(user:, password:)
    original_enabled = MissionControl::Jobs.http_basic_auth_enabled
    original_user = MissionControl::Jobs.http_basic_auth_user
    original_password = MissionControl::Jobs.http_basic_auth_password

    MissionControl::Jobs.http_basic_auth_enabled = true
    MissionControl::Jobs.http_basic_auth_user = user
    MissionControl::Jobs.http_basic_auth_password = password

    yield
  ensure
    MissionControl::Jobs.http_basic_auth_enabled = original_enabled
    MissionControl::Jobs.http_basic_auth_user = original_user
    MissionControl::Jobs.http_basic_auth_password = original_password
  end

  def basic_auth_header(user, password)
    {
      "Authorization" => ActionController::HttpAuthentication::Basic
        .encode_credentials(user, password)
    }
  end
end
```

Notes de design :
- Les contrôleurs du gem lisent les attributs du module **au moment de la requête** (`mattr_accessor`) : le stub direct est fiable et indépendant des fichiers d'environnement.
- Minitest parallélise par process forkés ; les tests d'un même worker tournent séquentiellement → pas de course sur les attributs mutés.
- `ensure` garantit la restauration même en cas d'échec.

- [ ] **Step 2: Préparer la base de test**

Run: `bin/rails db:test:prepare`
Expected: succès (tables solid_queue déjà dans schema.rb)

- [ ] **Step 3: Lancer les tests, vérifier qu'ils échouent pour la bonne raison**

Run: `bin/rails test test/integration/mission_control_jobs_test.rb -v`
Expected: 2 erreurs/échecs dus à `ActionController::RoutingError` (aucune route `/jobs`) — pas d'autre type d'erreur.

---

### Task 3: Montage et configuration (vert)

**Files:**
- Modify: `config/routes.rb`
- Modify: `config/environments/development.rb`
- Modify: `config/environments/test.rb`
- Modify: `config/environments/production.rb`

- [ ] **Step 1: Monter l'engine**

Dans `config/routes.rb`, après la route health :

```ruby
  get "up" => "rails/health#show", as: :rails_health_check

  mount MissionControl::Jobs::Engine, at: "/jobs"
```

- [ ] **Step 2: Ouvrir l'accès en développement**

Dans `config/environments/development.rb`, avant le `end` final du bloc `Rails.application.configure` :

```ruby
  # Open access to the Mission Control Jobs UI (/jobs) in development.
  # The gem denies access by default when enabled without credentials.
  config.mission_control.jobs.http_basic_auth_enabled = false
```

- [ ] **Step 3: Ouvrir l'accès en test**

Dans `config/environments/test.rb`, même ligne ajoutée avant le `end` final :

```ruby
  config.mission_control.jobs.http_basic_auth_enabled = false
```

- [ ] **Step 4: Configurer la Basic Auth en production**

Dans `config/environments/production.rb`, avant le `end` final :

```ruby
  # HTTP Basic Auth for the Mission Control Jobs UI (/jobs).
  # Enabled by default (deny-all until credentials are provided).
  # Set MISSION_CONTROL_JOBS_USER and MISSION_CONTROL_JOBS_PASSWORD in the
  # deployment environment (e.g. Kamal secrets). Both are required.
  if ENV["MISSION_CONTROL_JOBS_USER"].present? && ENV["MISSION_CONTROL_JOBS_PASSWORD"].present?
    config.mission_control.jobs.http_basic_auth_user = ENV["MISSION_CONTROL_JOBS_USER"]
    config.mission_control.jobs.http_basic_auth_password = ENV["MISSION_CONTROL_JOBS_PASSWORD"]
  end
```

Important : ces lignes vont dans le fichier d'**environnement**, pas dans un initializer (ordre de chargement — voir « Faits vérifiés » §2). Sans variables définies, `/jobs` répond 401 en prod : mode d'échec sûr voulu.

- [ ] **Step 5: Lancer les tests, vérifier le vert**

Run: `bin/rails test test/integration/mission_control_jobs_test.rb -v`
Expected: `2 runs, 2 assertions, 0 failures, 0 errors`

---

### Task 4: Vérification complète et commit

- [ ] **Step 1: Suite complète**

Run: `bin/rails test`
Expected: tous les tests verts (le reste de la suite ne touche pas `/jobs`).

- [ ] **Step 2: Smoke test manuel en dev (UI rendue + assets servis)**

```bash
RAILS_ENV=development bundle exec rails server -p 3999 > /tmp/opencode/mc_smoke.log 2>&1 &
SERVER_PID=$!
sleep 8
curl -s -o /dev/null -w "/jobs -> %{http_code}\n" http://localhost:3999/jobs
ASSET=$(curl -s http://localhost:3999/jobs | grep -oE '/assets/mission_control/jobs/application-[a-f0-9]+\.css' | head -1)
curl -s -o /dev/null -w "$ASSET -> %{http_code}\n" "http://localhost:3999$ASSET"
kill $SERVER_PID
```

Expected: `/jobs -> 200` et l'asset CSS `-> 200` (garde-fou recommandé par la revue de spec : pas seulement un 200 HTML sans styles).

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb config/environments/development.rb \
        config/environments/test.rb config/environments/production.rb \
        test/integration/mission_control_jobs_test.rb
git commit -m "feat: mount Mission Control Jobs UI at /jobs with basic auth in production"
```

Ne PAS ajouter `.ruby-version` ni `Procfile.dev`.

---

## Hors périmètre (documenté, fait côté déploiement)

Définir `MISSION_CONTROL_JOBS_USER` et `MISSION_CONTROL_JOBS_PASSWORD` comme secrets Kamal lors du déploiement prod. Sans eux, `/jobs` reste verrouillé (401).
