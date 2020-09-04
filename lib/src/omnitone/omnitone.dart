// Core Dependencies
import 'dart:web_audio';

// Internal Dependencies
import 'buffer_list.dart';
import 'foa_router.dart';
import 'foa_rotator.dart';
import 'foa_convolver.dart';
import 'foa_renderer.dart';
import 'hoa_convolver.dart';
import 'hoa_renderer.dart';
import 'hoa_rotator.dart';
import 'omni_utils.dart';

/// Omnitone class.
class Omnitone {
  /// Performs the async loading/decoding of multiple AudioBuffers from multiple
  /// URLs.
  /// [context] - Associated BaseAudioContext.
  /// [bufferData] - An ordered list of URLs.
  /// [options] - BufferList options.
  /// [options.dataType='url'] - BufferList data type.
  /// return this future resolves with a List of AudioBuffer.
  static Future<List<AudioBuffer>> createBufferList(
      AudioContext context, List<String> bufferData,
      {Map<String, dynamic> options}) {
    final bufferList = new BufferList(context, bufferData,
        options: options != null ? options : {'dataType': 'url'});
    return bufferList.load();
  }

  /// Perform channel-wise merge on multiple AudioBuffers. The sample rate and
  /// the length of buffers to be merged must be identical.
  /// [context] - Associated BaseAudioContext.
  /// [bufferList] - An array of AudioBuffers to be merged channel-wise.
  /// return A single merged AudioBuffer.
  static Function mergeBufferListByChannel = OmniUtils.mergeBufferListByChannel;

  /// Perform channel-wise split by the given channel count. For example,
  /// 1 x AudioBuffer(8) -> splitBuffer(context, buffer, 2) -> 4 x AudioBuffer(2).
  /// [context] - Associated BaseAudioContext.
  /// [audioBuffer] - An AudioBuffer to be splitted.
  /// [splitBy] - Number of channels to be splitted.
  /// return a list of splitted AudioBuffers.
  static Function splitBufferbyChannel = OmniUtils.splitBufferbyChannel;

  /// Creates an instance of FOA Convolver.
  /// [context] The associated AudioContext.
  /// [hrirBufferList] - An ordered-list of stereo
  /// returns new [FOAConvolver]
  static FOAConvolver createFOAConvolver(
          BaseAudioContext context, List<AudioBuffer> hrirBufferList) =>
      new FOAConvolver(context, hrirBufferList: hrirBufferList);

  /// Create an instance of FOA Router.
  /// [context] - Associated AudioContext.
  /// [channelMap] - Routing destination array.
  /// returns a new [FOARouter]
  static FOARouter createFOARouter(
          AudioContext context, List<num> channelMap) =>
      new FOARouter(context, channelMap);

  /// Create an instance of FOA Rotator.
  /// [context] - Associated AudioContext.
  /// returns a new [FOARotator]
  static FOARotator createFOARotator(AudioContext context) =>
      new FOARotator(context);

  /// Creates HOARotator for higher-order ambisonics rotation.
  /// [context] - Associated AudioContext.
  /// [ambisonicOrder] - Ambisonic order.
  /// returns a new [HOARotator]
  static HOARotator createHOARotator(
          AudioContext context, num ambisonicOrder) =>
      new HOARotator(context, ambisonicOrder);

  /// Creates HOAConvolver performs the multi-channel convolution for the optmized
  /// binaural rendering.
  /// [context] - Associated AudioContext.
  /// [ambisonicOrder] - Ambisonic order. (2 or 3)
  /// [hrirBufferList] - An ordered-list of stereo
  /// AudioBuffers for convolution. (SOA: 5 AudioBuffers, TOA: 8 AudioBuffers)
  /// returns a new [HOAConvovler]
  static HOAConvolver createHOAConvolver(AudioContext context,
          num ambisonicOrder, List<AudioBuffer> hrirBufferList) =>
      new HOAConvolver(context, ambisonicOrder, hrirBufferList: hrirBufferList);

  /// Create a FOARenderer, the first-order ambisonic decoder and the optimized
  /// binaural renderer.
  /// [context] - Associated AudioContext.
  /// [config]
  /// [config.channelMap] - Custom channel routing map. Useful for
  /// handling the inconsistency in browser's multichannel audio decoding.
  /// [config.hrirPathList] - A list of paths to HRIR files. It
  /// overrides the internal HRIR list if given.
  /// [config.renderingMode='ambisonic'] - Rendering mode.
  /// returns a new [FOARenderer]
  static FOARenderer createFOARenderer(
          AudioContext context, Map<String, dynamic> config) =>
      new FOARenderer(context, config);

  /// Creates HOARenderer for higher-order ambisonic decoding and the optimized
  /// binaural rendering.
  /// [context] - Associated AudioContext.
  /// [config]
  /// [config.ambisonicOrder=3] - Ambisonic order.
  /// [config.hrirPathList] - A list of paths to HRIR files. It
  /// overrides the internal HRIR list if given.
  /// [config.renderingMode='ambisonic'] - Rendering mode.
  /// returns a new [HOARenderer]
  static HOARenderer createHOARenderer(
          AudioContext context, Map<String, dynamic> config) =>
      new HOARenderer(context, config);
}
