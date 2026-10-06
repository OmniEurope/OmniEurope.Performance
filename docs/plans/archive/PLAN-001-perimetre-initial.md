<!-- SPDX-License-Identifier: EUPL-1.2 -->
# PLAN-001 : Périmètre initial

> Statut : **terminé** (2026-10-06), version 0.1.0 publiée sur NuGet.

## Objectif

Une page de mesure des performances, sans thème, qu'une application ASP.NET Core ajoute en deux lignes
(services, route) et qu'une bibliothèque de composants peut habiller ensuite.

## Architecture retenue (2026-10-06)

- **Un seul paquet** : collecteur côté serveur et page Razor dans `OmniEurope.Performance`. Le collecteur exige
  `FrameworkReference Microsoft.AspNetCore.App` : le paquet vise un hôte ASP.NET Core (Blazor Web App ou
  Server), pas un Blazor WebAssembly autonome.
- **Côté serveur** : collecte des durées de requête par route sans middleware, en écoutant l'histogramme
  `http.server.request.duration` qu'ASP.NET Core publie déjà (`MeterListener` dans un `IHostedService`).
- **Mémoire** : 2 Mio conservés au plus par défaut (`MemoryLimitBytes`). La liste des pires requêtes (`SlowestCount` par
  heure de la fenêtre) est servie en premier, le reste est un tampon circulaire alloué une fois pour les centiles.
  Fenêtre de 7 jours par défaut (`Window`), réglages lus dans la section `OmniPerformance`.
- **Côté page** : la page lit le collecteur par injection de dépendances, sans API JSON intermédiaire. Elle est
  servie par un point d'accès ordinaire (`MapOmniPerformance`, `RazorComponentResult`), indépendant du routeur
  Blazor de l'application ; `PerformanceReportView` porte les chiffres seuls pour un hôte qui les habille.

## Lot 1 : inventaire des mesures

- [x] Inventaire des mesures utiles à une page de performance minimale : ce qu'elle mesure, comment, ce qui
  sort du périmètre.
- Contrôle : la liste des mesures retenues et de celles laissées de côté est consignée ici.

Retenu :

- l'écoute de `http.server.request.duration` et le regroupement par modèle de route et méthode, insensible à la
  casse ;
- le rapport : appels les plus lents, centiles 50/95/99 au rang le plus proche, maximum, tri par 95e centile ;
- le filtre de routes configurable et l'exclusion par défaut des sondes et du framework ;
- la phrase de fenêtre (« depuis quand les chiffres comptent ») et l'avertissement quand des requêtes sont écartées.

Ajouté : fenêtre de 7 jours configurable ; limite mémoire avec roulement ; palmarès des pires requêtes
indépendant du roulement ; filtrage par `IMeterFactory` de l'hôte (deux hôtes d'un même processus ne se mélangent
pas) ; exclusion par défaut des fichiers statiques et de `/_blazor` ; modèle de route normalisé avec une barre
initiale.

Laissé de côté (sort du strict minimum) :

- l'export des chiffres vers un outil de supervision et leur lecture pour d'autres applications ;
- le rafraîchissement poussé par un hub temps réel ;
- une API JSON intermédiaire ;
- les mesures côté navigateur (WebAssembly) ;
- grilles, onglets, exports Markdown/CSV, en-tête et icônes : l'habillage revient à l'hôte ;
- l'atténuation des centiles calculés sur trop peu d'appels.

## Lot 2 : page minimale

- [x] Composant de page, balisage sémantique sans CSS, enregistrement en une ligne par côté
  (`AddOmniPerformance`, `MapOmniPerformance`).
- Contrôle : tests bUnit du rendu et de l'enregistrement ; aucun fichier `.css` ni dépendance tierce dans le
  paquet. Fait : 30 tests (bUnit, hôte de test ASP.NET Core de bout en bout, mesure mémoire), 0 `.css`, aucune
  dépendance dans le `.nuspec` hors `Microsoft.AspNetCore.App`.

## Lot 3 : mémoire bornée

- [x] Limite `MemoryLimitBytes` (2 Mio), tampon circulaire alloué une fois, palmarès horaire des pires requêtes
  hors roulement, cache des modèles de route sans allocation par requête.
- Contrôle : `RecorderMemoryTests` compte les octets alloués pour une semaine pleine (tampon roulé, chaque heure
  pleine) et exige qu'ils restent sous la limite. Fait : 2 056 520 octets pour 2 097 152, à l'identique d'une
  exécution à l'autre.

## Lot 4 : publication

- [x] Paquet NuGet 0.1.0 avec symboles (`.snupkg`), README embarqué, `ylaunch.ps1 -c` vert (contrôle CRAP).
- [x] `.github/workflows/ci.yml` (compilation, tests, couverture, CRAP, paquet vérifié, artefact) et
  `publish-nuget.yml` (sur version GitHub publiée, pousse le paquet validé par la CI, publication de confiance
  NuGet sans clé d'API).
- Contrôle : les étapes de `ci.yml` rejouées en local en Release passent (`CRAP gate passed`, paquet vérifié).
  Fait : version GitHub `0.1.0`, workflow « Publish NuGet » vert, paquet et symboles poussés sur nuget.org.
