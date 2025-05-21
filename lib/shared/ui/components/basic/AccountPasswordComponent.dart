import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

class AccountPasswordComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  // 新增顯示選項參數
  final List<String> displayOptions;
  // 新增固定的用戶名參數
  final String fixedUsername;
  // 新增是否禁用用戶名輸入的參數
  final bool disableUsername;

  const AccountPasswordComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    // 預設顯示所有選項
    this.displayOptions = const ['User', 'Password', 'Confirm Password'],
    // 預設用戶名為空
    this.fixedUsername = 'admin',
    // 預設不禁用用戶名輸入
    this.disableUsername = true,
  }) : super(key: key);

  @override
  State<AccountPasswordComponent> createState() => _AccountPasswordComponentState();
}

class _AccountPasswordComponentState extends State<AccountPasswordComponent> {
  // 添加 AppTheme 實例
  final AppTheme _appTheme = AppTheme();

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

    // 如果有固定用戶名，則設置到控制器中
    if (widget.fixedUsername.isNotEmpty) {
      _userController.text = widget.fixedUsername;
    }

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

  /// 檢查密碼字元是否合法
  ///
  /// 密碼必須滿足:
  /// 1. 只包含合法字元 (ASCII 可視字元，除了空格和雙引號)
  /// 2. 至少包含一個大寫字母
  /// 3. 至少包含一個小寫字母
  /// 4. 至少包含一個數字
  /// 5. 至少包含一個特殊字元
  bool _isPasswordCharactersValid(String password) {
    // 檢查是否只包含合法字元
    final RegExp validChars = RegExp(
        r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
    );

    // 檢查是否至少包含一個大寫字母
    final RegExp hasUppercase = RegExp(r'[A-Z]');

    // 檢查是否至少包含一個小寫字母
    final RegExp hasLowercase = RegExp(r'[a-z]');

    // 檢查是否至少包含一個數字
    final RegExp hasDigit = RegExp(r'[0-9]');

    // 檢查是否至少包含一個特殊字元
    final RegExp hasSpecialChar = RegExp(r'[\x21\x23-\x2F\x3A-\x3B\x3D\x3F-\x40\x5B\x5D-\x60\x7B-\x7E]');

    // 所有條件都必須滿足
    return validChars.hasMatch(password) &&
        hasUppercase.hasMatch(password) &&
        hasLowercase.hasMatch(password) &&
        hasDigit.hasMatch(password) &&
        hasSpecialChar.hasMatch(password);
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

  // 創建自定義密碼輸入框
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isError,
    required bool isVisible,
    required Function(bool) onVisibilityChanged,
    String hintText = '',
  }) {
    final screenSize = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: isError ? Color(0xFFFF00E5) : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: screenSize.width * 0.9,
          height: AppDimensions.inputHeight,
          child: Stack(
            children: [
              // 使用模糊背景輸入框，但根據錯誤狀態設置不同的邊框顏色
              CustomTextField(
                width: screenSize.width * 0.9,
                controller: controller,
                obscureText: !isVisible,
                borderColor: isError ? Color(0xFFFF00E5) : AppColors.primary,
                borderOpacity: 0.7,
                backgroundColor: Colors.black,
                backgroundOpacity: 0.4,
                hintText: hintText,
              ),

              // 添加密碼可見性切換按鈕
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: isError ? Color(0xFFFF00E5) : Colors.white,
                      size: 25,
                    ),
                    onPressed: () {
                      onVisibilityChanged(!isVisible);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your password must be at least 8 characters',
          style: TextStyle(
            fontSize: 12,
            color: isError ? Color(0xFFFF00E5) : Colors.white,
          ),
        ),
      ],
    );
  }

  // 創建用戶名輸入框
  Widget _buildUserField() {
    final screenSize = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        // 使用模糊背景輸入框
        CustomTextField(
          width: screenSize.width * 0.9,
          controller: _userController,
          enabled: !widget.disableUsername,
          backgroundColor: widget.disableUsername ? Colors.grey.withOpacity(0.3) : Colors.black,
          textStyle: TextStyle(
            color: widget.disableUsername ? Colors.grey[400] : Colors.white,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

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

    // 使用 buildStandardCard 替代原有的容器
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: containerHeight,
      child: Padding(
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
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // 動態顯示 User 輸入框
              if (widget.displayOptions.contains('User'))
                _buildUserField(),

              // 動態顯示 Password 輸入框
              if (widget.displayOptions.contains('Password')) ...[
                _buildPasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  isError: _isPasswordError,
                  isVisible: _passwordVisible,
                  onVisibilityChanged: (visible) {
                    setState(() {
                      _passwordVisible = visible;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],

              // 動態顯示 Confirm Password 輸入框
              if (widget.displayOptions.contains('Confirm Password'))
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  isError: _isConfirmPasswordError,
                  isVisible: _confirmPasswordVisible,
                  onVisibilityChanged: (visible) {
                    setState(() {
                      _confirmPasswordVisible = visible;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}