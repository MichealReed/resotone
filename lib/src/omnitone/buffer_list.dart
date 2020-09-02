import 'dart:html';
import 'dart:web_audio';
import 'omni_utils.dart';

/**
 * @file Streamlined AudioBuffer loader.
 */

/**
 * @typedef {string} BufferDataType
 */

/**
 * Buffer data type for ENUM.
 * @enum {BufferDataType}
 */
Map<String, String> BufferDataType = {
  /** @type {string} The data contains Base64-encoded string.. */
  'BASE64': 'base64',
  /** @type {string} The data is a URL for audio file. */
  'URL': 'url',
};

/**
 * BufferList object mananges the async loading/decoding of multiple
 * AudioBuffers from multiple URLs.
 * @constructor
 * @param {BaseAudioContext} context - Associated BaseAudioContext.
 * @param {string[]} bufferData - An ordered list of URLs.
 * @param {Object} options - Options
 * @param {string} [options.dataType='base64'] - BufferDataType specifier.
 * @param {Boolean} [options.verbose=false] - Log verbosity. |true| prints the
 * individual message from each URL and AudioBuffer.
 */
class BufferList {
  BaseAudioContext _context;
  Map<String, dynamic> _options;
  List<AudioBuffer> _bufferList;
  num _numberOfTasks;
  List<String> _bufferData;
  Function _resolveHandler;
  Function _rejectHandler;

  BufferList(BaseAudioContext context, List<String> bufferData,
      {Map<String, dynamic> options}) {
    _context = OmniUtils.isAudioContext(context) ? context : null;

    _options = {
      "dataType": BufferDataType['BASE64'],
      "verbose": false,
    };

    if (options != null) {
      if (options['dataType'] &&
          OmniUtils.isDefinedENUMEntry(BufferDataType, options['dataType'])) {
        _options['dataType'] = options['dataType'];
      }
      if (options['verbose']) {
        _options['verbose'] = options['verbose'];
      }
    }

    _bufferList = new List<AudioBuffer>();
    _bufferData = _options['dataType'] == BufferDataType['BASE64']
        ? bufferData
        : bufferData.elementAt(0);
    _numberOfTasks = _bufferData.length;

    _resolveHandler = null;
    _rejectHandler = () {};
  }

/**
 * Starts AudioBuffer loading tasks.
 * @return {Promise<AudioBuffer[]>} The promise resolves with an array of
 * AudioBuffer.
 */
  Future<List<AudioBuffer>> load({Function resolve, Function reject}) {
    return _promiseGenerator(resolve: resolve, reject: reject);
  }

/**
 * Promise argument generator. numernally starts multiple async loading tasks.
 * @private
 * @param {function} resolve Promise resolver.
 * @param {function} reject Promise reject.
 */
  _promiseGenerator({Function resolve, Function reject}) {
    if (resolve is! Function) {
      print('BufferList: Invalid Promise resolver.');
    } else {
      _resolveHandler = resolve;
    }

    if (reject is Function) {
      _rejectHandler = reject;
    }

    for (num i = 0; i < _bufferData.length; ++i) {
      _options['dataType'] != null && _options['dataType'] == BufferDataType['BASE64']
          ? _launchAsyncLoadTask(i)
          : _launchAsyncLoadTaskXHR(i);
    }
  }

/**
 * Run async loading task for Base64-encoded string.
 * @private
 * @param {Number} taskId Task ID number from the ordered list |bufferData|.
 */
  void _launchAsyncLoadTask(num taskId) {
    _context.decodeAudioData(
        OmniUtils.getArrayBufferFromBase64String(_bufferData[taskId]),
        (audioBuffer) {
          print(audioBuffer);
      _updateProgress(taskId, audioBuffer);
    }, (errorMessage) {
      _updateProgress(taskId, null);
      final message = 'BufferList: decoding ArrayByffer("' +
          taskId.toString() +
          '" from Base64-encoded data failed. (' +
          errorMessage.toString() +
          ')';
      _rejectHandler(message);
      print(message);
    });
  }

/**
 * Run async loading task via XHR for audio file URLs.
 * @private
 * @param {Number} taskId Task ID number from the ordered list |bufferData|.
 */
  void _launchAsyncLoadTaskXHR(num taskId) {
    final xhr = new HttpRequest();
    xhr.open('GET', _bufferData[taskId]);
    xhr.responseType = 'arraybuffer';

    xhr.onLoad.listen((event) {
      if (xhr.status == 200) {
        _context.decodeAudioData(xhr.response, (audioBuffer) {
          _updateProgress(taskId, audioBuffer);
        }, (errorMessage) {
          _updateProgress(taskId, null);
          final message = 'BufferList: decoding "' +
              _bufferData[taskId] +
              '" failed. (' +
              errorMessage.toString() +
              ')';
          _rejectHandler(message);
          print(message);
        });
      } else {
        final message = 'BufferList: XHR error while loading "' +
            _bufferData[taskId] +
            '". (' +
            xhr.status.toString() +
            ' ' +
            xhr.statusText +
            ')';
        _rejectHandler(message);
        print(message);
      }
    });

    xhr.onError.listen((event) {
      _updateProgress(taskId, null);
      _rejectHandler();
      print('BufferList: XHR network failed on loading "' +
          _bufferData[taskId] +
          '".');
    });

    xhr.send();
  }

/**
 * Updates the overall progress on loading tasks.
 * @param {Number} taskId Task ID number.
 * @param {AudioBuffer} audioBuffer Decoded AudioBuffer object.
 */
  _updateProgress(taskId, audioBuffer) {
    print(_bufferList);
    print(audioBuffer);
    _bufferList.add(audioBuffer);

    if (_options['verbose']) {
      final messageString = _options['dataType'] == BufferDataType['BASE64']
          ? 'ArrayBuffer(' + taskId + ') from Base64-encoded HRIR'
          : '"' + _bufferData[taskId] + '"';
      print('BufferList: ' + messageString + ' successfully loaded.');
    }

    if (--_numberOfTasks == 0) {
      final messageString = _options['dataType'] == BufferDataType['BASE64']
          ? _bufferData.length.toString() +
              ' AudioBuffers from Base64-encoded HRIRs'
          : _bufferData.length.toString() + ' files via XHR';
      print('BufferList: ' + messageString + ' loaded successfully.');
      _resolveHandler(_bufferList);
    }
  }
}
