/**
 * @file Omnitone library name space and user-facing APIs.
 */

import 'dart:web_audio';

import 'buffer_list.dart';
import 'foa_router.dart';
import 'foa_rotator.dart';
import 'foa_convolver.dart';
import 'foa_renderer.dart';
import 'hoa_convolver.dart';
import 'hoa_renderer.dart';
import 'hoa_rotator.dart';
import 'omni_utils.dart';

/**
 * Omnitone namespace.
 * @namespace
 */
class Omnitone {
/**
 * Performs the async loading/decoding of multiple AudioBuffers from multiple
 * URLs.
 * @param {BaseAudioContext} context - Associated BaseAudioContext.
 * @param {string[]} bufferData - An ordered list of URLs.
 * @param {Object} [options] - BufferList options.
 * @param {String} [options.dataType='url'] - BufferList data type.
 * @return {Promise<AudioBuffer[]>} - The promise resolves with an array of
 * AudioBuffer.
 */
  static Future<List<AudioBuffer>> createBufferList(
      AudioContext context, List<String> bufferData,
      {Map<String, dynamic> options}) {
    final bufferList = new BufferList(context, bufferData,
        options: options != null ? options : {'dataType': 'url'});
    return bufferList.load();
  }

/**
 * Perform channel-wise merge on multiple AudioBuffers. The sample rate and
 * the length of buffers to be merged must be identical.
 * @static
 * @function
 * @param {BaseAudioContext} context - Associated BaseAudioContext.
 * @param {AudioBuffer[]} bufferList - An array of AudioBuffers to be merged
 * channel-wise.
 * @return {AudioBuffer} - A single merged AudioBuffer.
 */
  static Function mergeBufferListByChannel = OmniUtils.mergeBufferListByChannel;

/**
 * Perform channel-wise split by the given channel count. For example,
 * 1 x AudioBuffer(8) -> splitBuffer(context, buffer, 2) -> 4 x AudioBuffer(2).
 * @static
 * @function
 * @param {BaseAudioContext} context - Associated BaseAudioContext.
 * @param {AudioBuffer} audioBuffer - An AudioBuffer to be splitted.
 * @param {Number} splitBy - Number of channels to be splitted.
 * @return {AudioBuffer[]} - An array of splitted AudioBuffers.
 */
  static Function splitBufferbyChannel = OmniUtils.splitBufferbyChannel;

/**
 * Creates an instance of FOA Convolver.
 * @see FOAConvolver
 * @param {BaseAudioContext} context The associated AudioContext.
 * @param {AudioBuffer[]} [hrirBufferList] - An ordered-list of stereo
 * @return {FOAConvolver}
 */
  static FOAConvolver createFOAConvolver(
          BaseAudioContext context, List<AudioBuffer> hrirBufferList) =>
      new FOAConvolver(context, hrirBufferList: hrirBufferList);

/**
 * Create an instance of FOA Router.
 * @see FOARouter
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Number[]} channelMap - Routing destination array.
 * @return {FOARouter}
 */
  static FOARouter createFOARouter(
          AudioContext context, List<num> channelMap) =>
      new FOARouter(context, channelMap);

/**
 * Create an instance of FOA Rotator.
 * @see FOARotator
 * @param {AudioContext} context - Associated AudioContext.
 * @return {FOARotator}
 */
  static FOARotator createFOARotator(AudioContext context) =>
      new FOARotator(context);

/**
 * Creates HOARotator for higher-order ambisonics rotation.
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Number} ambisonicOrder - Ambisonic order.
 * @return {HOARotator}
 */
  static HOARotator createHOARotator(
          AudioContext context, num ambisonicOrder) =>
      new HOARotator(context, ambisonicOrder);

/**
 * Creates HOAConvolver performs the multi-channel convolution for the optmized
 * binaural rendering.
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Number} ambisonicOrder - Ambisonic order. (2 or 3)
 * @param {AudioBuffer[]} [hrirBufferList] - An ordered-list of stereo
 * AudioBuffers for convolution. (SOA: 5 AudioBuffers, TOA: 8 AudioBuffers)
 * @return {HOAConvovler}
 */
  static HOAConvolver createHOAConvolver(AudioContext context,
          num ambisonicOrder, List<AudioBuffer> hrirBufferList) =>
      new HOAConvolver(context, ambisonicOrder, hrirBufferList: hrirBufferList);

/**
 * Create a FOARenderer, the first-order ambisonic decoder and the optimized
 * binaural renderer.
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Object} config
 * @param {Array} [config.channelMap] - Custom channel routing map. Useful for
 * handling the inconsistency in browser's multichannel audio decoding.
 * @param {Array} [config.hrirPathList] - A list of paths to HRIR files. It
 * overrides the internal HRIR list if given.
 * @param {RenderingMode} [config.renderingMode='ambisonic'] - Rendering mode.
 * @return {FOARenderer}
 */
  static FOARenderer createFOARenderer(
          AudioContext context, Map<String, dynamic> config) =>
      new FOARenderer(context, config);

/**
 * Creates HOARenderer for higher-order ambisonic decoding and the optimized
 * binaural rendering.
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Object} config
 * @param {Number} [config.ambisonicOrder=3] - Ambisonic order.
 * @param {Array} [config.hrirPathList] - A list of paths to HRIR files. It
 * overrides the internal HRIR list if given.
 * @param {RenderingMode} [config.renderingMode='ambisonic'] - Rendering mode.
 * @return {HOARenderer}
 */
  static HOARenderer createHOARenderer(
          AudioContext context, Map<String, dynamic> config) =>
      new HOARenderer(context, config);
}
