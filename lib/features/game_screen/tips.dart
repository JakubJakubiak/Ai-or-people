import 'dart:math';

import 'package:humanai/models/game_item.dart';

/// Short "what to look for" hints shown after each answer, so every round
/// teaches something about telling AI and human work apart.
class Tips {
  static final _random = Random();

  static const _aiImage = [
    'Count fingers and check teeth and ears — AI often fuses or duplicates them.',
    'Zoom in on any text or signs. AI lettering tends to melt into gibberish.',
    'Skin that looks waxy and perfectly smooth is a classic AI tell.',
    'Check the background: objects that blend into each other or bend oddly.',
    'Look at pairs — earrings, glasses, eyes. AI often makes them mismatched.',
    'Lighting that is dramatic everywhere at once, with no clear source, hints at AI.',
    'Fur, hair and fabric that turn into a soft blur at the edges often mean AI.',
  ];

  static const _humanImage = [
    'Real photos keep fine, slightly messy detail: stray hairs, dust, sensor noise.',
    'Shadows and reflections all agree with one light source — hard for AI to fake.',
    'Readable text, logos and number plates are a good sign of a real photo.',
    'Imperfect framing and ordinary moments are more typical of human photos.',
    'Depth of field behaves like a real lens: blur grows smoothly with distance.',
  ];

  static const _aiVideo = [
    'Watch things as they move: AI video makes shapes morph, flicker or merge.',
    'Check hands and feet in motion — fingers change count, feet slide on the ground.',
    'AI clips often have a dreamy, slow-motion glide with no real camera shake.',
    'Look at the background over time: details appear and vanish between frames.',
    'Physics gives it away: liquids, smoke and cloth that move in impossible ways.',
  ];

  static const _humanVideo = [
    'Details stay the same from frame to frame — textures do not crawl or shimmer.',
    'Natural hand-held shake and focus hunting point to a real camera.',
    'Real motion has weight: things speed up, slow down and collide believably.',
    'Small accidents — a blink, a stumble, a passer-by — are hard for AI to invent.',
  ];

  static const _aiMusic = [
    'Listen to the top end of the vocals: AI voices have a faint metallic shimmer.',
    'AI lyrics are often generic, and consonants get slurred or swallowed.',
    'Hi-hats and cymbals that sound watery or smeared are a common AI artifact.',
    'Instruments blur into one wall of sound instead of sitting in clear places.',
    'AI songs often drift: the melody wanders and endings fade out awkwardly.',
  ];

  static const _humanMusic = [
    'Each instrument has its own clear space in the mix, with crisp drum hits.',
    'Human tracks follow a deliberate plan: build-ups, drops and clean transitions.',
    'Vocals breathe — you can hear breaths, phrasing and intentional emphasis.',
    'A clean, noise-free top end usually means a real studio production.',
  ];

  static String forItem(GameItem item) {
    final list = switch ((item.type, item.isAi)) {
      (MediaType.image, true) => _aiImage,
      (MediaType.image, false) => _humanImage,
      (MediaType.video, true) => _aiVideo,
      (MediaType.video, false) => _humanVideo,
      (MediaType.music, true) => _aiMusic,
      (MediaType.music, false) => _humanMusic,
    };
    return list[_random.nextInt(list.length)];
  }
}
