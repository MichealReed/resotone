/**
 * @file A collection of convolvers. Can be used for the optimized HOA binaural
 * rendering. (e.g. SH-MaxRe HRTFs)
 */
import 'dart:web_audio';

/**
 * A convolver network for N-channel HOA stream.
 * @finalructor
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Number} ambisonicOrder - Ambisonic order. (2 or 3)
 * @param {AudioBuffer[]} [hrirBufferList] - An ordered-list of stereo
 * AudioBuffers for convolution. (SOA: 5 AudioBuffers, TOA: 8 AudioBuffers)
 */
class HOAConvolver {
  AudioContext _context;
  bool _active;
  bool _isBufferLoaded;
  num _ambisonicOrder;
  num _numberOfChannels;
  ChannelSplitterNode _inputSplitter;
  List<ChannelMergerNode> _stereoMergers;
  List<ConvolverNode> _convolvers;
  List<ChannelSplitterNode> _stereoSplitters;
  GainNode _positiveIndexSphericalHarmonics;
  GainNode _negativeIndexSphericalHarmonics;
  GainNode _inverter;
  ChannelMergerNode _binauralMerger;
  GainNode _outputGain;
  ChannelSplitterNode input;
  GainNode output;

  HOAConvolver(AudioContext context, num ambisonicOrder,
      {List<AudioBuffer> hrirBufferList}) {
    _context = context;

    _active = false;
    _isBufferLoaded = false;

    // The number of channels K based on the ambisonic order N where K = (N+1)^2.
    _ambisonicOrder = ambisonicOrder;
    _numberOfChannels = (_ambisonicOrder + 1) * (_ambisonicOrder + 1);

    _buildAudioGraph();
    if (hrirBufferList != null) {
      setHRIRBufferList(hrirBufferList);
    }

    enable();
  }

/**
 * Build the internal audio graph.
 * For TOA convolution:
 *   input -> splitter(16) -[0,1]-> merger(2) -> convolver(2) -> splitter(2)
 *                         -[2,3]-> merger(2) -> convolver(2) -> splitter(2)
 *                         -[4,5]-> ... (6 more, 8 branches total)
 * @private
 */
  void _buildAudioGraph() {
    final numberOfStereoChannels = (_numberOfChannels / 2).ceil();

    _inputSplitter = _context.createChannelSplitter(_numberOfChannels);
    _stereoMergers = [];
    _convolvers = [];
    _stereoSplitters = [];
    _positiveIndexSphericalHarmonics = _context.createGain();
    _negativeIndexSphericalHarmonics = _context.createGain();
    _inverter = _context.createGain();
    _binauralMerger = _context.createChannelMerger(2);
    _outputGain = _context.createGain();

    for (num i = 0; i < numberOfStereoChannels; ++i) {
      _stereoMergers.add(_context.createChannelMerger(2));
      _convolvers.add(_context.createConvolver());
      _stereoSplitters.add(_context.createChannelSplitter(2));
      _convolvers[i].normalize = false;
    }

    for (num l = 0; l <= _ambisonicOrder; ++l) {
      for (num m = -l; m <= l; m++) {
        // We compute the ACN index (k) of ambisonics channel using the degree (l)
        // and index (m): k = l^2 + l + m
        final acnIndex = l * l + l + m;
        final stereoIndex = (acnIndex / 2).floor();

        // Split channels from input into array of stereo convolvers.
        // Then create a network of mergers that produces the stereo output.
        _inputSplitter.connectNode(
            _stereoMergers[stereoIndex], acnIndex, acnIndex % 2);
        _stereoMergers[stereoIndex].connectNode(_convolvers[stereoIndex]);
        _convolvers[stereoIndex].connectNode(_stereoSplitters[stereoIndex]);

        // Positive index (m >= 0) spherical harmonics are symmetrical around the
        // front axis, while negative index (m < 0) spherical harmonics are
        // anti-symmetrical around the front axis. We will exploit this symmetry
        // to reduce the number of convolutions required when rendering to a
        // symmetrical binaural renderer.
        if (m >= 0) {
          _stereoSplitters[stereoIndex]
              .connectNode(_positiveIndexSphericalHarmonics, acnIndex % 2);
        } else {
          _stereoSplitters[stereoIndex]
              .connectNode(_negativeIndexSphericalHarmonics, acnIndex % 2);
        }
      }
    }

    _positiveIndexSphericalHarmonics.connectNode(_binauralMerger, 0, 0);
    _positiveIndexSphericalHarmonics.connectNode(_binauralMerger, 0, 1);
    _negativeIndexSphericalHarmonics.connectNode(_binauralMerger, 0, 0);
    _negativeIndexSphericalHarmonics.connectNode(_inverter);
    _inverter.connectNode(_binauralMerger, 0, 1);

    // For asymmetric index.
    _inverter.gain.value = -1;

    // Input/Output proxy.
    input = _inputSplitter;
    output = _outputGain;
  }

/**
 * Assigns N HRIR AudioBuffers to N convolvers: Note that we use 2 stereo
 * convolutions for 4-channel direct convolution. Using mono convolver or
 * 4-channel convolver is not viable because mono convolution wastefully
 * produces the stereo outputs, and the 4-ch convolver does cross-channel
 * convolution. (See Web Audio API spec)
 * @param {AudioBuffer[]} hrirBufferList - An array of stereo AudioBuffers for
 * convolvers.
 */
  void setHRIRBufferList(List<AudioBuffer> hrirBufferList) {
    // After these assignments, the channel data in the buffer is immutable in
    // FireFox. (i.e. neutered) So we should avoid re-assigning buffers, otherwise
    // an exception will be thrown.
    if (_isBufferLoaded) {
      return;
    }

    for (num i = 0; i < hrirBufferList.length; ++i) {
      _convolvers[i].buffer = hrirBufferList[i];
    }

    _isBufferLoaded = true;
  }

/**
 * Enable HOAConvolver instance. The audio graph will be activated and pulled by
 * the WebAudio engine. (i.e. consume CPU cycle)
 */
  void enable() {
    _binauralMerger.connectNode(_outputGain);
    _active = true;
  }

/**
 * Disable HOAConvolver instance. The inner graph will be disconnectNodeed from the
 * audio destination, thus no CPU cycle will be consumed.
 */
  void disable() {
    _binauralMerger.disconnect();
    _active = false;
  }
}
