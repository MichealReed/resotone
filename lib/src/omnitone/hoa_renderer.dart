// Core Dependencies
import 'dart:web_audio';

// Internal Dependencies
import 'buffer_list.dart';
import 'hoa_convolver.dart';
import 'hoa_rotator.dart';
import 'omni_utils.dart';

// Resource Dependencies
import 'resources/omnitone_toa_hrir_base64.dart';
import 'resources/omnitone_soa_hrir_base64.dart';

// Currently SOA and TOA are only supported.
const SupportedAmbisonicOrder = [2, 3];

/// Omnitone HOA renderer class. Uses the optimized convolution technique.
class HOARenderer {
  AudioContext _context;
  Map<String, dynamic> _config;
  List<num> _tempMatrix4;
  bool _isRendererReady;

  GainNode input;
  GainNode output;
  GainNode _bypass;
  HOARotator hoaRotator;
  HOAConvolver _hoaConvolver;

  // [context] - Associated AudioContext.
  // [config]
  // [config.ambisonicOrder=3] - Ambisonic order.
  // [config.hrirPathList] - A list of paths to HRIR files. It
  // overrides the internal HRIR list if given.
  // [config.renderingMode='ambisonic'] - Rendering mode.
  HOARenderer(AudioContext context, Map<String, dynamic> config) {
    _context = OmniUtils.isAudioContext(context) ? context : null;

    _config = {
      'ambisonicOrder': 3,
      'renderingMode': RenderingMode.AMBISONIC,
    };

    if (config != null && config.containsKey('ambisonicOrder')) {
      if (SupportedAmbisonicOrder.contains(config['ambisonicOrder'])) {
        _config['ambisonicOrder'] = config['ambisonicOrder'];
      } else {
        print('HOARenderer: Invalid ambisonic order. (got ' +
            config['ambisonicOrder'] +
            ') Fallbacks to 3rd-order ambisonic.');
      }
    }

    _config['numberOfChannels'] =
        (_config['ambisonicOrder'] + 1) * (_config['ambisonicOrder'] + 1);
    _config['numberOfStereoChannels'] =
        ((_config['numberOfChannels'] as num) / 2).ceil();

    if (config != null &&
        config.containsKey('hrirPathList') &&
        config['hrirPathList'] is List) {
      if (config['hrirPathList'] &&
          config['hrirPathList'].length == _config['numberOfStereoChannels']) {
        _config['pathList'] = config['hrirPathList'];
      } else {
        print('HOARenderer: Invalid HRIR URLs. It must be an array with ' +
            _config['numberOfStereoChannels'] +
            ' URLs to HRIR files.' +
            ' (got ' +
            config['hrirPathList'] +
            ')');
      }
    }

    if (config != null && config.containsKey('renderingMode')) {
      if ((RenderingMode.values).contains(config['renderingMode'])) {
        _config['renderingMode'] = config['renderingMode'];
      } else {
        print('HOARenderer: Invalid rendering mode. (got ' +
            config['renderingMode'] +
            ') Fallbacks to "ambisonic".');
      }
    }

    _buildAudioGraph();

    _isRendererReady = false;
  }

  /// Builds the internal audio graph.
  void _buildAudioGraph() {
    input = _context.createGain();
    output = _context.createGain();
    _bypass = _context.createGain();
    hoaRotator = new HOARotator(_context, _config['ambisonicOrder']);
    _hoaConvolver = new HOAConvolver(_context, _config['ambisonicOrder']);
    input.connectNode(hoaRotator.input);
    input.connectNode(_bypass);
    hoaRotator.output.connectNode(_hoaConvolver.input);
    _hoaConvolver.output.connectNode(output);

    input.channelCount = _config['numberOfChannels'];
    input.channelCountMode = 'explicit';
    input.channelInterpretation = 'discrete';
  }

  /// Internal callback handler for |initialize| method.
  /// [resolve] - Resolution handler.
  /// [reject] - Rejection handler.

  void _initializeCallback({Function resolve, Function reject}) {
    BufferList bufferList;
    if (_config.containsKey('pathList')) {
      bufferList = new BufferList(_context, _config['pathList'],
          options: {'dataType': 'url'});
    } else {
      bufferList = _config['ambisonicOrder'] == 2
          ? new BufferList(_context, OmnitoneSOAHrirBase64)
          : new BufferList(_context, OmnitoneTOAHrirBase64);
    }

    bufferList.load(resolve: (hrirBufferList) {
      _hoaConvolver.setHRIRBufferList(hrirBufferList);
      setRenderingMode(_config['renderingMode']);
      _isRendererReady = true;
      print('FOARenderer: HRIRs loaded successfully. Ready.');
    }, reject: () {
      const errorMessage = 'HOARenderer: HRIR loading/decoding failed.';
      print(errorMessage);
    });
  }

  /// Initializes and loads the resource for the renderer.
  Future initialize() {
    print('HOARenderer: Initializing... (mode: ' +
        _config['renderingMode'].toString() +
        ')');

    return new Future(_initializeCallback);
  }

  /// Updates the rotation matrix with 3x3 matrix.
  /// [rotationMatrix3] - A 3x3 rotation matrix. (column-major)
  void setRotationMatrix3(List<num> rotationMatrix3) {
    if (!_isRendererReady) {
      return;
    }

    hoaRotator.setRotationMatrix3(rotationMatrix3);
  }

  /// Updates the rotation matrix with 4x4 matrix.
  /// [rotationMatrix4] - A 4x4 rotation matrix. (column-major)
  void setRotationMatrix4(List<num> rotationMatrix4) {
    if (!_isRendererReady) {
      return;
    }
    hoaRotator.setRotationMatrix4(rotationMatrix4);
  }

  /// Set the decoding mode.
  /// [mode] - Decoding mode.
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
        _hoaConvolver.enable();
        _bypass.disconnect();
        break;
      case RenderingMode.BYPASS:
        _hoaConvolver.disable();
        _bypass.connectNode(output);
        break;
      case RenderingMode.OFF:
        _hoaConvolver.disable();
        _bypass.disconnect();
        break;
      default:
        print('HOARenderer: Rendering mode "' +
            mode.toString() +
            '" is not ' +
            'supported.');
        return;
    }

    _config['renderingMode'] = mode;
    print('HOARenderer: Rendering mode changed. (' + mode.toString() + ')');
  }
}
