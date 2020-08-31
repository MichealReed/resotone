/**
 * @file A collection of convolvers. Can be used for the optimized FOA binaural
 * rendering. (e.g. SH-MaxRe HRTFs)
 */

import 'dart:web_audio';

/**
 * FOAConvolver. A collection of 2 stereo convolvers for 4-channel FOA stream.
 * @constructor
 * @param {BaseAudioContext} context The associated AudioContext.
 * @param {AudioBuffer[]} [hrirBufferList] - An ordered-list of stereo
 * AudioBuffers for convolution. (i.e. 2 stereo AudioBuffers for FOA)
 */
class FOAConvolver {
  AudioContext _context;
  bool _active;
  bool _isBufferLoaded;
  ChannelSplitterNode _splitterWYZX;
  ChannelMergerNode _mergerWY;
  ChannelMergerNode _mergerZX;
  ConvolverNode _convolverWY;
  ConvolverNode _convolverZX;
  ChannelSplitterNode _splitterWY;
  ChannelSplitterNode _splitterZX;
  GainNode _inverter;
  ChannelMergerNode _mergerBinaural;
  GainNode _summingBus;
  ChannelSplitterNode input;
  GainNode output;

  FOAConvolver(AudioContext context, {List<AudioBuffer> hrirBufferList}) {
    _context = context;

    _active = false;
    _isBufferLoaded = false;

    _buildAudioGraph();

    if (hrirBufferList != null) {
      setHRIRBufferList(hrirBufferList);
    }

    enable();
  }

/**
 * Build the internal audio graph.
 *
 * @private
 */
  void _buildAudioGraph() {
    _splitterWYZX = _context.createChannelSplitter(4);
    _mergerWY = _context.createChannelMerger(2);
    _mergerZX = _context.createChannelMerger(2);
    _convolverWY = _context.createConvolver();
    _convolverZX = _context.createConvolver();
    _splitterWY = _context.createChannelSplitter(2);
    _splitterZX = _context.createChannelSplitter(2);
    _inverter = _context.createGain();
    _mergerBinaural = _context.createChannelMerger(2);
    _summingBus = _context.createGain();

    // Group W and Y, then Z and X.
    _splitterWYZX.connectNode(_mergerWY, 0, 0);
    _splitterWYZX.connectNode(_mergerWY, 1, 1);
    _splitterWYZX.connectNode(_mergerZX, 2, 0);
    _splitterWYZX.connectNode(_mergerZX, 3, 1);

    // Create a network of convolvers using splitter/merger.
    _mergerWY.connectNode(_convolverWY);
    _mergerZX.connectNode(_convolverZX);
    _convolverWY.connectNode(_splitterWY);
    _convolverZX.connectNode(_splitterZX);
    _splitterWY.connectNode(_mergerBinaural, 0, 0);
    _splitterWY.connectNode(_mergerBinaural, 0, 1);
    _splitterWY.connectNode(_mergerBinaural, 1, 0);
    _splitterWY.connectNode(_inverter, 1, 0);
    _inverter.connectNode(_mergerBinaural, 0, 1);
    _splitterZX.connectNode(_mergerBinaural, 0, 0);
    _splitterZX.connectNode(_mergerBinaural, 0, 1);
    _splitterZX.connectNode(_mergerBinaural, 1, 0);
    _splitterZX.connectNode(_mergerBinaural, 1, 1);

    // By default, WebAudio's convolver does the normalization based on IR's
    // energy. For the precise convolution, it must be disabled before the buffer
    // assignment.
    _convolverWY.normalize = false;
    _convolverZX.normalize = false;

    // For asymmetric degree.
    _inverter.gain.value = -1;

    // Input/output proxy.
    input = _splitterWYZX;
    output = _summingBus;
  }

/**
 * Assigns 2 HRIR AudioBuffers to 2 convolvers: Note that we use 2 stereo
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

    _convolverWY.buffer = hrirBufferList[0];
    _convolverZX.buffer = hrirBufferList[1];
    _isBufferLoaded = true;
  }

/**
 * Enable FOAConvolver instance. The audio graph will be activated and pulled by
 * the WebAudio engine. (i.e. consume CPU cycle)
 */
  void enable() {
    _mergerBinaural.connectNode(_summingBus);
    _active = true;
  }

/**
 * Disable FOAConvolver instance. The inner graph will be disconnectNodeed from the
 * audio destination, thus no CPU cycle will be consumed.
 */
  void disable() {
    _mergerBinaural.disconnect();
    _active = false;
  }
}
