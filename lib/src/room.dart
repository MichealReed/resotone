/// @file Compnume room model with early and late reflections.
/// @author Andrew Allen <bitllama@google.com>

// Internal Dependencies.
import 'dart:math';
import 'dart:web_audio';

import 'late_reflections.dart';
import 'early_reflections.dart';
import 'reso_utils.dart';

/// Generate absorption coefficients from material names.
/// [materials]

Map<String, dynamic> _getCoefficientsFromMaterials(
    Map<String, dynamic> materials) {
  print(materials);
  // Initialize coefficients to use defaults.
  Map<String, dynamic> coefficients = Map<String, dynamic>();

  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    if (ResoUtils.DEFAULT_ROOM_MATERIALS.containsKey(property)) {
      coefficients[property] = ResoUtils.ROOM_MATERIAL_COEFFICIENTS[property];
    }
  });

  // Sanitize materials.
  if (materials == null) {
    materials = ResoUtils.DEFAULT_ROOM_MATERIALS;
  }

  // Assign coefficients using provided materials.
  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    print("$property : $value");
    if (ResoUtils.DEFAULT_ROOM_MATERIALS.containsKey(property) &&
        materials.containsKey(property)) {
      if (!ResoUtils.ROOM_MATERIAL_COEFFICIENTS
          .containsValue(materials[property])) {
        coefficients[property] =
            ResoUtils.ROOM_MATERIAL_COEFFICIENTS[materials[property]];
      } else {
        print('Material \"' +
            materials[property] +
            '\" on wall \"' +
            property +
            '\" not found. Using \"' +
            ResoUtils.DEFAULT_ROOM_MATERIALS[property] +
            '\".');
      }
    } else {
      print('Wall \"' + property + '\" is not defined. Default used.');
    }
  });
  return coefficients;
}

/// Sanitize coefficients.
/// [coefficients]

Map<String, dynamic> _sanitizeCoefficients(Map<String, dynamic> coefficients) {
  if (coefficients == null) {
    coefficients = new Map<String, dynamic>();
  }

  ResoUtils.DEFAULT_ROOM_MATERIALS.forEach((property, value) {
    if (!(coefficients.containsKey(property))) {
      // If element is not present, use default coefficients.
      coefficients[property] = ResoUtils.ROOM_MATERIAL_COEFFICIENTS[
          ResoUtils.DEFAULT_ROOM_MATERIALS[property]];
    }
  });
  return coefficients;
}

/// Sanitize dimensions.
/// [dimensions]

Map<String, dynamic> _sanitizeDimensions(Map<String, dynamic> dimensions) {
  if (dimensions == null) {
    dimensions = {};
  }
  ResoUtils.DEFAULT_ROOM_DIMENSIONS.forEach((property, value) {
    if (!(dimensions.containsKey(property))) {
      dimensions[property] = ResoUtils.DEFAULT_ROOM_DIMENSIONS[property];
    }
  });

  return dimensions;
}

/// Compute frequency-dependent reverb durations.
/// [dimensions]
/// [coefficients]
/// [speedOfSound]

List<num> _getDurationsFromProperties(Map<String, dynamic> dimensions,
    Map<String, dynamic> coefficients, num speedOfSound) {
  List<num> durations = new List<num>(ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS);

  // Sanitize inputs.
  dimensions = _sanitizeDimensions(dimensions);
  coefficients = _sanitizeCoefficients(coefficients);
  if (speedOfSound == null) {
    speedOfSound = ResoUtils.DEFAULT_SPEED_OF_SOUND;
  }

  // Acoustic constant.
  num k = ResoUtils.TWENTY_FOUR_LOG10 / speedOfSound;

  // Compute volume, skip if room is not present.
  num volume = dimensions['width'] * dimensions['height'] * dimensions['depth'];
  if (volume < ResoUtils.ROOM_MIN_VOLUME) {
    return durations;
  }

  // Room surface area.
  num leftRightArea = dimensions['width'] * dimensions['height'];
  num floorCeilingArea = dimensions['width'] * dimensions['depth'];
  num frontBackArea = dimensions['depth'] * dimensions['height'];
  num totalArea = 2 * (leftRightArea + floorCeilingArea + frontBackArea);
  for (num i = 0; i < ResoUtils.NUMBER_REVERB_FREQUENCY_BANDS; i++) {
    // Effective absorptive area.
    num absorbtionArea = (coefficients['left'][i] + coefficients['right'][i]) *
            leftRightArea +
        (coefficients['down'][i] + coefficients['up'][i]) * floorCeilingArea +
        (coefficients['front'][i] + coefficients['back'][i]) * frontBackArea;
    num meanAbsorbtionArea = absorbtionArea / totalArea;

    // Compute reverberation using Eyring equation [1].
    // [1] Beranek, Leo L. "Analysis of Sabine and Eyring equations and their
    //     application to concert hall audience and chair absorption." The
    //     Journal of the Acoustical Society of America, Vol. 120, No. 3.
    //     (2006), pp. 1399-1399.
    durations[i] = ResoUtils.ROOM_EYRING_CORRECTION_COEFFICIENT *
        k *
        volume /
        (-totalArea * log(1 - meanAbsorbtionArea) +
            4 * ResoUtils.ROOM_AIR_ABSORPTION_COEFFICIENTS[i] * volume);
  }
  return durations;
}

/// Compute reflection coefficients from absorption coefficients.
///   absorptionCoefficients
/// @return

Map<String, dynamic> _computeReflectionCoefficients(
    Map<String, dynamic> absorptionCoefficients) {
  print(absorptionCoefficients);
  Map<String, dynamic> reflectionCoefficients = new Map<String, dynamic>();
  ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.forEach((property, value) {
    if (ResoUtils.DEFAULT_REFLECTION_COEFFICIENTS.containsKey(property)) {
      // Compute average absorption coefficient (per wall).
      reflectionCoefficients[property] = 0;
      for (num j = 0; j < ResoUtils.NUMBER_REFLECTION_AVERAGING_BANDS; j++) {
        num bandIndex = j + ResoUtils.ROOM_STARTING_AVERAGING_BAND;
        reflectionCoefficients[property] +=
            absorptionCoefficients[property][bandIndex];
      }
      reflectionCoefficients[property] /=
          ResoUtils.NUMBER_REFLECTION_AVERAGING_BANDS;

      // Convert absorption coefficient to reflection coefficient.
      reflectionCoefficients[property] =
          sqrt(1 - reflectionCoefficients[property]);
    }
  });
  return reflectionCoefficients;
}

/// Model that manages early and late reflections using acoustic
/// properties and listener position relative to a rectangular room.
class Room {
  EarlyReflections earlyReflections;
  LateReflections lateReflections;
  num speedOfSound;
  ChannelMergerNode _merger;
  GainNode output;
  Room(AudioContext context, Map<String, dynamic> options) {
    // Use defaults for null arguments.
    if (options == null) {
      options = {};
    }
    if (options['listenerPosition'] == null) {
      options['listenerPosition'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['dimensions'] == null) {
      options['dimensions'] = ResoUtils.DEFAULT_ROOM_DIMENSIONS;
    }
    if (options['materials'] == null) {
      options['materials'] = ResoUtils.DEFAULT_ROOM_MATERIALS;
    }
    if (options['speedOfSound'] == null) {
      options['speedOfSound'] = ResoUtils.DEFAULT_SPEED_OF_SOUND;
    }

    // Sanitize room-properties-related arguments.
    options['dimensions'] = _sanitizeDimensions(options['dimensions']);
    Map<String, dynamic> absorptionCoefficients =
        _getCoefficientsFromMaterials(options['materials']);
    print("absorption complete");
    Map<String, dynamic> reflectionCoefficients =
        _computeReflectionCoefficients(absorptionCoefficients);
    print("reflections complete");

    List<num> durations = _getDurationsFromProperties(
        options['dimensions'], absorptionCoefficients, options['speedOfSound']);
    print("dimension complete");

    // Construct submodules for early and late reflections.
    earlyReflections = new EarlyReflections(context, {
      'dimensions': options['dimensions'],
      'coefficients': reflectionCoefficients,
      'speedOfSound': options['speedOfSound'],
      'listenerPosition': options['listenerPosition'],
    });
    lateReflections = new LateReflections(context, {
      'durations': durations,
    });

    speedOfSound = options['speedOfSound'];

    // Construct auxillary audio nodes.
    output = context.createGain();
    earlyReflections.output.connectNode(output);
    _merger = context.createChannelMerger(4);

    lateReflections.output.connectNode(_merger, 0, 0);
    _merger.connectNode(output);
  }

  /// Set the room's dimensions and wall materials.
  /// [dimensions] Room dimensions (in meters).
  /// [materials] Named acoustic materials per wall.
  void setProperties(
      Map<String, dynamic> dimensions, Map<String, dynamic> materials) {
    // Compute late response.
    Map<String, dynamic> absorptionCoefficients =
        _getCoefficientsFromMaterials(materials);
    List<num> durations = _getDurationsFromProperties(
        dimensions, absorptionCoefficients, speedOfSound);
    lateReflections.setDurations(durations);

    // Compute early response.
    earlyReflections.speedOfSound = speedOfSound;
    Map<String, dynamic> reflectionCoefficients =
        _computeReflectionCoefficients(absorptionCoefficients);
    earlyReflections.setRoomProperties(dimensions, reflectionCoefficients);
  }

  /// Set the listener's position (in meters), where origin is the center of
  /// the room.
  ///  [x]
  ///  [y]
  ///  [z]
  void setListenerPosition(num x, num y, num z) {
    earlyReflections.speedOfSound = speedOfSound;
    earlyReflections.setListenerPosition(x, y, z);

    // Disable room effects if the listener is outside the room boundaries.
    num distance = getDistanceOutsideRoom(x, y, z);
    num gain = 1;
    if (distance > ResoUtils.EPSILON_FLOAT) {
      gain = 1 - distance / ResoUtils.LISTENER_MAX_OUTSIDE_ROOM_DISTANCE;

      // Clamp gain between 0 and 1.
      gain = max(0, min(1, gain));
    }
    output.gain.value = gain;
  }

  /// Compute distance outside room of provided position (in meters).
  ///  [x]
  ///  [y]
  ///  [z]
  /// return Distance outside room (in meters). Returns 0 if inside room.
  num getDistanceOutsideRoom(num x, num y, num z) {
    num dx = max(
        0,
        max(-earlyReflections.halfDimensions['width'] - x,
            x - earlyReflections.halfDimensions['width']));
    num dy = max(
        0,
        max(-earlyReflections.halfDimensions['height'] - y,
            y - earlyReflections.halfDimensions['height']));
    num dz = max(
        0,
        max(-earlyReflections.halfDimensions['depth'] - z,
            z - earlyReflections.halfDimensions['depth']));
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
}
