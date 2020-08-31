import 'dart:web_audio';

/**
 * @file Listener model to spatialize sources in an environment.
 * @author Andrew Allen <bitllama@google.com>
 */

// Internal dependencies.
import 'omnitone/omnitone.dart';
import 'encoder.dart';
import 'reso_utils.dart';

/**
 * @class Listener
 * @description Listener model to spatialize sources in an environment.
 * @param {AudioContext} context
 * Associated {@link
https://developer.mozilla.org/en-US/docs/Web/API/AudioContext AudioContext}.
 * @param {Object} options
 * @param {Number} options.ambisonicOrder
 * Desired ambisonic order. Defaults to
 * {@linkcode ResoUtils.DEFAULT_AMBISONIC_ORDER DEFAULT_AMBISONIC_ORDER}.
 * @param {Float32Array} options.position
 * Initial position (in meters), where origin is the center of
 * the room. Defaults to
 * {@linkcode ResoUtils.DEFAULT_POSITION DEFAULT_POSITION}.
 * @param {Float32Array} options.forward
 * The listener's initial forward vector. Defaults to
 * {@linkcode ResoUtils.DEFAULT_FORWARD DEFAULT_FORWARD}.
 * @param {Float32Array} options.up
 * The listener's initial up vector. Defaults to
 * {@linkcode ResoUtils.DEFAULT_UP DEFAULT_UP}.
 */
class Listener {
  // Public variables.
  /**
   * Position (in meters).
   * @member {Float32Array} position
   * @memberof Listener
   * @instance
   */
  /**
   * Ambisonic (multichannel) input {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} input
   * @memberof Listener
   * @instance
   */
  /**
   * Binaurally-rendered stereo (2-channel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} output
   * @memberof Listener
   * @instance
   */
  /**
   * Ambisonic (multichannel) output {@link
   * https://developer.mozilla.org/en-US/docs/Web/API/AudioNode AudioNode}.
   * @member {AudioNode} ambisonicOutput
   * @memberof Listener
   * @instance
   */
  AudioContext _context;
  num _ambisonicOrder;
  List<num> position;
  List<num> _tempMatrix3;
  dynamic _renderer;
  GainNode input;
  GainNode output;
  GainNode ambisonicOutput;

  Listener(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for undefined arguments.
    if (options == null) {
      options = new Map<String, dynamic>();
    }
    if (options['ambisonicOrder'] == null) {
      options['ambisonicOrder'] = ResoUtils.DEFAULT_AMBISONIC_ORDER;
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

    // Member variables.
    position = new List<num>(3);
    _tempMatrix3 = new List<num>(9);

    // Select the appropriate HRIR filters using 2-channel chunks since
    // multichannel audio is not yet supported by a majority of browsers.
    _ambisonicOrder = Encoder.validateAmbisonicOrder(options['ambisonicOrder']);

    // Create audio nodes.
    _context = context;
    if (_ambisonicOrder == 1) {
      _renderer = Omnitone.createFOARenderer(context, {});
    } else if (_ambisonicOrder > 1) {
      _renderer = Omnitone.createHOARenderer(context, {
        'ambisonicOrder': _ambisonicOrder,
      });
    }

    // These nodes are created in order to safely asynchronously load Omnitone
    // while the rest of the scene is being created.
    input = context.createGain();
    output = context.createGain();
    ambisonicOutput = context.createGain();

    // Initialize Omnitone (async) and connect to audio graph when complete.
    _renderer.initialize().then(() {
      // Connect pre-rotated soundfield to renderer.
      input.connectNode(_renderer.input);

      // Connect rotated soundfield to ambisonic output.
      if (_ambisonicOrder > 1) {
        _renderer._hoaRotator.output.connect(ambisonicOutput);
      } else {
        _renderer._foaRotator.output.connect(ambisonicOutput);
      }

      // Connect binaurally-rendered soundfield to binaural output.
      _renderer.output.connect(output);
    });

    // Set orientation and update rotation matrix accordingly.
    setOrientation(
        options['forward'][0],
        options['forward'][1],
        options['forward'][2],
        options['up'][0],
        options['up'][1],
        options['up'][2]);
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
  void setOrientation(num forwardX, num forwardY, num forwardZ, upX, upY, upZ) {
    var right =
        ResoUtils.crossProduct([forwardX, forwardY, forwardZ], [upX, upY, upZ]);
    _tempMatrix3[0] = right[0];
    _tempMatrix3[1] = right[1];
    _tempMatrix3[2] = right[2];
    _tempMatrix3[3] = upX;
    _tempMatrix3[4] = upY;
    _tempMatrix3[5] = upZ;
    _tempMatrix3[6] = forwardX;
    _tempMatrix3[7] = forwardY;
    _tempMatrix3[8] = forwardZ;
    _renderer.setRotationMatrix3(_tempMatrix3);
  }
}
