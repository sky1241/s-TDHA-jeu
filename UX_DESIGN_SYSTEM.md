# Winter Tree - Design System Flutter

Reference UX rapide pour ce projet. Basee sur Material Design 3, iOS HIG, et les patterns universels.

---

## 1. Design Tokens

### Spacing (grille 8dp)

| Token | Valeur | Usage |
|-------|--------|-------|
| `xs`  | 4dp    | Micro-espacement, icon-text |
| `s`   | 8dp    | Gap elements lies |
| `m`   | 16dp   | Padding standard, marges ecran |
| `l`   | 24dp   | Separation groupes |
| `xl`  | 32dp   | Separation sections |
| `xxl` | 48dp   | Touch target min, grandes separations |

### Rayons (Border Radius)

| Token     | Valeur | Usage |
|-----------|--------|-------|
| `card`    | 16dp   | Cards, containers |
| `button`  | 28dp   | Boutons (pill shape) |
| `progress`| 8dp    | Barres de progression |
| `chip`    | 8dp    | Chips, tags profil |

### Animations

| Token    | Duree  | Usage |
|----------|--------|-------|
| `micro`  | 150ms  | Feedback micro-interactions |
| `standard`| 300ms | Transitions d'etat |
| `large`  | 500ms  | Grandes transitions, entrees |

### Easing

| Contexte | Courbe | Dart |
|----------|--------|------|
| Entree   | ease-out (decelere) | `Curves.easeOut` |
| Sortie   | ease-in (accelere) | `Curves.easeIn` |
| Sur place | ease-in-out | `Curves.easeInOut` |
| Rebond   | elastic-out | `Curves.elasticOut` |

---

## 2. Couleurs

### Strategie

- `ColorScheme.fromSeed(seedColor: Color(0xFF1565C0))` pour light + dark
- Jamais de hex en dur : toujours `cs.primary`, `cs.surface`, etc.
- Dark mode automatique via `ThemeMode.system`

### Roles semantiques utilises

| Role | Usage |
|------|-------|
| `primary` | Titres, boutons principaux, accents |
| `onSurface` | Texte principal |
| `onSurfaceVariant` | Texte secondaire |
| `outline` | Texte tertiaire, sous-titres discrets |
| `outlineVariant` | Bordures, dividers, icones inactives |
| `primaryContainer` | Fond gradient subtil (alpha 0.2-0.3) |
| `surfaceContainerLow` | Fond cards secondaires |
| `surfaceContainerHighest` | Fond cards stats |
| `errorContainer` | Cards donnees hors seuil |
| `tertiaryContainer` | Cards avertissement medical |
| `error` | Texte "a eviter", commissions |

### Couleurs profils

| Profil | Couleur |
|--------|---------|
| Typique | `Colors.green` |
| Haute variabilite | `Colors.blue` |
| Inattention | `Colors.orange` |
| Impulsivite | `Colors.red` |
| Mixte | `Colors.purple` |

### Contraste WCAG AA

- Texte normal : >= 4.5:1
- Texte large (>=18pt ou >=14pt bold) : >= 3:1
- Composants UI : >= 3:1

---

## 3. Typographie M3

| Style | Usage dans l'app |
|-------|-----------------|
| `displayLarge` | Countdown (96px custom) |
| `headlineMedium` | Titre "Schtroumpf Quest" |
| `headlineSmall` | Titres ecrans, messages enfant |
| `titleLarge` | Label bouton "Jouer !" |
| `titleMedium` | Valeurs data cards, consigne jeu |
| `titleSmall` | Niveau, sous-titres cards |
| `bodyLarge` | Description, messages |
| `bodySmall` | Labels, subtitles, sources |
| `labelLarge` | Boutons, progression |
| `labelMedium` | Sous-headers conseils |
| `labelSmall` | Chips profil |

---

## 4. Composants

### Boutons (touch target >= 48dp)

| Type | Usage | Style |
|------|-------|-------|
| `FilledButton` | Action principale (Jouer, Rejouer) | Pill shape, padding xl/m |
| `OutlinedButton` | Action secondaire (Historique, Accueil) | Bordure outlineVariant |
| `OutlinedButton.icon` | Vue parent | Icone + label, plus visible |
| `IconButton` | Retour | 48x48dp min, tooltip |

### Cards

| Variante | Usage |
|----------|-------|
| `Card(elevation: 4, clipBehavior: antiAlias)` | Image village hero |
| `Card(color: surfaceContainerHighest)` | Stats, niveaux |
| `Card(color: surfaceContainerLow)` | Data cards normales |
| `Card(color: errorContainer)` | Data cards hors seuil |
| `Card(color: tertiaryContainer)` | Avertissement medical |
| `_Advice(tint: color)` | Cards conseils (tint a 6% opacite) |

### Progress indicators

- `LinearProgressIndicator` avec `ClipRRect(borderRadius: 8dp)`
- Couleur : `cs.primary` sur fond `surfaceContainerLow`
- Hauteur : 6-8dp

---

## 5. Patterns UX

### Transitions de page (shared axis M3)

```dart
FadeTransition + SlideTransition(Offset(0.04, 0))
duration: 300ms
enter: easeOut / exit: easeIn
```

### Gradient fond d'ecran

```dart
LinearGradient(
  topCenter -> bottomCenter,
  [cs.primaryContainer.withValues(alpha: 0.2-0.3), cs.surface],
)
```

Applique sur : Home, Game, Result.

### Countdown (onboarding pattern)

- 3-2-1 avant le jeu
- `AnimatedSwitcher` + `ScaleTransition(elasticOut)`
- Haptic `selectionClick()` a chaque seconde
- Icone `touch_app` + instruction "Appuie quand tu vois une maison !"

### Feedback jeu

| Action | Visuel | Haptic |
|--------|--------|--------|
| Bon tap (maison) | \u2714 vert, scale bounce | `lightImpact` |
| Mauvais tap (smurf) | \u2718 rouge, scale pop | `heavyImpact` |
| Maison ratee | ! orange | - |
| Countdown tick | - | `selectionClick` |

### Animations staggered (resultats)

- Emoji profil : fade 0-0.3
- Etoiles : chaque etoile decalee de 0.1 (0.2, 0.3, 0.4...) avec elasticOut
- Message : fade 0.5-0.8
- Total : 1200ms

### Empty state (historique)

Structure Winter Tree :
1. Icone contextuelle (64dp, outlineVariant)
2. Titre explicatif
3. Message secondaire
4. CTA primaire (FilledButton.icon)

### Scroll physics

- `BouncingScrollPhysics()` sur les listes scrollables (parent view, historique)

### Accessibilite

- `Semantics(label: ...)` sur les images (village, stimuli jeu)
- `tooltip` sur les IconButton
- Touch targets >= 48dp partout
- Dark mode automatique

---

## 6. Architecture fichiers

```
lib/
  main.dart          # App complete (~1660 lignes)

assets/
  images/
    village_stroumpf.jpg    # Hero image accueil
    maison_*.png            # 6 cibles (rouge, bleu, vert, jaune, violet, orange)
    *.jpg / *.png           # 19 distracteurs (schtroumpfs)

test/
  widget_test.dart   # Test de lancement basique
```

### Classes principales

| Classe | Role |
|--------|------|
| `SchtroumpfApp` | MaterialApp, theme light/dark |
| `HomeScreen` | Accueil avec stats et progression |
| `GameScreen` | Jeu CPT (80 stimuli, countdown) |
| `ResultScreen` | Switch kid/parent view |
| `_KidView` | Resultats enfant avec etoiles |
| `_ParentView` | Resultats detailles + conseils |
| `HistoryScreen` | Historique des parties |
| `GameResult` | Modele donnees + calcul profil |
| `GameHistory` | Persistence SharedPreferences |

### Widgets reutilisables

| Widget | Usage |
|--------|-------|
| `_Section` | Titre de section (titleMedium bold primary) |
| `_DataCard` | Carte donnee clinique (icone + label + valeur + subtitle) |
| `_Advice` | Carte conseil avec tint couleur |
| `_Header` | En-tete icone + texte dans advice card |
| `_Bullets` | Liste a puces |

### Cards conseils par profil

| Card | Couleur tint | Contenu |
|------|-------------|---------|
| `_EightyTwentyCard` | green / primary | Strategie 80/20 (forces/faiblesses) |
| `_ActivitiesCard` | deepOrange | Exercices psy (memoire, inhibition, attention, regulation) |
| `_DailyActionsCard` | purple | Routine, activites, a eviter |
| `_CommunicationCard` | teal | Quoi dire / ne pas dire / lien |
| `_SchoolCard` | indigo | Devoirs + ecole |
| `_WhenToConsultCard` | green/error | Quand consulter + ressources |

---

## 7. Regles a toujours respecter

1. **Touch target >= 48dp** sur TOUT element interactif
2. **Espacement grille 8dp** (xs=4, s=8, m=16, l=24, xl=32, xxl=48)
3. **Pas de hex en dur** : utiliser les roles semantiques ColorScheme
4. **Feedback < 100ms** sur chaque interaction (haptic + visuel)
5. **Animations tokenisees** : micro 150ms, standard 300ms, large 500ms
6. **Easing directionnel** : ease-out entree, ease-in sortie
7. **Empty states** : icone + titre + message + CTA
8. **Gradient subtil** sur les ecrans principaux (primaryContainer alpha 0.2)
9. **Semantics** sur les images et elements visuels
10. **Scroll BouncingScrollPhysics** sur les listes
