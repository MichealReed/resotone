// Core Dependencies
import 'dart:web_audio';

/// Channel router for FOA stream.
class FOARouter {
  AudioContext _context;
  ChannelSplitterNode _splitter;
  ChannelMergerNode _merger;
  ChannelSplitterNode input;
  ChannelMergerNode output;
  List<num> _channelMap;

  static final ChannelMap = {
    // ACN channel map for Chrome and FireFox. (FFMPEG)
    'DEFAULT': [0, 1, 2, 3],
    // Safari's 4-channel map for AAC codec.
    'SAFARI': [2, 0, 1, 3],
    // ACN > FuMa conversion map.
    'FUMA': [0, 3, 1, 2],
  };

  // [context] - Associated AudioContext.
  // [channelMap] - Routing destination array.
  FOARouter(AudioContext context, List<num> channelMap) {
    _context = context;

    _splitter = _context.createChannelSplitter(4);
    _merger = _context.createChannelMerger(4);

    // input/output proxy.
    input = _splitter;
    output = _merger;

    setChannelMap(channelMap != null ? channelMap : ChannelMap['DEFAULT']);
  }

  /// Sets channel map.
  /// [channelMap] - A new channel map for FOA stream.
  setChannelMap(List<num> channelMap) {
    if (channelMap is! List) {
      return;
    }

    _channelMap = channelMap;
    _splitter.disconnect();
    _splitter.connectNode(_merger, 0, _channelMap[0]);
    _splitter.connectNode(_merger, 1, _channelMap[1]);
    _splitter.connectNode(_merger, 2, _channelMap[2]);
    _splitter.connectNode(_merger, 3, _channelMap[3]);
  }
}
