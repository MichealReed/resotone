// Core dependencies
import 'dart:math';
import 'dart:web_audio';

// Internal dependencies
import 'reso_utils.dart';

/// Ray-tracing-based early reflections model.
/// [context]
/// [options]
/// [options.dimensions]
/// Room dimensions (in meters). Defaults to
/// [ResoUtils.DEFAULT_ROOM_DIMENSIONS DEFAULT_ROOM_DIMENSIONS].
/// [options.coefficients]
/// Frequency-independent reflection coeffs per wall. Defaults to
/// [ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS]
/// [options.speedOfSound]
/// (in meters / second). Defaults to [ResoUtils.DEFAULT_SPEED_OF_SOUND]
/// [options.listenerPosition]
/// (in meters). Defaults to
/// [ResoUtils.DEFAULT_POSITION].

class EarlyReflections {
  num speedOfSound;
  GainNode input;
  GainNode output;
  BiquadFilterNode _lowpass;
  Map<String, DelayNode> _delays;
  Map<String, GainNode> _gains;
  Map<String, GainNode> _inverters;
  ChannelMergerNode _merger;
  List<num> _listenerPosition;
  Map<String, dynamic> halfDimensions;
  Map<String, dynamic> _coefficients;

  EarlyReflections(AudioContext context, Map<String, dynamic> options) {
    if (options == null) {
      options = {};
    }
    if (options['speedOfSound'] == null) {
      options['speedOfSound'] = ResoUtils.DEFAULT_SPEED_OF_SOUND;
    }
    if (options['listenerPosition'] == null) {
      options['listenerPosition'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['coefficients'] == null) {
      options['coefficients'] = ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS;
    }

    // Assign room's speed of sound.
    speedOfSound = options['speedOfSound'];

    // Create nodes.
    input = context.createGain();
    output = context.createGain();
    _lowpass = context.createBiquadFilter();
    _delays = new Map<String, DelayNode>();
    _gains = new Map<String,
        GainNode>(); // gainPerWall = (ReflectionCoeff / Attenuation)
    _inverters = new Map<String,
        GainNode>(); // 3 of these are needed for right/back/down walls.
    _merger = context.createChannelMerger(4); // First-order encoding only.

    ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
      if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
        _delays[property] =
            context.createDelay(ResoUtils.DEFAULT_REFLECTION_MAX_DURATION);
        _gains[property] = context.createGain();
      }
    });
    // connectNode audio graph for each wall reflection.
    _inverters['right'] = context.createGain();
    _inverters['down'] = context.createGain();
    _inverters['back'] = context.createGain();

    // Initialize lowpass filter.
    _lowpass.type = 'lowpass';
    _lowpass.frequency.value = ResoUtils.DEFAULT_REFLECTION_CUTOFF_FREQUENCY;
    _lowpass.Q.value = 0;

    // Initialize encoder directions, set delay times and gains to 0.
    ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
      if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
        _delays[property].delayTime.value = 0;
        _gains[property].gain.value = 0;
      }
    });

    // Initialize inverters for opposite walls ('right', 'down', 'back' only).
    _inverters['right'].gain.value = -1;
    _inverters['down'].gain.value = -1;
    _inverters['back'].gain.value = -1;

    // connectNode nodes.
    input.connectNode(_lowpass);
    ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
      if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
        _lowpass.connectNode(_delays[property]);
        _delays[property].connectNode(_gains[property]);
        _gains[property].connectNode(_merger, 0, 0);
      }
    });

    // connectNode gains to ambisonic channel output.
    // Left: [1 1 0 0]
    // Right: [1 -1 0 0]
    // Up: [1 0 1 0]
    // Down: [1 0 -1 0]
    // Front: [1 0 0 1]
    // Back: [1 0 0 -1]
    _gains['left'].connectNode(_merger, 0, 1);

    _gains['right'].connectNode(_inverters['right']);
    _inverters['right'].connectNode(_merger, 0, 1);

    _gains['up'].connectNode(_merger, 0, 2);

    _gains['down'].connectNode(_inverters['down']);
    _inverters['down'].connectNode(_merger, 0, 2);

    _gains['front'].connectNode(_merger, 0, 3);

    _gains['back'].connectNode(_inverters['back']);
    _inverters['back'].connectNode(_merger, 0, 3);
    _merger.connectNode(output);

    // Initialize.
    _listenerPosition = options['listenerPosition'];
    setRoomProperties(options['dimensions'], options['coefficients']);
  }

  /// Set the listener's position (in meters),
  /// where 0,0,0 is the center of the room.
  /// [x]
  /// [y]
  /// [z]

  void setListenerPosition(num x, num y, num z) {
    // Assign listener position.
    _listenerPosition = [x, y, z];

    // Determine distances to each wall.
    Map<String, dynamic> distances = {
      'left': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['width'] + x) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
      'right': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['width'] - x) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
      'front': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['depth'] + z) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
      'back': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['depth'] - z) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
      'down': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['height'] + y) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
      'up': ResoUtils.DEFAULT_REFLECTION_MULTIPLIER *
              max(0, halfDimensions['height'] - y) +
          ResoUtils.DEFAULT_REFLECTION_MIN_DISTANCE,
    };

    // Assign delay & attenuation values using distances.
    ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
      if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
        // Compute and assign delay (in seconds).
        num delayInSecs = distances[property] / speedOfSound;
        _delays[property].delayTime.value = delayInSecs;

        // Compute and assign gain, uses logarithmic rolloff: "g = R / (d + 1)"
        num attenuation = _coefficients[property] / distances[property];
        _gains[property].gain.value = attenuation;
      }
    });
  }

  /// Set the room's properties which determines the characteristics of
  /// reflections.
  /// Room [dimensions] (in meters). Defaults to
  /// [ResoUtils.DEFAULT_ROOM_DIMENSIONS DEFAULT_ROOM_DIMENSIONS].
  /// [coefficients]
  /// Frequency-independent reflection coeffs per wall. Defaults to
  /// [ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS]
  void setRoomProperties(
      Map<String, dynamic> dimensions, Map<String, dynamic> coefficients) {
    if (dimensions == null) {
      dimensions = ResoUtils.DEFAULT_ROOM_DIMENSIONS;
    }
    if (coefficients == null) {
      coefficients = ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS;
    }
    _coefficients = coefficients;

    // Sanitize dimensions and store half-dimensions.
    halfDimensions = new Map<String, dynamic>();
    halfDimensions['width'] = dimensions['width'] * 0.5;
    halfDimensions['height'] = dimensions['height'] * 0.5;
    halfDimensions['depth'] = dimensions['depth'] * 0.5;

    // Update listener position with new room properties.
    setListenerPosition(
        _listenerPosition[0], _listenerPosition[1], _listenerPosition[2]);
  }
}
