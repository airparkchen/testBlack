import 'package:flutter/material.dart';

class SetSSIDComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  // Display options parameter
  final List<String> displayOptions;

  // 在 SetSSIDComponent 類中添加
  final String? initialSsid;
  final String? initialSecurityOption;
  final String? initialPassword;

  const SetSSIDComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    this.displayOptions = const ['no authentication', 'Enhanced Open (OWE)', 'WPA2 Personal', 'WPA3 Personal', 'WPA2/WPA3 Personal', 'WPA2 Enterprise'],
    this.initialSsid,
    this.initialSecurityOption,
    this.initialPassword,
  }) : super(key: key);

  @override
  State<SetSSIDComponent> createState() => _SetSSIDComponentState();
}

class _SetSSIDComponentState extends State<SetSSIDComponent> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _selectedSecurityOption = ''; // Initial empty value, will be set to first option
  bool _passwordVisible = false;
  bool _showPasswordField = true;

  // Error state flags
  bool _isSsidError = false;
  bool _isPasswordError = false;

  // Error message texts
  String _ssidErrorText = '';
  String _passwordErrorText = '';

  // 在 _SetSSIDComponentState 類的 initState 方法中
  @override
  void initState() {
    super.initState();

    // 先設置安全選項，因為它會影響密碼欄位的顯示
    if (widget.initialSecurityOption != null &&
        widget.initialSecurityOption!.isNotEmpty &&
        widget.displayOptions.contains(widget.initialSecurityOption)) {
      _selectedSecurityOption = widget.initialSecurityOption!;
    } else if (widget.displayOptions.isNotEmpty) {
      _selectedSecurityOption = widget.displayOptions.first;
    }

    // 更新密碼欄位可見性
    _updatePasswordVisibility();

    // 初始化SSID
    if (widget.initialSsid != null && widget.initialSsid!.isNotEmpty) {
      _ssidController.text = widget.initialSsid!;
    }

    // 初始化密碼（確保只在需要密碼的安全類型上設置）
    if (_showPasswordField && widget.initialPassword != null && widget.initialPassword!.isNotEmpty) {
      print('正在設置初始密碼，長度: ${widget.initialPassword!.length}');
      _passwordController.text = widget.initialPassword!;
    }

    // 添加監聽器
    _ssidController.addListener(() {
      _validateSsid();
      _notifyFormChanged();
    });

    _passwordController.addListener(() {
      _validatePassword();
      _notifyFormChanged();
    });

    // 使用 addPostFrameCallback 確保UI已經構建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 再次確認密碼是否正確設置
      if (_showPasswordField && widget.initialPassword != null && widget.initialPassword!.isNotEmpty &&
          _passwordController.text != widget.initialPassword) {
        print('重新設置密碼，確保顯示正確');
        setState(() {
          _passwordController.text = widget.initialPassword!;
        });
      }

      // 驗證初始表單狀態
      _validateForm();
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
      // Determine whether to show password field based on security option
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

  // Validate SSID
  void _validateSsid() {
    final ssid = _ssidController.text;

    setState(() {
      if (ssid.isEmpty) {
        _isSsidError = true;
        _ssidErrorText = 'Please enter an SSID';
      } else if (ssid.length > 64) {
        _isSsidError = true;
        _ssidErrorText = 'SSID must be 64 characters or less';
      } else if (!_isValidCharacters(ssid)) {
        _isSsidError = true;
        _ssidErrorText = 'SSID contains invalid characters';
      } else {
        _isSsidError = false;
        _ssidErrorText = '';
      }
    });
  }

  // Validate Password
  void _validatePassword() {
    final password = _passwordController.text;

    if (!_showPasswordField) {
      setState(() {
        _isPasswordError = false;
        _passwordErrorText = '';
      });
      return;
    }

    setState(() {
      if (password.isEmpty) {
        _isPasswordError = true;
        _passwordErrorText = 'Please enter a password';
      } else if (password.length < 8) {
        _isPasswordError = true;
        _passwordErrorText = 'Password must be at least 8 characters';
      } else if (password.length > 64) {
        _isPasswordError = true;
        _passwordErrorText = 'Password must be 64 characters or less';
      } else if (!_isValidCharacters(password)) {
        _isPasswordError = true;
        _passwordErrorText = 'Password contains invalid characters';
      } else {
        _isPasswordError = false;
        _passwordErrorText = '';
      }
    });
  }

  // Check if characters are valid
  bool _isValidCharacters(String text) {
    final validChars = RegExp(
        r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
    );
    return validChars.hasMatch(text);
  }

  bool _validateForm() {
    if (_isSsidError || _ssidController.text.isEmpty) {
      return false;
    }

    if (_showPasswordField && (_isPasswordError || _passwordController.text.isEmpty)) {
      return false;
    }

    return true;
  }

  // Get error message for display in warning panel
  String? _getErrorMessage() {
    if (_ssidController.text.isEmpty) {
      return 'Please enter an SSID';
    } else if (_isSsidError) {
      return _ssidErrorText;
    }

    if (_showPasswordField) {
      if (_passwordController.text.isEmpty) {
        return 'Please enter a password';
      } else if (_isPasswordError) {
        return _passwordErrorText;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final String? errorMessage = _getErrorMessage();

    return Container(
      width: screenSize.width * 0.9,
      // 不設置固定高度，使用 SingleChildScrollView 處理超出部分
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Set SSID',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'SSID',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: _isSsidError ? Colors.red : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextFormField(
              controller: _ssidController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEFEFEF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide(
                    color: _isSsidError ? Colors.red : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide(
                    color: _isSsidError ? Colors.red : Colors.grey.shade400,
                  ),
                ),
              ),
              style: TextStyle(
                fontSize: 16,
                color: _isSsidError ? Colors.red : Colors.black,
              ),
            ),
          ),
          if (_isSsidError)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                _ssidErrorText,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
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
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(2),
              ),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFEFEFEF),
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
                dropdownColor: const Color(0xFFEFEFEF),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedSecurityOption = newValue;
                    });
                    _updatePasswordVisibility();
                    if (_showPasswordField) {
                      _validatePassword();
                    }
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
            Text(
              'Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
                color: _isPasswordError ? Colors.red : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(
                      color: _isPasswordError ? Colors.red : Colors.grey.shade400,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(
                      color: _isPasswordError ? Colors.red : Colors.grey.shade400,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility : Icons.visibility_off,
                      color: _isPasswordError ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _passwordVisible = !_passwordVisible;
                      });
                    },
                  ),
                ),
                style: TextStyle(
                  fontSize: 16,
                  color: _isPasswordError ? Colors.red : Colors.black,
                ),
              ),
            ),
            if (_isPasswordError)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _passwordErrorText,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
          ],

          // Display form error message if validation fails
          if (errorMessage != null && !_validateForm()) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Colors.red[50],
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}