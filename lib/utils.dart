part of situm_flutter_ar;

// TODO: temporal AR screen for Android (WIP).

class _ARWIPScreen extends StatefulWidget {
  final VoidCallback onWidgetCreated;
  final VoidCallback onBackButtonPressed;

  const _ARWIPScreen({
    Key? key,
    required this.onWidgetCreated,
    required this.onBackButtonPressed,
  }) : super(key: key);

  @override
  _ARWIPScreenState createState() => _ARWIPScreenState();
}

class _ARWIPScreenState extends State<_ARWIPScreen> {
  bool widgetCreated = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (!widgetCreated) {
      widgetCreated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onWidgetCreated.call();
      });
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.blue,
          ),
          onPressed: () {
            widget.onBackButtonPressed.call();
          },
        ),
        title: const Text('AR Screen'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera,
              size: 100.0,
              color: Colors.blue,
            ),
            SizedBox(height: 20.0),
            Text(
              'AR for Android coming soon',
              style: TextStyle(fontSize: 18.0),
            ),
          ],
        ),
      ),
    );
  }
}
