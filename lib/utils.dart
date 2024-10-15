part of 'ar.dart';

class ArScreenBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ArScreenBackButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Platform.isAndroid ? 31.0 : 28.0,
      left: 8.0,
      child: Container(
        width: 42.0,
        height: 42.0,
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: Colors.white,
            width: 3.0,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          child: const Center(
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
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

Widget _createButtonsDebugAR(
    VoidCallback onRedrawPressed, VoidCallback onUpdatePressed) {
  return Align(
    alignment: Alignment.bottomRight,
    child: Column(
      mainAxisSize: MainAxisSize.min, // Minimizar la altura del Column
      crossAxisAlignment: CrossAxisAlignment.end, // Alinear al final (derecha)
      children: [
        ElevatedButton(onPressed: onRedrawPressed, child: Text('Redraw World')),
        SizedBox(height: 10), // Espacio entre los botones
        ElevatedButton(onPressed: onUpdatePressed, child: Text('Update Arrow')),
      ],
    ),
  );
}

Widget _createWorldRedrawButton(VoidCallback onPressed) {
  return Align(
    alignment: Alignment.bottomRight,
    child: SizedBox(
      child: ElevatedButton(onPressed: onPressed, child: Text('Redraw World')),
    ),
  );
}

Widget _createUpdateArrowTargetButton(VoidCallback onPressed) {
  return Align(
    alignment: Alignment.bottomCenter,
    child: SizedBox(
      child: ElevatedButton(onPressed: onPressed, child: Text('Update Arrow')),
    ),
  );
}

class ARLoadingWidget extends StatelessWidget {
  const ARLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(8, 120, 8, 8),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: Colors.white,
          width: 3.0,
        ),
      ),
      child: const ListTile(
        leading: Icon(Icons.view_in_ar, color: Colors.white),
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1,
            color: Colors.white,
          ),
        ),
        title: Text(
          "AR Loading",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
