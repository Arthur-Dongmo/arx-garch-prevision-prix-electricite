# Prévision à court terme des prix de l'électricité — Modèles ARX-GARCH

Modélisation et prévision des prix journaliers de l'électricité sur un marché dérégulé (Lituanie, Nord Pool), en intégrant la production éolienne comme variable exogène.

> **Le modèle ARX(3)-APARCH(1,1) réduit l'erreur de prévision (MAPE) de 3,54 % à 3,21 % par rapport au modèle autorégressif de référence**, en captant à la fois l'effet de la production éolienne et l'asymétrie de la volatilité des prix.

Ce dépôt s'appuie sur mon mémoire de Master en Modélisation Mathématique en Économie et Finance (École Nationale Supérieure Polytechnique de Yaoundé — CETIC).

## Sommaire

- [Objectif / Problématique](#objectif--problématique)
- [Outils et compétences mobilisées](#outils-et-compétences-mobilisées)
- [Données](#données)
- [Méthodologie](#méthodologie)
- [Résultats](#résultats)
- [Limites et perspectives](#limites-et-perspectives)

## Objectif / Problématique

Depuis la dérégulation des marchés de l'électricité, les prix sont fixés par des mécanismes de marché concurrentiels et affichent une forte volatilité, non linéaire et asymétrique dans le temps. Pour les producteurs et fournisseurs, anticiper ces prix avec précision est central pour les stratégies d'enchères, la couverture de risque et les décisions d'investissement.

Ce projet répond à une question précise : **la prise en compte de la demande et de la production d'énergie éolienne améliore-t-elle la précision des prévisions de prix journaliers de l'électricité ?**

## Outils et compétences mobilisées

- **Langage** : R (`rugarch`, `forecast`, `tseries`, `FinTS`, `skedastic`, `vars`, `urca`, `ggplot2`), EViews 9
- **Économétrie des séries temporelles** : tests de racine unitaire, modèles ARX, famille GARCH (GARCH, EGARCH, GJR-GARCH, APARCH), estimation par maximum de vraisemblance
- **Diagnostic statistique** : tests de Ljung-Box, ARCH-LM (Engle), White, Jarque-Bera
- **Évaluation de modèles prédictifs** : validation train/test, comparaison multi-critères (RMSE, MAE, MAPE, TIC)
- **Data visualisation** : ggplot2, analyse exploratoire de séries chronologiques

## Données

| | |
|---|---|
| Source | [Nord Pool](https://www.nordpoolgroup.com) (prix), [Litgrid](https://www.litgrid.eu) (demande, production éolienne) |
| Marché | Lituanie — session Day-Ahead |
| Période | 01/01/2018 – 31/12/2019 (730 observations journalières) |
| Échantillon d'estimation | 699 jours (01/01/2018 – 30/11/2019) |
| Échantillon de test | 31 jours (décembre 2019) |
| Variables | Prix de l'électricité (€/MWh, transformé en log), demande d'électricité, production éolienne |

## Méthodologie

1. **Analyse exploratoire** : stationnarité (tests ADF, Phillips-Perron), normalité et asymétrie de la distribution (Jarque-Bera, skewness/kurtosis).
2. **Modèle moyen** : sélection d'un processus autorégressif AR(3) par les critères AIC/SIC/HQC, puis extension en ARX avec la demande et l'énergie éolienne comme régresseurs exogènes.
3. **Diagnostic des résidus** : tests de Ljung-Box, test ARCH d'Engle et test de White, mettant en évidence une hétéroscédasticité conditionnelle à modéliser.
4. **Modélisation de la variance** : estimation par maximum de vraisemblance (sous hypothèse d'une distribution de Student) de quatre spécifications GARCH captant différentes formes de volatilité — GARCH(2,1), EGARCH(1,1), GJR-GARCH(1,1) et APARCH(1,1) — chacune avec et sans variables exogènes (8 modèles au total).
5. **Évaluation** : prévisions statiques hors échantillon, comparées sur 4 critères — RMSE, MAE, MAPE, coefficient d'inégalité de Theil (TIC).

## Résultats

| Modèle | RMSE | MAE | MAPE (%) | TIC |
|---|---|---|---|---|
| AR | 0.1494 | 0.1268 | 3.541 | 0.02025 |
| ARX | 0.1428 | 0.1250 | 3.467 | 0.01938 |
| AR-GARCH | 0.1420 | 0.1193 | 3.311 | 0.01928 |
| ARX-GARCH | 0.1396 | 0.1196 | 3.303 | 0.01897 |
| AR-EGARCH | 0.1408 | 0.1178 | 3.266 | 0.01912 |
| ARX-EGARCH | 0.1391 | 0.1175 | 3.240 | 0.01891 |
| AR-GJR-GARCH | 0.1713 | 0.1459 | 4.095 | 0.02311 |
| ARX-GJR-GARCH | 0.1392 | 0.1176 | 3.242 | 0.01892 |
| AR-APARCH | 0.1407 | 0.1178 | 3.264 | 0.01912 |
| **ARX-APARCH** | **0.1384** | **0.1164** | **3.209** | **0.01882** |

**Enseignements principaux :**
- L'intégration de l'énergie éolienne améliore systématiquement la performance prédictive et impacte négativement le prix (effet significatif à 1 %) — une production éolienne plus élevée est associée à des prix plus bas.
- La demande d'électricité n'apporte pas de gain prédictif significatif sur la période étudiée.
- La volatilité des prix est non linéaire, asymétrique et présente un effet de levier : les chocs négatifs impactent davantage la volatilité que les chocs positifs de même ampleur (EGARCH, GJR-GARCH, APARCH).
- Le modèle ARX-APARCH domine sur les 4 critères de performance (RMSE, MAE, MAPE, TIC) parmi les 10 spécifications comparées.

## Limites et perspectives

- La base de données ne couvre que la demande et la production éolienne parmi les variables exogènes envisagées ; le prix des combustibles fossiles (charbon, gaz naturel, CO2) et le solaire photovoltaïque n'ont pas pu être intégrés faute de disponibilité des données, ce qui limite l'évaluation complète de leur effet sur le prix.
- Contrairement à d'autres marchés (actions, matières premières), l'effet de levier inverse classique n'est pas confirmé ici : les chocs négatifs augmentent davantage la volatilité que les chocs positifs, un résultat cohérent avec une partie de la littérature mais qui mériterait d'être testé sur une période plus longue.
- Une extension naturelle consisterait à estimer les modèles ARX-GARCH par une approche bayésienne, qui permettrait de mieux quantifier l'incertitude des paramètres et de capter les sauts de volatilité, plutôt que le maximum de vraisemblance utilisé ici.
