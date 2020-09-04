// Core dependencies
import 'dart:web_audio';

// Internal dependencies
import 'listener.dart';
import 'source.dart';
import 'room.dart';
import 'encoder.dart';
import 'reso_utils.dart';


/// Main class for managing sources, room and listener models.
/// [context] - Audio Context[options]
/// [options] provides Options for constructing a new ResonanceAudio scene.
class ResonanceAudio {
  
  num ambisonicOrder;
  List<Source> _sources;
  Room room;
  Listener listener;
  AudioContext context;
  GainNode output;
  GainNode ambisonicOutput;
  GainNode ambisonicInput;

  ResonanceAudio();

  Future<void> init(AudioContext ctxt, {Map<String, dynamic> options}) async {
    context = ctxt;

    // Use defaults for null arguments.
    if (options == null) {
      options = Map<String, dynamic>();
    }
    if (options['ambisonicOrder'] == null) {
      options['ambisonicOrder'] = ResoUtils.DEFAULT_AMBISONIC_ORDER;
    }
    if (options['listenerPosition'] == null) {
      options['listenerPosition'] = ResoUtils.DEFAULT_POSITION;
    }
    if (options['listenerForward'] == null) {
      options['listenerForward'] = ResoUtils.DEFAULT_FORWARD;
    }
    if (options['listenerUp'] == null) {
      options['listenerUp'] = ResoUtils.DEFAULT_UP;
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

    // Create member submodules.
    ambisonicOrder = Encoder.validateAmbisonicOrder(options['ambisonicOrder']);
    _sources = new List<Source>();
    print("create room");
    room = new Room(ctxt, {
      'listenerPosition': options['listenerPosition'],
      'dimensions': options['dimensions'],
      'materials': options['materials'],
      'speedOfSound': options['speedOfSound'],
    });
    print('create Listener');
    listener = new Listener();
    await listener.init(ctxt, {
      'ambisonicOrder': options['ambisonicOrder'],
      'position': options['listenerPosition'],
      'forward': options['listenerForward'],
      'up': options['listenerUp'],
    });

    // Create auxillary audio nodes.
    output = context.createGain();
    ambisonicOutput = context.createGain();
    ambisonicInput = listener.input;

    // Connect audio graph.
    room.output.connectNode(listener.input);
    listener.output.connectNode(output);
    listener.ambisonicOutput.connectNode(ambisonicOutput);
    return null;
  }

/// Create a new source for the scene using [options]
/// Options for constructing a new Source.
  Source createSource({Map<String, dynamic> options}) {
    // Create a source and push it to the internal sources array, returning
    // the object's reference to the user.
    Source source = new Source(this, options);
    _sources.add(source);
    return source;
  }

/// Set the scene's desired ambisonic order.
/// [ambisonicOrder] Desired ambisonic order.
  void setAmbisonicOrder(num ambisonicOrder) {
    ambisonicOrder = Encoder.validateAmbisonicOrder(ambisonicOrder);
  }

/// Set the room's dimensions and wall materials.
/// [dimensions] Room dimensions (in meters).
/// [materials] Named acoustic materials per wall.
  void setRoomProperties(
      Map<String, dynamic> dimensions, Map<String, dynamic> materials) {
    room.setProperties(dimensions, materials);
  }

///Set the listener's position (in meters), where origin is the center of
///the room.
/// [x]
/// [y]
/// [z]
  void setListenerPosition(num x, num y, num z) {
    // Update listener position.
    listener.position[0] = x;
    listener.position[1] = y;
    listener.position[2] = z;
    room.setListenerPosition(x, y, z);

    // Update sources with new listener position.
    _sources.forEach((element) {
      element.update();
    });
  }


 /// Set the source's orientation using forward and up vectors.
 /// [forwardX]
 /// [forwardY]
 /// [forwardZ]
 /// [upX]
 /// [upY]
 /// [upZ]

  void setListenerOrientation(
      num forwardX, num forwardY, num forwardZ, num upX, num upY, num upZ) {
    listener.setOrientation(forwardX, forwardY, forwardZ, upX, upY, upZ);
  }

/// Set the speed of sound from [speedOfSound].
  void setSpeedOfSound(num speedOfSound) {
    room.speedOfSound = speedOfSound;
  }
}
