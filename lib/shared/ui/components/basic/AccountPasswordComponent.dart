import 'package:flutter/material.dart';

class AccountPasswordComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  // 新增顯示選項參數
  final List<String> displayOptions;

  const AccountPasswordComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    // 預設顯示所有選項
    this.displayOptions = const ['User', 'Password', 'Confirm Password'],
  }) : super(key: key);

  @override
  State<AccountPasswordComponent> createState() => _AccountPasswordComponentState();
}

class _AccountPasswordComponentState extends State<AccountPasswordComponent> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // 錯誤狀態
  bool _isPasswordError = false;
  bool _isConfirmPasswordError = false;

  @override
  void initState() {
    super.initState();
    _userController.addListener(_notifyFormChanged);
    _passwordController.addListener(() {
      _validatePassword();
      _notifyFormChanged();
    });
    _confirmPasswordController.addListener(() {
      _validateConfirmPassword();
      _notifyFormChanged();
    });
  }

  @override
  void dispose() {
    _userController.removeListener(_notifyFormChanged);
    _passwordController.removeListener(_notifyFormChanged);
    _confirmPasswordController.removeListener(_notifyFormChanged);
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 驗證密碼是否符合規則
  void _validatePassword() {
    final password = _passwordController.text;

    // 檢查長度和字元
    final bool isValid = password.isNotEmpty &&
        password.length >= 8 &&
        password.length <= 32 &&
        _isPasswordCharactersValid(password);

    setState(() {
      _isPasswordError = password.isNotEmpty && !isValid;
    });

    // 如果確認密碼已經輸入，則重新驗證確認密碼
    if (_confirmPasswordController.text.isNotEmpty) {
      _validateConfirmPassword();
    }
  }

  // 檢查密碼字元是否合法
  bool _isPasswordCharactersValid(String password) {
    final RegExp validChars = RegExp(
        r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$');
    return validChars.hasMatch(password);
  }

  // 驗證確認密碼是否與密碼相符
  void _validateConfirmPassword() {
    final confirmPassword = _confirmPasswordController.text;
    final password = _passwordController.text;

    setState(() {
      _isConfirmPasswordError =
          confirmPassword.isNotEmpty && confirmPassword != password;
    });
  }

  void _notifyFormChanged() {
    if (widget.onFormChanged != null) {
      widget.onFormChanged!(
        _userController.text,
        _passwordController.text,
        _confirmPasswordController.text,
        _validateForm(),
      );
    }
  }

  // 根據顯示選項驗證表單
  bool _validateForm() {
    if (widget.displayOptions.contains('User') &&
        _userController.text.isEmpty) {
      return false;
    }

    if (widget.displayOptions.contains('Password')) {
      // 密碼非空且符合要求才算有效
      final password = _passwordController.text;
      if (password.isEmpty ||
          password.length < 8 ||
          password.length > 32 ||
          !_isPasswordCharactersValid(password)) {
        return false;
      }
    }

    if (widget.displayOptions.contains('Confirm Password')) {
      // 確認密碼非空且與密碼一致才算有效
      final confirmPassword = _confirmPasswordController.text;
      if (confirmPassword.isEmpty ||
          confirmPassword != _passwordController.text) {
        return false;
      }
    }

    return true;
  }

  @override
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery
        .of(context)
        .size;

    // 根據顯示選項計算適當的容器高度
    double containerHeight = screenSize.height * 0.25; // 基本高度

    // 每個表單項目增加高度
    if (widget.displayOptions.contains('User')) {
      containerHeight += screenSize.height * 0.09;
    }
    if (widget.displayOptions.contains('Password')) {
      containerHeight += screenSize.height * 0.09;
    }
    if (widget.displayOptions.contains('Confirm Password')) {
      containerHeight += screenSize.height * 0.09;
    }

    return Container(
      width: screenSize.width * 0.9,
      height: containerHeight,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 動態顯示 User 輸入框
            if (widget.displayOptions.contains('User')) ...[
              const Text(
                'User',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: screenSize.width * 0.9,
                child: TextFormField(
                  controller: _userController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                    errorStyle: const TextStyle(fontSize: 12),
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // 動態顯示 Password 輸入框
            if (widget.displayOptions.contains('Password')) ...[
              // 標籤顏色根據錯誤狀態變化
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
                width: screenSize.width * 0.9,
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: _isPasswordError ? Colors.red : Colors.grey
                            .shade400,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: _isPasswordError ? Colors.red : Colors.grey
                            .shade400,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons
                            .visibility_off,
                        // 圖標顏色根據錯誤狀態變化
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
              const SizedBox(height: 4),
              Text(
                'Your password must be at least 8 characters',
                style: TextStyle(
                  fontSize: 12,
                  color: _isPasswordError ? Colors.red : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 動態顯示 Confirm Password 輸入框
            if (widget.displayOptions.contains('Confirm Password')) ...[
              // 標籤顏色根據錯誤狀態變化
              Text(
                'Confirm Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: _isConfirmPasswordError ? Colors.red : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: screenSize.width * 0.9,
                child: TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_confirmPasswordVisible,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Color(0xFFEFEFEF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: _isConfirmPasswordError ? Colors.red : Colors
                            .grey.shade400,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide(
                        color: _isConfirmPasswordError ? Colors.red : Colors
                            .grey.shade400,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible ? Icons.visibility : Icons
                            .visibility_off,
                        // 圖標顏色根據錯誤狀態變化
                        color: _isConfirmPasswordError ? Colors.red : Colors
                            .grey,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _confirmPasswordVisible = !_confirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: _isConfirmPasswordError ? Colors.red : Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your password must be at least 8 characters',
                style: TextStyle(
                  fontSize: 12,
                  color: _isConfirmPasswordError ? Colors.red : Colors.black,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}