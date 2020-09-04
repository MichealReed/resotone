// Core Dependencies
import 'dart:typed_data';
import 'dart:web_audio';
import 'dart:html';


/// Rendering mode ENUM.
enum RenderingMode {
  // Use ambisonic rendering.
  AMBISONIC,
  // Bypass. No ambisonic rendering.
  BYPASS,
  //Disable audio output.
  OFF
}

/// Omnitone utility class for defaults and helper methods
class OmniUtils {
// Static temp storage for matrix inversion.
  static num a00;
  static num a01;
  static num a02;
  static num a03;
  static num a10;
  static num a11;
  static num a12;
  static num a13;
  static num a20;
  static num a21;
  static num a22;
  static num a23;
  static num a30;
  static num a31;
  static num a32;
  static num a33;
  static num b00;
  static num b01;
  static num b02;
  static num b03;
  static num b04;
  static num b05;
  static num b06;
  static num b07;
  static num b08;
  static num b09;
  static num b10;
  static num b11;
  static num det;

  /// A 4x4 matrix inversion utility. This does not handle the case when the
  /// arguments are not proper 4x4 matrices.
  /// [out]   The inverted result.
  /// [a]     The source matrix.
  /// out
  static invertMatrix4(out, a) {
    a00 = a[0];
    a01 = a[1];
    a02 = a[2];
    a03 = a[3];
    a10 = a[4];
    a11 = a[5];
    a12 = a[6];
    a13 = a[7];
    a20 = a[8];
    a21 = a[9];
    a22 = a[10];
    a23 = a[11];
    a30 = a[12];
    a31 = a[13];
    a32 = a[14];
    a33 = a[15];
    b00 = a00 * a11 - a01 * a10;
    b01 = a00 * a12 - a02 * a10;
    b02 = a00 * a13 - a03 * a10;
    b03 = a01 * a12 - a02 * a11;
    b04 = a01 * a13 - a03 * a11;
    b05 = a02 * a13 - a03 * a12;
    b06 = a20 * a31 - a21 * a30;
    b07 = a20 * a32 - a22 * a30;
    b08 = a20 * a33 - a23 * a30;
    b09 = a21 * a32 - a22 * a31;
    b10 = a21 * a33 - a23 * a31;
    b11 = a22 * a33 - a23 * a32;
    det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

    if (det == null) {
      return null;
    }

    det = 1.0 / det;
    out[0] = (a11 * b11 - a12 * b10 + a13 * b09) * det;
    out[1] = (a02 * b10 - a01 * b11 - a03 * b09) * det;
    out[2] = (a31 * b05 - a32 * b04 + a33 * b03) * det;
    out[3] = (a22 * b04 - a21 * b05 - a23 * b03) * det;
    out[4] = (a12 * b08 - a10 * b11 - a13 * b07) * det;
    out[5] = (a00 * b11 - a02 * b08 + a03 * b07) * det;
    out[6] = (a32 * b02 - a30 * b05 - a33 * b01) * det;
    out[7] = (a20 * b05 - a22 * b02 + a23 * b01) * det;
    out[8] = (a10 * b10 - a11 * b08 + a13 * b06) * det;
    out[9] = (a01 * b08 - a00 * b10 - a03 * b06) * det;
    out[10] = (a30 * b04 - a31 * b02 + a33 * b00) * det;
    out[11] = (a21 * b02 - a20 * b04 - a23 * b00) * det;
    out[12] = (a11 * b07 - a10 * b09 - a12 * b06) * det;
    out[13] = (a00 * b09 - a01 * b07 + a02 * b06) * det;
    out[14] = (a31 * b01 - a30 * b03 - a32 * b00) * det;
    out[15] = (a20 * b03 - a21 * b01 + a22 * b00) * det;

    return out;
  }

  /// Check if a value is defined in the ENUM dictionary.
  /// [enumDictionary] - ENUM dictionary.
  /// [entryValue] - a value to probe.
  static isDefinedENUMEntry(enumDictionary, entryValue) {
    for (var enumKey in enumDictionary) {
      if (entryValue == enumDictionary[enumKey]) {
        return true;
      }
    }
    return false;
  }

  /// Check if the given object is an instance of BaseAudioContext.
  /// [context] - A context object to be checked.
  static bool isAudioContext(context) {
    // TODO(hoch): Update this when BaseAudioContext is available for all
    // browsers.
    return context is AudioContext || context is AudioBuffer ? true : false;
  }

  /// Check if the given object is a valid AudioBuffer.
  /// [audioBuffer] An AudioBuffer object to be checked.
  static bool isAudioBuffer(audioBuffer) {
    return audioBuffer is AudioBuffer ? true : false;
  }

  /// Perform channel-wise merge on multiple AudioBuffers. The sample rate and
  /// the length of buffers to be merged must be identical.
  /// [context] - Associated BaseAudioContext.
  /// [bufferList] - An array of AudioBuffers to be merged
  /// channel-wise.
  /// returns a single merged AudioBuffer.
  static AudioBuffer mergeBufferListByChannel(
      context, List<AudioBuffer> bufferList) {
    num bufferLength = bufferList[0].length;
    num bufferSampleRate = bufferList[0].sampleRate;
    num bufferNumberOfChannel = 0;

    for (num i = 0; i < bufferList.length; ++i) {
      if (bufferNumberOfChannel > 32) {
        print('Utils.mergeBuffer: Number of channels cannot exceed 32.' +
            '(got ' +
            bufferNumberOfChannel.toString() +
            ')');
      }
      if (bufferLength != bufferList[i].length) {
        print('Utils.mergeBuffer: AudioBuffer lengths are ' +
            'inconsistent. (expected ' +
            bufferLength.toString() +
            ' but got ' +
            bufferList[i].length.toString() +
            ')');
      }
      if (bufferSampleRate != bufferList[i].sampleRate) {
        print('Utils.mergeBuffer: AudioBuffer sample rates are ' +
            'inconsistent. (expected ' +
            bufferSampleRate.toString() +
            ' but got ' +
            bufferList[i].sampleRate.toString() +
            ')');
      }
      bufferNumberOfChannel += bufferList[i].numberOfChannels;
    }

    final buffer = context.createBuffer(
        bufferNumberOfChannel, bufferLength, bufferSampleRate);
    num destinationChannelIndex = 0;
    for (num i = 0; i < bufferList.length; ++i) {
      for (num j = 0; j < bufferList[i].numberOfChannels; ++j) {
        buffer
            .getChannelData(destinationChannelIndex++)
            .set(bufferList[i].getChannelData(j));
      }
    }

    return buffer;
  }

  /// Perform channel-wise split by the given channel count. For example,
  /// 1 x AudioBuffer(8) -> splitBuffer(context, buffer, 2) -> 4 x AudioBuffer(2).
  /// [context] - Associated BaseAudioContext.
  /// [audioBuffer] - An AudioBuffer to be splitted.
  /// [splitBy] - Number of channels to be splitted.
  /// returns a list of splitted AudioBuffers.
  static List<AudioBuffer> splitBufferbyChannel(context, audioBuffer, splitBy) {
    if (audioBuffer.numberOfChannels <= splitBy) {
      print('Utils.splitBuffer: Insufficient number of channels. (' +
          audioBuffer.numberOfChannels +
          ' splitted by ' +
          splitBy +
          ')');
    }

    List<AudioBuffer> bufferList = [];
    num sourceChannelIndex = 0;
    num numberOfSplittedBuffer = (audioBuffer.numberOfChannels / splitBy * 1);
    numberOfSplittedBuffer = numberOfSplittedBuffer.ceil();
    for (num i = 0; i < numberOfSplittedBuffer; ++i) {
      final buffer = context.createBuffer(
          splitBy, audioBuffer.length, audioBuffer.sampleRate);
      for (num j = 0; j < splitBy; ++j) {
        if (sourceChannelIndex < audioBuffer.numberOfChannels) {
          buffer
              .getChannelData(j)
              .set(audioBuffer.getChannelData(sourceChannelIndex++));
        }
      }
      bufferList.add(buffer);
    }

    return bufferList;
  }

  /// Converts Base64-encoded string to [ByteBuffer].
  /// [base64String] - Base64-encoded string.
  /// returns a converted [ByteBuffer] object.
  static ByteBuffer getArrayBufferFromBase64String(String base64String) {
    String binaryString = window.atob(base64String);
    Uint8List byteArray = new Uint8List(binaryString.length);
    num index = 0;
    for (num i = 0; i < binaryString.length; i++) {
      byteArray[index] = binaryString.codeUnitAt(index);
      index += 1;
    }
    return byteArray.buffer;
  }
}
