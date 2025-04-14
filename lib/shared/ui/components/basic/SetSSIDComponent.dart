import 'package:flutter/material.dart';

class SetSSIDComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;

  const SetSSIDComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  State<SetSSIDComponent> createState() => _SetSSIDComponentState();
}

class _SetSSIDComponentState extends State<SetSSIDComponent> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedSecurityOption = 'WPA3 Personal';
  bool _passwordVisible = false;
  bool _showPasswordField = true;

  final List<String> _securityOptions = [
    'no authentication',
    'Enhanced Open (OWE)',
    'WPA2 Personal',
    'WPA3 Personal',
    'WPA2/WPA3 Personal',
    'WPA2 Enterprise'
  ];

  @override
  void initState() {
    super.initState();
    _ssidController.addListener(_notifyFormChanged);
    _passwordController.addListener(_notifyFormChanged);

    // 使用 addPostFrameCallback 避免在 build 期間調用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePasswordVisibility();
      _notifyFormChanged();
    });
  }

  @override
  void dispose() {
    _ssidController.removeListener(_notifyFormChanged);
    _passwordController.removeListener(_notifyFormChanged);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updatePasswordVisibility() {
    setState(() {
      // 根據安全選項決定是否顯示密碼輸入框
      _showPasswordField = !(_selectedSecurityOption == 'no authentication' ||
          _selectedSecurityOption == 'Enhanced Open (OWE)');
    });
  }

  void _notifyFormChanged() {
    if (widget.onFormChanged != null) {
      bool isValid = _validateForm();
      widget.onFormChanged!(
        _ssidController.text,
        _selectedSecurityOption,
        _passwordController.text,
        isValid,
      );
    }
  }

  bool _validateForm() {
    if (_ssidController.text.isEmpty) {
      return false;
    }

    if (_showPasswordField && _passwordController.text.isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      width: screenSize.width * 0.9,
      height: screenSize.height * 0.60,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.only(top: 30.0, left: 25.0, right: 25.0, bottom: 25.0),
      alignment: Alignment.topLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text(
              'Set SSID',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'SSID',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: screenSize.width * 0.9,
              child: TextFormField(
                controller: _ssidController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Security Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: screenSize.width * 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  value: _selectedSecurityOption,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  iconSize: 24,
                  elevation: 16,
                  dropdownColor: Colors.white,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSecurityOption = newValue;
                      });
                      _updatePasswordVisibility();
                      _notifyFormChanged();
                    }
                  },
                  items: _securityOptions.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (_showPasswordField) ...[
              const SizedBox(height: 30),
              const Text(
                'Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: screenSize.width * 0.9,
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}