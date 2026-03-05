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
// Sources activites parent :
//   - Dawson & Guare (2010) - Smart but Scattered (fonctions executives)
//   - Barkley (2013) - Taking Charge of ADHD
//   - Diamond & Lee (2011) - meta-analyse entrainement fonctions executives
//   - Greene (2014) - The Explosive Child (approche CPS)
//   - Rapport et al. (2013) - Working memory training for ADHD
// ---------------------------------------------------------------

// ---------------------------------------------------------------
// DESIGN TOKENS (Winter Tree UX - MOBILE.md)
// ---------------------------------------------------------------
class _S {
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
  static const Duration large = Duration(milliseconds: 500);
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
}

class _R {
  static const double card = 16.0;
  static const double button = 28.0;
  static const double progress = 8.0;
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
  // Edge-to-edge status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const SchtroumpfApp());
}

// ---------------------------------------------------------------
// M3 THEME
// ---------------------------------------------------------------
final _seed = const Color(0xFF1565C0);
final _lightScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
final _darkScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);

ThemeData _buildTheme(ColorScheme cs) => ThemeData(
  colorScheme: cs,
  useMaterial3: true,
  cardTheme: CardThemeData(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_R.card)),
    margin: EdgeInsets.zero,
    surfaceTintColor: Colors.transparent,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(0, _S.xxl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_R.button)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, _S.xxl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_R.button)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, _S.xxl),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_R.button)),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(minimumSize: const Size(0, _S.xxl)),
  ),
  appBarTheme: AppBarTheme(
    centerTitle: false,
    backgroundColor: cs.surface,
    surfaceTintColor: Colors.transparent,
  ),
  dividerTheme: DividerThemeData(
    color: cs.outlineVariant.withValues(alpha: 0.3),
    space: _S.l,
    thickness: 1,
  ),
);

class SchtroumpfApp extends StatelessWidget {
  const SchtroumpfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Schtroumpf Quest',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(_lightScheme),
      darkTheme: _buildTheme(_darkScheme),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------
// PAGE TRANSITION - M3 shared axis
// ---------------------------------------------------------------
Route<T> _route<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: _Anim.enter, reverseCurve: _Anim.exit),
        child: SlideTransition(
          position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: _Anim.enter)),
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

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _totalGames = 0, _bestStars = 0, _level = 0;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: _Anim.large)..forward();
    _loadStats();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final games = await GameHistory.getTotalGames();
    final stars = await GameHistory.getBestStars();
    final level = await GameHistory.getLevel();
    if (mounted) setState(() { _totalGames = games; _bestStars = stars; _level = level; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.3),
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _fadeCtrl, curve: _Anim.enter),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: _S.l),
                child: Column(
                  children: [
                    const SizedBox(height: _S.l),
                    // Village image with shadow card
                    Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      child: Semantics(
                        label: 'Village des Schtroumpfs',
                        child: Image.asset(
                          'assets/images/village_stroumpf.jpg',
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: _S.l),
                    Text(
                      'Schtroumpf Quest',
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: _S.s),
                    Text(
                      'Aide les Schtroumpfs a rentrer chez eux !\nAppuie sur la maison quand tu la vois !',
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    if (_totalGames > 0) ...[
                      const SizedBox(height: _S.m),
                      // Stats card with level progress
                      Card(
                        color: cs.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(_S.m),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.trending_up_rounded, size: 18, color: cs.primary),
                                  const SizedBox(width: _S.s),
                                  Text(
                                    'Niveau $_level',
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold, color: cs.primary,
                                    ),
                                  ),
                                  const SizedBox(width: _S.m),
                                  Text(
                                    '$_totalGames parties',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              // Level progress bar
                              if (_level < 5) ...[
                                const SizedBox(height: _S.s),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(_R.progress),
                                  child: LinearProgressIndicator(
                                    value: (_level % 5) / 5.0 + 0.05,
                                    minHeight: 6,
                                    backgroundColor: cs.surfaceContainerLow,
                                    valueColor: AlwaysStoppedAnimation(cs.primary),
                                  ),
                                ),
                                const SizedBox(height: _S.xs),
                                Text(
                                  '3 etoiles pour monter au niveau ${_level + 1}',
                                  style: tt.bodySmall?.copyWith(color: cs.outline, fontSize: 11),
                                ),
                              ],
                              const SizedBox(height: _S.s),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Record ', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                  ...List.generate(5, (i) => Icon(
                                    i < _bestStars ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: i < _bestStars ? Colors.amber : cs.outlineVariant,
                                    size: 20,
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: _S.xl),
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(_route(const GameScreen()));
                        _loadStats();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('Jouer !', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: _S.xl, vertical: _S.m),
                      ),
                    ),
                    if (_totalGames > 0) ...[
                      const SizedBox(height: _S.m),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(_route(const HistoryScreen()));
                        },
                        icon: const Icon(Icons.timeline_rounded),
                        label: const Text('Historique'),
                      ),
                    ],
                    const SizedBox(height: _S.xl),
                  ],
                ),
              ),
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
  Stimulus({required this.type, required this.asset}) : shownAt = DateTime.now();
}

enum AttentionProfile { typical, highVariability, inattention, impulsivity, mixed }

// Profile color for cards and tags
Color _profileColor(AttentionProfile p) {
  switch (p) {
    case AttentionProfile.typical: return Colors.green;
    case AttentionProfile.highVariability: return Colors.blue;
    case AttentionProfile.inattention: return Colors.orange;
    case AttentionProfile.impulsivity: return Colors.red;
    case AttentionProfile.mixed: return Colors.purple;
  }
}

class GameResult {
  final int totalTargets, hits, misses, falseAlarms;
  final double meanRtMs, sdRtMs;

  const GameResult({
    required this.totalTargets, required this.hits, required this.misses,
    required this.falseAlarms, required this.meanRtMs, required this.sdRtMs,
  });

  double get omissionRate => totalTargets == 0 ? 0 : misses / totalTargets;
  double get commissionRate {
    final d = 80 - totalTargets;
    return d == 0 ? 0 : falseAlarms / d;
  }

  AttentionProfile get profile {
    final hIIV = sdRtMs >= 250;
    final hOm = omissionRate >= 0.30;
    final hCom = commissionRate >= 0.25;
    if (hOm && hCom) return AttentionProfile.mixed;
    if (hOm) return AttentionProfile.inattention;
    if (hCom) return AttentionProfile.impulsivity;
    if (hIIV) return AttentionProfile.highVariability;
    return AttentionProfile.typical;
  }

  String get profileLabel => switch (profile) {
    AttentionProfile.typical => 'Bonne attention soutenue',
    AttentionProfile.highVariability => 'Attention variable',
    AttentionProfile.inattention => 'Inattention predominante',
    AttentionProfile.impulsivity => 'Impulsivite predominante',
    AttentionProfile.mixed => 'Mixte (inattention + impulsivite)',
  };

  String get profileEmoji => switch (profile) {
    AttentionProfile.typical => '\u2B50',
    AttentionProfile.highVariability => '\u{1F3AF}',
    AttentionProfile.inattention => '\u{1F50D}',
    AttentionProfile.impulsivity => '\u26A1',
    AttentionProfile.mixed => '\u{1F300}',
  };

  String get kidMessage => switch (profile) {
    AttentionProfile.typical => 'Super ! Tu as trouve toutes les maisons !',
    AttentionProfile.highVariability => 'Bien joue ! Continue a t\'entrainer !',
    AttentionProfile.inattention => 'Bien essaye ! La prochaine fois, prends ton temps !',
    AttentionProfile.impulsivity => 'Tu es rapide comme l\'eclair ! Attends bien la maison !',
    AttentionProfile.mixed => 'Beau parcours ! Tu t\'ameliores a chaque partie !',
  };

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
// GAME SCREEN - with countdown
// ---------------------------------------------------------------
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
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

  // Countdown before game starts
  int _countdown = 3;
  bool _gameStarted = false;
  Timer? _countdownTimer;

  String? _feedbackIcon;
  Color? _feedbackColor;
  Timer? _feedbackTimer;

  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;

  Duration get _stimulusDuration {
    final penalty = _difficultyLevel * 50;
    final base = 1100 - penalty - (_currentRound * 12);
    return Duration(milliseconds: base.clamp(500, 1100));
  }

  Duration get _isi => Duration(milliseconds: 700 + _rng.nextInt(700));

  String _pickAsset(List<String> queue, List<String> all) {
    if (queue.isEmpty) { queue.addAll(all); queue.shuffle(_rng); }
    if (queue.length > 1 && queue.first == _lastAsset) {
      queue.add(queue.removeAt(0));
    }
    final p = queue.removeAt(0);
    _lastAsset = p;
    return p;
  }

  void _showFeedback(String icon, Color color) {
    _feedbackTimer?.cancel();
    setState(() { _feedbackIcon = icon; _feedbackColor = color; });
    _feedbackTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _feedbackIcon = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _smurfQueue = List.of(_smurfAssets)..shuffle(_rng);
    _houseQueue = List.of(_houseAssets)..shuffle(_rng);
    _bounceCtrl = AnimationController(vsync: this, duration: _Anim.standard);
    _bounceAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut),
    );
    GameHistory.getLevel().then((level) => _difficultyLevel = level);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _countdown--);
      HapticFeedback.selectionClick();
      if (_countdown <= 0) {
        t.cancel();
        setState(() => _gameStarted = true);
        _startNextStimulus();
      }
    });
  }

  @override
  void dispose() {
    _stimulusTimer?.cancel();
    _interTimer?.cancel();
    _feedbackTimer?.cancel();
    _countdownTimer?.cancel();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _startNextStimulus() {
    if (_currentRound >= totalRounds) { _endGame(); return; }

    final isHouse = _rng.nextDouble() < houseProbability;
    final stim = Stimulus(
      type: isHouse ? StimulusType.house : StimulusType.smurf,
      asset: isHouse ? _pickAsset(_houseQueue, _houseAssets) : _pickAsset(_smurfQueue, _smurfAssets),
    );
    _stimuli.add(stim);
    setState(() { _currentStimulus = stim; _waitingForNext = false; _currentRound++; });
    _bounceCtrl.forward(from: 0);

    _stimulusTimer = Timer(_stimulusDuration, () {
      if (stim.type == StimulusType.house && !stim.responded) {
        _showFeedback('!', Colors.orange);
      }
      setState(() => _currentStimulus = null);
      _waitingForNext = true;
      _interTimer = Timer(_isi, _startNextStimulus);
    });
  }

  void _onTap() {
    if (!_gameStarted || _waitingForNext || _currentStimulus == null || _gameOver) return;
    final stim = _currentStimulus!;
    if (stim.responded) return;
    stim.responded = true;

    if (stim.type == StimulusType.house) {
      _reactionTimes.add(DateTime.now().difference(stim.shownAt).inMicroseconds / 1000.0);
      _bounceCtrl.reverse();
      HapticFeedback.lightImpact();
      _showFeedback('\u2714', Colors.green);
    } else {
      HapticFeedback.heavyImpact();
      _showFeedback('\u2718', Colors.red);
    }
  }

  void _endGame() {
    setState(() => _gameOver = true);
    _stimulusTimer?.cancel();
    _interTimer?.cancel();

    int tt = 0, h = 0, m = 0, fa = 0;
    for (final s in _stimuli) {
      if (s.type == StimulusType.house) { tt++; s.responded ? h++ : m++; }
      else { if (s.responded) fa++; }
    }

    final meanRt = _reactionTimes.isEmpty ? 0.0
        : _reactionTimes.reduce((a, b) => a + b) / _reactionTimes.length;
    double sdRt = 0;
    if (_reactionTimes.length >= 2) {
      final v = _reactionTimes.map((rt) => (rt - meanRt) * (rt - meanRt)).reduce((a, b) => a + b) / (_reactionTimes.length - 1);
      sdRt = sqrt(v);
    }

    final result = GameResult(totalTargets: tt, hits: h, misses: m, falseAlarms: fa, meanRtMs: meanRt, sdRtMs: sdRt);
    GameHistory.save(result);

    Future.delayed(_Anim.standard, () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(_route(ResultScreen(result: result)));
    });
  }

  static const _houseAssets = [
    'assets/images/maison_rouge.png', 'assets/images/maison_bleu.png',
    'assets/images/maison_vert.png', 'assets/images/maison_jaune.png',
    'assets/images/maison_violet.png', 'assets/images/maison_orange.png',
  ];

  static const _smurfAssets = [
    'assets/images/grognion.jpg', 'assets/images/bricoleur.jpg',
    'assets/images/lunette.jpg', 'assets/images/stroumpfette.jpg',
    'assets/images/grand_stroumpf.jpg', 'assets/images/cuisinier.jpg',
    'assets/images/farceur.png', 'assets/images/gourmand.png',
    'assets/images/costo.jpg', 'assets/images/coquet.jpg',
    'assets/images/paysant.jpg', 'assets/images/pareseu.jpg',
    'assets/images/musicien.jpg', 'assets/images/noir.jpg',
    'assets/images/bebe.jpg', 'assets/images/gargamel.jpg',
    'assets/images/azrael.jpg', 'assets/images/cosmonaute.jpg',
    'assets/images/reporter.png',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = _currentRound / totalRounds;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primaryContainer.withValues(alpha: 0.15), cs.surface],
          ),
        ),
        child: SafeArea(
        child: GestureDetector(
          onTap: _onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.expand(
            child: !_gameStarted
                // ---------- COUNTDOWN ----------
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Prepare-toi !',
                          style: tt.headlineSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: _S.l),
                        AnimatedSwitcher(
                          duration: _Anim.standard,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                            child: child,
                          ),
                          child: Text(
                            '$_countdown',
                            key: ValueKey(_countdown),
                            style: tt.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                              fontSize: 96,
                            ),
                          ),
                        ),
                        const SizedBox(height: _S.l),
                        Icon(Icons.touch_app_rounded, size: 48, color: cs.outlineVariant),
                        const SizedBox(height: _S.s),
                        Text(
                          'Appuie quand tu vois une maison !',
                          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                // ---------- GAME ----------
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(_S.m),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(_R.progress),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: cs.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(cs.primary),
                              ),
                            ),
                            const SizedBox(height: _S.s),
                            Text(
                              '$_currentRound / $totalRounds',
                              style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          ScaleTransition(
                            scale: _bounceAnim,
                            child: SizedBox(
                              height: 200,
                              child: _currentStimulus == null
                                  ? const SizedBox.shrink()
                                  : Semantics(
                      label: _currentStimulus!.type == StimulusType.house ? 'Maison' : 'Schtroumpf',
                      child: Image.asset(_currentStimulus!.asset, height: 200, fit: BoxFit.contain),
                    ),
                            ),
                          ),
                          if (_feedbackIcon != null)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: _Anim.micro,
                              curve: _Anim.enter,
                              builder: (_, v, child) => Opacity(
                                opacity: v,
                                child: Transform.scale(scale: 0.5 + v * 0.5, child: child),
                              ),
                              child: Text(
                                _feedbackIcon!,
                                style: TextStyle(fontSize: 80, color: _feedbackColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: _S.xxl),
                        child: Text(
                          'Appuie sur la maison !',
                          style: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [cs.primaryContainer.withValues(alpha: 0.2), cs.surface],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: _Anim.standard,
            switchInCurve: _Anim.enter,
            switchOutCurve: _Anim.exit,
            child: _parentMode
                ? _ParentView(key: const ValueKey('p'), result: widget.result, onBack: () => setState(() => _parentMode = false))
                : _KidView(key: const ValueKey('k'), result: widget.result, onParentMode: () => setState(() => _parentMode = true)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// KID VIEW - with staggered star animation
// ---------------------------------------------------------------
class _KidView extends StatefulWidget {
  final GameResult result;
  final VoidCallback onParentMode;
  const _KidView({super.key, required this.result, required this.onParentMode});
  @override
  State<_KidView> createState() => _KidViewState();
}

class _KidViewState extends State<_KidView> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = widget.result;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_S.l),
        child: Column(
          children: [
            // Animated emoji
            FadeTransition(
              opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.3, curve: Curves.easeOut)),
              child: Text(r.profileEmoji, style: const TextStyle(fontSize: 80)),
            ),
            const SizedBox(height: _S.m),
            // Staggered stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final start = 0.2 + i * 0.1;
                final end = (start + 0.15).clamp(0.0, 1.0);
                return FadeTransition(
                  opacity: CurvedAnimation(parent: _ctrl, curve: Interval(start, end, curve: Curves.easeOut)),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _ctrl, curve: Interval(start, end, curve: Curves.elasticOut)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        i < r.stars ? Icons.star_rounded : Icons.star_border_rounded,
                        color: i < r.stars ? Colors.amber : cs.outlineVariant,
                        size: 40,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: _S.l),
            FadeTransition(
              opacity: CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
              child: Column(
                children: [
                  Text(
                    r.kidMessage,
                    textAlign: TextAlign.center,
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                  const SizedBox(height: _S.s),
                  Text(
                    'Maisons trouvees : ${r.hits} / ${r.totalTargets}',
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _S.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(_route(const GameScreen())),
                  child: const Text('Rejouer'),
                ),
                const SizedBox(width: _S.s),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Accueil'),
                ),
              ],
            ),
            const SizedBox(height: _S.l),
            OutlinedButton.icon(
              onPressed: widget.onParentMode,
              icon: Icon(Icons.insights_rounded, size: 18, color: cs.outline),
              label: Text('Voir les details (parents)', style: tt.labelLarge?.copyWith(color: cs.outline)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: _S.l, vertical: _S.m),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// PARENT VIEW
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
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(_S.m + _S.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: cs.primary),
              tooltip: 'Retour',
              constraints: const BoxConstraints(minWidth: _S.xxl, minHeight: _S.xxl),
            ),
            const SizedBox(width: _S.s),
            Expanded(child: Text('Resultats detailles', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary))),
          ]),
          const SizedBox(height: _S.s),

          // Warning
          Card(
            color: cs.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(_S.m),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, color: cs.onTertiaryContainer, size: 20),
                const SizedBox(width: _S.s),
                Expanded(child: Text(
                  'Ces donnees sont des indicateurs de jeu, pas un diagnostic medical. '
                  'Consultez un professionnel de sante pour toute evaluation TDAH.',
                  style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
                )),
              ]),
            ),
          ),
          const SizedBox(height: _S.l),

          // Profile chip
          _Section('Profil observe'),
          _DataCard(icon: result.profileEmoji, label: 'Profil', value: result.profileLabel,
            subtitle: _profileExpl(result.profile), accentColor: _profileColor(result.profile)),
          const SizedBox(height: _S.s),

          _Section('Temps de reaction'),
          _DataCard(icon: '\u23F1', label: 'RT moyen',
            value: '${result.meanRtMs > 0 ? result.meanRtMs.toStringAsFixed(0) : "--"} ms',
            subtitle: '${result.rtCategory}  |  Norme ~655ms, TDAH ~734ms',
            highlight: result.meanRtMs > 734 && result.meanRtMs > 0),
          const SizedBox(height: _S.s),
          _DataCard(icon: '\u{1F4CA}', label: 'Variabilite (IIV)',
            value: '${result.sdRtMs > 0 ? result.sdRtMs.toStringAsFixed(0) : "--"} ms',
            subtitle: '${result.variabilityCategory}  |  Norme ~204ms, TDAH >=250ms',
            highlight: result.sdRtMs >= 250),
          const SizedBox(height: _S.s),

          _Section('Erreurs'),
          _DataCard(icon: '\u{1F441}', label: 'Omissions',
            value: '${result.misses}/${result.totalTargets}  (${(result.omissionRate * 100).toStringAsFixed(0)}%)',
            subtitle: 'Seuil : >=30% = inattention', highlight: result.omissionRate >= 0.30),
          const SizedBox(height: _S.s),
          _DataCard(icon: '\u26A1', label: 'Commissions',
            value: '${result.falseAlarms}  (${(result.commissionRate * 100).toStringAsFixed(0)}%)',
            subtitle: 'Seuil : >=25% = impulsivite', highlight: result.commissionRate >= 0.25),
          const SizedBox(height: _S.l),

          _Section('Strategie 80/20'),
          _EightyTwentyCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Actions au quotidien'),
          _DailyActionsCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Activites a faire ensemble'),
          _ActivitiesCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Communiquer avec votre enfant'),
          _CommunicationCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Ecole et devoirs'),
          _SchoolCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Quand consulter ?'),
          _WhenToConsultCard(profile: result.profile),
          const SizedBox(height: _S.l),

          _Section('Sources scientifiques'),
          Text(
            '- Kofler et al. (2013) - Meta-analyse 319 etudes IIV\n'
            '- PMC3413905 - SD_RT controles/TDAH\n'
            '- PMC5858546 - RT moyen controles/TDAH\n'
            '- BMC Pediatrics 2024 - omissions/commissions\n'
            '- Barkley (2015) - ADHD Handbook\n'
            '- DuPaul & Stoner (2014) - ADHD in Schools\n'
            '- Dawson & Guare (2010) - Smart but Scattered\n'
            '- Diamond & Lee (2011) - Executive functions training\n'
            '- Rapport et al. (2013) - Working memory & ADHD',
            style: tt.bodySmall?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: _S.xl),
        ],
      ),
    );
  }

  String _profileExpl(AttentionProfile p) => switch (p) {
    AttentionProfile.typical => 'RT et variabilite dans les normes saines',
    AttentionProfile.highVariability => 'SD_RT >=250ms : variabilite elevee (Kofler 2013)',
    AttentionProfile.inattention => 'Omissions >=30% : difficulte a detecter la cible',
    AttentionProfile.impulsivity => 'Commissions >=25% : reponses trop rapides',
    AttentionProfile.mixed => 'Omissions et commissions elevees',
  };
}

// ---------------------------------------------------------------
// REUSABLE WIDGETS
// ---------------------------------------------------------------
class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: _S.s),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary,
    )),
  );
}

class _DataCard extends StatelessWidget {
  final String icon, label, value, subtitle;
  final bool highlight;
  final Color? accentColor;
  const _DataCard({required this.icon, required this.label, required this.value,
    required this.subtitle, this.highlight = false, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      color: highlight ? cs.errorContainer : cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(_S.m),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: _S.m),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: _S.xs),
            Text(value, style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: accentColor ?? (highlight ? cs.onErrorContainer : cs.primary),
            )),
            const SizedBox(height: _S.xs),
            Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.outline)),
          ])),
        ]),
      ),
    );
  }
}

class _Advice extends StatelessWidget {
  final Color? tint;
  final List<Widget> children;
  const _Advice({this.tint, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    color: tint?.withValues(alpha: 0.06) ?? Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(_S.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  );
}

class _Header extends StatelessWidget {
  final IconData icon; final String text; final Color color;
  const _Header({required this.icon, required this.text, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: color), const SizedBox(width: _S.s),
    Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
  ]);
}

class _Bullets extends StatelessWidget {
  final List<String> items; final String pre; final TextStyle? style;
  const _Bullets(this.items, {this.pre = '-', this.style});
  @override
  Widget build(BuildContext context) {
    final def = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((s) => Padding(
      padding: const EdgeInsets.only(bottom: _S.xs),
      child: Text('$pre $s', style: style ?? def),
    )).toList());
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
      strengths: ['Attention soutenue sur la duree', 'Regularite et coherence', 'Bonne gestion des consignes'],
      weaknesses: ['Risque d\'ennui sur taches repetitives', 'Flexibilite si interruption'],
      tips80: ['Taches structurees et rhythmees', 'Plannings fixes, routines', 'Projets longs de perseverance'],
      tips20: ['Variete pour eviter la saturation', 'Signaux visuels pour les interruptions'],
    ),
    AttentionProfile.highVariability: (
      strengths: ['Flexibilite cognitive elevee', 'Reactivite aux nouveaux stimuli', 'Creativite et pensee associative'],
      weaknesses: ['Incoherence vitesse de traitement', 'Difficulte a maintenir un rythme'],
      tips80: ['Environnement stimulant et varie', 'Taches courtes, variations frequentes', 'Arts, improvisation, projets ouverts'],
      tips20: ['Routines courtes pour ancrer le focus', 'Timer visible pour intervalles previsibles'],
    ),
    AttentionProfile.inattention: (
      strengths: ['Vision globale et pensee divergente', 'Curiosite pour les sujets passionnants', 'Creativite et imagination'],
      weaknesses: ['Detection des cibles dans le flux', 'Maintien de l\'attention sur la duree'],
      tips80: ['Projets visuels, creatifs, en mouvement', 'Hyperfocus : s\'appuyer sur les passions', 'Narration, jeux de role'],
      tips20: ['Sessions 10-15 min max avec pauses', 'Check-listes visuelles colorees', 'Reduire les distracteurs visuels'],
    ),
    AttentionProfile.impulsivity: (
      strengths: ['Rapidite de reaction', 'Enthousiasme et energie', 'Leadership et prise d\'initiative'],
      weaknesses: ['Controle inhibiteur', 'Reponses precipitees'],
      tips80: ['Sports de reaction : tennis, judo, foot', 'Jeux rapides, brainstorming', 'Activites orales dynamiques'],
      tips20: ['STOP : compter jusqu\'a 3 avant de repondre', 'Relecture systematique', 'Jeux de patience courts'],
    ),
    AttentionProfile.mixed: (
      strengths: ['Energie et spontaneite', 'Traitement rapide en rafale', 'Adaptabilite'],
      weaknesses: ['Focus soutenu', 'Controle inhibiteur'],
      tips80: ['Sport : canal naturel pour l\'energie', 'Projets courts et intenses', 'Apprentissage kinesthesique'],
      tips20: ['Structure externe : timer, planning visuel', 'Recompenses immediates par etape', 'Pleine conscience 2-3 min'],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;
    return Column(children: [
      _Advice(tint: Colors.green, children: [
        const _Header(icon: Icons.fitness_center_rounded, text: 'Points forts - exploiter a 80%', color: Colors.green),
        const SizedBox(height: _S.s),
        _Bullets(d.strengths),
        const Divider(),
        Text('Comment les exploiter :', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: _S.xs),
        _Bullets(d.tips80, pre: '->'),
      ]),
      const SizedBox(height: _S.s),
      _Advice(tint: cs.primary, children: [
        _Header(icon: Icons.track_changes_rounded, text: 'A travailler - 20%', color: cs.primary),
        const SizedBox(height: _S.s),
        _Bullets(d.weaknesses),
        const Divider(),
        Text('Strategies :', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: _S.xs),
        _Bullets(d.tips20, pre: '->'),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------
// ACTIVITES A FAIRE ENSEMBLE (Dawson & Guare, Diamond & Lee, Rapport)
// ---------------------------------------------------------------
class _ActivitiesCard extends StatelessWidget {
  final AttentionProfile profile;
  const _ActivitiesCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      memoire: [
        'Jeu de Memory avec 12 puis 16 puis 20 cartes (augmenter progressivement)',
        'Repeter une liste de courses ensemble : l\'enfant ajoute un mot a chaque tour',
        '"J\'ai mis dans ma valise..." : jeu de memoire en chaine',
      ],
      inhibition: [
        '1-2-3 Soleil : parfait pour entrainer le controle moteur',
        'Jacques a dit : ne bouger QUE quand on dit "Jacques a dit"',
        'Jeu du silence : qui tient le plus longtemps sans bruit (avec timer)',
      ],
      attention: [
        'Cherche et trouve (type Ou est Charlie) : 10 min par jour',
        'Puzzle adapte a l\'age : 50-100 pieces a 5 ans',
        'Coloriage mandala : favorise la concentration et le calme',
      ],
      regulationTitle: 'Auto-regulation',
      regulation: [
        'Respiration du ballon : inspirer en gonflant le ventre, expirer lentement (5 cycles)',
        'La tortue : quand tu es enerve, rentre dans ta carapace (bras croises, tete baissee, 3 respirations)',
        'Thermometre des emotions : dessiner ensemble comment on se sent (de 1 a 10)',
      ],
    ),
    AttentionProfile.highVariability: (
      memoire: [
        'Simon electronique ou appli Simon Says : entrainer les sequences',
        'Jeu des 7 differences : comparer deux images',
        'Repeter un rythme frappe dans les mains (3 coups, puis 4, puis 5...)',
      ],
      inhibition: [
        'Feu rouge / Feu vert : courir au vert, s\'arreter net au rouge',
        'Le robot : donner des instructions, l\'enfant ne bouge QU\'au signal',
        'Jeu de cartes "Bazar bizarre" : inhiber la premiere reponse',
      ],
      attention: [
        'Timer Challenge : deviner quand 1 minute est passee (sans regarder)',
        'Lecture a deux voix : un paragraphe chacun, attention a la suite',
        'Jeu de Kim : montrer 10 objets, en cacher 1, lequel manque ?',
      ],
      regulationTitle: 'Structurer le temps',
      regulation: [
        'Time Timer visible : 10 min de jeu, 5 min de rangement',
        'Routine du soir en 5 images : l\'enfant coche chaque etape',
        'Sablier de 3 min pour les transitions : "quand le sable est fini, on change"',
      ],
    ),
    AttentionProfile.inattention: (
      memoire: [
        'Jeu de Memory (commencer petit : 8 cartes, augmenter)',
        'Course d\'objets : "va chercher... la cuillere, le livre ET le crayon" (3 puis 4 objets)',
        'Histoires a tiroirs : raconter une histoire, l\'enfant doit se souvenir des personnages',
      ],
      inhibition: [
        'Jeu du Ni Oui Ni Non : entrainer l\'ecoute active',
        'Dessiner sans lever le crayon : planifier avant d\'agir',
        'Marche lente : traverser la piece le plus lentement possible',
      ],
      attention: [
        'I Spy / Je vois quelque chose de... : observation active',
        'Ecouter un son dans la nature et le decrire (oiseau, vent, voiture)',
        'Perles et colliers : enfiler dans un ordre precis (rouge, bleu, rouge, bleu...)',
      ],
      regulationTitle: 'Reveil attentionnel',
      regulation: [
        'Check-in sensoriel : "que vois-tu ? qu\'entends-tu ? que sens-tu ?" (5 sens)',
        'Exercice du spot : fixer un point 30 secondes, puis fermer les yeux et le "voir"',
        'Yoga de l\'arbre : equilibre sur un pied, bras en l\'air, 20 secondes',
      ],
    ),
    AttentionProfile.impulsivity: (
      memoire: [
        'Jeu de paires avec delai : retourner une carte, attendre 5 sec, puis la 2eme',
        'Suite de chiffres a l\'envers : dire 3-7-2, l\'enfant repete 2-7-3',
        'Chansons a gestes (Tete epaules genoux pieds) : memoire + sequence',
      ],
      inhibition: [
        'Statue musicale : danser puis se figer quand la musique s\'arrete',
        'Le jeu du roi : le roi dit "Marche !" mais montre l\'inverse - suivre les MOTS pas les gestes',
        'Tour de Jenga/Kapla : retirer doucement, sans faire tomber (patience motrice)',
      ],
      attention: [
        'Labyrinthe sur papier : tracer le chemin au crayon SANS toucher les murs',
        'Jeu de l\'horloge : "dis-moi quand tu penses qu\'1 minute est passee"',
        'Origami simple : suivre les etapes dans l\'ordre (avion, bateau)',
      ],
      regulationTitle: 'Canaliser l\'energie',
      regulation: [
        'Respiration du dragon : inspirer par le nez, souffler fort par la bouche 3x',
        'Serre les poings 5 sec, relache : sentir la difference tension/detente',
        'Course sur place 30 sec puis immobilite totale 30 sec (alterner 3x)',
      ],
    ),
    AttentionProfile.mixed: (
      memoire: [
        'Jeu de Memory avec timer : trouver les paires avant que le sable coule',
        'Ecouter une histoire courte et dessiner ce qu\'on a retenu',
        'Faire les courses ensemble : l\'enfant retient 3 articles (sans liste)',
      ],
      inhibition: [
        '1-2-3 Soleil version lente : ne bouger que TRES lentement',
        'Mikado : retirer les batonnets sans faire bouger les autres',
        'Jeu "Jean dit" avec pieges de plus en plus rapides',
      ],
      attention: [
        'Chasse au tresor maison : 5 indices a trouver dans l\'ordre',
        'Relier les points (de 1 a 50+) : attention sequentielle',
        'Jeu des erreurs : trouver 7 differences entre 2 dessins',
      ],
      regulationTitle: 'Corps et calme',
      regulation: [
        'Parcours moteur maison : ramper sous la table, sauter sur un coussin, equilibre sur une corde',
        'Le chat qui s\'etire : 3 postures de yoga animal (chat, chien, cobra) enchainement lent',
        'Massage des mains avec creme : moment calme sensoriel avant les devoirs',
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;
    return _Advice(tint: Colors.deepOrange, children: [
      const _Header(icon: Icons.psychology_rounded, text: 'Exercices a faire ensemble', color: Colors.deepOrange),
      const SizedBox(height: _S.m),

      _Header(icon: Icons.grid_view_rounded, text: 'Memoire de travail', color: cs.primary),
      const SizedBox(height: _S.xs),
      Text('(Rapport et al. 2013 - Working memory training)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic)),
      const SizedBox(height: _S.s),
      _Bullets(d.memoire, pre: '->'),
      const Divider(),

      _Header(icon: Icons.front_hand_rounded, text: 'Controle inhibiteur', color: cs.primary),
      const SizedBox(height: _S.xs),
      Text('(Diamond & Lee 2011 - Executive functions)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic)),
      const SizedBox(height: _S.s),
      _Bullets(d.inhibition, pre: '->'),
      const Divider(),

      _Header(icon: Icons.visibility_rounded, text: 'Entrainement attentionnel', color: cs.primary),
      const SizedBox(height: _S.xs),
      Text('(Dawson & Guare 2010 - Smart but Scattered)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic)),
      const SizedBox(height: _S.s),
      _Bullets(d.attention, pre: '->'),
      const Divider(),

      _Header(icon: Icons.self_improvement_rounded, text: d.regulationTitle, color: cs.primary),
      const SizedBox(height: _S.xs),
      Text('(Barkley 2013 - Taking Charge of ADHD)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.outline, fontStyle: FontStyle.italic)),
      const SizedBox(height: _S.s),
      _Bullets(d.regulation, pre: '->'),
    ]);
  }
}

// ---------------------------------------------------------------
// DAILY ACTIONS
// ---------------------------------------------------------------
class _DailyActionsCard extends StatelessWidget {
  final AttentionProfile profile;
  const _DailyActionsCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      routine: ['Rythme regulier : lever, repas, coucher a heures fixes', 'Alterner calme et actif', 'Activites de groupe'],
      activities: ['Jeux de societe progressifs (echecs, Dobble)', 'Lecture 15-20 min/jour', 'Sports d\'endurance'],
      avoid: ['Ecrans passifs > 30 min', 'Emploi du temps surcharge'],
    ),
    AttentionProfile.highVariability: (
      routine: ['Routine visuelle (pictogrammes)', 'Timer colore : blocs de 10-15 min', 'Transitions annoncees 5 min avant'],
      activities: ['Arts plastiques, musique, danse', 'Construction (Lego, Kapla)', 'Sport varie : obstacles, escalade'],
      avoid: ['Taches monotones sans pauses', 'Punir la lenteur (c\'est neurologique)'],
    ),
    AttentionProfile.inattention: (
      routine: ['Routine matinale simplifiee 4-5 etapes', 'Affaires du lendemain posees la veille', 'Coin calme pour les devoirs'],
      activities: ['Chasses au tresor', 'Dessin, peinture, modelage', 'Nature : missions d\'observation'],
      avoid: ['Repeter "concentre-toi !"', 'Plusieurs consignes a la fois', 'Comparer avec les autres'],
    ),
    AttentionProfile.impulsivity: (
      routine: ['Sport AVANT les devoirs (20 min)', 'Fidget autorise en tache calme', 'Feliciter chaque attente reussie'],
      activities: ['Judo, karate', 'Theatre, jeux de role', 'Cuisine ensemble'],
      avoid: ['"Arrete de bouger !" -> alternative motrice', 'Punitions disproportionnees', 'Sucre + ecrans avant coucher'],
    ),
    AttentionProfile.mixed: (
      routine: ['Pictogrammes + timer', '10 min travail / 5 min mouvement', '3 choses bien faites ce soir'],
      activities: ['Trampoline, velo, natation', 'Jeux cooperatifs', 'Musique : batterie, djembe, danse'],
      avoid: ['Assis > 15 min sans pause', 'Attentes sans occupation', 'Etiquettes negatives'],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;
    return _Advice(tint: Colors.purple, children: [
      const _Header(icon: Icons.home_rounded, text: 'Routine et activites', color: Colors.purple),
      const SizedBox(height: _S.s),
      _Bullets(d.routine, pre: '->'),
      const Divider(),
      Text('Activites recommandees :', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
      const SizedBox(height: _S.xs),
      _Bullets(d.activities),
      const Divider(),
      _Header(icon: Icons.warning_amber_rounded, text: 'A eviter', color: cs.error),
      const SizedBox(height: _S.xs),
      _Bullets(d.avoid, pre: 'x', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error)),
    ]);
  }
}

// ---------------------------------------------------------------
// COMMUNICATION
// ---------------------------------------------------------------
class _CommunicationCard extends StatelessWidget {
  final AttentionProfile profile;
  const _CommunicationCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      doSay: ['"Tu as bien gere ton temps, bravo !"', '"Qu\'est-ce que tu as prefere ?"', '"Tu peux essayer de..."'],
      dontSay: ['"C\'est facile pourtant"'],
      bonding: ['15 min 1-a-1 jeu libre', 'Valider les emotions'],
    ),
    AttentionProfile.highVariability: (
      doSay: ['"C\'est dur de rester concentre, on fait une pause ?"', '"Tu as tenu 10 min, c\'est super !"', '"Un a la fois"'],
      dontSay: ['"Tu pourrais si tu voulais"', '"Pourquoi ca marche des fois et pas d\'autres ?"'],
      bonding: ['Activites nouvelles ensemble', 'Histoires a tour de role'],
    ),
    AttentionProfile.inattention: (
      doSay: ['"Regarde-moi" (contact visuel d\'abord)', '"Redis-moi ce que tu as compris"', '"On met un rappel ensemble"'],
      dontSay: ['"Tu n\'ecoutes jamais !"', '"Je l\'ai dit 10 fois"'],
      bonding: ['Ecouter ses passions sans limite', 'Lire ensemble le soir'],
    ),
    AttentionProfile.impulsivity: (
      doSay: ['"Stop. Respire. Dis-moi"', '"J\'aime ton energie !"', '"Tu as reussi a attendre, bravo"'],
      dontSay: ['"Calme-toi !" sans alternative', '"Tu fais expres"'],
      bonding: ['Jeux physiques ensemble', 'Missions a responsabilite'],
    ),
    AttentionProfile.mixed: (
      doSay: ['"Un truc a la fois"', '"Fier de toi pour avoir essaye"', '"Ton cerveau est different et c\'est OK"'],
      dontSay: ['"Intelligent mais pas d\'effort"', '"Les autres y arrivent"'],
      bonding: ['Code secret pour moments difficiles', 'Journal des 3 meilleurs moments', 'Calins : se reancrer'],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;
    return _Advice(tint: Colors.teal, children: [
      const _Header(icon: Icons.chat_bubble_outline_rounded, text: 'Quoi dire', color: Colors.teal),
      const SizedBox(height: _S.s),
      _Bullets(d.doSay, pre: '->'),
      const Divider(),
      _Header(icon: Icons.warning_amber_rounded, text: 'A ne pas dire', color: cs.error),
      const SizedBox(height: _S.xs),
      _Bullets(d.dontSay, pre: 'x', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error)),
      const Divider(),
      Text('Renforcer le lien :', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
      const SizedBox(height: _S.xs),
      _Bullets(d.bonding, pre: '->'),
    ]);
  }
}

// ---------------------------------------------------------------
// SCHOOL
// ---------------------------------------------------------------
class _SchoolCard extends StatelessWidget {
  final AttentionProfile profile;
  const _SchoolCard({required this.profile});

  static const _data = {
    AttentionProfile.typical: (
      homework: ['Creneaux reguliers', 'Tache difficile en premier', 'Recompense apres'],
      school: ['Participation active', 'Communication enseignant'],
    ),
    AttentionProfile.highVariability: (
      homework: ['10 min max + timer', 'Varier les matieres', 'Mouvement autorise', 'Verifier la consigne'],
      school: ['Place devant loin des fenetres', 'PAP si besoin', 'Consignes ecrites', 'Temps supplementaire'],
    ),
    AttentionProfile.inattention: (
      homework: ['Bureau epure', 'Une tache a la fois', 'Surligner les mots-cles', 'Consigne a voix haute'],
      school: ['Premier rang, eleve calme', 'Consignes individuelles', 'Check-liste devoirs', 'Tiers temps possible'],
    ),
    AttentionProfile.impulsivity: (
      homework: ['Sport 20 min avant', 'Relire avant de finir', 'Etape par etape', 'Mouvement autorise'],
      school: ['Responsabilites motrices', 'Signal discret enseignant', 'Valoriser bonnes prises de parole', 'Alternatives a la punition'],
    ),
    AttentionProfile.mixed: (
      homework: ['8-10 min / 3-5 min pause', 'Barrer chaque exercice fini', 'Code couleur par matiere', 'Recompense par bloc'],
      school: ['PAP ou PPS', 'Place strategique', 'Evaluations fractionnees', 'Cahier liaison hebdo', 'Ergotherapeute scolaire'],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = _data[profile]!;
    return _Advice(tint: Colors.indigo, children: [
      const _Header(icon: Icons.menu_book_rounded, text: 'Devoirs', color: Colors.indigo),
      const SizedBox(height: _S.s),
      _Bullets(d.homework, pre: '->'),
      const Divider(),
      Text('A l\'ecole :', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
      const SizedBox(height: _S.xs),
      _Bullets(d.school),
    ]);
  }
}

// ---------------------------------------------------------------
// WHEN TO CONSULT
// ---------------------------------------------------------------
class _WhenToConsultCard extends StatelessWidget {
  final AttentionProfile profile;
  const _WhenToConsultCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ok = profile == AttentionProfile.typical;
    return _Advice(tint: ok ? Colors.green : cs.error, children: [
      _Header(icon: ok ? Icons.check_circle_outline_rounded : Icons.medical_services_outlined,
        text: ok ? 'Profil dans les normes' : 'Signes a surveiller', color: ok ? Colors.green : cs.error),
      const SizedBox(height: _S.s),
      if (ok)
        Text('Les resultats sont dans les normes saines. Consultez si changements : baisse scolaire, difficultes relationnelles, ou souffrance exprimee.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant))
      else ...[
        Text('Ce jeu n\'est PAS un diagnostic. Evaluez si :', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: _S.s),
        const _Bullets(['Presentes depuis > 6 mois', '2+ contextes (maison ET ecole)', 'Impact sur apprentissages/relations', 'Souffrance exprimee']),
        const Divider(),
        Text('Qui consulter :', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: _S.xs),
        const _Bullets(['Pediatre : premier bilan', 'Neuropediatre/pedopsychiatre : diagnostic', 'Neuropsychologue : bilan complet (WISC, TEA-Ch)', 'Psychomotricien, orthophoniste, ergotherapeute'], pre: '->'),
        const Divider(),
        Text('Ressources :', style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
        const SizedBox(height: _S.xs),
        const _Bullets(['HyperSupers TDAH France', '"Mon cerveau a besoin de lunettes" (Dr Vincent)', '"100 idees pour les troubles de l\'attention" (Lussier)']),
      ],
    ]);
  }
}

// ---------------------------------------------------------------
// HISTORY SCREEN - profile color coded
// ---------------------------------------------------------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  static const _pNames = ['Typique', 'Variable', 'Inattention', 'Impulsivite', 'Mixte'];
  static const _pColors = [Colors.green, Colors.blue, Colors.orange, Colors.red, Colors.purple];

  @override
  void initState() { super.initState(); _load(); }

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
      appBar: AppBar(title: const Text('Historique')),
      body: _history.isEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(_S.l),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.history_rounded, size: 64, color: cs.outlineVariant),
                const SizedBox(height: _S.m),
                Text('Aucune partie jouee', style: tt.headlineSmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: _S.s),
                Text('L\'historique apparaitra ici.', style: tt.bodyMedium?.copyWith(color: cs.outline), textAlign: TextAlign.center),
                const SizedBox(height: _S.l),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pushReplacement(_route(const GameScreen())),
                  icon: const Icon(Icons.play_arrow_rounded), label: const Text('Jouer'),
                ),
              ]),
            ))
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(_S.m),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final h = _history[i];
                final date = DateTime.tryParse(h['date'] ?? '');
                final dateStr = date != null ? '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}' : '?';
                final stars = (h['stars'] as num?)?.toInt() ?? 0;
                final hits = h['hits'] ?? 0;
                final total = h['totalTargets'] ?? 0;
                final meanRt = (h['meanRtMs'] as num?)?.toInt() ?? 0;
                final pIdx = (h['profile'] as num?)?.toInt() ?? 0;
                final pName = pIdx < _pNames.length ? _pNames[pIdx] : '?';
                final pColor = pIdx < _pColors.length ? _pColors[pIdx] : cs.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: _S.s),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(_S.m),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(dateStr, style: tt.bodySmall?.copyWith(color: cs.outline)),
                          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (j) => Icon(
                            j < stars ? Icons.star_rounded : Icons.star_border_rounded,
                            color: j < stars ? Colors.amber : cs.outlineVariant, size: 18,
                          ))),
                        ]),
                        const SizedBox(height: _S.s),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: _S.s, vertical: _S.xs),
                            decoration: BoxDecoration(
                              color: pColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(_S.s),
                            ),
                            child: Text(pName, style: tt.labelSmall?.copyWith(color: pColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: _S.s),
                          Text('$hits/$total maisons', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          const SizedBox(width: _S.s),
                          Text('${meanRt}ms', style: tt.bodySmall?.copyWith(color: cs.outline)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
