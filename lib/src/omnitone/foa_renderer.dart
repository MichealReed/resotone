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
 * @file Omnitone FOARenderer. This is user-facing API for the first-order
 * ambisonic decoder and the optimized binaural renderer.
 */

import 'buffer_list.dart';
import 'foa_convolver.dart';
import 'foa_rotator.dart';
import 'foa_router.dart';
import 'omni_utils.dart';
import 'resources/omnitone_foa_hrir_base64.dart';

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

/**
 * Omnitone FOA renderer class. Uses the optimized convolution technique.
 * @constructor
 * @param {AudioContext} context - Associated AudioContext.
 * @param {Object} config
 * @param {Array} [config.channelMap] - Custom channel routing map. Useful for
 * handling the inconsistency in browser's multichannel audio decoding.
 * @param {Array} [config['hrirPathList']] - A list of paths to HRIR files. It
 * overrides the internal HRIR list if given.
 * @param {RenderingMode} [config['renderingMode']='ambisonic'] - Rendering mode.
 */
class FOARenderer {
  AudioContext _context;
  Map<String, dynamic> _config;
  List<num> _tempMatrix4;
  bool _isRendererReady;

  GainNode input;
  GainNode output;
  GainNode _bypass;
  FOARouter _foaRouter;
  FOARotator _foaRotator;
  FOAConvolver _foaConvolver;

  FOARenderer(AudioContext context, Map<String, dynamic> config) {
    _context = OmniUtils.isAudioContext(context) ? context : null;

    _config = {
      'channelMap': FOARouter.ChannelMap['DEFAULT'],
      'renderingMode': RenderingMode.AMBISONIC,
    };

    if (config != null) {
      if (config['channelMap']) {
        if (config['channelMap'] is List && config['channelMap'].length == 4) {
          _config['channelMap'] = config['channelMap'];
        } else {
          print('FOARenderer: Invalid channel map. (got ' +
              config['channelMap'] +
              ')');
        }
      }

      if (config['hrirPathList']) {
        if (config['hrirPathList'] && config['hrirPathList'].length == 2) {
          _config['pathList'] = config['hrirPathList'];
        } else {
          print('FOARenderer: Invalid HRIR URLs. It must be an array with ' +
              '2 URLs to HRIR files. (got ' +
              config['hrirPathList'] +
              ')');
        }
      }

      if (config['renderingMode']) {
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

/**
 * Builds the internal audio graph.
 * @private
 */
  void _buildAudioGraph() {
    input = _context.createGain();
    output = _context.createGain();
    _bypass = _context.createGain();
    _foaRouter = new FOARouter(_context, _config['channelMap']);
    _foaRotator = new FOARotator(_context);
    _foaConvolver = new FOAConvolver(_context);
    input.connectNode(_foaRouter.input);
    input.connectNode(_bypass);
    _foaRouter.output.connectNode(_foaRotator.input);
    _foaRotator.output.connectNode(_foaConvolver.input);
    _foaConvolver.output.connectNode(output);

    input.channelCount = 4;
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
    final bufferList = _config['pathList']
        ? new BufferList(_context, _config['pathList'],
            options: {'dataType': 'url'})
        : new BufferList(_context, OmnitoneFOAHrirBase64);
    bufferList.load().then(
        (hrirBufferList) {
          _foaConvolver.setHRIRBufferList(hrirBufferList);
          setRenderingMode(_config['renderingMode']);
          _isRendererReady = true;
          print('FOARenderer: HRIRs loaded successfully. Ready.');
          resolve();
        }.call(this), onError: () {
      const errorMessage = 'FOARenderer: HRIR loading/decoding failed.';
      reject(errorMessage);
      print(errorMessage);
    });
  }

/**
 * Initializes and loads the resource for the renderer.
 * @return {Promise}
 */
  Future initialize() {
    print('FOARenderer: Initializing... (mode: ' +
        _config['renderingMode'] +
        ')');

    return new Future(_initializeCallback.call);
  }

/**
 * Set the channel map.
 * @param {Number[]} channelMap - Custom channel routing for FOA stream.
 */
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

/**
 * Updates the rotation matrix with 3x3 matrix.
 * @param {Number[]} rotationMatrix3 - A 3x3 rotation matrix. (column-major)
 */
  void setRotationMatrix3(List<num> rotationMatrix3) {
    if (!_isRendererReady) {
      return;
    }

    _foaRotator.setRotationMatrix3(rotationMatrix3);
  }

/**
 * Updates the rotation matrix with 4x4 matrix.
 * @param {Number[]} rotationMatrix4 - A 4x4 rotation matrix. (column-major)
 */
  void setRotationMatrix4(List<num> rotationMatrix4) {
    if (!_isRendererReady) {
      return;
    }

    _foaRotator.setRotationMatrix4(rotationMatrix4);
  }

/**
 * Set the rotation matrix from a Three.js camera object. Depreated in V1, and
 * this exists only for the backward compatiblity. Instead, use
 * |setRotatationMatrix4()| with Three.js |camera.worldMatrix.elements|.
 * @deprecated
 * @param {Object} cameraMatrix - Matrix4 from Three.js |camera.matrix|.
 */
  void setRotationMatrixFromCamera(cameraMatrix) {
    if (!_isRendererReady) {
      return;
    }
    // Extract the inner array elements and inverse. (The actual view rotation is
    // the opposite of the camera movement.)
    OmniUtils.invertMatrix4(_tempMatrix4, cameraMatrix.elements);
    _foaRotator.setRotationMatrix4(_tempMatrix4);
  }

/**
 * Set the rendering mode.
 * @param {RenderingMode} mode - Rendering mode.
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
