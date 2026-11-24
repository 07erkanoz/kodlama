// LifeOS Yankı'dan (lib/ui/desktop/ajan_skins.dart) alındı: figürlerin hareket durumu.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What Folio Ajan's full screen shows: nothing yet, or one of the voice's
/// moments.
enum AjanMood { idle, listening, speaking, working }

/// The middle figure's state between frames: how loud, how far it has
/// turned, each mood's weight eased in and out, and the last seconds of
/// the voice's loudness for the waves and bars to draw.
class AjanMotion {
  double level = 0, spin = 0, t = 0;
  AjanMood mood = AjanMood.idle;

  /// Each mood's weight, 0…1, eased: a change of mood blends, never jumps.
  double listen = 0, speak = 0, work = 0;

  /// The loudness heard, newest first, one a frame.
  final history = Float32List(160);

  void step(double t, double frames, AjanMood mood, double sound) {
    this.t = t;
    this.mood = mood;
    final s = sound.clamp(0.0, 1.0);
    final target = switch (mood) {
      AjanMood.idle => .05 + .03 * math.sin(t * .9),
      AjanMood.listening => .08 + .05 * math.sin(t * 1.3) + s * .5,
      AjanMood.speaking => .25 + s * 1.1,
      AjanMood.working => .3,
    };
    final ease = 1 - math.pow(1 - .18, frames).toDouble();
    level += (target - level) * ease;
    final slow = 1 - math.pow(1 - .08, frames).toDouble();
    listen += ((mood == AjanMood.listening ? 1 : 0) - listen) * slow;
    speak += ((mood == AjanMood.speaking ? 1 : 0) - speak) * slow;
    work += ((mood == AjanMood.working ? 1 : 0) - work) * slow;
    spin +=
        (mood == AjanMood.working ? .035 : .006 + level * .01) *
        frames.toDouble();
    final n = frames.round().clamp(1, 8);
    final heard =
        (s * (.35 + speak * .65 + listen * .4) +
                work * .12 +
                .02 * math.sin(t * 2.1))
            .clamp(0.0, 1.0);
    for (var k = 0; k < n; k++) {
      history.setRange(1, history.length, history);
      history[0] = heard;
    }
  }
}
