import 'dart:async';
import 'dart:html' as html;
import 'dart:web_audio' as audio;
import 'package:resotone/resotone.dart';
import 'package:flutter/material.dart';

typedef void OnError(Exception exception);

const kUrl =
    "https://cors-anywhere.herokuapp.com/https://nightride.fm/stream/nightride.m4a";

enum PlayerState { stopped, playing, paused }

class HTMLAudioPlayerWidget extends StatefulWidget {
  String url;
  double x;
  double y;
  ResonanceAudio resonanceAudio;
  HTMLAudioPlayerWidget({@required this.x, this.y});

  @override
  _HTMLAudioPlayerWidgetState createState() => _HTMLAudioPlayerWidgetState();
}

class _HTMLAudioPlayerWidgetState extends State<HTMLAudioPlayerWidget> {
  Duration duration;
  Duration position;

  double prevX = 0;
  double prevY = 0;

  String localFilePath;

  PlayerState playerState = PlayerState.stopped;
  bool init = false;

  html.AudioElement player;
  audio.AudioListener listener;
  audio.AudioContext audioCtx;
  audio.PannerNode panner;
  Source source;
  audio.MediaElementAudioSourceNode audioElementSource;

  double lastPosition = 0;
  String currentUrl;

  get isPlaying => playerState == PlayerState.playing;
  get isPaused => playerState == PlayerState.paused;

  get durationText =>
      duration != null ? duration.toString().split('.').first : '';

  get positionText =>
      position != null ? position.toString().split('.').first : '';

  bool isMuted = false;
  String uid;
  StreamSubscription _positionSubscription;
  StreamSubscription _audioPlayerStateSubscription;

  @override
  void initState() {
    player = new html.AudioElement(kUrl);
    player.crossOrigin = "*";
    audioInit();
    super.initState();
  }

  void audioInit() async {
    audioCtx = new audio.AudioContext();

    var roomDimensions = {
      'width': 5,
      'height': 5,
      'depth': 5,
    };

    var roomMaterials = {
      // Room wall materials
      'left': 'brick-bare',
      'right': 'curtain-heavy',
      'front': 'marble',
      'back': 'glass-thin',
      // Room floor
      'down': 'grass',
      // Room ceiling
      'up': 'marble',
    };
    print("create rso");

    resoScene = ResonanceAudio();
    await resoScene.init(audioCtx, options: {
      'ambisonicOrder': 1,
      'dimensions': roomDimensions,
      'materials': roomMaterials
    });

    resoScene.setRoomProperties(roomDimensions, roomMaterials);
    print("create media element");

    resoScene.setListenerPosition(1, 0, 0);
    print("create source");
    source = resoScene.createSource();
    source.setPosition(10000, 0, 0);
    source.setMaxDistance(10);
    source.setSourceWidth(10);

    print("connect source");
    audioElementSource = audioCtx.createMediaElementSource(player);
    resoScene.output.connectNode(audioCtx.destination);

    audioElementSource.connectNode(source.input);
  }

  @override
  void dispose() {
    try {
      _positionSubscription.cancel();
      _audioPlayerStateSubscription.cancel();
      player.pause();
    } catch (e) {}
    super.dispose();
  }

  void initAudioPlayer() {}

  Future pause() async {
    player.pause();
    setState(() => playerState = PlayerState.paused);
  }

  Future mute(bool muted) async {
    player.volume = muted ? 0 : 100;
    setState(() {
      isMuted = muted;
    });
  }

  void _updateUserPos(double x, double y) {
    if (listener != null) {
      listener.setPosition(x, y, 0);
    }
    if (source != null) {
      source.setPosition(x, y, 0);
    }
  }

  void onComplete() {
    setState(() => playerState = PlayerState.stopped);
  }

  @override
  Widget build(BuildContext context) {
    return _buildPlayer();
  }

  Widget _buildPlayer() => Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                onPressed: () => _playReso(kUrl, 1000, 1000, 5000, 2500),
                iconSize: 64.0,
                icon: Icon(Icons.play_arrow),
                color: Colors.cyan,
              ),
              IconButton(
                onPressed: isPlaying ? () => pause() : null,
                iconSize: 64.0,
                icon: Icon(Icons.pause),
                color: Colors.cyan,
              ),
            ]),
            if (position != null) _buildMuteButtons(),
            if (position != null) _buildProgressView()
          ],
        ),
      );

  Row _buildProgressView() => Row(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.all(12.0),
        ),
        Text(
          position != null
              ? "${positionText ?? ''} ${durationText ?? ''}"
              : duration != null
                  ? durationText
                  : '',
          style: TextStyle(fontSize: 24.0),
        )
      ]);

  Row _buildMuteButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        HtmlElementView(viewType: uid),
        if (!isMuted)
          FlatButton.icon(
            onPressed: () => mute(true),
            icon: Icon(
              Icons.headset_off,
              color: Colors.cyan,
            ),
            label: Text('Mute', style: TextStyle(color: Colors.cyan)),
          ),
        if (isMuted)
          FlatButton.icon(
            onPressed: () => mute(false),
            icon: Icon(Icons.headset, color: Colors.cyan),
            label: Text('Unmute', style: TextStyle(color: Colors.cyan)),
          ),
      ],
    );
  }

  ResonanceAudio resoScene;

  void _playReso(
      String url, double posX, double posY, double width, double height) async {
    audioCtx.resume();
    setState(() {
      playerState = PlayerState.playing;
    });
    player.play();
  }
}
