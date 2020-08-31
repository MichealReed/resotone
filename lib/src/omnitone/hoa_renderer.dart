/**
 * @license
 * Copyright 2017 Google Inc. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:web_audio';

/**
 * @file Omnitone HOARenderer. This is user-facing API for the higher-order
 * ambisonic decoder and the optimized binaural renderer.
 */

import 'buffer_list.dart';
import 'hoa_convolver.dart';
import 'hoa_rotator.dart';
import 'omni_utils.dart';

import 'resources/omnitone_toa_hrir_base64.dart';
import 'resources/omnitone_soa_hrir_base64.dart';

/**
 * @typedef {string} RenderingMode
 */

/**
 * Rendering mode ENUM.
 * @enum {RenderingMode}
 */
enum RenderingMode {
  /** @type {string} Use ambisonic rendering. */
  AMBISONIC,
  /** @type {string} Bypass. No ambisonic rendering. */
  BYPASS,
  /** @type {string} Disable audio output. */
  OFF
}

// Currently SOA and TOA are only supported.
const SupportedAmbisonicOrder = [2, 3];

/**
 * Omnitone HOA renderer class. Uses the optimized convolution technique.
 * @constructor
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Object} config
 * @param {Number} [config.ambisonicOrder=3] - Ambisonic order.
 * @param {Array} [config.hrirPathList] - A list of paths to HRIR files. It
 * overrides the internal HRIR list if given.
 * @param {RenderingMode} [config.renderingMode='ambisonic'] - Rendering mode.
 */
class HOARenderer {
  AudioContext _context;
  Map<String, dynamic> _config;
  List<num> _tempMatrix4;
  bool _isRendererReady;

  GainNode input;
  GainNode output;
  GainNode _bypass;
  HOARotator _hoaRotator;
  HOAConvolver _hoaConvolver;

  HOARenderer(AudioContext context, config) {
    _context = OmniUtils.isAudioContext(context) ? context : null;

    _config = {
      'ambisonicOrder': 3,
      'renderingMode': RenderingMode.AMBISONIC,
    };

    if (config && config.ambisonicOrder) {
      if (SupportedAmbisonicOrder.contains(config.ambisonicOrder)) {
        _config['ambisonicOrder'] = config.ambisonicOrder;
      } else {
        print('HOARenderer: Invalid ambisonic order. (got ' +
            config.ambisonicOrder +
            ') Fallbacks to 3rd-order ambisonic.');
      }
    }

    _config['numberOfChannels'] =
        (_config['ambisonicOrder'] + 1) * (_config['ambisonicOrder'] + 1);
    _config['numberOfStereoChannels'] =
        ((_config['numberOfChannels'] as num) / 2).ceil();

    if (config && config['hrirPathList'] is List) {
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

    if (config && config.renderingMode) {
      if ((RenderingMode.values).contains(config['renderingMode'])) {
        _config['renderingMode'] = config.renderingMode;
      } else {
        print('HOARenderer: Invalid rendering mode. (got ' +
            config.renderingMode +
            ') Fallbacks to "ambisonic".');
      }
    }

    _buildAudioGraph();

    _isRendererReady = false;
  }

/**
 * Builds the internal audio graph.
 * @private
 */
  void _buildAudioGraph() {
    input = _context.createGain();
    output = _context.createGain();
    _bypass = _context.createGain();
    _hoaRotator = new HOARotator(_context, _config['ambisonicOrder']);
    _hoaConvolver = new HOAConvolver(_context, _config['ambisonicOrder']);
    input.connectNode(_hoaRotator.input);
    input.connectNode(_bypass);
    _hoaRotator.output.connectNode(_hoaConvolver.input);
    _hoaConvolver.output.connectNode(output);

    input.channelCount = _config['numberOfChannels'];
    input.channelCountMode = 'explicit';
    input.channelInterpretation = 'discrete';
  }

/**
 * Internal callback handler for |initialize| method.
 * @private
 * @param {function} resolve - Resolution handler.
 * @param {function} reject - Rejection handler.
 */
  void _initializeCallback(resolve, reject) {
    BufferList bufferList;
    if (_config['pathList'] != null) {
      bufferList = new BufferList(_context, _config['pathList'],
          options: {'dataType': 'url'});
    } else {
      bufferList = _config['ambisonicOrder'] == 2
          ? new BufferList(_context, OmnitoneSOAHrirBase64)
          : new BufferList(_context, OmnitoneTOAHrirBase64);
    }

    bufferList.load().then(
        (hrirBufferList) {
          _hoaConvolver.setHRIRBufferList(hrirBufferList);
          setRenderingMode(_config['renderingMode']);
          _isRendererReady = true;
          print('FOARenderer: HRIRs loaded successfully. Ready.');
          resolve();
        }.call(this), onError: () {
      const errorMessage = 'HOARenderer: HRIR loading/decoding failed.';
      reject(errorMessage);
      print(errorMessage);
    });
  }

/**
 * Initializes and loads the resource for the renderer.
 * @return {Promise}
 */
  Future initialize() {
    print('HOARenderer: Initializing... (mode: ' +
        _config['renderingMode'] +
        ')');

    return new Future(_initializeCallback.call);
  }

/**
 * Updates the rotation matrix with 3x3 matrix.
 * @param {Number[]} rotationMatrix3 - A 3x3 rotation matrix. (column-major)
 */
  void setRotationMatrix3(List<num> rotationMatrix3) {
    if (!_isRendererReady) {
      return;
    }

    _hoaRotator.setRotationMatrix3(rotationMatrix3);
  }

/**
 * Updates the rotation matrix with 4x4 matrix.
 * @param {Number[]} rotationMatrix4 - A 4x4 rotation matrix. (column-major)
 */
  void setRotationMatrix4(List<num> rotationMatrix4) {
    if (!_isRendererReady) {
      return;
    }

    _hoaRotator.setRotationMatrix4(rotationMatrix4);
  }

/**
 * Set the decoding mode.
 * @param {RenderingMode} mode - Decoding mode.
 *  - 'ambisonic': activates the ambisonic decoding/binaurl rendering.
 *  - 'bypass': bypasses the input stream directly to the output. No ambisonic
 *    decoding or encoding.
 *  - 'off': all the processing off saving the CPU power.
 */
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
