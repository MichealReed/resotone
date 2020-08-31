/**
 * @file An audio channel router to resolve different channel layouts between
 * browsers.
 */

/**
 * @typedef {Number[]} ChannelMap
 */

import 'dart:web_audio';

/**
 * Channel map dictionary ENUM.
 * @enum {ChannelMap}
 */

/**
 * Channel router for FOA stream.
 * @constructor
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Number[]} channelMap - Routing destination array.
 */
class FOARouter {
  AudioContext _context;
  ChannelSplitterNode _splitter;
  ChannelMergerNode _merger;
  ChannelSplitterNode input;
  ChannelMergerNode output;
  List<num> _channelMap;

  static final ChannelMap = {
    /** @type {Number[]} - ACN channel map for Chrome and FireFox. (FFMPEG) */
    'DEFAULT': [0, 1, 2, 3],
    /** @type {Number[]} - Safari's 4-channel map for AAC codec. */
    'SAFARI': [2, 0, 1, 3],
    /** @type {Number[]} - ACN > FuMa conversion map. */
    'FUMA': [0, 3, 1, 2],
  };

  FOARouter(AudioContext context, List<num> channelMap) {
    this._context = context;

    this._splitter = this._context.createChannelSplitter(4);
    this._merger = this._context.createChannelMerger(4);

    // input/output proxy.
    this.input = this._splitter;
    this.output = this._merger;

    this.setChannelMap(channelMap != null ? channelMap : ChannelMap['DEFAULT']);
  }

/**
 * Sets channel map.
 * @param {Number[]} channelMap - A new channel map for FOA stream.
 */
  setChannelMap(List<num> channelMap) {
    if (channelMap is! List) {
      return;
    }

    this._channelMap = channelMap;
    this._splitter.disconnect();
    this._splitter.connectNode(this._merger, 0, this._channelMap[0]);
    this._splitter.connectNode(this._merger, 1, this._channelMap[1]);
    this._splitter.connectNode(this._merger, 2, this._channelMap[2]);
    this._splitter.connectNode(this._merger, 3, this._channelMap[3]);
  }
}
