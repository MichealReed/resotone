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
    this._context = OmniUtils.isAudioContext(context) ? context : null;

    this._options = {
      "dataType": BufferDataType['BASE64'],
      "verbose": false,
    };

    if (options != null) {
      if (options['dataType'] &&
          OmniUtils.isDefinedENUMEntry(BufferDataType, options['dataType'])) {
        this._options['dataType'] = options['dataType'];
      }
      if (options['verbose']) {
        this._options['verbose'] = options['verbose'];
      }
    }

    this._bufferList = new List<AudioBuffer>();
    this._bufferData = this._options['dataType'] == BufferDataType['BASE64']
        ? bufferData
        : bufferData.elementAt(0);
    this._numberOfTasks = this._bufferData.length;

    this._resolveHandler = null;
    this._rejectHandler = () {};
  }

/**
 * Starts AudioBuffer loading tasks.
 * @return {Promise<AudioBuffer[]>} The promise resolves with an array of
 * AudioBuffer.
 */
  Future<List<AudioBuffer>> load() {
    return new Future<List<AudioBuffer>>(_promiseGenerator(load));
  }

/**
 * Promise argument generator. numernally starts multiple async loading tasks.
 * @private
 * @param {function} resolve Promise resolver.
 * @param {function} reject Promise reject.
 */
  _promiseGenerator(Function resolve, {Function reject}) {
    if (resolve is! Function) {
      print('BufferList: Invalid Promise resolver.');
    } else {
      _resolveHandler = resolve;
    }

    if (reject is Function) {
      this._rejectHandler = reject;
    }

    for (num i = 0; i < this._bufferData.length; ++i) {
      this._options['dataType'] == BufferDataType['BASE64']
          ? this._launchAsyncLoadTask(i)
          : this._launchAsyncLoadTaskXHR(i);
    }
  }

/**
 * Run async loading task for Base64-encoded string.
 * @private
 * @param {Number} taskId Task ID number from the ordered list |bufferData|.
 */
  void _launchAsyncLoadTask(num taskId) {
    this._context.decodeAudioData(
        OmniUtils.getArrayBufferFromBase64String(this._bufferData[taskId]),
        (AudioBuffer audioBuffer) {
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
  void _launchAsyncLoadTaskXHR(taskId) {
    final xhr = new HttpRequest();
    xhr.open('GET', this._bufferData[taskId]);
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
    this._bufferList[taskId] = audioBuffer;

    if (this._options['verbose']) {
      final messageString = _options['dataType'] == BufferDataType['BASE64']
          ? 'ArrayBuffer(' + taskId + ') from Base64-encoded HRIR'
          : '"' + this._bufferData[taskId] + '"';
      print('BufferList: ' + messageString + ' successfully loaded.');
    }

    if (--this._numberOfTasks == 0) {
      final messageString = _options['dataType'] == BufferDataType['BASE64']
          ? this._bufferData.length.toString() +
              ' AudioBuffers from Base64-encoded HRIRs'
          : this._bufferData.length.toString() + ' files via XHR';
      print('BufferList: ' + messageString + ' loaded successfully.');
      this._resolveHandler(this._bufferList);
    }
  }
}
