import 'package:flutter/material.dart';

class PolygonForm extends StatelessWidget {
  final List<TextEditingController> xControllers;
  final List<TextEditingController> yControllers;

  const PolygonForm({
    super.key,
    required this.xControllers,
    required this.yControllers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: List.generate(4, (i) => _buildPointRow(i)));
  }

  Widget _buildPointRow(int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '頂点 ${index + 1}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _coordinateField(xControllers[index], 'X (m)')),
          const SizedBox(width: 8),
          Expanded(child: _coordinateField(yControllers[index], 'Y (m)')),
        ],
      ),
    );
  }

  Widget _coordinateField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
    );
  }
}
