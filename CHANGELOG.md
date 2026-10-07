# Journal des modifications

Les changements notables de ce projet seront documentés ici selon le format Keep a Changelog.

## [Unreleased]

## [1.0.0] - 2026-10-07

### Added

- `AddOmniPerformanceCollector` : le collecteur seul, sans les services de la page (composants Razor, localisation),
  pour un hôte qui affiche les chiffres lui-même ; `MapOmniPerformance` refuse un tel hôte au démarrage.
- Planchers de couverture bloquants, dans le lanceur (`-c`) et l'intégration continue : 95 % des lignes, 85 % des
  branches.

### Changed

- Première version stable : l'API publique suit désormais le versionnage sémantique.

## [0.2.0] - 2026-10-06

### Added

- Signal de changement `RequestPerformanceRecorder.WaitForChangeAsync` : se termine dès qu'une requête mesurée est
  enregistrée, plusieurs requêtes entre deux attentes ne donnent qu'un signal ; il permet à une page de
  l'application de se mettre à jour en direct.

### Changed

- Description du paquet et README : la limite de 2 Mio porte sur la mémoire conservée par le collecteur ; le README
  précise ce qui reste hors de cette limite (cache des modèles de route, copie du tampon le temps d'afficher la page).

### Fixed

- Le filtre par défaut écarte les familles `/health`, `/_framework`, `/_content` et `/_blazor` par segment entier :
  `/healthcare/{id}` est de nouveau mesuré.
- La page n'est plus mesurée elle-même : sa lecture ne figure plus parmi les appels les plus lents.
- `<html lang>` vaut `fr` sous la culture invariante (au lieu du code inexistant `iv`).
- L'affichage de la page n'alloue plus qu'une copie du tampon (environ 1,9 Mio au lieu de plusieurs Mio) : les centiles
  sont lus sur la copie triée sur place, le palmarès sort d'un tas borné.

### Removed

- Configuration des mises à jour automatiques des dépendances : plus aucune demande de mise à jour automatique ; le lanceur local signale les paquets
  et le SDK en retard.

## [0.1.0] - 2026-10-06

### Added

- Squelette du dépôt : solution, projet `src/OmniEurope.Performance`, licence EUPL-1.2, lanceur
  `ylaunch.ps1`, contrôle CRAP (`scripts/crap-gate.ps1`).
- Collecteur `RequestPerformanceRecorder` : durées de requête par modèle de route, lues sur la mesure
  `http.server.request.duration` d'ASP.NET Core, sans middleware ; fenêtre de 7 jours, 2 Mio de mémoire conservée au plus, avec roulement, pires requêtes gardées
  hors roulement, réglages `OmniPerformance`.
- Page `/performance` (`AddOmniPerformance`, `MapOmniPerformance`) : document HTML sans style, appels les plus
  lents et centiles par route ; `PerformanceReportView` pour un hôte qui l'habille. Textes français et anglais.
- Suite de tests `tests/OmniEurope.Performance.Tests` (xUnit v3, bUnit, hôte de test ASP.NET Core, mesure mémoire).
- Intégration continue et publication NuGet (`.github/workflows`), paquet de symboles `.snupkg`.

### Changed

- Le paquet référence le framework partagé `Microsoft.AspNetCore.App` au lieu du paquet
  `Microsoft.AspNetCore.Components.Web` : il exige un hôte ASP.NET Core.
