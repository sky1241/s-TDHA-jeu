import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------
// Sources scientifiques implementees :
//   - Kofler et al. (2013) - meta-analyse 319 etudes IIV ADHD
//   - PMC5858546 - RT moyen controles ~655ms, ADHD ~734-844ms
//   - PMC3413905 - SD_RT controles ~204ms, ADHD ~250ms+
//   - BMC Pediatrics 2024 (PMC11515130) - omissions/commissions
//
// Marqueurs cliniques implementes :
//   1. SD du temps de reaction (IIV) = marqueur #1 TDAH
//   2. Taux d'omission  = inattention
//   3. Taux de commission = impulsivite
//   4. RT moyen (secondaire)
// ---------------------------------------------------------------

// ---------------------------------------------------------------
// DESIGN TOKENS (Winter Tree UX - MOBILE.md)
// Spacing: base 8dp, Touch: 48dp min, Animations: tokenized
// Typography: M3 scale, Colors: semantic roles
// ---------------------------------------------------------------
class _Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class _Anim {
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 300);
  static const Curve enterCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
}

class _Radii {
  static const double card = 16.0;
  static const double button = 28.0;
  static const double progressBar = 8.0;
}

// ---------------------------------------------------------------
// HISTORIQUE & PROGRESSION
// ---------------------------------------------------------------
class GameHistory {
  static const _key = 'game_history';
  static const _levelKey = 'difficulty_level';

  static Future<List<Map<String, dynamic>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> save(GameResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    history.add(jsonEncode({
      'date': DateTime.now().toIso8601String(),
      'hits': result.hits,
      'totalTargets': result.totalTargets,
      'misses': result.misses,
      'falseAlarms': result.falseAlarms,
      'meanRtMs': result.meanRtMs,
      'sdRtMs': result.sdRtMs,
      'stars': result.stars,
      'profile': result.profile.index,
    }));
    await prefs.setStringList(_key, history);

    final level = prefs.getInt(_levelKey) ?? 0;
    if (result.stars >= 3 && level < 5) {
      await prefs.setInt(_levelKey, level + 1);
    }
  }

  static Future<int> getLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_levelKey) ?? 0;
  }

  static Future<int> getBestStars() async {
    final history = await load();
    if (history.isEmpty) return 0;
    return history.map((h) => (h['stars'] as num?)?.toInt() ?? 0).reduce(max);
  }

  static Future<int> getTotalGames() async {
    final history = await load();
    return history.length;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SchtroumpfApp());
}

// ---------------------------------------------------------------
// M3 THEME - Semantic color roles, typography scale
// ---------------------------------------------------------------
final _lightScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1565C0),
  brightness: Brightness.light,
);

final _darkScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF1565C0),
  brightness: Brightness.dark,
);

class SchtroumpfApp extends StatelessWidget {
  const SchtroumpfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schtroumpf Quest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: _lightScheme,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_Radii.card),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl), // 48dp touch target
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_Radii.button),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl), // 48dp touch target
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_Radii.button),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl), // 48dp touch target
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false, // M3 Android: left-aligned title
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: _darkScheme,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_Radii.card),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_Radii.button),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_Radii.button),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _Spacing.xxl),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------
// PAGE TRANSITION - M3 easing: ease-out for entering
// ---------------------------------------------------------------
Route<T> _buildPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: _Anim.enterCurve,
          reverseCurve: _Anim.exitCurve,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.05, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: _Anim.enterCurve,
          )),
          child: child,
        ),
      );
    },
    transitionDuration: _Anim.standard,
    reverseTransitionDuration: _Anim.standard,
  );
}

// ---------------------------------------------------------------
// HOME SCREEN
// ---------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _totalGames = 0;
  int _bestStars = 0;
  int _level = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final games = await GameHistory.getTotalGames();
    final stars = await GameHistory.getBestStars();
    final level = await GameHistory.getLevel();
    if (mounted) {
      setState(() {
        _totalGames = games;
        _bestStars = stars;
        _level = level;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: _Spacing.m),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: _Spacing.l),
                // Village image with M3 card treatment
                ClipRRect(
                  borderRadius: BorderRadius.circular(_Radii.card),
                  child: Image.asset(
                    'assets/images/village_stroumpf.jpg',
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: _Spacing.l),
                // Title - M3 Headline Medium (28sp)
                Text(
                  'Schtroumpf Quest',
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: _Spacing.s),
                // Subtitle - M3 Body Large (16sp)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _Spacing.m),
                  child: Text(
                    'Aide les Schtroumpfs a rentrer chez eux !\nAppuie sur la maison quand tu la vois !',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                // Stats chip - only when games played
                if (_totalGames > 0) ...[
                  const SizedBox(height: _Spacing.m),
                  Card(
                    color: cs.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _Spacing.l,
                        vertical: _Spacing.s + _Spacing.xs,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Niveau $_level  |  $_totalGames parties jouees',
                            style: tt.labelLarge?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: _Spacing.xs),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Record : ', style: tt.labelLarge?.copyWith(color: cs.primary)),
                              ...List.generate(5, (i) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Icon(
                                  i < _bestStars ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: i < _bestStars ? Colors.amber : cs.outlineVariant,
                                  size: 22,
                                ),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: _Spacing.xl),
                // Play button - 48dp+ touch target, M3 filled button
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      _buildPageRoute(const GameScreen()),
                    );
                    _loadStats();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _Spacing.xxl,
                      vertical: _Spacing.m,
                    ),
                    textStyle: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Jouer !'),
                ),
                const SizedBox(height: _Spacing.m),
                // History button - 48dp+ touch target
                if (_totalGames > 0)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        _buildPageRoute(const HistoryScreen()),
                      );
                    },
                    icon: const Icon(Icons.timeline_rounded),
                    label: Text('Historique', style: tt.labelLarge),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _Spacing.l,
                        vertical: _Spacing.s + _Spacing.xs,
                      ),
                    ),
                  ),
                const SizedBox(height: _Spacing.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// GAME LOGIC
// ---------------------------------------------------------------
enum StimulusType { smurf, house }

class Stimulus {
  final StimulusType type;
  final DateTime shownAt;
  final String asset;
  bool responded = false;

  Stimulus({required this.type, required this.asset})
      : shownAt = DateTime.now();
}

enum AttentionProfile {
  typical,
  highVariability,
  inattention,
  impulsivity,
  mixed,
}

class GameResult {
  final int totalTargets;
  final int hits;
  final int misses;
  final int falseAlarms;
  final double meanRtMs;
  final double sdRtMs;

  const GameResult({
    required this.totalTargets,
    required this.hits,
    required this.misses,
    required this.falseAlarms,
    required this.meanRtMs,
    required this.sdRtMs,
  });

  double get omissionRate => totalTargets == 0 ? 0 : misses / totalTargets;

  double get commissionRate {
    final distractors = 80 - totalTargets;
    return distractors == 0 ? 0 : falseAlarms / distractors;
  }

  AttentionProfile get profile {
    final highIIV = sdRtMs >= 250;
    final highOmission = omissionRate >= 0.30;
    final highCommission = commissionRate >= 0.25;

    if (highOmission && highCommission) return AttentionProfile.mixed;
    if (highOmission) return AttentionProfile.inattention;
    if (highCommission) return AttentionProfile.impulsivity;
    if (highIIV) return AttentionProfile.highVariability;
    return AttentionProfile.typical;
  }

  String get profileLabel {
    switch (profile) {
      case AttentionProfile.typical:
        return 'Bonne attention soutenue';
      case AttentionProfile.highVariability:
        return 'Attention variable';
      case AttentionProfile.inattention:
        return 'Inattention predominante';
      case AttentionProfile.impulsivity:
        return 'Impulsivite predominante';
      case AttentionProfile.mixed:
        return 'Mixte (inattention + impulsivite)';
    }
  }

  String get profileEmoji {
    switch (profile) {
      case AttentionProfile.typical:
        return '???';
      case AttentionProfile.highVariability:
        return '????';
      case AttentionProfile.inattention:
        return '????';
      case AttentionProfile.impulsivity:
        return '???';
      case AttentionProfile.mixed:
        return '????';
    }
  }

  String get kidMessage {
    switch (profile) {
      case AttentionProfile.typical:
        return 'Super ! Tu as trouve toutes les maisons !';
      case AttentionProfile.highVariability:
        return 'Bien joue ! Continue a t\'entrainer !';
      case AttentionProfile.inattention:
        return 'Bien essaye ! La prochaine fois, prends ton temps !';
      case AttentionProfile.impulsivity:
        return 'Tu es rapide comme l\'eclair ! Attends bien la maison !';
      case AttentionProfile.mixed:
        return 'Beau parcours ! Tu t\'ameliores a chaque partie !';
    }
  }

  int get stars {
    int s = 0;
    if (totalTargets > 0 && hits / totalTargets >= 0.5) s++;
    if (totalTargets > 0 && hits / totalTargets >= 0.75) s++;
    if (totalTargets > 0 && hits / totalTargets >= 0.90) s++;
    if (commissionRate < 0.15) s++;
    if (sdRtMs < 250 && sdRtMs > 0) s++;
    return s;
  }

  String get rtCategory {
    if (meanRtMs < 655) return 'Tres rapide';
    if (meanRtMs < 734) return 'Dans la norme';
    if (meanRtMs < 810) return 'Un peu lent';
    return 'Lent';
  }

  String get variabilityCategory {
    if (sdRtMs < 204) return 'Tres regulier';
    if (sdRtMs < 250) return 'Regulier';
    if (sdRtMs < 298) return 'Variable';
    return 'Tres variable';
  }
}

// ---------------------------------------------------------------
// GAME SCREEN
// ---------------------------------------------------------------
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const int totalRounds = 80;
  static const double houseProbability = 0.20;

  final _rng = Random();
  final List<Stimulus> _stimuli = [];
  final List<double> _reactionTimes = [];

  late List<String> _smurfQueue;
  late List<String> _houseQueue;
  String? _lastAsset;

  int _currentRound = 0;
  Stimulus? _currentStimulus;
  bool _waitingForNext = false;
  Timer? _stimulusTimer;
  Timer? _interTimer;
  bool _gameOver = false;
  int _difficultyLevel = 0;

  String? _feedbackIcon;
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  Duration get _stimulusDuration {
    final levelPenalty = _difficultyLevel * 50;
    final base = 1100 - levelPenalty - (_currentRound * 12);
    return Duration(milliseconds: base.clamp(500, 1100));
  }

  Duration get _interStimulusDuration =>
      Duration(milliseconds: 700 + _rng.nextInt(700));

  String _pickAsset(List<String> queue, List<String> allAssets) {
    if (queue.isEmpty) {
      queue.addAll(allAssets);
      queue.shuffle(_rng);
    }
    if (queue.length > 1 && queue.first == _lastAsset) {
      final moved = queue.removeAt(0);
      queue.add(moved);
    }
    final picked = queue.removeAt(0);
    _lastAsset = picked;
    return picked;
  }

  void _showFeedback(String icon, Color color) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackIcon = icon;
      _feedbackColor = color;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _feedbackIcon = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _smurfQueue = List.of(_smurfAssets)..shuffle(_rng);
    _houseQueue = List.of(_houseAssets)..shuffle(_rng);
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: _Anim.standard,
    );
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
    GameHistory.getLevel().then((level) {
      _difficultyLevel = level;
    });
    _startNextStimulus();
  }

  @override
  void dispose() {
    _stimulusTimer?.cancel();
    _interTimer?.cancel();
    _feedbackTimer?.cancel();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _startNextStimulus() {
    if (_currentRound >= totalRounds) {
      _endGame();
      return;
    }

    final isHouse = _rng.nextDouble() < houseProbability;
    final stim = Stimulus(
      type: isHouse ? StimulusType.house : StimulusType.smurf,
      asset: isHouse
          ? _pickAsset(_houseQueue, _houseAssets)
          : _pickAsset(_smurfQueue, _smurfAssets),
    );
    _stimuli.add(stim);

    setState(() {
      _currentStimulus = stim;
      _waitingForNext = false;
      _currentRound++;
    });

    _bounceCtrl.forward(from: 0);

    _stimulusTimer = Timer(_stimulusDuration, () {
      if (stim.type == StimulusType.house && !stim.responded) {
        _showFeedback('!', Colors.orange);
      }
      setState(() => _currentStimulus = null);
      _waitingForNext = true;
      _interTimer = Timer(_interStimulusDuration, _startNextStimulus);
    });
  }

  void _onTap() {
    if (_waitingForNext || _currentStimulus == null || _gameOver) return;
    final stim = _currentStimulus!;
    if (stim.responded) return;
    stim.responded = true;

    if (stim.type == StimulusType.house) {
      final rtMs =
          DateTime.now().difference(stim.shownAt).inMicroseconds / 1000.0;
      _reactionTimes.add(rtMs);
      _bounceCtrl.reverse();
      HapticFeedback.lightImpact();
      _showFeedback('???', Colors.green);
    } else {
      HapticFeedback.heavyImpact();
      _showFeedback('???', Colors.red);
    }
  }

  void _endGame() {
    setState(() => _gameOver = true);
    _stimulusTimer?.cancel();
    _interTimer?.cancel();

    int totalTargets = 0, hits = 0, misses = 0, falseAlarms = 0;
    for (final s in _stimuli) {
      if (s.type == StimulusType.house) {
        totalTargets++;
        s.responded ? hits++ : misses++;
      } else {
        if (s.responded) falseAlarms++;
      }
    }

    final meanRt = _reactionTimes.isEmpty
        ? 0.0
        : _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;

    double sdRt = 0;
    if (_reactionTimes.length >= 2) {
      final variance = _reactionTimes
              .map((rt) => (rt - meanRt) * (rt - meanRt))
              .reduce((a, b) => a + b) /
          (_reactionTimes.length - 1);
      sdRt = sqrt(variance);
    }

    final result = GameResult(
      totalTargets: totalTargets,
      hits: hits,
      misses: misses,
      falseAlarms: falseAlarms,
      meanRtMs: meanRt,
      sdRtMs: sdRt,
    );

    GameHistory.save(result);

    Future.delayed(_Anim.standard, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _buildPageRoute(ResultScreen(result: result)),
      );
    });
  }

  static const _houseAssets = [
    'assets/images/maison_rouge.png',
    'assets/images/maison_bleu.png',
    'assets/images/maison_vert.png',
    'assets/images/maison_jaune.png',
    'assets/images/maison_violet.png',
    'assets/images/maison_orange.png',
  ];

  static const _smurfAssets = [
    'assets/images/grognion.jpg',
    'assets/images/bricoleur.jpg',
    'assets/images/lunette.jpg',
    'assets/images/stroumpfette.jpg',
    'assets/images/grand_stroumpf.jpg',
    'assets/images/cuisinier.jpg',
    'assets/images/farceur.png',
    'assets/images/gourmand.png',
    'assets/images/costo.jpg',
    'assets/images/coquet.jpg',
    'assets/images/paysant.jpg',
    'assets/images/pareseu.jpg',
    'assets/images/musicien.jpg',
    'assets/images/noir.jpg',
    'assets/images/bebe.jpg',
    'assets/images/gargamel.jpg',
    'assets/images/azrael.jpg',
    'assets/images/cosmonaute.jpg',
    'assets/images/reporter.png',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = _currentRound / totalRounds;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: Column(
              children: [
                // Progress bar area
                Padding(
                  padding: const EdgeInsets.all(_Spacing.m),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_Radii.progressBar),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: cs.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                      const SizedBox(height: _Spacing.s),
                      Text(
                        '$_currentRound / $totalRounds',
                        style: tt.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Stimulus image + feedback overlay
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: _bounceAnim,
                      child: SizedBox(
                        height: 200,
                        child: _currentStimulus == null
                            ? const SizedBox.shrink()
                            : Image.asset(
                                _currentStimulus!.asset,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    if (_feedbackIcon != null)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: _Anim.micro,
                        curve: _Anim.enterCurve,
                        builder: (_, val, child) => Opacity(
                          opacity: val,
                          child: Transform.scale(
                            scale: 0.5 + val * 0.5,
                            child: child,
                          ),
                        ),
                        child: Text(
                          _feedbackIcon!,
                          style: TextStyle(
                            fontSize: 80,
                            color: _feedbackColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                // Instruction text
                Padding(
                  padding: const EdgeInsets.only(bottom: _Spacing.xxl),
                  child: Text(
                    'Appuie sur la maison !',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// RESULT SCREEN
// ---------------------------------------------------------------
class ResultScreen extends StatefulWidget {
  final GameResult result;

  const ResultScreen({super.key, required this.result});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _parentMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: _Anim.standard,
          switchInCurve: _Anim.enterCurve,
          switchOutCurve: _Anim.exitCurve,
          child: _parentMode
              ? _ParentView(
                  key: const ValueKey('parent'),
                  result: widget.result,
                  onBack: () => setState(() => _parentMode = false),
                )
              : _KidView(
                  key: const ValueKey('kid'),
                  result: widget.result,
                  onParentMode: () => setState(() => _parentMode = true),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// KID VIEW - positive, no stressful numbers
// ---------------------------------------------------------------
class _KidView extends StatelessWidget {
  final GameResult result;
  final VoidCallback onParentMode;

  const _KidView({super.key, required this.result, required this.onParentMode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_Spacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(result.profileEmoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: _Spacing.m),
            // Stars row - icons instead of text emojis
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < result.stars ? Icons.star_rounded : Icons.star_border_rounded,
                  color: i < result.stars ? Colors.amber : cs.outlineVariant,
                  size: 36,
                ),
              )),
            ),
            const SizedBox(height: _Spacing.l),
            Text(
              result.kidMessage,
              textAlign: TextAlign.center,
              style: tt.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: _Spacing.s),
            Text(
              'Maisons trouvees : ${result.hits} / ${result.totalTargets}',
              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: _Spacing.xl + _Spacing.s),
            // Action buttons - 48dp+ touch targets, 8dp gap
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    _buildPageRoute(const GameScreen()),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _Spacing.l,
                      vertical: _Spacing.s + _Spacing.xs,
                    ),
                  ),
                  child: Text('Rejouer', style: tt.labelLarge),
                ),
                const SizedBox(width: _Spacing.s),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _Spacing.l,
                      vertical: _Spacing.s + _Spacing.xs,
                    ),
                  ),
                  child: Text('Accueil', style: tt.labelLarge),
                ),
              ],
            ),
            const SizedBox(height: _Spacing.l),
            TextButton(
              onPressed: onParentMode,
              child: Text(
                'Vue parent',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// PARENT VIEW - clinical data + advice
// ---------------------------------------------------------------
class _ParentView extends StatelessWidget {
  final GameResult result;
  final VoidCallback onBack;

  const _ParentView({super.key, required this.result, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(_Spacing.m + _Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with back button - 48dp touch target
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded, color: cs.primary),
                iconSize: 24,
                constraints: const BoxConstraints(
                  minWidth: _Spacing.xxl,
                  minHeight: _Spacing.xxl,
                ),
              ),
              const SizedBox(width: _Spacing.s),
              Text(
                'Resultats detailles',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: _Spacing.s),

          // Warning banner
          Card(
            color: cs.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(_Spacing.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: cs.onTertiaryContainer, size: 20),
                  const SizedBox(width: _Spacing.s),
                  Expanded(
                    child: Text(
                      'Ces donnees sont des indicateurs de jeu, pas un diagnostic medical. '
                      'Consultez un professionnel de sante pour toute evaluation TDAH.',
                      style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Profil observe'),
          _DataCard(
            icon: result.profileEmoji,
            label: 'Profil',
            value: result.profileLabel,
            subtitle: _profileExplanation(result.profile),
          ),
          const SizedBox(height: _Spacing.s),

          _SectionTitle('Temps de reaction (RT)'),
          _DataCard(
            icon: '???',
            label: 'RT moyen',
            value:
                '${result.meanRtMs > 0 ? result.meanRtMs.toStringAsFixed(0) : "--"} ms',
            subtitle:
                '${result.rtCategory}  |  Norme saine ~655ms, TDAH ~734ms',
            highlight: result.meanRtMs > 734 && result.meanRtMs > 0,
          ),
          const SizedBox(height: _Spacing.s),
          _DataCard(
            icon: '????',
            label: 'Variabilite du RT (IIV)',
            value:
                '${result.sdRtMs > 0 ? result.sdRtMs.toStringAsFixed(0) : "--"} ms',
            subtitle:
                '${result.variabilityCategory}  |  Norme ~204ms, TDAH >=250ms',
            highlight: result.sdRtMs >= 250,
          ),
          const SizedBox(height: _Spacing.s),

          _SectionTitle('Erreurs'),
          _DataCard(
            icon: '????',
            label: 'Omissions (maisons ratees)',
            value:
                '${result.misses} / ${result.totalTargets}  (${(result.omissionRate * 100).toStringAsFixed(0)}%)',
            subtitle: 'Seuil clinique : >=30% = inattention marquee',
            highlight: result.omissionRate >= 0.30,
          ),
          const SizedBox(height: _Spacing.s),
          _DataCard(
            icon: '???',
            label: 'Commissions (fausses alarmes)',
            value:
                '${result.falseAlarms}  (${(result.commissionRate * 100).toStringAsFixed(0)}%)',
            subtitle: 'Seuil clinique : >=25% = impulsivite marquee',
            highlight: result.commissionRate >= 0.25,
          ),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Strategie 80 / 20'),
          _EightyTwentyCard(profile: result.profile),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Actions au quotidien'),
          _DailyActionsCard(profile: result.profile),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Communiquer avec votre enfant'),
          _CommunicationCard(profile: result.profile),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('A l\'ecole et aux devoirs'),
          _SchoolCard(profile: result.profile),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Quand consulter un professionnel ?'),
          _WhenToConsultCard(profile: result.profile),
          const SizedBox(height: _Spacing.l),

          _SectionTitle('Sources scientifiques'),
          Text(
            '- Kofler et al. (2013) - Meta-analyse 319 etudes : IIV = marqueur #1 TDAH\n'
            '- PMC3413905 - SD_RT : controles 204ms, TDAH 250ms\n'
            '- PMC5858546 - RT moyen : controles 655ms, TDAH 734-844ms\n'
            '- BMC Pediatrics 2024 - seuils omissions/commissions enfants 6-12 ans\n'
            '- Barkley, R.A. (2015) - Attention-Deficit Hyperactivity Disorder: A Handbook\n'
            '- DuPaul & Stoner (2014) - ADHD in the Schools',
            style: tt.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: _Spacing.l),
        ],
      ),
    );
  }

  String _profileExplanation(AttentionProfile p) {
    switch (p) {
      case AttentionProfile.typical:
        return 'RT et variabilite dans les normes saines';
      case AttentionProfile.highVariability:
        return 'SD_RT >=250ms : variabilite elevee, signe caracteristique TDAH (Kofler 2013)';
      case AttentionProfile.inattention:
        return 'Taux d\'omission >=30% : difficulte a detecter la cible';
      case AttentionProfile.impulsivity:
        return 'Taux de commission >=25% : tendance a repondre sans attendre';
      case AttentionProfile.mixed:
        return 'Omissions et commissions elevees simultanement';
    }
  }
}

// ---------------------------------------------------------------
// REUSABLE DESIGN COMPONENTS - M3 styling
// ---------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _Spacing.s),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String subtitle;
  final bool highlight;

  const _DataCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: highlight ? cs.errorContainer : cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(_Spacing.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: _Spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: _Spacing.xs),
                  Text(
                    value,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: highlight ? cs.onErrorContainer : cs.primary,
                    ),
                  ),
                  const SizedBox(height: _Spacing.xs),
                  Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// ADVICE CARD HELPER - consistent styling
// ---------------------------------------------------------------
class _AdviceCard extends StatelessWidget {
  final Color? cardColor;
  final List<Widget> children;

  const _AdviceCard({this.cardColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(_Spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _AdviceSectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _AdviceSectionHeader({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: _Spacing.s),
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final String prefix;
  final TextStyle? style;

  const _BulletList({
    required this.items,
    this.prefix = '-',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: _Spacing.xs),
        child: Text('$prefix $s', style: style ?? defaultStyle),
      )).toList(),
    );
  }
}

// ---------------------------------------------------------------
// 80/20 CARD
// ---------------------------------------------------------------
class _EightyTwentyCard extends StatelessWidget {
  final AttentionProfile profile;
  const _EightyTwentyCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      strengths: [
        'Attention soutenue sur la duree',
        'Regularite et coherence dans les taches',
        'Bonne gestion des consignes simples',
      ],
      weaknesses: [
        'Risque d\'ennui sur taches repetitives',
        'Peut manquer de flexibilite si interruption',
      ],
      tips80: [
        'Proposer des taches structurees et rhythmees',
        'Exploiter la regularite : plannings fixes, routines',
        'Valoriser les projets longs qui demandent de la perseverance',
      ],
      tips20: [
        'Introduire de la variete pour eviter la saturation',
        'Apprendre a gerer les interruptions avec des signaux visuels',
      ],
    ),
    AttentionProfile.highVariability: (
      strengths: [
        'Flexibilite cognitive elevee',
        'Forte reactivite aux nouveaux stimuli',
        'Creativite et pensee associative',
      ],
      weaknesses: [
        'Incoherence dans la vitesse de traitement',
        'Difficulte a maintenir un rythme stable',
      ],
      tips80: [
        'Environnement stimulant et change regulierement',
        'Taches courtes avec variations frequentes',
        'Exploiter la creativite : arts, improvisation, projets ouverts',
      ],
      tips20: [
        'Introduire des routines courtes pour ancrer le focus',
        'Timer visible pour creer des intervalles previsibles',
      ],
    ),
    AttentionProfile.inattention: (
      strengths: [
        'Vision globale et pensee divergente',
        'Curiosite et interet pour les sujets qui passionnent',
        'Creativite et imagination',
      ],
      weaknesses: [
        'Detection des stimuli cibles dans le flux',
        'Maintien de l\'attention sur la duree',
      ],
      tips80: [
        'Projets visuels, creatifs, en mouvement',
        'Hyperfocus : identifier les passions et s\'appuyer dessus',
        'Apprentissage par l\'histoire, la narration, les jeux de role',
      ],
      tips20: [
        'Sessions courtes (10-15 min max) avec pauses',
        'Check-listes visuelles et rappels colores',
        'Reduire les distracteurs visuels dans l\'environnement de travail',
      ],
    ),
    AttentionProfile.impulsivity: (
      strengths: [
        'Rapidite de reaction et reflexes vifs',
        'Enthousiasme et energie',
        'Leadership naturel et prise d\'initiative',
      ],
      weaknesses: [
        'Controle inhibiteur : attendre avant d\'agir',
        'Reponses precipitees sans verifier',
      ],
      tips80: [
        'Sports de reaction : tennis, judo, foot, basket',
        'Jeux rapides ou la vitesse est un avantage',
        'Brainstorming, debats, activites orales dynamiques',
      ],
      tips20: [
        'Technique STOP : compter jusqu\'a 3 avant de repondre',
        'Relecture systematique avant de valider',
        'Jeux de patience courts pour entrainer l\'inhibition',
      ],
    ),
    AttentionProfile.mixed: (
      strengths: [
        'Energie et spontaneite',
        'Traitement rapide en mode rafale',
        'Adaptabilite a des contextes varies',
      ],
      weaknesses: [
        'Focus soutenu : attention qui se disperse',
        'Controle inhibiteur : reponses sans attendre la cible',
      ],
      tips80: [
        'Activites physiques et sport : canal naturel pour l\'energie',
        'Projets courts et intenses avec objectifs clairs',
        'Apprentissage kinesthesique : manipuler, bouger, construire',
      ],
      tips20: [
        'Structure externe forte : timer, planning visuel, routine fixe',
        'Recompenses immediates pour chaque petite etape',
        'Techniques de pleine conscience adaptees aux enfants (2-3 min)',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;

    return Column(
      children: [
        // Strengths 80%
        _AdviceCard(
          cardColor: Colors.green.withValues(alpha: 0.08),
          children: [
            const _AdviceSectionHeader(
              icon: Icons.fitness_center_rounded,
              text: 'Points forts - exploiter a 80%',
              color: Colors.green,
            ),
            const SizedBox(height: _Spacing.s),
            _BulletList(items: d.strengths, prefix: '-'),
            Divider(color: cs.outlineVariant, height: _Spacing.l),
            Text('Comment les exploiter :', style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: _Spacing.xs),
            _BulletList(items: d.tips80, prefix: '->'),
          ],
        ),
        const SizedBox(height: _Spacing.s),
        // Weaknesses 20%
        _AdviceCard(
          cardColor: cs.primaryContainer.withValues(alpha: 0.3),
          children: [
            _AdviceSectionHeader(
              icon: Icons.track_changes_rounded,
              text: 'Points a travailler - 20% seulement',
              color: cs.primary,
            ),
            const SizedBox(height: _Spacing.s),
            _BulletList(items: d.weaknesses, prefix: '-'),
            Divider(color: cs.outlineVariant, height: _Spacing.l),
            Text('Strategies :', style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: _Spacing.xs),
            _BulletList(items: d.tips20, prefix: '->'),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// ACTIONS AU QUOTIDIEN
// ---------------------------------------------------------------
class _DailyActionsCard extends StatelessWidget {
  final AttentionProfile profile;
  const _DailyActionsCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      routine: [
        'Maintenir un rythme regulier : lever, repas, coucher a heures fixes',
        'Alterner temps calme et temps actif dans la journee',
        'Encourager les activites de groupe pour developper la cooperation',
      ],
      activities: [
        'Jeux de societe avec regles progressives (echecs, Uno, Dobble)',
        'Lecture quotidienne 15-20 min : renforce l\'attention soutenue',
        'Sports d\'endurance : velo, natation, course',
      ],
      avoid: [
        'Ecrans passifs plus de 30 min d\'affilee',
        'Surcharger l\'emploi du temps : garder du temps libre non structure',
      ],
    ),
    AttentionProfile.highVariability: (
      routine: [
        'Routine visuelle affichee (pictogrammes) : matin, apres-midi, soir',
        'Timer colore (Time Timer) pour decouper les activites en blocs de 10-15 min',
        'Transitions annoncees 5 min a l\'avance : "Dans 5 min on passe a..."',
      ],
      activities: [
        'Arts plastiques, musique, danse : valorisent la creativite',
        'Jeux de construction (Lego, Kapla) : structurent la pensee',
        'Sport avec variete : parcours d\'obstacles, escalade, arts martiaux',
      ],
      avoid: [
        'Taches monotones sans pauses : fractionner en petits objectifs',
        'Punir la lenteur ou l\'irregularite : c\'est neurologique, pas de la mauvaise volonte',
      ],
    ),
    AttentionProfile.inattention: (
      routine: [
        'Routine matinale simplifiee : max 4-5 etapes avec pictogrammes',
        'Poser les affaires du lendemain la veille (cartable, vetements)',
        'Creer un "coin calme" pour les devoirs : peu de stimuli visuels',
      ],
      activities: [
        'Jeux de piste, chasses au tresor : mobilisent l\'attention de facon ludique',
        'Dessin, peinture, modelage : canalisent le monde interieur riche',
        'Promenades en nature avec missions d\'observation (compter les oiseaux...)',
      ],
      avoid: [
        'Repeter "concentre-toi !" : inefficace et decourageant',
        'Donner plusieurs consignes a la fois : une seule a la fois, verifier la comprehension',
        'Comparer avec les freres/soeurs ou camarades',
      ],
    ),
    AttentionProfile.impulsivity: (
      routine: [
        'Activite physique AVANT les devoirs (20 min minimum)',
        'Balle anti-stress ou fidget autorise pendant les taches calmes',
        'Feliciter chaque fois que l\'enfant attend son tour ou leve la main',
      ],
      activities: [
        'Sports de combat cadres (judo, karate) : apprennent le controle du corps',
        'Jeux de role et theatre : apprennent a ecouter et attendre',
        'Cuisine ensemble : suivre des etapes dans l\'ordre = entrainement a l\'inhibition',
      ],
      avoid: [
        'Dire "arrete de bouger !" : proposer plutot une alternative motrice',
        'Punitions disproportionnees : l\'enfant ne fait pas expres, son frein est en developpement',
        'Sucre et ecrans juste avant le coucher',
      ],
    ),
    AttentionProfile.mixed: (
      routine: [
        'Routine courte et visuelle : pictogrammes + timer',
        'Alterner 10 min de travail / 5 min de mouvement',
        'Rituel de fin de journee : 3 choses bien faites aujourd\'hui (valorisation)',
      ],
      activities: [
        'Trampoline, velo, natation : depenser l\'energie avant les taches cognitives',
        'Jeux cooperatifs plutot que competitifs : reduit la frustration',
        'Musique et rythme : batterie, djembe, danse - structurent le cerveau',
      ],
      avoid: [
        'Longues periodes assises sans pause : maximum 10-15 min pour commencer',
        'Attentes sans occupation (salle d\'attente, file) : prevoir un petit jeu/livre',
        'Les etiquettes negatives : "turbulent", "dans la lune" - ca marque',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;

    return _AdviceCard(
      cardColor: Colors.purple.withValues(alpha: 0.06),
      children: [
        const _AdviceSectionHeader(
          icon: Icons.home_rounded,
          text: 'Routine et activites',
          color: Colors.purple,
        ),
        const SizedBox(height: _Spacing.s),
        _BulletList(items: d.routine, prefix: '->'),
        Divider(color: cs.outlineVariant, height: _Spacing.l),
        Text('Activites recommandees :', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: _Spacing.xs),
        _BulletList(items: d.activities, prefix: '-'),
        Divider(color: cs.outlineVariant, height: _Spacing.l),
        _AdviceSectionHeader(
          icon: Icons.warning_amber_rounded,
          text: 'A eviter',
          color: cs.error,
        ),
        const SizedBox(height: _Spacing.xs),
        _BulletList(
          items: d.avoid,
          prefix: 'x',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// COMMUNICATION AVEC L'ENFANT
// ---------------------------------------------------------------
class _CommunicationCard extends StatelessWidget {
  final AttentionProfile profile;
  const _CommunicationCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      doSay: [
        '"Tu as bien gere ton temps, bravo !"',
        '"Qu\'est-ce que tu as prefere faire aujourd\'hui ?"',
        '"Tu peux essayer de... qu\'en penses-tu ?"',
      ],
      dontSay: [
        '"C\'est facile pourtant" - minimise l\'effort',
      ],
      bonding: [
        'Moment quotidien 1-a-1 (15 min) : jeu libre choisi par l\'enfant',
        'Valider les emotions meme quand tout va bien : "Je vois que tu es fier"',
      ],
    ),
    AttentionProfile.highVariability: (
      doSay: [
        '"Je vois que c\'est dur de rester concentre, on fait une pause ?"',
        '"Tu as tenu 10 minutes, c\'est super !" (valoriser l\'effort, pas le resultat)',
        '"On decoupe en petits morceaux, un a la fois"',
      ],
      dontSay: [
        '"Tu pourrais si tu voulais" - il veut, mais son cerveau fluctue',
        '"Pourquoi tu y arrives des fois et pas d\'autres ?" - c\'est justement le TDAH',
      ],
      bonding: [
        'Activites nouvelles ensemble : l\'enfant HV adore la nouveaute',
        'Raconter des histoires a tour de role : stimule et canalise',
      ],
    ),
    AttentionProfile.inattention: (
      doSay: [
        '"Regarde-moi, je vais te dire une chose importante" (contact visuel d\'abord)',
        '"Redis-moi ce que tu as compris" (verifier sans accuser)',
        '"C\'est pas grave d\'avoir oublie, on met un rappel ensemble"',
      ],
      dontSay: [
        '"Tu n\'ecoutes jamais !" - il ecoute mais le signal se perd',
        '"Je te l\'ai deja dit 10 fois" - repeter calmement fait partie du processus',
      ],
      bonding: [
        'Ecouter ses passions sans limite de temps : l\'hyperfocus est une force',
        'Lire ensemble le soir : moment calme qui renforce le lien et l\'attention',
      ],
    ),
    AttentionProfile.impulsivity: (
      doSay: [
        '"Stop. Respire. Maintenant dis-moi" (technique en 3 temps)',
        '"J\'aime ton energie ! On va trouver comment l\'utiliser"',
        '"Tu as reussi a attendre, c\'est un super effort !"',
      ],
      dontSay: [
        '"Calme-toi !" sans donner d\'alternative - plutot : "Serre fort tes poings puis relache"',
        '"Tu fais expres" - non, son systeme de freinage est en construction',
      ],
      bonding: [
        'Jeux physiques ensemble : lutte douce, courses, danse',
        'Lui donner des "missions" a responsabilite : porter les courses, aider a cuisiner',
      ],
    ),
    AttentionProfile.mixed: (
      doSay: [
        '"On va faire un truc a la fois, et tu vas y arriver"',
        '"Je suis fier de toi pour avoir essaye" (effort > resultat)',
        '"Ton cerveau fonctionne differemment et c\'est OK"',
      ],
      dontSay: [
        '"Tu es intelligent mais tu ne fais pas d\'effort" - il en fait enormement',
        '"Les autres y arrivent bien" - la comparaison est toxique',
      ],
      bonding: [
        'Creer un "code secret" entre vous pour les moments difficiles (geste, mot)',
        'Journal ensemble le soir : dessiner ou ecrire les 3 meilleurs moments',
        'Calins et contact physique : l\'enfant mixte a souvent besoin de se reancrer',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;

    return _AdviceCard(
      cardColor: Colors.teal.withValues(alpha: 0.06),
      children: [
        const _AdviceSectionHeader(
          icon: Icons.chat_bubble_outline_rounded,
          text: 'Quoi dire',
          color: Colors.teal,
        ),
        const SizedBox(height: _Spacing.s),
        _BulletList(items: d.doSay, prefix: '->'),
        Divider(color: cs.outlineVariant, height: _Spacing.l),
        _AdviceSectionHeader(
          icon: Icons.warning_amber_rounded,
          text: 'A ne pas dire',
          color: cs.error,
        ),
        const SizedBox(height: _Spacing.xs),
        _BulletList(
          items: d.dontSay,
          prefix: 'x',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
        ),
        Divider(color: cs.outlineVariant, height: _Spacing.l),
        Text('Renforcer le lien :', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: _Spacing.xs),
        _BulletList(items: d.bonding, prefix: '->'),
      ],
    );
  }
}

// ---------------------------------------------------------------
// A L'ECOLE ET AUX DEVOIRS
// ---------------------------------------------------------------
class _SchoolCard extends StatelessWidget {
  final AttentionProfile profile;
  const _SchoolCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      homework: [
        'Creneaux reguliers : meme heure, meme lieu chaque jour',
        'Commencer par la tache la plus difficile quand l\'energie est haute',
        'Recompense apres les devoirs : temps libre, jeu, activite choisie',
      ],
      school: [
        'Encourager la participation active en classe',
        'Discuter avec l\'enseignant pour maintenir la stimulation',
      ],
    ),
    AttentionProfile.highVariability: (
      homework: [
        'Sessions de 10 min maximum avec minuteur visible',
        'Varier l\'ordre des matieres pour maintenir l\'interet',
        'Autoriser le mouvement : debout, ballon d\'assise, fidget discret',
        'Verifier la comprehension de la consigne avant de commencer',
      ],
      school: [
        'Demander a etre place devant, loin des fenetres',
        'Plan d\'accompagnement personnalise (PAP) si besoin',
        'Consignes ecrites en plus des consignes orales',
        'Temps supplementaire pour les evaluations',
      ],
    ),
    AttentionProfile.inattention: (
      homework: [
        'Environnement epure : bureau range, pas de jouets visibles',
        'Une seule tache visible a la fois (cacher le reste)',
        'Surligner les mots-cles dans les consignes',
        'Relire ensemble la consigne a voix haute avant de commencer',
      ],
      school: [
        'Place au premier rang, a cote d\'un eleve calme',
        'Repeter les consignes individuellement si possible',
        'Check-liste dans le cahier de texte : cocher chaque devoir fait',
        'Amenagements possibles : tiers temps, secretaire, ordinateur',
      ],
    ),
    AttentionProfile.impulsivity: (
      homework: [
        'Activite physique de 20 min AVANT de s\'asseoir',
        'Regle du "je relis une fois avant de dire que c\'est fini"',
        'Decomposer les problemes : etape 1, puis etape 2...',
        'Autoriser le mouvement sur place (se balancer, fidget)',
      ],
      school: [
        'Donner des responsabilites motrices : distribuer les feuilles, effacer le tableau',
        'Signal discret avec l\'enseignant pour l\'aider a attendre (pouce, clin d\'oeil)',
        'Valoriser les prises de parole au bon moment',
        'Eviter les punitions pour agitation : proposer des alternatives',
      ],
    ),
    AttentionProfile.mixed: (
      homework: [
        'Blocs de 8-10 min travail / 3-5 min pause mouvement',
        'Objectif visible : "tu as 3 exercices, on barre chaque exercice fini"',
        'Utiliser des couleurs : un code couleur par matiere',
        'Recompense immediate apres chaque bloc reussi',
      ],
      school: [
        'PAP ou PPS recommande : amenagements officiels',
        'Place strategique : devant, couloir, possibilite de se lever',
        'Evaluations fractionnees si possible',
        'Communication reguliere parent-enseignant : cahier de liaison hebdomadaire',
        'Ergotherapeute scolaire pour des strategies personnalisees',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;

    return _AdviceCard(
      cardColor: Colors.indigo.withValues(alpha: 0.06),
      children: [
        const _AdviceSectionHeader(
          icon: Icons.menu_book_rounded,
          text: 'Devoirs',
          color: Colors.indigo,
        ),
        const SizedBox(height: _Spacing.s),
        _BulletList(items: d.homework, prefix: '->'),
        Divider(color: cs.outlineVariant, height: _Spacing.l),
        Text('A l\'ecole :', style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: _Spacing.xs),
        _BulletList(items: d.school, prefix: '-'),
      ],
    );
  }
}

// ---------------------------------------------------------------
// QUAND CONSULTER
// ---------------------------------------------------------------
class _WhenToConsultCard extends StatelessWidget {
  final AttentionProfile profile;
  const _WhenToConsultCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTypical = profile == AttentionProfile.typical;

    return _AdviceCard(
      cardColor: isTypical
          ? Colors.green.withValues(alpha: 0.06)
          : cs.errorContainer.withValues(alpha: 0.3),
      children: [
        _AdviceSectionHeader(
          icon: isTypical ? Icons.check_circle_outline_rounded : Icons.medical_services_outlined,
          text: isTypical ? 'Profil dans les normes' : 'Signes a surveiller',
          color: isTypical ? Colors.green : cs.error,
        ),
        const SizedBox(height: _Spacing.s),
        if (isTypical) ...[
          Text(
            'Les resultats de votre enfant sont dans les normes saines. '
            'Continuez a maintenir de bonnes habitudes !\n\n'
            'Consultez si vous observez des changements : '
            'baisse scolaire soudaine, difficultes relationnelles nouvelles, '
            'ou si l\'enfant exprime lui-meme une souffrance.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ] else ...[
          Text(
            'Ce jeu n\'est PAS un diagnostic. Cependant, les resultats '
            'suggerent des particularites attentionnelles qui meritent '
            'une evaluation professionnelle si :',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: _Spacing.s),
          _BulletList(items: const [
            'Les difficultes sont presentes depuis plus de 6 mois',
            'Elles se manifestent dans au moins 2 contextes (maison ET ecole)',
            'Elles impactent les apprentissages ou les relations sociales',
            'L\'enfant souffre ou exprime de la frustration',
          ], prefix: '-'),
          Divider(color: cs.outlineVariant, height: _Spacing.l),
          Text('Qui consulter :', style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: _Spacing.xs),
          _BulletList(items: const [
            'Medecin traitant / pediatre : premier bilan et orientation',
            'Neuropediatre ou pedopsychiatre : diagnostic officiel TDAH',
            'Neuropsychologue : bilan attentionnel complet (WISC, TEA-Ch, CPT)',
            'Psychomotricien : si agitation motrice importante',
            'Orthophoniste : si difficultes de lecture/ecriture associees',
            'Ergotherapeute : strategies d\'organisation au quotidien',
          ], prefix: '->'),
          Divider(color: cs.outlineVariant, height: _Spacing.l),
          Text('Ressources utiles :', style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: _Spacing.xs),
          _BulletList(items: const [
            'HyperSupers TDAH France : association de parents',
            'TDAH-France.fr : informations validees scientifiquement',
            'Livre : "Mon cerveau a besoin de lunettes" (Dr Annick Vincent)',
            'Livre : "100 idees pour mieux gerer les troubles de l\'attention" (F. Lussier)',
          ], prefix: '-'),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------
// ECRAN HISTORIQUE - with proper empty state
// ---------------------------------------------------------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  static const _profileNames = [
    'Typique',
    'Variable',
    'Inattention',
    'Impulsivite',
    'Mixte',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await GameHistory.load();
    if (mounted) setState(() => _history = h.reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Historique'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: _history.isEmpty
          // Empty state per UX guidelines: illustration + message + CTA
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(_Spacing.l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 64,
                      color: cs.outlineVariant,
                    ),
                    const SizedBox(height: _Spacing.m),
                    Text(
                      'Aucune partie jouee',
                      style: tt.headlineSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: _Spacing.s),
                    Text(
                      'L\'historique de tes parties apparaitra ici.',
                      style: tt.bodyMedium?.copyWith(color: cs.outline),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: _Spacing.l),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          _buildPageRoute(const GameScreen()),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Jouer maintenant'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(_Spacing.m),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final h = _history[i];
                final date = DateTime.tryParse(h['date'] ?? '');
                final dateStr = date != null
                    ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                    : '?';
                final stars = (h['stars'] as num?)?.toInt() ?? 0;
                final hits = h['hits'] ?? 0;
                final total = h['totalTargets'] ?? 0;
                final meanRt = (h['meanRtMs'] as num?)?.toInt() ?? 0;
                final sdRt = (h['sdRtMs'] as num?)?.toInt() ?? 0;
                final profileIdx = (h['profile'] as num?)?.toInt() ?? 0;
                final profileName = profileIdx < _profileNames.length
                    ? _profileNames[profileIdx]
                    : '?';

                return Padding(
                  padding: const EdgeInsets.only(bottom: _Spacing.s),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(_Spacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(dateStr, style: tt.bodySmall?.copyWith(color: cs.outline)),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (j) => Icon(
                                  j < stars ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: j < stars ? Colors.amber : cs.outlineVariant,
                                  size: 18,
                                )),
                              ),
                            ],
                          ),
                          const SizedBox(height: _Spacing.s),
                          Text(
                            'Profil : $profileName',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(height: _Spacing.xs),
                          Text(
                            'Maisons : $hits/$total  |  RT moyen : ${meanRt}ms  |  Variabilite : ${sdRt}ms',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
