// Core Dependencies
import 'dart:web_audio';

// Internal Dependencies
import 'omnitone/omnitone.dart';
import 'encoder.dart';
import 'reso_utils.dart';

/// Listener model to spatialize sources in an environment.
class Listener {
// Desired ambisonic order. Defaults to
// [ResoUtils.DEFAULT_AMBISONIC_ORDER DEFAULT_AMBISONIC_ORDER].
// [options.position]
// Initial position (in meters), where origin is the center of
// the room. Defaults to
// [ResoUtils.DEFAULT_POSITION DEFAULT_POSITION].
// [options.forward]
// The listener's initial forward vector. Defaults to
// [ResoUtils.DEFAULT_FORWARD DEFAULT_FORWARD].
// [options.up]
// The listener's initial up vector. Defaults to
// [ResoUtils.DEFAULT_UP DEFAULT_UP].
  AudioContext _context;
  num _ambisonicOrder;
  List<num> position;
  List<num> _tempMatrix3;
  dynamic _renderer;
  GainNode input;
  GainNode output;
  GainNode ambisonicOutput;

  Listener();

  Future<void> init(AudioContext context, Map<String, dynamic> options) async {
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

    // Initialize Omnitone (async) and connectNode to audio graph when complete.
    await _renderer.initialize();

    // Connect pre-rotated soundfield to renderer.
    input.connectNode(_renderer.input);

    // Connect rotated soundfield to ambisonic output.
    if (_ambisonicOrder > 1) {
      _renderer.hoaRotator.output.connectNode(ambisonicOutput);
    } else {
      _renderer.foaRotator.output.connectNode(ambisonicOutput);
    }

    // Connect binaurally-rendered soundfield to binaural output.
    _renderer.output.connectNode(output);

    // Set orientation and update rotation matrix accordingly.
    setOrientation(
        options['forward'][0],
        options['forward'][1],
        options['forward'][2],
        options['up'][0],
        options['up'][1],
        options['up'][2]);
    return null;
  }

  /// Set the source's orientation using forward and up vectors.
  ///  forwardX
  ///  forwardY
  ///  forwardZ
  ///  upX
  ///  upY
  ///  upZ

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
