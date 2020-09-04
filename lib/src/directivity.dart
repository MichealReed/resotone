// Core dependencies
import 'dart:math';
import 'dart:web_audio';

// Internal dependencies.
import 'reso_utils.dart';

/// Directivity/occlusion filter.
/// [context]
/// [options]
/// [options.alpha]
/// Determines directivity pattern (0 to 1). See
/// [setPattern] for more details. Defaults to
/// [ResoUtils.DEFAULT_DIRECTIVITY_ALPHA ].
/// [options.sharpness]
/// Determines the sharpness of the directivity pattern (1 to Inf). See
/// [setPattern] for more details. Defaults to
/// [ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS]

class Directivity {
  AudioContext _context;
  BiquadFilterNode _lowpass;
  BiquadFilterNode input;
  BiquadFilterNode output;

  num _cosTheta;
  num _alpha;
  num _sharpness;

  Directivity(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = Map<String, dynamic>();
    }
    if (options['alpha'] == null) {
      options['alpha'] = ResoUtils.DEFAULT_DIRECTIVITY_ALPHA;
    }
    if (options['sharpness'] == null) {
      options['sharpness'] = ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS;
    }

    // Create audio node.
    _context = context;
    _lowpass = context.createBiquadFilter();

    // Initialize filter coefficients.
    _lowpass.type = 'lowpass';
    _lowpass.Q.value = 0;
    _lowpass.frequency.value = context.sampleRate * 0.5;

    _cosTheta = 0;
    setPattern(options['alpha'], options['sharpness']);

    // Input/Output proxy.
    input = _lowpass;
    output = _lowpass;
  }

  /// Compute the filter using the source's forward orientation and the listener's
  /// position.
  /// [forward] The source's forward vector.
  /// [direction] The direction from the source to the
  /// listener.
  void computeAngle(List<num> forward, List<num> direction) {
    List<num> forwardNorm = ResoUtils.normalizeVector(forward);
    List<num> directionNorm = ResoUtils.normalizeVector(direction);
    num coeff = 1;
    if (_alpha > ResoUtils.EPSILON_FLOAT) {
      num cosTheta = forwardNorm[0] * directionNorm[0] +
          forwardNorm[1] * directionNorm[1] +
          forwardNorm[2] * directionNorm[2];
      coeff = (1 - _alpha) + _alpha * cosTheta;
      coeff = pow(coeff, _sharpness);
    }
    _lowpass.frequency.value = _context.sampleRate * 0.5 * coeff;
  }

  /// Set source's directivity pattern (defined by alpha), where 0 is an
  /// omnidirectional pattern, 1 is a bidirectional pattern, 0.5 is a cardiod
  /// pattern. The sharpness of the pattern is increased exponenentially.
  /// [alpha]
  /// Determines directivity pattern (0 to 1).
  /// [sharpness]
  /// Determines the sharpness of the directivity pattern (1 to Inf).
  /// [ResoUtils.DEFAULT_DIRECTIVITY_SHARPNESS].

  void setPattern(num alpha, num sharpness) {
    // Clamp and set values.
    _alpha = min(1, max(0, alpha));
    _sharpness = max(1, sharpness);

    // Update angle calculation using new values.
    computeAngle([_cosTheta * _cosTheta, 0, 0], [1, 0, 0]);
  }
}
