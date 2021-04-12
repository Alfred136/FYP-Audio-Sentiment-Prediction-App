import 'dart:convert';

import 'dart:io' as io;
import 'dart:math';

import 'package:audio_recorder/audio_recorder.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() => runApp(new MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('Real-time Audio Sentiment Analysis'),
          backgroundColor: Colors.blueGrey[700],
        ),
        body: new AppBody(),
      ),
    );
  }
}

class AppBody extends StatefulWidget {
  final LocalFileSystem localFileSystem;

  AppBody({localFileSystem})
      : this.localFileSystem = localFileSystem ?? LocalFileSystem();

  @override
  State<StatefulWidget> createState() => new AppBodyState();
}

class AppBodyState extends State<AppBody> {
  Recording _recording = new Recording();
  bool _isRecording = false;
  Random random = new Random();
  TextEditingController _controller = new TextEditingController();
  File file;
  String _predictedEmotion = "None";
  String _defaultFilename = "testAudio";
  int _recordingCount = 0;

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new Padding(
        padding: new EdgeInsets.all(8.0),
        child: new Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              new Icon(
                Icons.mic,
                color: Colors.blueGrey[600],
                size: 80,
              ),
              new FlatButton(
                onPressed: _isRecording ? null : _start,
                child: new Text("Start"),
                color: Colors.green[300],
              ),
              new FlatButton(
                onPressed: _isRecording ? _stop : null,
                child: new Text("Stop"),
                color: Colors.red[200],
              ),
              new TextField(
                controller: _controller,
                decoration: new InputDecoration(
                  hintText: 'Enter a custom path',
                ),
              ),
              new Text((_recording.extension == null) ? "Format: none" : "Format: ${_recording.extension}", style: TextStyle(fontSize: 15)),
              new Text((_recording.duration == null) ? "Audio duration: none" : "Audio duration: ${_recording.duration.inSeconds.toString()}(s)", style: TextStyle(fontSize: 15)),
              new Text("Emotion: $_predictedEmotion", style: TextStyle(fontSize: 20)),
              new Padding(padding: EdgeInsets.only(top: 10))
            ],
        ),
      ),
    );
  }

  // start recording audio
  _start() async {
    try {
      if (await AudioRecorder.hasPermissions) {
        String path;
        io.Directory tempDirectory = await getTemporaryDirectory();
        
        if (_controller.text != null && _controller.text != "") {
          // user specifies filename and path
          path = _controller.text;
          if (!_controller.text.contains('/')) {           
            path = tempDirectory.path + '/' + _controller.text;
          }         
        } else {
          // create default filename and path
          path = tempDirectory.path + '/' + _defaultFilename + _recordingCount.toString();
          _recordingCount++;
        }
        print(" Start recording: $path");
        await AudioRecorder.start(path: path, audioOutputFormat: AudioOutputFormat.WAV);
        bool isRecording = await AudioRecorder.isRecording;
        setState(() {
          _recording = new Recording(duration: new Duration(), path: "");
          _isRecording = isRecording;
        });

      } else {
        Scaffold.of(context).showSnackBar(
            new SnackBar(content: new Text("You must accept permissions")));
      }
    } catch (e) {
      print(e);
    }
  }

  // stop recording audio
  _stop() async {
    var recording = await AudioRecorder.stop();
    print(" Stop recording: ${recording.path}");
    bool isRecording = await AudioRecorder.isRecording;
    file = widget.localFileSystem.file(recording.path);
    print(" File length: ${await file.length()}");
    print(" File path: ${file.path}");
    _predictEmotion();
    setState(() {
      _recording = recording;
      _isRecording = isRecording;
    });
    _controller.text = recording.path;
  }

  // call emotion prediction Api by sending POST request to local Flask server
  _predictEmotion() async {
    String url = 'http://10.0.2.2:5000/predict';
    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.files.add(await http.MultipartFile.fromPath('audiopath', file.path));
    print(" Request: " + request.toString());

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    var jsonData = json.decode(response.body);
    print(jsonData.toString());

    if(response.statusCode==200){   
      print(" Successful: post request");  
      if(jsonData['error']=='0' && jsonData['prediction']!=null){   // check data returned by api 
        setState(() {
          _predictedEmotion = jsonData['prediction'];
          print(" Successful: emotion prediction");
        });
      }else{
        print(" Failed: emotion prediction");
      }
    }else{
      print(" Failed: post request");
    }
  }
}