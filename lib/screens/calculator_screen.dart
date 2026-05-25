import 'package:flutter/material.dart';
import 'login_screen.dart';

// This screen looks exactly like a calculator.
// Entering the secret code "1337." navigates to the real vault login.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({Key? key}) : super(key: key);

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const String _secretCode = '1337.';

  String _display = '0';
  String _input = '';
  String _expression = '';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;

  void _onButtonPressed(String value) {
    // Check for secret code
    _input += value;
    if (_input.endsWith(_secretCode)) {
      _input = '';
      _navigateToVault();
      return;
    }
    // Trim input to avoid memory issues
    if (_input.length > 20) _input = _input.substring(_input.length - 20);

    if (value == 'C') {
      _clear();
    } else if (value == '⌫') {
      _backspace();
    } else if (['+', '-', '×', '÷'].contains(value)) {
      _setOperator(value);
    } else if (value == '=') {
      _calculate();
    } else if (value == '%') {
      _percentage();
    } else if (value == '+/-') {
      _toggleSign();
    } else {
      _appendNumber(value);
    }
  }

  void _navigateToVault() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void _clear() {
    setState(() {
      _display = '0';
      _expression = '';
      _input = '';
      _firstOperand = null;
      _operator = null;
      _shouldResetDisplay = false;
    });
  }

  void _backspace() {
    setState(() {
      if (_display.length > 1) {
        _display = _display.substring(0, _display.length - 1);
      } else {
        _display = '0';
      }
    });
  }

  void _appendNumber(String value) {
    setState(() {
      if (_shouldResetDisplay) {
        _display = value == '.' ? '0.' : value;
        _shouldResetDisplay = false;
      } else {
        if (value == '.' && _display.contains('.')) return;
        if (_display == '0' && value != '.') {
          _display = value;
        } else {
          if (_display.length < 12) _display += value;
        }
      }
    });
  }

  void _setOperator(String op) {
    setState(() {
      _firstOperand = double.tryParse(_display);
      _operator = op;
      _expression = '$_display $op';
      _shouldResetDisplay = true;
    });
  }

  void _calculate() {
    if (_firstOperand == null || _operator == null) return;
    final second = double.tryParse(_display) ?? 0;
    double result = 0;
    switch (_operator) {
      case '+': result = _firstOperand! + second; break;
      case '-': result = _firstOperand! - second; break;
      case '×': result = _firstOperand! * second; break;
      case '÷': result = second != 0 ? _firstOperand! / second : 0; break;
    }
    setState(() {
      _expression = '';
      _display = _formatResult(result);
      _firstOperand = null;
      _operator = null;
      _shouldResetDisplay = true;
    });
  }

  void _percentage() {
    final value = double.tryParse(_display) ?? 0;
    setState(() => _display = _formatResult(value / 100));
  }

  void _toggleSign() {
    final value = double.tryParse(_display) ?? 0;
    setState(() => _display = _formatResult(value * -1));
  }

  String _formatResult(double value) {
    if (value == value.truncate()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Display
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                alignment: Alignment.bottomRight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_expression.isNotEmpty)
                      Text(
                        _expression,
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 20),
                      ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _display,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildRow(['C', '+/-', '%', '÷'],
                        [_grayBtn, _grayBtn, _grayBtn, _orangeBtn]),
                    _buildRow(['7', '8', '9', '×'],
                        [_darkBtn, _darkBtn, _darkBtn, _orangeBtn]),
                    _buildRow(['4', '5', '6', '-'],
                        [_darkBtn, _darkBtn, _darkBtn, _orangeBtn]),
                    _buildRow(['1', '2', '3', '+'],
                        [_darkBtn, _darkBtn, _darkBtn, _orangeBtn]),
                    _buildLastRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> labels, List<_BtnStyle> styles) {
    return Expanded(
      child: Row(
        children: List.generate(labels.length, (i) {
          return _calcButton(labels[i], styles[i]);
        }),
      ),
    );
  }

  Widget _buildLastRow() {
    return Expanded(
      child: Row(
        children: [
          _calcButton('0', _darkBtn, wide: true),
          _calcButton('.', _darkBtn),
          _calcButton('=', _orangeBtn),
        ],
      ),
    );
  }

  Widget _calcButton(String label, _BtnStyle style,
      {bool wide = false}) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: GestureDetector(
          onTap: () => _onButtonPressed(label),
          child: Container(
            decoration: BoxDecoration(
              color: style.color,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: style.textColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _grayBtn = _BtnStyle(
      color: Color(0xFFA5A5A5), textColor: Colors.black);
  static const _darkBtn = _BtnStyle(
      color: Color(0xFF333333), textColor: Colors.white);
  static const _orangeBtn = _BtnStyle(
      color: Color(0xFFFF9500), textColor: Colors.white);
}

class _BtnStyle {
  final Color color;
  final Color textColor;
  const _BtnStyle({required this.color, required this.textColor});
}
