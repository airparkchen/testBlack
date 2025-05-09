import 'package:flutter/material.dart';

class SetSSIDComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  // 新增顯示選項參數
  final List<String> displayOptions;

  const SetSSIDComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    // 預設顯示所有選項
    this.displayOptions = const ['no authentication', 'Enhanced Open (OWE)', 'WPA2 Personal', 'WPA3 Personal', 'WPA2/WPA3 Personal', 'WPA2 Enterprise'],
  }) : super(key: key);

  @override
  State<SetSSIDComponent> createState() => _SetSSIDComponentState();
}

class _SetSSIDComponentState extends State<SetSSIDComponent> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedSecurityOption = ''; // 初始值設為空字串，後面會設定為第一個選項
  bool _passwordVisible = false;
  bool _showPasswordField = true;

  @override
  void initState() {
    super.initState();
    _ssidController.addListener(_notifyFormChanged);
    _passwordController.addListener(_notifyFormChanged);

    // 設定初始安全選項為第一個可用選項
    if (widget.displayOptions.isNotEmpty) {
      _selectedSecurityOption = widget.displayOptions.first;
    } else {
      _selectedSecurityOption = 'WPA3 Personal'; // 如果沒有選項，使用默認值
    }

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
                  fillColor: Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
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
                  color: Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  value: _selectedSecurityOption,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  iconSize: 24,
                  elevation: 16,
                  dropdownColor: Color(0xFFEFEFEF),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedSecurityOption = newValue;
                      });
                      _updatePasswordVisibility();
                      _notifyFormChanged();
                    }
                  },
                  items: widget.displayOptions.map<DropdownMenuItem<String>>((String value) {
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
                    fillColor: Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
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