/**
 * @license
 * Copyright 2017 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math';
import 'dart:web_audio';

/**
 * @file Source model to spatialize an audio buffer.
 * @author Andrew Allen <bitllama@google.com>
 */

// Internal dependencies.
import 'directivity.dart';
import 'attenuation.dart';
import 'encoder.dart';
import 'reso_utils.dart';
import 'resonance_audio.dart';

/**
 * Options for constructing a new Source.
 * @typedef {Object} Source~SourceOptions
 * @property {List<num>} position
 * The source's initial position (in meters), where origin is the center of
 * the room. Defaults to {@linkcode ResoUtils.DEFAULT_POSITION DEFAULT_POSITION}.
 * @property {List<num>} forward
 * The source's initial forward vector. Defaults to
 * {@linkcode ResoUtils.DEFAULT_FORWARD DEFAULT_FORWARD}.
 * @property {List<num>} up
 * The source's initial up vector. Defaults to
 * {@linkcode ResoUtils.DEFAULT_UP DEFAULT_UP}.
 * @property {Number} minDistance
 * Min. distance (in meters). Defaults to
 * {@linkcode ResoUtils.DEFAULT_MIN_DISTANCE DEFAULT_MIN_DISTANCE}.
 * @property {Number} maxDistance
 * Max. distance (in meters). Defaults to
 * {@linkcode ResoUtils.DEFAULT_MAX_DISTANCE DEFAULT_MAX_DISTANCE}.
 * @property {string} rolloff
 * Rolloff model to use, chosen from options in
 * {@linkcode ResoUtils.ATTENUATION_ROLLOFFS ATTENUATION_ROLLOFFS}. Defaults to
 * {@linkcode ResoUtils.DEFAULT_ATTENUATION_ROLLOFF DEFAULT_ATTENUATION_ROLLOFF}.
 * @property {Number} gain Input gain (linear). Defaults to
 * {@linkcode ResoUtils.DEFAULT_SOURCE_GAIN DEFAULT_SOURCE_GAIN}.
 * @property {Number} alpha Directivity alpha. Defaults to
 * {@linkcode ResoUtils.DEFAULT_DIRECTIVITY_ALPHA DEFAULT_DIRECTIVITY_ALPHA}.
 * @property {Number} sharpness Directivity sharpness. Defaults to
 * {@linkcode ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS
 * DEFAULT_DIRECTIVITY_SHARPNESS}.
 * @property {Number} sourceWidth
 * Source width (in degrees). Where 0 degrees is a point source and 360 degrees
 * is an omnidirectional source. Defaults to
 * {@linkcode ResoUtils.DEFAULT_SOURCE_WIDTH DEFAULT_SOURCE_WIDTH}.
 */

/**
 * @class Source
 * @description Source model to spatialize an audio buffer.
 * @param {ResonanceAudio} scene Associated {@link ResonanceAudio
 * ResonanceAudio} instance.
 * @param {Source~SourceOptions} options
 * Options for constructing a new Source.
 */
class Source {
  // Public variables.
  /**
   * Mono (1-channel) input {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} input
   * @memberof Source
   * @instance
   */
  /**
   *
   */

  Source(ResonanceAudio scene, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = new Map<String, dynamic>();
    }
    if (options['position'] == null) {
      options['position'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['forward'] == null) {
      options['forward'] = ResoUtils.DEFAULT_FORWARD;
    }
    if (options['up'] == null) {
      options['up'] = ResoUtils.DEFAULT_UP;
    }
    if (options['minDistance'] == null) {
      options['minDistance'] = ResoUtils.DEFAULT_MIN_DISTANCE;
    }
    if (options['maxDistance'] == null) {
      options['maxDistance'] = ResoUtils.DEFAULT_MAX_DISTANCE;
    }
    if (options['rolloff'] == null) {
      options['rolloff'] = ResoUtils.DEFAULT_ATTENUATION_ROLLOFF;
    }
    if (options['gain'] == null) {
      options['gain'] = ResoUtils.DEFAULT_SOURCE_GAIN;
    }
    if (options['alpha'] == null) {
      options['alpha'] = ResoUtils.DEFAULT_DIRECTIVITY_ALPHA;
    }
    if (options['sharpness'] == null) {
      options['sharpness'] = ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS;
    }
    if (options['sourceWidth'] == null) {
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

/**
 * Set source's position (in meters), where origin is the center of
 * the room.
 * @param {Number} x
 * @param {Number} y
 * @param {Number} z
 */
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

/**
 * Set source's rolloff.
 * @param {string} rolloff
 * Rolloff model to use, chosen from options in
 * {@linkcode ResoUtils.ATTENUATION_ROLLOFFS ATTENUATION_ROLLOFFS}.
 */
  void setRolloff(String rolloff) {
    _attenuation.setRolloff(rolloff);
  }

/**
 * Set source's minimum distance (in meters).
 * @param {Number} minDistance
 */
  void setMinDistance(num minDistance) {
    _attenuation.minDistance = minDistance;
  }

/**
 * Set source's maximum distance (in meters).
 * @param {Number} maxDistance
 */
  void setMaxDistance(num maxDistance) {
    _attenuation.maxDistance = maxDistance;
  }

/**
 * Set source's gain (linear).
 * @param {Number} gain
 */
  void setGain(num gain) {
    input.gain.value = gain;
  }

/**
 * Set the source's orientation using forward and up vectors.
 * @param {Number} forwardX
 * @param {Number} forwardY
 * @param {Number} forwardZ
 * @param {Number} upX
 * @param {Number} upY
 * @param {Number} upZ
 */
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

/**
 * Set the source width (in degrees). Where 0 degrees is a point source and 360
 * degrees is an omnidirectional source.
 * @param {Number} sourceWidth (in degrees).
 */
  void setSourceWidth(num sourceWidth) {
    _encoder.setSourceWidth(sourceWidth);
    setPosition(_position[0], _position[1], _position[2]);
  }

/**
 * Set source's directivity pattern (defined by alpha), where 0 is an
 * omnidirectional pattern, 1 is a bidirectional pattern, 0.5 is a cardiod
 * pattern. The sharpness of the pattern is increased exponentially.
 * @param {Number} alpha
 * Determines directivity pattern (0 to 1).
 * @param {Number} sharpness
 * Determines the sharpness of the directivity pattern (1 to Inf).
 */
  void setDirectivityPattern(num alpha, num sharpness) {
    _directivity.setPattern(alpha, sharpness);
    setPosition(_position[0], _position[1], _position[2]);
  }

/**
 * Determine the distance a source is outside of a room. Attenuate gain going
 * to the reflections and reverb when the source is outside of the room.
 * @param {Number} distance Distance in meters.
 * @return {Number} Gain (linear) of source.
 * @private
 */
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
