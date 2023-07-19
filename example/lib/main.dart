import 'package:flutter/material.dart';
import 'package:app_version_checker/app_version_checker.dart';

final newVersion = AppVersionChecker(
  iOSId: 'com.google.Vespa',
  androidId: 'com.google.android.apps.cloudconsole',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final status = await newVersion.getVersionStatus();
  if (status != null) {
    debugPrint(status.releaseNotes);
    debugPrint(status.appStoreLink);
    debugPrint(status.localVersion.toVersionString());
    debugPrint(status.storeVersion.toVersionString());
    debugPrint(status.canUpdate.toString());
  }

  runApp(MyApp(status: status));
}

class MyApp extends StatelessWidget {
  final AppVersions? status;
  const MyApp({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => InitStateWrapper(
          onInitState: () {
            final status = this.status;
            if (status != null && status.canUpdate == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'There is an update available',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
                          ),
                          SizedBox(height: 10),
                          MaterialButton(
                            color: Colors.blue,
                            onPressed: () => newVersion.launchAppStore(status.appStoreLink),
                            child: Text('Update Now', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              });
            }
          },
          child: MyHomePage(),
        ),
      ),
    );
  }
}

// HOME

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Example App"),
      ),
      body: Center(
        child: Text('Hello World'),
      ),
    );
  }
}

// UTILS

class InitStateWrapper extends StatefulWidget {
  final Function() onInitState;
  final Widget child;
  const InitStateWrapper({Key? key, required this.onInitState, required this.child}) : super(key: key);

  @override
  State<InitStateWrapper> createState() => _InitStateWrapperState();
}

class _InitStateWrapperState extends State<InitStateWrapper> {
  @override
  void initState() {
    super.initState();
    widget.onInitState();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
