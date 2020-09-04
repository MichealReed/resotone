/// Core dependencies
import 'dart:math';
import 'dart:web_audio';

/// Kronecker Delta function.
/// [i]
/// [j]
num getKroneckerDelta(num i, num j) {
  return i == j ? 1 : 0;
}

/// A helper function to allow us to access a matrix array in the same
/// manner, assuming it is a (2l+1)x(2l+1) matrix. 2 uses an odd convention of
/// referring to the rows and columns using centered indices, so the middle row
/// and column are (0, 0) and the upper left would have negative coordinates.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [l]
/// [i]
/// [j]
/// [gainValue]
num setCenteredElement(
    List<List<GainNode>> matrix, num l, num i, num j, num gainValue) {
  final index = (j + l) * (2 * l + 1) + (i + l);
  // Row-wise indexing.
  if (gainValue.isFinite) {
    matrix[l - 1][index].gain.value = gainValue;
  } else {
    matrix[l - 1][index].gain.value = 1;
  }
}

/// This is a helper function to allow us to access a matrix array in the same
/// manner, assuming it is a (2l+1) x (2l+1) matrix.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [l]
/// [i]
/// [j]
num getCenteredElement(List<List<GainNode>> matrix, num l, num i, num j) {
  // Row-wise indexing.
  final index = (j + l) * (2 * l + 1) + (i + l);
  return matrix[l - 1][index].gain.value;
}

/// Helper function defined in 2 that is used by the functions U, V, W.
/// This should not be called on its own, as U, V, and W (and their coefficients)
/// select the appropriate matrix elements to access arguments |a| and |b|.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [i]
/// [a]
/// [b]
/// [l]
num getP(List<List<GainNode>> matrix, num i, num a, num b, num l) {
  if (b == l) {
    return getCenteredElement(matrix, 1, i, 1) *
            getCenteredElement(matrix, l - 1, a, l - 1) -
        getCenteredElement(matrix, 1, i, -1) *
            getCenteredElement(matrix, l - 1, a, -l + 1);
  } else if (b == -l) {
    return getCenteredElement(matrix, 1, i, 1) *
            getCenteredElement(matrix, l - 1, a, -l + 1) +
        getCenteredElement(matrix, 1, i, -1) *
            getCenteredElement(matrix, l - 1, a, l - 1);
  } else {
    return getCenteredElement(matrix, 1, i, 0) *
        getCenteredElement(matrix, l - 1, a, b);
  }
}

/// The functions U, V, and W should only be called if the correspondingly
/// named coefficient u, v, w from the function ComputeUVWCoeff() is non-zero.
/// When the coefficient is 0, these would attempt to access matrix elements that
/// are out of bounds. The vector of rotations, |r|, must have the |l - 1|
/// previously compnumed band rotations. These functions are valid for |l >= 2|.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [m]
/// [n]
/// [l]
num getU(List<List<GainNode>> matrix, num m, num n, num l) {
  // Although [1, 2] split U into three cases for m == 0, m < 0, m > 0
  // the actual values are the same for all three cases.
  return getP(matrix, 0, m, n, l);
}

/// The functions U, V, and W should only be called if the correspondingly
/// named coefficient u, v, w from the function ComputeUVWCoeff() is non-zero.
/// When the coefficient is 0, these would attempt to access matrix elements that
/// are out of bounds. The vector of rotations, |r|, must have the |l - 1|
/// previously compnumed band rotations. These functions are valid for |l >= 2|.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [m]
/// [n]
/// [l]
num getV(List<List<GainNode>> matrix, num m, num n, num l) {
  if (m == 0) {
    return getP(matrix, 1, 1, n, l) + getP(matrix, -1, -1, n, l);
  } else if (m > 0) {
    final d = getKroneckerDelta(m, 1);
    return getP(matrix, 1, m - 1, n, l) * sqrt(1 + d) -
        getP(matrix, -1, -m + 1, n, l) * (1 - d);
  } else {
    // Note there is apparent errata in [1,2,2b] dealing with this particular
    // case. [2b] writes it should be P*1-d)+P*1-d)^0.5
    // [1] writes it as P*1+d)+P*1-d)^0.5, but going through the math by hand,
    // you must have it as P*1-d)+P*1+d)^0.5 to form a 2^.5 term, which
    // parallels the case where m > 0.
    final d = getKroneckerDelta(m, -1);
    return getP(matrix, 1, m + 1, n, l) * (1 - d) +
        getP(matrix, -1, -m - 1, n, l) * sqrt(1 + d);
  }
}

/// The functions U, V, and W should only be called if the correspondingly
/// named coefficient u, v, w from the function ComputeUVWCoeff() is non-zero.
/// When the coefficient is 0, these would attempt to access matrix elements that
/// are out of bounds. The vector of rotations, |r|, must have the |l - 1|
/// previously compnumed band rotations. These functions are valid for |l >= 2|.
/// [matrix] N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.
/// [m]
/// [n]
/// [l]
num getW(List<List<GainNode>> matrix, num m, num n, num l) {
  // Whenever this happens, w is also 0 so W can be anything.
  if (m == 0) {
    return 0;
  }

  return m > 0
      ? getP(matrix, 1, m + 1, n, l) + getP(matrix, -1, -m - 1, n, l)
      : getP(matrix, 1, m - 1, n, l) - getP(matrix, -1, -m + 1, n, l);
}

/// Calculates the coefficients applied to the U, V, and W functions. Because
/// their equations share many common terms they are computed simultaneously.
/// [m]
/// [n]
/// [l]
/// returns 3 coefficients for U, V and W functions.
List<num> computeUVWCoeff(num m, num n, num l) {
  final d = getKroneckerDelta(m, 0);
  final reciprocalDenominator =
      (n) == l ? 1 / (2 * l * (2 * l - 1)) : 1 / ((l + n) * (l - n));

  return [
    sqrt((l + m) * (l - m) * reciprocalDenominator),
    0.5 *
        (1 - 2 * d) *
        sqrt((1 + d) *
            (l + (m).abs() - 1) *
            (l + (m).abs()) *
            reciprocalDenominator),
    -0.5 *
        (1 - d) *
        sqrt((l - (m).abs() - 1) * (l - (m).abs())) *
        reciprocalDenominator,
  ];
}

/// Calculates the (2l+1) x (2l+1) rotation matrix for the band l.
/// This uses the matrices computed for band 1 and band l-1 to compute the
/// matrix for band l. |rotations| must contain the previously computed l-1
/// rotation matrices.
/// This implementation comes from p. 5 (6346), Table 1 and 2 in 2 taking
/// into account the corrections from 2b.
/// [matrix] - N matrices of gainNodes, each with where
/// n=1,2,...,N.
/// [l]
void computeBandRotation(List<List<GainNode>> matrix, num l) {
  // The lth band rotation matrix has rows and columns equal to the number of
  // coefficients within that band (-l <= m <= l implies 2l + 1 coefficients).
  for (int m = -l; m <= l; m++) {
    for (int n = -l; n <= l; n++) {
      final uvwCoefficients = computeUVWCoeff(m, n, l);

      // The functions U, V, W are only safe to call if the coefficients
      // u, v, w are not zero.
      if ((uvwCoefficients[0]).abs() > 0) {
        uvwCoefficients[0] *= getU(matrix, m, n, l);
      }
      if ((uvwCoefficients[1]).abs() > 0) {
        uvwCoefficients[1] *= getV(matrix, m, n, l);
      }
      if ((uvwCoefficients[2]).abs() > 0) {
        uvwCoefficients[2] *= getW(matrix, m, n, l);
      }

      setCenteredElement(matrix, l, m, n,
          uvwCoefficients[0] + uvwCoefficients[1] + uvwCoefficients[2]);
    }
  }
}

/// Compute the HOA rotation matrix after setting the transform matrix.
/// [matrix] - N matrices of gainNodes, each with (2n+1) x (2n+1)
/// elements, where n=1,2,...,N.

void computeHOAMatrices(List<List<GainNode>> matrix) {
  // We start by computing the 2nd-order matrix from the 1st-order matrix.
  for (int i = 2; i <= matrix.length; i++) {
    computeBandRotation(matrix, i);
  }
}

/// Higher-order-ambisonic decoder based on gain node network. We expect
/// the order of the channels to conform to ACN ordering. Below are the helper
/// methods to compute SH rotation using recursion. The code uses maths described
/// in the following papers:
///  1 - R. Green, "Spherical Harmonic Lighting: The Gritty Details", GDC 2003,
///      http://www.research.scea.com/gdc2003/spherical-harmonic-lighting.pdf
///  2 - J. Ivanic and K. Ruedenberg, "Rotation Matrices for Real
///      Spherical Harmonics. Direct Determination by Recursion", J. Phys.
///      Chem., vol. 100, no. 15, pp. 6342-6347, 1996.
///      http://pubs.acs.org/doi/pdf/10.1021/jp953350u
///  2b - Corrections to initial publication:
///       http://pubs.acs.org/doi/pdf/10.1021/jp9833350
///  [context] - Associated AudioContext.
///  [ambisonicOrder] - Ambisonic order.
class HOARotator {
  AudioContext _context;
  num _ambisonicOrder;
  ChannelSplitterNode _splitter;
  ChannelMergerNode _merger;
  ChannelSplitterNode input;
  ChannelMergerNode output;
  List<List<GainNode>> _gainNodeMatrix;

  HOARotator(AudioContext context, num ambisonicOrder) {
    _context = context;
    _ambisonicOrder = ambisonicOrder;

    // We need to determine the number of channels K based on the ambisonic order
    // N where K = (N + 1)^2.
    final numberOfChannels = (ambisonicOrder + 1) * (ambisonicOrder + 1);

    _splitter = _context.createChannelSplitter(numberOfChannels);
    _merger = _context.createChannelMerger(numberOfChannels);

    // Create a set of per-order rotation matrices using gain nodes.
    _gainNodeMatrix = new List<List<GainNode>>();
    num orderOffset;
    num rows;
    num inputIndex;
    num outputIndex;
    num matrixIndex;
    for (int i = 1; i <= ambisonicOrder; i++) {
      // Each ambisonic order requires a separate (2l + 1) x (2l + 1) rotation
      // matrix. We compute the offset value as the first channel index of the
      // current order where
      //   k_last = l^2 + l + m,
      // and m = -l
      //   k_last = l^2
      orderOffset = i * i;

      // Uses row-major indexing.
      rows = (2 * i + 1);

      _gainNodeMatrix.add(new List<GainNode>());
      for (num j = 0; j < rows; j++) {
        inputIndex = orderOffset + j;
        for (num k = 0; k < rows; k++) {
          outputIndex = orderOffset + k;
          matrixIndex = j * rows + k;
          _gainNodeMatrix[i - 1].add(_context.createGain());
          _splitter.connectNode(
              _gainNodeMatrix[i - 1][matrixIndex], inputIndex);
          _gainNodeMatrix[i - 1][matrixIndex]
              .connectNode(_merger, 0, outputIndex);
        }
      }
    }

    // W-channel is not involved in rotation, skip straight to ouput.
    _splitter.connectNode(_merger, 0, 0);

    // Default Identity matrix.
    setRotationMatrix3([1, 0, 0, 0, 1, 0, 0, 0, 1]);

    // Input/Output proxy.
    input = _splitter;
    output = _merger;
  }

  /// Updates the rotation matrix with 3x3 matrix.
  /// [rotationMatrix3] - A 3x3 rotation matrix. (column-major)
  void setRotationMatrix3(List<num> rotationMatrix3) {
    _gainNodeMatrix[0][0].gain.value = -rotationMatrix3[0];
    _gainNodeMatrix[0][1].gain.value = rotationMatrix3[1];
    _gainNodeMatrix[0][2].gain.value = -rotationMatrix3[2];
    _gainNodeMatrix[0][3].gain.value = -rotationMatrix3[3];
    _gainNodeMatrix[0][4].gain.value = rotationMatrix3[4];
    _gainNodeMatrix[0][5].gain.value = -rotationMatrix3[5];
    _gainNodeMatrix[0][6].gain.value = -rotationMatrix3[6];
    _gainNodeMatrix[0][7].gain.value = rotationMatrix3[7];
    _gainNodeMatrix[0][8].gain.value = -rotationMatrix3[8];
    computeHOAMatrices(_gainNodeMatrix);
  }

  /// Updates the rotation matrix with 4x4 matrix.
  /// [rotationMatrix4] - A 4x4 rotation matrix. (column-major)
  void setRotationMatrix4(List<num> rotationMatrix4) {
    _gainNodeMatrix[0][0].gain.value = -rotationMatrix4[0];
    _gainNodeMatrix[0][1].gain.value = rotationMatrix4[1];
    _gainNodeMatrix[0][2].gain.value = -rotationMatrix4[2];
    _gainNodeMatrix[0][3].gain.value = -rotationMatrix4[4];
    _gainNodeMatrix[0][4].gain.value = rotationMatrix4[5];
    _gainNodeMatrix[0][5].gain.value = -rotationMatrix4[6];
    _gainNodeMatrix[0][6].gain.value = -rotationMatrix4[8];
    _gainNodeMatrix[0][7].gain.value = rotationMatrix4[9];
    _gainNodeMatrix[0][8].gain.value = -rotationMatrix4[10];
    computeHOAMatrices(_gainNodeMatrix);
  }

  /// Returns the current 3x3 rotation matrix.
  /// returns a 3x3 rotation matrix. (column-major)
  List<num> getRotationMatrix3() {
    final rotationMatrix3 = new List<num>(9);
    rotationMatrix3[0] = -_gainNodeMatrix[0][0].gain.value;
    rotationMatrix3[1] = _gainNodeMatrix[0][1].gain.value;
    rotationMatrix3[2] = -_gainNodeMatrix[0][2].gain.value;
    rotationMatrix3[4] = -_gainNodeMatrix[0][3].gain.value;
    rotationMatrix3[5] = _gainNodeMatrix[0][4].gain.value;
    rotationMatrix3[6] = -_gainNodeMatrix[0][5].gain.value;
    rotationMatrix3[8] = -_gainNodeMatrix[0][6].gain.value;
    rotationMatrix3[9] = _gainNodeMatrix[0][7].gain.value;
    rotationMatrix3[10] = -_gainNodeMatrix[0][8].gain.value;
    return rotationMatrix3;
  }

  /// Returns the current 4x4 rotation matrix.
  /// returns a 4x4 rotation matrix. (column-major)
  List<num> getRotationMatrix4() {
    final rotationMatrix4 = new List<num>(16);
    rotationMatrix4[0] = -_gainNodeMatrix[0][0].gain.value;
    rotationMatrix4[1] = _gainNodeMatrix[0][1].gain.value;
    rotationMatrix4[2] = -_gainNodeMatrix[0][2].gain.value;
    rotationMatrix4[4] = -_gainNodeMatrix[0][3].gain.value;
    rotationMatrix4[5] = _gainNodeMatrix[0][4].gain.value;
    rotationMatrix4[6] = -_gainNodeMatrix[0][5].gain.value;
    rotationMatrix4[8] = -_gainNodeMatrix[0][6].gain.value;
    rotationMatrix4[9] = _gainNodeMatrix[0][7].gain.value;
    rotationMatrix4[10] = -_gainNodeMatrix[0][8].gain.value;
    return rotationMatrix4;
  }

  /// Get the current ambisonic order.
  num getAmbisonicOrder() {
    return _ambisonicOrder;
  }
}
