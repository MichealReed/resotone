// Core Dependencies
import 'dart:math';
import 'dart:web_audio';

// Internal Dependencies.
import 'reso_utils.dart';

/// Late-reflections reverberation filter for Ambisonic content.
class LateReflections {
// Multiband RT60 durations (in seconds) for each frequency band, listed as
// Defaults to [ResoUtils.DEFAULT_REVERB_DURATIONS].
// [options.predelay] Pre-delay (in milliseconds). Defaults to
// [ResoUtils.DEFAULT_REVERB_PREDELAY DEFAULT_REVERB_PREDELAY].
// [options.gain] Output gain (linear). Defaults to
// [ResoUtils.DEFAULT_REVERB_GAIN DEFAULT_REVERB_GAIN].
// [options.bandwidth] Bandwidth (in octaves) for each frequency
// band. Defaults to[ResoUtils.DEFAULT_REVERB_BANDWIDTH DEFAULT_REVERB_BANDWIDTH].
// [options.tailonset] Length (in milliseconds) of impulse
// response to apply a half-Hann window. Defaults to
// [ResoUtils.DEFAULT_REVERB_TAIL_ONSET DEFAULT_REVERB_TAIL_ONSET].
  num _bandwidthCoeff;
  num _tailonsetSamples;
  AudioContext _context;
  GainNode input;
  DelayNode _predelay;
  ConvolverNode _convolver;
  GainNode output;
  LateReflections(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options['durations'] == null) {
      options['durations'] = ResoUtils.DEFAULT_REVERB_DURATIONS;
    }
    if (options['predelay'] == null) {
      options['predelay'] = ResoUtils.DEFAULT_REVERB_PREDELAY;
    }
    if (options['gain'] == null) {
      options['gain'] = ResoUtils.DEFAULT_REVERB_GAIN;
    }
    if (options['bandwidth'] == null) {
      options['bandwidth'] = ResoUtils.DEFAULT_REVERB_BANDWIDTH;
    }
    if (options['tailonset'] == null) {
      options['tailonset'] = ResoUtils.DEFAULT_REVERB_TAIL_ONSET;
    }

    // Assign pre-computed variables.
    num delaySecs = options['predelay'] / 1000;
    _bandwidthCoeff = options['bandwidth'] * ResoUtils.LOG2_DIV2;
    _tailonsetSamples = options['tailonset'] / 1000;

    // Create nodes.
    _context = context;
    input = context.createGain();
    _predelay = context.createDelay(delaySecs);
    _convolver = context.createConvolver();
    output = context.createGain();

    // Set reverb attenuation.
    output.gain.value = options['gain'];

    // Disable normalization.
    _convolver.normalize = false;

    // connectNode nodes.
    input.connectNode(_predelay);
    _predelay.connectNode(_convolver);
    _convolver.connectNode(output);

    // Compute IR using RT60 values.
    setDurations(options['durations']);
  }

  /// Re-compute a new impulse response by providing Multiband RT60 durations.
  ///  durations
  /// Multiband RT60 durations (in seconds) for each frequency band, listed as
  /// ResoUtils.DEFAULT_REVERB_FREQUENCY_BANDS
  /// DEFAULT_REVERB_FREQUENCY_BANDS}.

  void setDurations(List<num> durations) {
    if (durations.length != ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS) {
      print('Warning: invalid number of RT60 values provided to reverb.');
      return;
    }

    // Compute impulse response.
    List<num> durationsSamples =
        new List<num>(ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS);
    num sampleRate = _context.sampleRate;

    for (num i = 0; i < durations.length; i++) {
      // Clamp within suitable range.
      durations[i] =
          max(0, min(ResoUtils.DEFAULT_REVERB_MAX_DURATION, durations[i]));

      // Convert seconds to samples.
      durationsSamples[i] = (durations[i] *
              sampleRate *
              ResoUtils.DEFAULT_REVERB_DURATION_MULTIPLIER)
          .round();
    }
    ;

    // Determine max RT60 length in samples.
    num durationsSamplesMax = 0;
    for (num i = 0; i < durationsSamples.length; i++) {
      if (durationsSamples[i] > durationsSamplesMax) {
        durationsSamplesMax = durationsSamples[i];
      }
    }

    // Skip this step if there is no reverberation to compute.
    if (durationsSamplesMax < 1) {
      durationsSamplesMax = 1;
    }

    // Create impulse response buffer.
    AudioBuffer buffer =
        _context.createBuffer(1, durationsSamplesMax, sampleRate);
    List<num> bufferData = buffer.getChannelData(0);

    Random rand = new Random();
    // Create noise signal (computed once, referenced in each band's routine).
    final noiseSignal = new List<num>(durationsSamplesMax);
    for (num i = 0; i < durationsSamplesMax; i++) {
      noiseSignal[i] = rand.nextDouble() * 2 - 1;
    }

    // Compute the decay rate per-band and filter the decaying noise signal.
    for (num i = 0; i < ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS; i++) {
      // Compute decay rate.
      num decayRate = -ResoUtils.LOG1000 / durationsSamples[i];

      // Construct a standard one-zero, two-pole bandpass filter:
      // H(z) = (b0 /// z^0 + b1 /// z^-1 + b2 /// z^-2) / (1 + a1 /// z^-1 + a2 /// z^-2)
      num omega = ResoUtils.TWO_PI *
          ResoUtils.DEFAULT_REVERB_FREQUENCY_BANDS[i] /
          sampleRate;
      num sinOmega = sin(omega);
      num alpha = sinOmega * ResoUtils.sinh(_bandwidthCoeff * omega / sinOmega);
      num a0CoeffReciprocal = 1 / (1 + alpha);
      num b0Coeff = alpha * a0CoeffReciprocal;
      num a1Coeff = -2 * cos(omega) * a0CoeffReciprocal;
      num a2Coeff = (1 - alpha) * a0CoeffReciprocal;

      // We optimize since b2 = -b0, b1 = 0.
      // Update equation for two-pole bandpass filter:
      //   u[n] = x[n] - a1 /// x[n-1] - a2 /// x[n-2]
      //   y[n] = b0 /// (u[n] - u[n-2])
      num um1 = 0;
      num um2 = 0;
      for (num j = 0; j < durationsSamples[i]; j++) {
        // Exponentially-decaying white noise.
        num x = noiseSignal[j] * exp(decayRate * j);

        // Filter signal with bandpass filter and add to output.
        num u = x - a1Coeff * um1 - a2Coeff * um2;
        bufferData[j] += b0Coeff * (u - um2);

        // Update coefficients.
        um2 = um1;
        um1 = u;
      }
    }

    // Create and apply half of a Hann window to the beginning of the
    // impulse response.
    num halfHannLength = (_tailonsetSamples).round();
    for (num i = 0; i < min(bufferData.length, halfHannLength); i++) {
      num halfHann =
          0.5 * (1 - cos(ResoUtils.TWO_PI * i / (2 * halfHannLength - 1)));
      bufferData[i] *= halfHann;
    }
    _convolver.buffer = buffer;
  }
}
