# Schtroumpf Quest - Depistage TDAH par le jeu

Application mobile Flutter de depistage ludique du TDAH chez l'enfant, basee sur le protocole scientifique **Conners K-CPT 2** (Continuous Performance Test).

L'enfant aide les Schtroumpfs a rentrer chez eux en appuyant uniquement sur les maisons qui apparaissent parmi les personnages. Derriere ce jeu simple se cache un test attentionnel complet qui mesure 4 marqueurs cliniques valides.

---

## Fonctionnalites

### Pour l'enfant
- **Jeu visuel et ludique** avec les Schtroumpfs de Peyo (images BD classiques)
- **80 stimuli** dont 20% de cibles (maisons) - conforme protocole CPT
- **6 variantes de maisons** (couleurs differentes) et **19 personnages**
- **Feedback immediat** : retour visuel + haptique a chaque action
- **Systeme d'etoiles** (0-5) pour la motivation
- **Difficulte progressive** sur 6 niveaux (-50ms par niveau)

### Pour les parents
- **Detection automatique du profil attentionnel** : Typique, Haute Variabilite, Inattention, Impulsivite, Mixte
- **Conseils personnalises** selon le profil detecte :
  - Strategie 80/20 (forces a exploiter / faiblesses a travailler)
  - Actions au quotidien (routine, activites, choses a eviter)
  - Communication adaptee (quoi dire / ne pas dire)
  - Strategies ecole et devoirs
  - Quand et qui consulter
- **Historique des parties** avec suivi de progression
- **Avertissement medical** : le jeu n'est pas un diagnostic

---

## Marqueurs cliniques mesures

| Marqueur | Description | Seuil clinique | Source |
|----------|-------------|----------------|--------|
| **IIV (SD du RT)** | Variabilite intra-individuelle du temps de reaction - marqueur #1 du TDAH | >= 250ms | Kofler et al. 2013, PMC3413905 |
| **Omissions** | Cibles non detectees = inattention | >= 30% | BMC Pediatrics 2024 |
| **Commissions** | Fausses alarmes = impulsivite | >= 25% | BMC Pediatrics 2024 |
| **RT moyen** | Temps de reaction moyen | > 734ms | PMC5858546 |

---

## Profils detectes

| Profil | Critere | Indicateur |
|--------|---------|------------|
| Typique | Tous les marqueurs dans les normes | Bonne attention soutenue |
| Haute Variabilite | SD_RT >= 250ms | Fluctuation attentionnelle (Kofler 2013) |
| Inattention | Omissions >= 30% | Difficulte a detecter les cibles |
| Impulsivite | Commissions >= 25% | Reponses trop rapides sans attendre |
| Mixte | Omissions + Commissions elevees | Inattention + impulsivite combinees |

---

## Parametres du test

- **80 stimuli** (conforme Conners K-CPT 2)
- **20% de cibles** (maisons) / 80% de distracteurs (schtroumpfs)
- **ISI aleatoire** : 700-1400ms (inter-stimulus interval)
- **Duree stimulus** : 1100ms decroissant jusqu'a 500ms (fatigue attentionnelle simulee)
- **Duree totale** : ~7-8 minutes
- **Age cible** : 5-12 ans

---

## Stack technique

- **Flutter** (Dart) - SDK ^3.9.2
- **Material Design 3** - Theme complet light/dark avec tokens semantiques
- **SharedPreferences** - Stockage local de l'historique et progression
- **Architecture** : Single-file (~1700 lignes), pas d'over-engineering

### Design UX applique (Winter Tree)

- Grille d'espacement 8dp (tokens : 4, 8, 16, 24, 32, 48)
- Touch targets >= 48dp sur tous les elements interactifs
- Typographie M3 (headlineMedium, titleMedium, bodyLarge, labelLarge...)
- Transitions de page avec easing M3 (ease-out entree, ease-in sortie)
- Animations tokenisees (micro 150ms, standard 300ms)
- Cards avec elevation 2dp et borderRadius 16dp
- Empty states avec illustration + message + CTA
- Support dark mode automatique (ThemeMode.system)

---

## Installation

```bash
# Cloner le repo
git clone https://github.com/sky1241/s-TDHA-jeu.git
cd s-TDHA-jeu

# Installer les dependances
flutter pub get

# Lancer sur un appareil connecte
flutter run
```

---

## Sources scientifiques

- **Kofler et al. (2013)** - Meta-analyse de 319 etudes : IIV = marqueur #1 du TDAH
- **PMC3413905** - SD_RT : controles 204ms, TDAH 250ms+
- **PMC5858546** - RT moyen : controles 655ms, TDAH 734-844ms
- **BMC Pediatrics 2024 (PMC11515130)** - Seuils omissions/commissions enfants 6-12 ans
- **Barkley, R.A. (2015)** - Attention-Deficit Hyperactivity Disorder: A Handbook for Diagnosis and Treatment
- **DuPaul & Stoner (2014)** - ADHD in the Schools: Assessment and Intervention Strategies

---

## Avertissement

> Cette application est un **outil de depistage ludique**, pas un diagnostic medical. Les resultats sont des indicateurs de jeu bases sur des protocoles scientifiques valides. Pour toute evaluation TDAH, consultez un professionnel de sante (neuropediatre, pedopsychiatre, neuropsychologue).

---

*Developpe avec Flutter + Claude Code*
