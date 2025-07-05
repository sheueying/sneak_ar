import 'package:flutter/material.dart';

class DeepARView extends StatelessWidget {
  const DeepARView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'DeepARView minimal test',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
} 