part of 'ar.dart';

Widget _createTempBackButton(VoidCallback onPressed) {
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

void _showToast(BuildContext context, String message, Duration duration) {
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
      duration: duration,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
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
