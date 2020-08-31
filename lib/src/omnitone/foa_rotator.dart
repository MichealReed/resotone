import 'dart:web_audio';

/**
 * First-order-ambisonic decoder based on gain node network.
 * @constructor
 * @param {AudioContext} context - Associated AudioContext.
 */
class FOARotator {
  AudioContext _context;
  ChannelSplitterNode _splitter;
  GainNode _inY;
  GainNode _inZ;
  GainNode _inX;
  GainNode _m0;
  GainNode _m1;
  GainNode _m2;
  GainNode _m3;
  GainNode _m4;
  GainNode _m5;
  GainNode _m6;
  GainNode _m7;
  GainNode _m8;
  GainNode _outY;
  GainNode _outZ;
  GainNode _outX;
  ChannelMergerNode _merger;
  ChannelSplitterNode input;
  ChannelMergerNode output;

  FOARotator(AudioContext context) {
    _context = context;
    _splitter = _context.createChannelSplitter(4);
    _inY = _context.createGain();
    _inZ = _context.createGain();
    _inX = _context.createGain();
    _m0 = _context.createGain();
    _m1 = _context.createGain();
    _m2 = _context.createGain();
    _m3 = _context.createGain();
    _m4 = _context.createGain();
    _m5 = _context.createGain();
    _m6 = _context.createGain();
    _m7 = _context.createGain();
    _m8 = _context.createGain();
    _outY = _context.createGain();
    _outZ = _context.createGain();
    _outX = _context.createGain();
    _merger = _context.createChannelMerger(4);

    // ACN channel ordering: [1, 2, 3] => [-Y, Z, -X]
    // Y (from channel 1)
    _splitter.connectNode(_inY, 1);
    // Z (from channel 2)
    _splitter.connectNode(_inZ, 2);
    // X (from channel 3)
    _splitter.connectNode(_inX, 3);
    _inY.gain.value = -1;
    _inX.gain.value = -1;

    // Apply the rotation in the world space.
    // |Y|   | m0  m3  m6 |   | Y * m0 + Z * m3 + X * m6 |   | Yr |
    // |Z| * | m1  m4  m7 | = | Y * m1 + Z * m4 + X * m7 | = | Zr |
    // |X|   | m2  m5  m8 |   | Y * m2 + Z * m5 + X * m8 |   | Xr |
    _inY.connectNode(_m0);
    _inY.connectNode(_m1);
    _inY.connectNode(_m2);
    _inZ.connectNode(_m3);
    _inZ.connectNode(_m4);
    _inZ.connectNode(_m5);
    _inX.connectNode(_m6);
    _inX.connectNode(_m7);
    _inX.connectNode(_m8);
    _m0.connectNode(_outY);
    _m1.connectNode(_outZ);
    _m2.connectNode(_outX);
    _m3.connectNode(_outY);
    _m4.connectNode(_outZ);
    _m5.connectNode(_outX);
    _m6.connectNode(_outY);
    _m7.connectNode(_outZ);
    _m8.connectNode(_outX);

    // Transform 3: world space to audio space.
    // W -> W (to channel 0)
    _splitter.connectNode(_merger, 0, 0);
    // Y (to channel 1)
    _outY.connectNode(_merger, 0, 1);
    // Z (to channel 2)
    _outZ.connectNode(_merger, 0, 2);
    // X (to channel 3)
    _outX.connectNode(_merger, 0, 3);
    _outY.gain.value = -1;
    _outX.gain.value = -1;

    setRotationMatrix3([1, 0, 0, 0, 1, 0, 0, 0, 1]);

    // input/output proxy.
    input = _splitter;
    output = _merger;
  }

/**
 * Updates the rotation matrix with 3x3 matrix.
 * @param {Number[]} rotationMatrix3 - A 3x3 rotation matrix. (column-major)
 */
  void setRotationMatrix3(rotationMatrix3) {
    _m0.gain.value = rotationMatrix3[0];
    _m1.gain.value = rotationMatrix3[1];
    _m2.gain.value = rotationMatrix3[2];
    _m3.gain.value = rotationMatrix3[3];
    _m4.gain.value = rotationMatrix3[4];
    _m5.gain.value = rotationMatrix3[5];
    _m6.gain.value = rotationMatrix3[6];
    _m7.gain.value = rotationMatrix3[7];
    _m8.gain.value = rotationMatrix3[8];
  }

/**
 * Updates the rotation matrix with 4x4 matrix.
 * @param {Number[]} rotationMatrix4 - A 4x4 rotation matrix. (column-major)
 */
  void setRotationMatrix4(rotationMatrix4) {
    _m0.gain.value = rotationMatrix4[0];
    _m1.gain.value = rotationMatrix4[1];
    _m2.gain.value = rotationMatrix4[2];
    _m3.gain.value = rotationMatrix4[4];
    _m4.gain.value = rotationMatrix4[5];
    _m5.gain.value = rotationMatrix4[6];
    _m6.gain.value = rotationMatrix4[8];
    _m7.gain.value = rotationMatrix4[9];
    _m8.gain.value = rotationMatrix4[10];
  }

/**
 * Returns the current 3x3 rotation matrix.
 * @return {Number[]} - A 3x3 rotation matrix. (column-major)
 */
  List<num> getRotationMatrix3() {
    return [
      _m0.gain.value,
      _m1.gain.value,
      _m2.gain.value,
      _m3.gain.value,
      _m4.gain.value,
      _m5.gain.value,
      _m6.gain.value,
      _m7.gain.value,
      _m8.gain.value,
    ];
  }

/**
 * Returns the current 4x4 rotation matrix.
 * @return {Number[]} - A 4x4 rotation matrix. (column-major)
 */
  List<num> getRotationMatrix4() {
    final rotationMatrix4 = new List<double>(16);
    rotationMatrix4[0] = _m0.gain.value;
    rotationMatrix4[1] = _m1.gain.value;
    rotationMatrix4[2] = _m2.gain.value;
    rotationMatrix4[4] = _m3.gain.value;
    rotationMatrix4[5] = _m4.gain.value;
    rotationMatrix4[6] = _m5.gain.value;
    rotationMatrix4[8] = _m6.gain.value;
    rotationMatrix4[9] = _m7.gain.value;
    rotationMatrix4[10] = _m8.gain.value;
    return rotationMatrix4;
  }
}
