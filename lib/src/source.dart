// Core Dependencies
import 'dart:math';
import 'dart:web_audio';

// Internal Dependencies
import 'directivity.dart';
import 'attenuation.dart';
import 'encoder.dart';
import 'reso_utils.dart';
import 'resonance_audio.dart';

/// Source model to spatialize an audio buffer.
class Source {
  Source(ResonanceAudio scene, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    // Options for constructing a new Source.
    // [position]
    // The source's initial position (in meters), where origin is the center of
    // the room.
    // [forward]
    // The source's initial forward vector.
    // [up]
    // The source's initial up vector.
    // [minDistance]
    // Min. distance (in meters).
    // [maxDistance]
    // Max. distance (in meters).
    // [rolloff]
    // Rolloff model to use, chosen from options in
    // [ResoUtils.ATTENUATION_ROLLOFFS].
    // [gain] Input gain (linear).
    // [alpha] Directivity alpha.
    // [sharpness] Directivity sharpness.
    // [sourceWidth]
    // Source width (in degrees). Where 0 degrees is a point source and 360 degrees
    // is an omnidirectional source.
    if (options == null) {
      options = new Map<String, dynamic>();
    }
    if (!options.containsKey('position')) {
      options['position'] = ResoUtils.DEFAULT_POSITION;
    }
    if (!options.containsKey('forward')) {
      options['forward'] = ResoUtils.DEFAULT_FORWARD;
    }
    if (!options.containsKey('up')) {
      options['up'] = ResoUtils.DEFAULT_UP;
    }
    if (!options.containsKey('minDistance')) {
      options['minDistance'] = ResoUtils.DEFAULT_MIN_DISTANCE;
    }
    if (!options.containsKey('maxDistance')) {
      options['maxDistance'] = ResoUtils.DEFAULT_MAX_DISTANCE;
    }
    if (!options.containsKey('rolloff')) {
      options['rolloff'] = ResoUtils.DEFAULT_ATTENUATION_ROLLOFF;
    }
    if (!options.containsKey('gain')) {
      options['gain'] = ResoUtils.DEFAULT_SOURCE_GAIN;
    }
    if (!options.containsKey('alpha')) {
      options['alpha'] = ResoUtils.DEFAULT_DIRECTIVITY_ALPHA;
    }
    if (!options.containsKey('sharpness')) {
      options['sharpness'] = ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS;
    }
    if (!options.containsKey('sourceWidth')) {
      options['sourceWidth'] = ResoUtils.DEFAULT_SOURCE_WIDTH;
    }

    // Member variables.
    _scene = scene;
    _position = options['position'];
    _forward = options['forward'];
    _up = options['up'];
    _dx = new List<num>(3);
    _right = ResoUtils.crossProduct(_forward, _up);

    // Create audio nodes.
    AudioContext context = scene.context;
    input = context.createGain();
    _directivity = new Directivity(context, {
      'alpha': options['alpha'],
      'sharpness': options['sharpness'],
    });
    _toEarly = context.createGain();
    _toLate = context.createGain();
    _attenuation = new Attenuation(context, {
      'minDistance': options['minDistance'],
      'maxDistance': options['maxDistance'],
      'rolloff': options['rolloff'],
    });
    _encoder = new Encoder(context, {
      'ambisonicOrder': scene.ambisonicOrder,
      'sourceWidth': options['sourceWidth'],
    });

    // Connect nodes.
    input.connectNode(_toLate);
    _toLate.connectNode(scene.room.lateReflections.input);

    input.connectNode(_attenuation.input);
    _attenuation.output.connectNode(_toEarly);
    _toEarly.connectNode(scene.room.earlyReflections.input);

    _attenuation.output.connectNode(_directivity.input);
    _directivity.output.connectNode(_encoder.input);

    _encoder.output.connectNode(scene.listener.input);

    // Assign initial conditions.
    setPosition(
        options['position'][0], options['position'][1], options['position'][2]);
    input.gain.value = options['gain'];
  }

  ResonanceAudio _scene;
  List<num> _position;
  List<num> _forward;
  List<num> _up;
  List<num> _dx;
  List<num> _right;
  GainNode input;
  Directivity _directivity;
  GainNode _toEarly;
  GainNode _toLate;
  Attenuation _attenuation;
  Encoder _encoder;

  /// Set source's position (in meters), where origin is the center of
  /// the room.
  ///  [x]
  ///  [y]
  ///  [z]
  void setPosition(num x, num y, num z) {
    // Assign new position.
    _position[0] = x;
    _position[1] = y;
    _position[2] = z;

    // Handle far-field effect.
    num distance = _scene.room
        .getDistanceOutsideRoom(_position[0], _position[1], _position[2]);
    num gain = _computeDistanceOutsideRoom(distance);
    _toLate.gain.value = gain;
    _toEarly.gain.value = gain;

    update();
  }

// Update the source when changing the listener's position.
  void update() {
    // Compute distance to listener.
    for (num i = 0; i < 3; i++) {
      _dx[i] = _position[i] - _scene.listener.position[i];
    }
    num distance = sqrt(_dx[0] * _dx[0] + _dx[1] * _dx[1] + _dx[2] * _dx[2]);
    if (distance > 0) {
      // Normalize direction vector.
      _dx[0] /= distance;
      _dx[1] /= distance;
      _dx[2] /= distance;
    }

    // Compuete angle of direction vector.
    num azimuth = atan2(-_dx[0], _dx[2]) * ResoUtils.RADIANS_TO_DEGREES;
    num elevation = atan2(_dx[1], sqrt(_dx[0] * _dx[0] + _dx[2] * _dx[2])) *
        ResoUtils.RADIANS_TO_DEGREES;

    // Set distance/directivity/direction values.
    _attenuation.setDistance(distance);
    _directivity.computeAngle(_forward, _dx);
    _encoder.setDirection(azimuth, elevation);
  }

  /// Set source's [rolloff].
  /// Rolloff model to use, chosen from options in
  /// [ResoUtils.ATTENUATION_ROLLOFFS ATTENUATION_ROLLOFFS].

  void setRolloff(String rolloff) {
    _attenuation.setRolloff(rolloff);
  }

  /// Set source's minimum distance (in meters).
  /// [minDistance]
  void setMinDistance(num minDistance) {
    _attenuation.minDistance = minDistance;
  }

  /// Set source's maximum distance (in meters).
  /// [maxDistance]
  void setMaxDistance(num maxDistance) {
    _attenuation.maxDistance = maxDistance;
  }

  /// Set source's gain (linear).
  /// [gain]
  void setGain(num gain) {
    input.gain.value = gain;
  }

  /// Set the source's orientation using forward and up vectors.
  ///  [forwardX]
  ///  [forwardY]
  ///  [forwardZ]
  ///  [upX]
  ///  [upY]
  ///  [upZ]
  void setOrientation(
      num forwardX, num forwardY, num forwardZ, num upX, num upY, num upZ) {
    _forward[0] = forwardX;
    _forward[1] = forwardY;
    _forward[2] = forwardZ;
    _up[0] = upX;
    _up[1] = upY;
    _up[2] = upZ;
    _right = ResoUtils.crossProduct(_forward, _up);
  }

  /// Set the source width (in degrees). Where 0 degrees is a point source and 360
  /// degrees is an omnidirectional source.
  /// [sourceWidth] (in degrees).
  void setSourceWidth(num sourceWidth) {
    _encoder.setSourceWidth(sourceWidth);
    setPosition(_position[0], _position[1], _position[2]);
  }

  /// Set source's directivity pattern (defined by alpha), where 0 is an
  /// omnidirectional pattern, 1 is a bidirectional pattern, 0.5 is a cardiod
  /// pattern. The sharpness of the pattern is increased exponentially.
  /// [alpha]
  /// Determines directivity pattern (0 to 1).
  /// [sharpness]
  /// Determines the sharpness of the directivity pattern (1 to Inf).
  void setDirectivityPattern(num alpha, num sharpness) {
    _directivity.setPattern(alpha, sharpness);
    setPosition(_position[0], _position[1], _position[2]);
  }

  /// Determine the distance a source is outside of a room. Attenuate gain going
  /// to the reflections and reverb when the source is outside of the room.
  /// [distance] Distance in meters.
  /// return Gain (linear) of source.
  num _computeDistanceOutsideRoom(num distance) {
    // We apply a linear ramp from 1 to 0 as the source is up to 1m outside.
    num gain = 1;
    if (distance > ResoUtils.EPSILON_FLOAT) {
      gain = 1 - distance / ResoUtils.SOURCE_MAX_OUTSIDE_ROOM_DISTANCE;

      // Clamp gain between 0 and 1.
      gain = max(0, min(1, gain));
    }
    return gain;
  }
}
