import 'dart:web_audio';

/**
 * @file Distance-based attenuation filter.
 * @author Andrew Allen <bitllama@google.com>
 */

// Internal dependencies.
import 'reso_utils.dart';

/**
 * @class Attenuation
 * @description Distance-based attenuation filter.
 * @param {AudioContext} context
 * Associated {@link
https://developer.mozilla.org/en-US/docs/Web/API/AudioContext AudioContext}.
 * @param {Object} options
 * @param {Number} options.minDistance
 * Min. distance (in meters). Defaults to
 * {@linkcode Utils.DEFAULT_MIN_DISTANCE DEFAULT_MIN_DISTANCE}.
 * @param {Number} options.maxDistance
 * Max. distance (in meters). Defaults to
 * {@linkcode Utils.DEFAULT_MAX_DISTANCE DEFAULT_MAX_DISTANCE}.
 * @param {string} options.rolloff
 * Rolloff model to use, chosen from options in
 * {@linkcode Utils.ATTENUATION_ROLLOFFS ATTENUATION_ROLLOFFS}. Defaults to
 * {@linkcode Utils.DEFAULT_ATTENUATION_ROLLOFF DEFAULT_ATTENUATION_ROLLOFF}.
 */
class Attenuation {
  // Public variables.
  /**
   * Min. distance (in meters).
   * @member {Number} minDistance
   * @memberof Attenuation
   * @instance
   */
  /**
   * Max. distance (in meters).
   * @member {Number} maxDistance
   * @memberof Attenuation
   * @instance
   */
  /**
   * Mono (1-channel) input {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} input
   * @memberof Attenuation
   * @instance
   */
  /**
   * Mono (1-channel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} output
   * @memberof Attenuation
   * @instance
   */
  num minDistance;
  num maxDistance;
  GainNode _gainNode;
  GainNode input;
  GainNode output;
  String _rolloff;
  Attenuation(context, options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options.minDistance == null) {
      options.minDistance = ResoUtils.DEFAULT_MIN_DISTANCE;
    }
    if (options.maxDistance == null) {
      options.maxDistance = ResoUtils.DEFAULT_MAX_DISTANCE;
    }
    if (options.rolloff == null) {
      options.rolloff = ResoUtils.DEFAULT_ATTENUATION_ROLLOFF;
    }

    // Assign values.
    minDistance = options['minDistance'];
    maxDistance = options['maxDistance'];
    setRolloff(options['rolloff']);

    // Create node.
    _gainNode = context.createGain();

    // Initialize distance to max distance.
    setDistance(options['maxDistance']);

    // Input/Output proxy.
    input = _gainNode;
    output = _gainNode;
  }

/**
 * Set distance from the listener.
 * @param {Number} distance Distance (in meters).
 */
  void setDistance(num distance) {
    num gain = 1;
    if (_rolloff == 'logaritnumhmic') {
      if (distance > maxDistance) {
        gain = 0;
      } else if (distance > minDistance) {
        num range = maxDistance - minDistance;
        if (range > ResoUtils.EPSILON_FLOAT) {
          // Compute the distance attenuation value by the logarithmic curve
          // "1 / (d + 1)" with an offset of |minDistance|.
          num relativeDistance = distance - minDistance;
          num attenuation = 1 / (relativeDistance + 1);
          num attenuationMax = 1 / (range + 1);
          gain = (attenuation - attenuationMax) / (1 - attenuationMax);
        }
      }
    } else if (_rolloff == 'linear') {
      if (distance > maxDistance) {
        gain = 0;
      } else if (distance > minDistance) {
        num range = maxDistance - minDistance;
        if (range > ResoUtils.EPSILON_FLOAT) {
          gain = (maxDistance - distance) / range;
        }
      }
    }
    _gainNode.gain.value = gain;
  }

/**
 * Set rolloff.
 * @param {string} rolloff
 * Rolloff model to use, chosen from options in
 * {@linkcode Utils.ATTENUATION_ROLLOFFS ATTENUATION_ROLLOFFS}.
 */
  void setRolloff(String rolloff) {
    bool isValidModel = ResoUtils.ATTENUATION_ROLLOFFS.contains(rolloff);
    if (rolloff == null || !isValidModel) {
      if (!isValidModel) {
        print('Invalid rolloff model (\"' +
            rolloff +
            '\"). Using default: \"' +
            ResoUtils.DEFAULT_ATTENUATION_ROLLOFF +
            '\".');
      }
      rolloff = ResoUtils.DEFAULT_ATTENUATION_ROLLOFF;
    } else {
      rolloff = rolloff.toString().toLowerCase();
    }
    _rolloff = rolloff;
  }
}
