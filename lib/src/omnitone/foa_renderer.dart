// Core Dependencies
import 'dart:web_audio';

import 'buffer_list.dart';
import 'foa_convolver.dart';
import 'foa_rotator.dart';
import 'foa_router.dart';
import 'omni_utils.dart';
import 'resources/omnitone_foa_hrir_base64.dart';

/// Omnitone FOA renderer class. Uses the optimized convolution technique.
class FOARenderer {
  AudioContext _context;
  Map<String, dynamic> _config;
  List<num> _tempMatrix4;
  bool _isRendererReady;

  GainNode input;
  GainNode output;
  GainNode _bypass;
  FOARouter _foaRouter;
  FOARotator foaRotator;
  FOAConvolver _foaConvolver;
// [context] - Associated AudioContext.
// [config]
// [config.channelMap] - Custom channel routing map. Useful for
// handling the inconsistency in browser's multichannel audio decoding.
// [config['hrirPathList']] - A list of paths to HRIR files. It
// overrides the internal HRIR list if given.
// [config['renderingMode']='ambisonic'] - Rendering mode.
  FOARenderer(AudioContext context, Map<String, dynamic> config) {
    _context = OmniUtils.isAudioContext(context) ? context : null;

    _config = {
      'channelMap': FOARouter.ChannelMap['DEFAULT'],
      'renderingMode': RenderingMode.AMBISONIC,
    };

    if (config != null) {
      if (config.containsKey('channelMap')) {
        if (config['channelMap'] is List && config['channelMap'].length == 4) {
          _config['channelMap'] = config['channelMap'];
        } else {
          print('FOARenderer: Invalid channel map. (got ' +
              config['channelMap'] +
              ')');
        }
      }

      if (config.containsKey('hrirPathList')) {
        if (config['hrirPathList'] && config['hrirPathList'].length == 2) {
          _config['pathList'] = config['hrirPathList'];
        } else {
          print('FOARenderer: Invalid HRIR URLs. It must be an array with ' +
              '2 URLs to HRIR files. (got ' +
              config['hrirPathList'] +
              ')');
        }
      }

      if (config.containsKey('renderingMode')) {
        if (RenderingMode.values.contains(config['renderingMode'])) {
          _config['renderingMode'] = config['renderingMode'];
        } else {
          print('FOARenderer: Invalid rendering mode order. (got' +
              config['renderingMode'] +
              ') Fallbacks to the mode "ambisonic".');
        }
      }
    }

    _buildAudioGraph();

    _tempMatrix4 = new List<num>(16);
    _isRendererReady = false;
  }

  /// Builds the internal audio graph.
  void _buildAudioGraph() {
    input = _context.createGain();
    output = _context.createGain();
    _bypass = _context.createGain();
    _foaRouter = new FOARouter(_context, _config['channelMap']);
    foaRotator = new FOARotator(_context);
    _foaConvolver = new FOAConvolver(_context);
    input.connectNode(_foaRouter.input);
    input.connectNode(_bypass);
    _foaRouter.output.connectNode(foaRotator.input);
    foaRotator.output.connectNode(_foaConvolver.input);
    _foaConvolver.output.connectNode(output);

    input.channelCount = 4;
    input.channelCountMode = 'explicit';
    input.channelInterpretation = 'discrete';
  }

  /// Internal callback handler for |initialize| method.
  /// [resolve] - Resolution handler.
  /// [reject] - Rejection handler.
  Future<dynamic> _initializeCallback({Function resolve, Function reject}) {
    final bufferList = _config.containsKey('pathList')
        ? new BufferList(_context, _config['pathList'],
            options: {'dataType': 'url'})
        : new BufferList(_context, OmnitoneFOAHrirBase64);
    print("bufferList done");
    return bufferList.load(resolve: (hrirBufferList) {
      _foaConvolver.setHRIRBufferList(hrirBufferList);
      setRenderingMode(_config['renderingMode']);
      _isRendererReady = true;
      print('FOARenderer: HRIRs loaded successfully. Ready.');
      return hrirBufferList;
    }, reject: () {
      const errorMessage = 'FOARenderer: HRIR loading/decoding failed.';
      return reject(errorMessage);
    });
  }

  /// Initializes and loads the resource for the renderer.
  Future initialize() async {
    print('FOARenderer: Initializing... (mode: ' +
        _config['renderingMode'].toString() +
        ')');
    return await _initializeCallback();
  }

  /// Set the channel map.
  /// [channelMap] - Custom channel routing for FOA stream.
  void setChannelMap(channelMap) {
    if (!_isRendererReady) {
      return;
    }

    if (channelMap.toString() != _config['channelMap'].toString()) {
      print('Remapping channels ([' +
          _config['channelMap'].toString() +
          '] -> [' +
          channelMap.toString() +
          ']).');
      _config['channelMap'] = channelMap.slice();
      _foaRouter.setChannelMap(_config['channelMap']);
    }
  }

  /// Updates the rotation matrix with 3x3 matrix.
  /// [rotationMatrix3] - A 3x3 rotation matrix. (column-major)
  void setRotationMatrix3(List<num> rotationMatrix3) {
    if (!_isRendererReady) {
      return;
    }

    foaRotator.setRotationMatrix3(rotationMatrix3);
  }

  /// Updates the rotation matrix with 4x4 matrix.
  /// [rotationMatrix4] - A 4x4 rotation matrix. (column-major)
  void setRotationMatrix4(List<num> rotationMatrix4) {
    if (!_isRendererReady) {
      return;
    }

    foaRotator.setRotationMatrix4(rotationMatrix4);
  }

  /// Set the rendering mode.
  /// [mode] - Rendering mode.
  ///  - 'ambisonic': activates the ambisonic decoding/binaurl rendering.
  ///  - 'bypass': bypasses the input stream directly to the output. No ambisonic
  ///    decoding or encoding.
  ///  - 'off': all the processing off saving the CPU power.
  void setRenderingMode(RenderingMode mode) {
    if (mode == _config['renderingMode']) {
      return;
    }

    switch (mode) {
      case RenderingMode.AMBISONIC:
        _foaConvolver.enable();
        _bypass.disconnect();
        break;
      case RenderingMode.BYPASS:
        _foaConvolver.disable();
        _bypass.connectNode(output);
        break;
      case RenderingMode.OFF:
        _foaConvolver.disable();
        _bypass.disconnect();
        break;
      default:
        print('FOARenderer: Rendering mode "' +
            mode.toString() +
            '" is not ' +
            'supported.');
        return;
    }

    _config['renderingMode'] = mode;
    print('FOARenderer: Rendering mode changed. (' + mode.toString() + ')');
  }
}
