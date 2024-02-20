part of 'ar.dart';

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

Widget _createDebugModeSwitchButton(VoidCallback onPressed) {
  return Align(
    alignment: Alignment.bottomLeft,
    child: SizedBox(
      height: 32,
      width: 32,
      child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black54,
          child: const Icon(Icons.camera_outlined)),
    ),
  );
}

class _AmbienceSelector extends StatefulWidget {
  final bool debugMode;

  const _AmbienceSelector({
    super.key,
    required this.debugMode,
  });

  @override
  _AmbienceSelectorState createState() => _AmbienceSelectorState();
}

class _AmbienceSelectorState extends State<_AmbienceSelector> {
  final List<bool> _enjoySelected = [false];
  ARController arController = ARController();

  static const _ambiences3DNames = {
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
            Visibility(
              visible: widget.debugMode,
              child: PopupMenuButton<int>(
                onSelected: (int value) {
                  setState(() {
                    arController._selectAmbience(value);
                    if (value == 0) {
                      _enjoySelected[0] = false;
                      arController._setEnjoyMode(false);
                    }
                  });
                },
                itemBuilder: (BuildContext context) => [
                  ..._ambiences3DNames.entries.map(
                    (e) => PopupMenuItem<int>(
                      value: e.key,
                      child: Text(e.value.toUpperCase()),
                    ),
                  ),
                ],
                child: ValueListenableBuilder<int>(
                  valueListenable: arController._current3DAmbience,
                  builder: (context, ambienceCode, child) {
                    return ElevatedButton(
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
                        shape:
                            MaterialStateProperty.all<RoundedRectangleBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(10.0),
                                topRight: const Radius.circular(10.0),
                                bottomLeft: const Radius.circular(10.0),
                                bottomRight: Radius.circular(
                                    ambienceCode != 0 ? 0 : 10)),
                          ),
                        ),
                        side: MaterialStateProperty.all<BorderSide>(
                          const BorderSide(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                      child:
                          Text(_ambiences3DNames[ambienceCode]!.toUpperCase()),
                    );
                  },
                ),
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: arController._current3DAmbience,
              builder: (context, ambienceCode, child) {
                return Visibility(
                  visible: ambienceCode != 0,
                  child: SizedBox(
                    height: 34,
                    child: ToggleButtons(
                      onPressed: (int index) {
                        setState(() {
                          if (ambienceCode != 0) {
                            _enjoySelected[index] = !_enjoySelected[index];
                            arController._setEnjoyMode(_enjoySelected[index]);
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _showToast(BuildContext context, String message) {
  final scaffold = ScaffoldMessenger.of(context);
  scaffold.showSnackBar(
    SnackBar(
      content: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 27, 50, 120),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: const Icon(Icons.view_in_ar, color: Colors.white),
          title: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
      duration: const Duration(seconds: 3),
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
}
