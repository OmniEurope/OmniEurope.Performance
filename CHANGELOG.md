# Journal des modifications

Les changements notables de ce projet seront documentés ici selon le format Keep a Changelog.

## [Unreleased]

### Added

- Squelette du dépôt : solution, projet `src/OmniEurope.Performance`, licence EUPL-1.2, lanceur
  (`ylaunch.ps1`, cœur 1.0.5), contrôle CRAP (`scripts/crap-gate.ps1`), garde de versions Dependabot.
- Collecteur `RequestPerformanceRecorder` : durées de requête par modèle de route, lues sur la mesure
  `http.server.request.duration` d'ASP.NET Core, sans middleware ; fenêtre de 7 jours, 2 Mio de mémoire au plus avec roulement, pires requêtes gardées
  hors roulement, réglages `OmniPerformance`.
- Page `/performance` (`AddOmniPerformance`, `MapOmniPerformance`) : document HTML sans style, appels les plus
  lents et centiles par route ; `PerformanceReportView` pour un hôte qui l'habille. Textes français et anglais.
- Suite de tests `tests/OmniEurope.Performance.Tests` (xUnit v3, bUnit, hôte de test ASP.NET Core, mesure mémoire).
- Intégration continue et publication NuGet (`.github/workflows`), paquet de symboles `.snupkg`.

### Changed

- Le paquet référence le framework partagé `Microsoft.AspNetCore.App` au lieu du paquet
  `Microsoft.AspNetCore.Components.Web` : il exige un hôte ASP.NET Core.
