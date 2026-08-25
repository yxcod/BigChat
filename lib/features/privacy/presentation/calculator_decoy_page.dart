import 'package:flutter/material.dart';

class CalculatorDecoyPage extends StatefulWidget {
  const CalculatorDecoyPage({super.key});

  @override
  State<CalculatorDecoyPage> createState() => _CalculatorDecoyPageState();
}

class _CalculatorDecoyPageState extends State<CalculatorDecoyPage> {
  String _display = '0';
  double? _left;
  String? _operator;
  bool _replace = true;

  void _tap(String value) {
    setState(() {
      if (value == 'C') {
        _display = '0';
        _left = null;
        _operator = null;
        _replace = true;
      } else if ('+-×÷'.contains(value)) {
        _left = double.tryParse(_display) ?? 0;
        _operator = value;
        _replace = true;
      } else if (value == '=') {
        final right = double.tryParse(_display) ?? 0;
        final left = _left ?? 0;
        final result = switch (_operator) {
          '+' => left + right,
          '-' => left - right,
          '×' => left * right,
          '÷' => right == 0 ? double.nan : left / right,
          _ => right,
        };
        _display = result.isNaN
            ? '错误'
            : result == result.roundToDouble()
            ? result.toInt().toString()
            : result.toStringAsFixed(6).replaceFirst(RegExp(r'0+$'), '');
        _replace = true;
      } else {
        if (_replace || _display == '0' || _display == '错误') {
          _display = value == '.' ? '0.' : value;
          _replace = false;
        } else if (value != '.' || !_display.contains('.')) {
          _display += value;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = [
      'C',
      '÷',
      '×',
      '-',
      '7',
      '8',
      '9',
      '+',
      '4',
      '5',
      '6',
      '=',
      '1',
      '2',
      '3',
      '0',
      '.',
    ];
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _display,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: keys.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final key = keys[index];
                  return FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: '+-×÷='.contains(key)
                          ? Colors.orange
                          : const Color(0xFF2B2D31),
                    ),
                    onPressed: () => _tap(key),
                    child: Text(key, style: const TextStyle(fontSize: 25)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
