<!-- SPDX-License-Identifier: EUPL-1.2 -->
# OmniEurope.Performance

Bibliothèque Razor qui ajoute à une application ASP.NET Core **une page de mesure des performances du site**,
réduite au strict minimum : **aucun thème, aucun style, aucune dépendance tierce**, au plus 2 Mio de mémoire conservée.
Un seul paquet NuGet, sous licence EUPL-1.2.

## Utilisation

```powershell
dotnet add package OmniEurope.Performance
```

```csharp
builder.Services.AddOmniPerformance();                      // collecteur + ce que la page utilise
app.MapOmniPerformance().RequireAuthorization("Admin");     // la page, sur /performance
```

`MapOmniPerformance("/admin/performance")` change l'adresse. Les chiffres décrivent le site : protégez la page
avec la politique d'autorisation de l'application.

Un hôte qui affiche les chiffres lui-même (une API qui sert `RequestPerformanceRecorder.Summarize()`, une page à
ses couleurs) enregistre le collecteur seul avec `AddOmniPerformanceCollector()`, mêmes réglages : il ne reçoit ni
les services des composants Razor ni la localisation. `MapOmniPerformance` refuse alors de démarrer, la page exige
`AddOmniPerformance()`.

## Réglages

Section `OmniPerformance` de la configuration de l'hôte (appsettings, variables `OmniPerformance__Window`...),
puis `AddOmniPerformance(o => ...)`, qui a le dernier mot :

| Réglage | Défaut | Rôle |
|---|---|---|
| `Window` | `7.00:00:00` (7 jours) | Profondeur de la fenêtre, en mémoire, remise à zéro au redémarrage. |
| `SlowestCount` | `20` | Nombre de pires requêtes listées sur toute la fenêtre. |
| `MemoryLimitBytes` | `2097152` (2 Mio) | Mémoire conservée par le collecteur, allouée une fois au démarrage. |
| `RouteFilter` | sondes, framework et fichiers statiques écartés | Routes mesurées (code seulement). |

Un réglage qui ne laisse rien à mesurer (fenêtre ou nombre nul, limite trop basse pour la fenêtre choisie) est
refusé au démarrage de l'application.

## Ce que fait le paquet

- **Collecteur côté serveur, sans middleware** : `RequestPerformanceRecorder` écoute la mesure de durée que
  ASP.NET Core publie déjà pour chaque requête (`http.server.request.duration`), regroupée par modèle de route
  (`/orders/{id}`, jamais l'adresse concrète). Deux hôtes dans un même processus ne mélangent jamais leurs chiffres.
- **Mémoire bornée** : la limite est partagée entre la liste des pires requêtes (servie en premier) et un tampon
  circulaire de requêtes pour les centiles, alloué une fois : quand il est plein, la requête la plus récente prend
  la place de la plus ancienne. Rien ne grandit avec le trafic ; un test mesure les octets alloués par une semaine
  pleine et vérifie qu'ils restent sous la limite. Hors de cette limite : le cache des modèles de route (un par
  route de l'application) et, le temps d'afficher la page, une seule copie du tampon pour les centiles, elle aussi
  mesurée sous la limite par un test.
- **Les pires requêtes d'abord** : les `SlowestCount` requêtes les plus lentes de toute la fenêtre sont gardées à
  part du tampon (les `SlowestCount` pires de chaque heure), donc un site chargé ne les perd pas. Seule limite :
  sur l'heure la plus ancienne, en partie sortie de la fenêtre, une requête qui n'était pas dans le palmarès de
  son heure ne peut pas remplacer une requête expirée.
- **Centiles par route** : nombre d'appels, médiane, 95e et 99e centiles, maximum, calculés sur les requêtes du
  tampon ; la page dit depuis quand elles comptent et quand le roulement en a écarté. Rang le plus proche, sans
  interpolation : chaque chiffre est une requête réelle.
- **Page** : un document HTML complet, servi par un point d'accès ordinaire (indépendant du routeur Blazor de
  l'application) et exclu des mesures, pour ne jamais figurer parmi les appels lents. Textes en français, anglais
  fourni selon la culture de la requête (`UseRequestLocalization`).
- **Pour habiller la page** : `PerformanceReportView` affiche les chiffres seuls (sans `<html>`) à partir de
  `RequestPerformanceRecorder.Summarize()`, pour être placée dans une page aux couleurs de l'application.
- **Pour une page en direct** : `RequestPerformanceRecorder.WaitForChangeAsync(ct)` se termine dès qu'une requête
  mesurée a été enregistrée depuis l'attente précédente ; les requêtes arrivées entre deux attentes ne donnent qu'un
  signal, une route écartée par le filtre n'en donne aucun. Il est fait pour un seul consommateur (un service de fond
  qui prévient les pages ouvertes et espace lui-même ses annonces). Si les pages relisent les chiffres par un point
  d'accès de l'application, excluez-le des mesures (`.DisableHttpMetrics()`), sinon chaque lecture relance le signal.

## Ce qu'il ne fait pas, volontairement

- **Aucun thème ni style** : pas de CSS, pas de script, pas d'icônes, pas de mise en page. Le balisage est
  sémantique (titres, tableaux) pour rester lisible sans feuille de style. L'habillage appartient à l'application
  ou à sa bibliothèque de composants, qui dépend de ce paquet, jamais l'inverse.
- **Pas de Blazor WebAssembly autonome** : le collecteur vit dans le processus serveur, le paquet exige un hôte
  ASP.NET Core (Blazor Web App, Blazor Server, API).
- Rien au-delà de la page : la page fournie ne se rafraîchit pas seule (recharger la page relit les chiffres ;
  le signal ci-dessus sert aux pages de l'application), pas d'historique au-delà de la fenêtre ni après un
  redémarrage, pas d'envoi de données.

## Dépendances

- Exécution : le framework partagé `Microsoft.AspNetCore.App` seulement, aucun paquet tiers.
- Tests uniquement : `xunit.v3` (Apache-2.0), `bunit` (MIT), `Microsoft.AspNetCore.TestHost` (MIT),
  `coverlet.MTP` (MIT), `Microsoft.Testing.Extensions.TrxReport` (MIT).

## Développement

```powershell
.\ylaunch.ps1 -t     # compile et lance les tests
.\ylaunch.ps1 -c     # couverture, puis contrôle CRAP (aucune méthode au-dessus de 30)
```

Avant de compiler, le lanceur signale, sans bloquer, un SDK .NET plus récent que celui utilisé et les paquets NuGet
en retard : le dépôt n'ouvre aucune demande de mise à jour automatique.

Git flow : `main` pour les versions publiées, `develop` pour l'intégration, `feature/*` pour le travail. Une
version GitHub publiée (`0.1.0`) déclenche la publication NuGet du paquet validé par l'intégration continue.

## Licence

EUPL-1.2, voir [LICENSE](LICENSE).
