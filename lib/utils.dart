part of 'ar.dart';

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

Widget _createTempBackButton(VoidCallback onPressed) {
  return Positioned(
      top: Platform.isAndroid ? 31.0 : 28.0,
      left: 8.0,
      child: Container(
        width: 42.0, // Tamaño del botón
        height: 42.0,
        decoration: BoxDecoration(
          color: Colors.grey, // Color de fondo
          borderRadius: BorderRadius.circular(10.0), // Bordes redondeados
          border: Border.all(
            color: Colors.white, // Color del borde
            width: 3.0, // Grosor del borde
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: const Center(
            child: Icon(
              Icons.arrow_back,
              color: Colors.white, // Color del icono
            ),
          ),
        ),
      ));
}

class _AmbienceSelector extends StatefulWidget {
  final Function(int ambience) onAmbienceSelected;
  final Function(bool enjoyEnabled) onEnjoyToggle;

  const _AmbienceSelector({
    super.key,
    required this.onAmbienceSelected,
    required this.onEnjoyToggle,
  });

  @override
  _AmbienceSelectorState createState() => _AmbienceSelectorState();
}

class _AmbienceSelectorState extends State<_AmbienceSelector> {
  int _selectedOption = 0;
  final List<bool> _enjoySelected = [false];

  static const ambiences = {
    0: 'No ambience',
    1: 'Desert',
    2: 'Oasis',
    3: 'City',
    4: 'Sea'
  };

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<int>(
              onSelected: (int value) {
                setState(() {
                  _selectedOption = value;
                  widget.onAmbienceSelected.call(value);
                  if (value == 0) {
                    _enjoySelected[0] = false;
                    widget.onEnjoyToggle(false);
                  }
                });
              },
              itemBuilder: (BuildContext context) => [
                ...ambiences.entries.map(
                  (e) => PopupMenuItem<int>(
                    value: e.key,
                    child: Text(e.value.toUpperCase()),
                  ),
                ),
              ],
              child: ElevatedButton(
                onPressed: null,
                style: ButtonStyle(
                  fixedSize: MaterialStateProperty.all<Size>(
                    const Size.fromHeight(55.0),
                  ),
                  foregroundColor: MaterialStateProperty.all<Color>(
                    Colors.white,
                  ),
                  backgroundColor: MaterialStateProperty.all<Color>(
                    Colors.grey.withOpacity(0.80),
                  ),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(10.0),
                          topRight: const Radius.circular(10.0),
                          bottomLeft: const Radius.circular(10.0),
                          bottomRight:
                              Radius.circular(_selectedOption != 0 ? 0 : 10)),
                    ),
                  ),
                  side: MaterialStateProperty.all<BorderSide>(
                    const BorderSide(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(ambiences[_selectedOption]!.toUpperCase()),
              ),
            ),
            Visibility(
              visible: _selectedOption != 0,
              child: SizedBox(
                height: 34,
                child: ToggleButtons(
                  onPressed: (int index) {
                    setState(() {
                      if (_selectedOption != 0) {
                        _enjoySelected[index] = !_enjoySelected[index];
                        widget.onEnjoyToggle(_enjoySelected[index]);
                      }
                    });
                  },
                  borderWidth: 2,
                  color: Colors.white,
                  fillColor: Colors.green[400],
                  selectedColor: Colors.white,
                  borderColor: Colors.white,
                  selectedBorderColor: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                  ),
                  isSelected: _enjoySelected,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
                      child: Text("Enjoy".toUpperCase()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
