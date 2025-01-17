// /*
//  * Copyright (C) 2021 Miðeind ehf.
//  * 
//  * Licensed under the Apache License, Version 2.0 (the "License");
//  * you may not use this file except in compliance with the License.
//  * You may obtain a copy of the License at
//  * 
//  * http://www.apache.org/licenses/LICENSE-2.0
//  * 
//  * Unless required by applicable law or agreed to in writing, software
//  * distributed under the License is distributed on an "AS IS" BASIS,
//  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  * See the License for the specific language governing permissions and
//  * limitations under the License.
//  *
//  */

// // Example application demonstrating use of the Flutter Snowboy plugin.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_snowboy/flutter_snowboy.dart';
import 'package:audiofileplayer/audiofileplayer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound_lite/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(SnowboyExampleApp());
}

class SnowboyExampleApp extends StatefulWidget {
  @override
  _SnowboyExampleAppState createState() => _SnowboyExampleAppState();
}

class _SnowboyExampleAppState extends State<SnowboyExampleApp> {
  bool running = false;
  int numDetected = 0;
  String status = "Snowboy is not running";
  String buttonTitle = 'Start detection';
  Snowboy? detector;
  FlutterSoundRecorder _micRecorder = FlutterSoundRecorder();
  StreamController<Food>? _recordingDataController;
  StreamSubscription? _recordingDataSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    PermissionStatus status = await Permission.microphone.request();
    // if (status != PermissionStatus.granted)
    //   throw RecordingPermissionException("Microphone permission not granted");

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      //String modelPath = await copyModelToFilesystem("hi_embla.pmdl");
      String modelPath = await copyModelToFilesystem("hey_tulu.pmdl");
      // Create detector object and prepare it
      detector = Snowboy();
      await detector!.prepare(modelPath);
      detector!.hotwordHandler = hotwordHandler;
    } on PlatformException {}
  }

  // Copy model from asset bundle to temp directory on the filesystem
  static Future<String> copyModelToFilesystem(String filename) async {
    String dir = (await getTemporaryDirectory()).path;
    String finalPath = "$dir/$filename";
    if (await File(finalPath).exists() == true) {
      return finalPath;
    }
    ByteData bytes = await rootBundle.load("assets/$filename");
    final buffer = bytes.buffer;
    File(finalPath).writeAsBytes(
        buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
    return finalPath;
  }

  // Function to invoke when hotword is detected
  void hotwordHandler() {
    // Play sound
    Audio.load('assets/ding.wav')
      ..play()
      ..dispose();
    // Increment counter
    setState(() {
      numDetected += 1;
    });
  }

  void startDetection() async {
    // Prep recording session
    await _micRecorder.openAudioSession();

    // Create recording stream
    _recordingDataController = StreamController<Food>();
    _recordingDataSubscription =
        _recordingDataController!.stream.listen((buffer) {
      // When we get data, feed it into Snowboy detector
      if (buffer is FoodData) {
        Uint8List copy = new Uint8List.fromList(buffer.data!.toList());
        // print("Got audio data (${buffer.data.lengthInBytes} bytes");
        detector!.detect(copy);
      }
    });

    // Start recording
    await _micRecorder.startRecorder(
        toStream: _recordingDataController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000);
  }

  void stopDetection() async {
    await _micRecorder.stopRecorder();
    await _micRecorder.closeAudioSession();
    await _recordingDataSubscription?.cancel();
    await _recordingDataController?.close();
  }

  void toggleHotwordDetection() {
    String s;
    String t;
    bool r;

    if (running == false) {
      startDetection();
      //s = "Snowboy is running\nSay 'Hi Embla' to trigger hotword handler.";
      s = "Snowboy is running\nSay 'Hey Tulu' to trigger hotword handler.";
      t = "Stop detection";
      r = true;
    } else {
      stopDetection();
      s = "Snowboy is not running";
      t = "Start detection";
      r = false;
    }
    setState(() {
      status = s;
      running = r;
      buttonTitle = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Snowboy example app'),
        ),
        body: Center(
          child: Column(children: <Widget>[
            MaterialButton(
              minWidth: double.infinity,
              child: Text(buttonTitle,
                  style: TextStyle(
                    fontSize: 30.0,
                  )),
              onPressed: toggleHotwordDetection,
            ),
            Text(status,
                style: TextStyle(
                  fontSize: 20.0,
                )),
            Text('Hotword heard $numDetected times',
                style: TextStyle(
                  fontSize: 20.0,
                )),
          ]),
        ),
      ),
    );
  }
}
