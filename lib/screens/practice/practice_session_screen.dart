import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../data/practice/practice_bank.dart';
import '../../models/practice_exercise.dart';
import '../../theme_provider.dart';

/// Sesión de práctica estilo Duolingo (hasta 10 ejercicios).
class PracticeSessionScreen extends StatefulWidget {
  final PracticeCategory category;
  final String level;
  final Color accentColor;

  const PracticeSessionScreen({
    super.key,
    required this.category,
    required this.level,
    required this.accentColor,
  });

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  late final List<PracticeExercise> _exercises;
  int _index = 0;
  String? _selected;
  bool _checked = false;
  bool _finished = false;
  int _correctCount = 0;

  final AudioPlayer _sfxPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _exercises = PracticeBank.byCategoryAndLevel(
      widget.category,
      widget.level,
      limit: 10,
      shuffle: true,
    );
    _sfxPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  @override
  void dispose() {
    _sfxPlayer.dispose();
    super.dispose();
  }

  Future<void> _playFeedbackSound(bool correct) async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(
        AssetSource(correct ? 'sound/correct.mp3' : 'sound/incorrect.mp3'),
        volume: correct ? 0.45 : 1.0,
      );
    } catch (e) {
      debugPrint('Practice sfx error: $e');
    }
  }

  PracticeExercise? get _current =>
      _exercises.isEmpty || _index >= _exercises.length
          ? null
          : _exercises[_index];

  double get _progress {
    if (_exercises.isEmpty) return 1;
    if (_finished) return 1;
    return (_index + (_checked ? 1 : 0)) / _exercises.length;
  }

  void _onCheck() {
    final ex = _current;
    if (ex == null || _selected == null) return;
    final ok = ex.isCorrect(_selected!);
    setState(() {
      _checked = true;
      if (ok) _correctCount++;
    });
    _playFeedbackSound(ok);
  }

  void _onContinue() {
    if (_index + 1 >= _exercises.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _checked = false;
    });
  }

  void _retry() {
    setState(() {
      _exercises
        ..clear()
        ..addAll(
          PracticeBank.byCategoryAndLevel(
            widget.category,
            widget.level,
            limit: 10,
            shuffle: true,
          ),
        );
      _index = 0;
      _selected = null;
      _checked = false;
      _finished = false;
      _correctCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgScaffold,
      body: SafeArea(
        child: _exercises.isEmpty
            ? _buildEmpty(context)
            : _finished
                ? _buildScore(context)
                : _buildSession(context),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: context.textColor),
            ),
          ),
          const Spacer(),
          Icon(Icons.inbox_rounded, size: 56, color: context.subtitleColor),
          const SizedBox(height: 16),
          Text(
            'No hay ejercicios para ${widget.category.label} ${widget.level}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.textColor,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Salir'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSession(BuildContext context) {
    final ex = _current!;
    final isCorrect = _checked && _selected != null && ex.isCorrect(_selected!);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: context.textColor),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 12,
                    backgroundColor: widget.accentColor.withValues(alpha: 0.15),
                    color: widget.accentColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_index + 1}/${_exercises.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.subtitleColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ex.instruction,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.borderColor),
                    boxShadow: [
                      if (!context.isDarkMode)
                        BoxShadow(
                          color: context.shadowColor,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Text(
                    ex.prompt,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                      color: context.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...ex.options.map((opt) => _optionTile(context, ex, opt)),
                if (_checked) ...[
                  const SizedBox(height: 16),
                  _feedbackCard(context, isCorrect, ex),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _checked
                  ? _onContinue
                  : (_selected == null ? null : _onCheck),
              style: FilledButton.styleFrom(
                backgroundColor: _checked
                    ? (isCorrect
                        ? const Color(0xFF1FAB5E)
                        : const Color(0xFFE74C3C))
                    : widget.accentColor,
                disabledBackgroundColor:
                    widget.accentColor.withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _checked ? 'CONTINUAR' : 'COMPROBAR',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionTile(
    BuildContext context,
    PracticeExercise ex,
    String opt,
  ) {
    final selected = _selected == opt;
    final showResult = _checked;
    final isAnswer = ex.isCorrect(opt);

    Color border;
    Color bg;
    Color fg = context.textColor;

    if (showResult && isAnswer) {
      border = const Color(0xFF1FAB5E);
      bg = const Color(0xFF1FAB5E).withValues(alpha: 0.12);
      fg = const Color(0xFF1FAB5E);
    } else if (showResult && selected && !isAnswer) {
      border = const Color(0xFFE74C3C);
      bg = const Color(0xFFE74C3C).withValues(alpha: 0.12);
      fg = const Color(0xFFE74C3C);
    } else if (selected) {
      border = widget.accentColor;
      bg = widget.accentColor.withValues(alpha: 0.12);
      fg = widget.accentColor;
    } else {
      border = context.borderColor;
      bg = context.cardColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _checked
              ? null
              : () => setState(() => _selected = opt),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: selected || showResult ? 2 : 1),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedbackCard(
    BuildContext context,
    bool isCorrect,
    PracticeExercise ex,
  ) {
    final color =
        isCorrect ? const Color(0xFF1FAB5E) : const Color(0xFFE74C3C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? '¡Correcto!' : 'Incorrecto',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              'Respuesta: ${ex.answer}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ],
          if (ex.explanation != null && ex.explanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ex.explanation!,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: context.subtitleColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScore(BuildContext context) {
    final total = _exercises.length;
    final pct = total == 0 ? 0 : ((_correctCount / total) * 100).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: context.textColor),
            ),
          ),
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 48,
              color: widget.accentColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Sesión completada!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.category.label} · ${widget.level}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.subtitleColor,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.borderColor),
              boxShadow: [
                if (!context.isDarkMode)
                  BoxShadow(
                    color: context.shadowColor,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$_correctCount / $total',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct% aciertos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _retry,
              style: FilledButton.styleFrom(
                backgroundColor: widget.accentColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Reintentar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textColor,
                side: BorderSide(color: context.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Salir',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
