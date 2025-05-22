import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

class AccountPasswordComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  final List<String> displayOptions;
  final String fixedUsername;
  final bool disableUsername;
  final double? height; // 新增高度參數

  const AccountPasswordComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    this.displayOptions = const ['User', 'Password', 'Confirm Password'],
    this.fixedUsername = 'admin',
    this.disableUsername = true,
    this.height, // 高度參數可選
  }) : super(key: key);

  @override
  State<AccountPasswordComponent> createState() => _AccountPasswordComponentState();
}

class _AccountPasswordComponentState extends State<AccountPasswordComponent> {
  final AppTheme _appTheme = AppTheme();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 焦點節點
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isPasswordError = false;
  bool _isConfirmPasswordError = false;

  @override
  void initState() {
    super.initState();

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

    // 添加焦點監聽
    _passwordFocusNode.addListener(_handlePasswordFocus);
    _confirmPasswordFocusNode.addListener(_handleConfirmPasswordFocus);
  }

  @override
  void dispose() {
    _passwordFocusNode.removeListener(_handlePasswordFocus);
    _confirmPasswordFocusNode.removeListener(_handleConfirmPasswordFocus);
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _scrollController.dispose();
    _userController.removeListener(_notifyFormChanged);
    _passwordController.removeListener(_notifyFormChanged);
    _confirmPasswordController.removeListener(_notifyFormChanged);
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 處理密碼輸入框獲得焦點
  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus) {
      // 延遲執行，確保鍵盤已完全彈出
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // 滾動到合適的位置，這個值需要根據您的UI調整
          _scrollController.animateTo(
            widget.displayOptions.contains('User') ? 80.0 : 0.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // 處理確認密碼輸入框獲得焦點
  void _handleConfirmPasswordFocus() {
    if (_confirmPasswordFocusNode.hasFocus) {
      // 延遲執行，確保鍵盤已完全彈出
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // 滾動到合適的位置，這個值需要根據您的UI調整
          _scrollController.animateTo(
            widget.displayOptions.contains('Password') ? 150.0 : 80.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _validatePassword() {
    // 驗證密碼的代碼保持不變
    final password = _passwordController.text;
    final bool isValid = password.isNotEmpty &&
        password.length >= 8 &&
        password.length <= 32 &&
        _isPasswordCharactersValid(password);

    setState(() {
      _isPasswordError = password.isNotEmpty && !isValid;
    });

    if (_confirmPasswordController.text.isNotEmpty) {
      _validateConfirmPassword();
    }
  }

  bool _isPasswordCharactersValid(String password) {
    // 密碼驗證代碼保持不變
    final RegExp validChars = RegExp(
        r'^[\x21\x23-\x2F\x30-\x39\x3A-\x3B\x3D\x3F-\x40\x41-\x5A\x5B\x5D-\x60\x61-\x7A\x7B-\x7E]+$'
    );
    final RegExp hasUppercase = RegExp(r'[A-Z]');
    final RegExp hasLowercase = RegExp(r'[a-z]');
    final RegExp hasDigit = RegExp(r'[0-9]');
    final RegExp hasSpecialChar = RegExp(r'[\x21\x23-\x2F\x3A-\x3B\x3D\x3F-\x40\x5B\x5D-\x60\x7B-\x7E]');

    return validChars.hasMatch(password) &&
        hasUppercase.hasMatch(password) &&
        hasLowercase.hasMatch(password) &&
        hasDigit.hasMatch(password) &&
        hasSpecialChar.hasMatch(password);
  }

  void _validateConfirmPassword() {
    // 驗證確認密碼的代碼保持不變
    final confirmPassword = _confirmPasswordController.text;
    final password = _passwordController.text;

    setState(() {
      _isConfirmPasswordError =
          confirmPassword.isNotEmpty && confirmPassword != password;
    });
  }

  void _notifyFormChanged() {
    // 通知表單變更的代碼保持不變
    if (widget.onFormChanged != null) {
      widget.onFormChanged!(
        _userController.text,
        _passwordController.text,
        _confirmPasswordController.text,
        _validateForm(),
      );
    }
  }

  bool _validateForm() {
    // 驗證表單的代碼保持不變
    if (widget.displayOptions.contains('User') &&
        _userController.text.isEmpty) {
      return false;
    }

    if (widget.displayOptions.contains('Password')) {
      final password = _passwordController.text;
      if (password.isEmpty ||
          password.length < 8 ||
          password.length > 32 ||
          !_isPasswordCharactersValid(password)) {
        return false;
      }
    }

    if (widget.displayOptions.contains('Confirm Password')) {
      final confirmPassword = _confirmPasswordController.text;
      if (confirmPassword.isEmpty ||
          confirmPassword != _passwordController.text) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 使用傳入的高度參數或默認值
    double cardHeight = widget.height ?? (screenSize.height * 0.5);

    // 鍵盤彈出時調整卡片高度
    if (bottomInset > 0) {
      // 根據鍵盤高度調整卡片高度
      cardHeight = screenSize.height - bottomInset - 190; // 保留上方空間，這個值需要根據您的UI調整
      // 確保最小高度
      cardHeight = cardHeight < 300 ? 300 : cardHeight;
    }

    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: Column(
        children: [
          // 標題區域(固定)
          Container(
            padding: EdgeInsets.fromLTRB(25, bottomInset > 0 ? 15 : 25, 25, bottomInset > 0 ? 5 : 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Set Password',
                style: TextStyle(
                  fontSize: bottomInset > 0 ? 18 : 22, // 鍵盤彈出時縮小字體
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 可滾動的內容區域
          Expanded(
            child: _buildContent(bottomInset),
          ),
        ],
      ),
    );
  }

  // 分離內容構建，專注於可滾動性
  Widget _buildContent(double bottomInset) {
    return Padding(
      padding: EdgeInsets.fromLTRB(25, 10, 25, bottomInset > 0 ? 10 : 25),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // 表單項目
          if (widget.displayOptions.contains('User'))
            _buildUserField(),

          if (widget.displayOptions.contains('Password')) ...[
            _buildPasswordField(
              controller: _passwordController,
              label: 'Password',
              isError: _isPasswordError,
              isVisible: _passwordVisible,
              focusNode: _passwordFocusNode, // 使用專用的焦點節點
              onVisibilityChanged: (visible) {
                setState(() {
                  _passwordVisible = visible;
                });
              },
            ),
            SizedBox(height: bottomInset > 0 ? 10 : 20), // 鍵盤彈出時減少間距
          ],

          if (widget.displayOptions.contains('Confirm Password'))
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              isError: _isConfirmPasswordError,
              isVisible: _confirmPasswordVisible,
              focusNode: _confirmPasswordFocusNode, // 使用專用的焦點節點
              onVisibilityChanged: (visible) {
                setState(() {
                  _confirmPasswordVisible = visible;
                });
              },
            ),

          // 鍵盤彈出時的額外空間
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isError,
    required bool isVisible,
    required Function(bool) onVisibilityChanged,
    FocusNode? focusNode, // 添加焦點節點參數
    String hintText = '',
  }) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bottomInset > 0 ? 16 : 18, // 鍵盤彈出時縮小字體
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
              CustomTextField(
                width: screenSize.width * 0.9,
                controller: controller,
                focusNode: focusNode, // 設置焦點節點
                obscureText: !isVisible,
                borderColor: isError ? Color(0xFFFF00E5) : AppColors.primary,
                borderOpacity: 0.7,
                backgroundColor: Colors.black,
                backgroundOpacity: 0.4,
                hintText: hintText,
              ),
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
            fontSize: bottomInset > 0 ? 10 : 12, // 鍵盤彈出時縮小字體
            color: isError ? Color(0xFFFF00E5) : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildUserField() {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User',
          style: TextStyle(
            fontSize: bottomInset > 0 ? 16 : 18, // 鍵盤彈出時縮小字體
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          width: screenSize.width * 0.9,
          controller: _userController,
          enabled: !widget.disableUsername,
          backgroundColor: widget.disableUsername ? Colors.grey.withOpacity(0.3) : Colors.black,
          textStyle: TextStyle(
            color: widget.disableUsername ? Colors.grey[400] : Colors.white,
          ),
        ),
        SizedBox(height: bottomInset > 0 ? 10 : 24), // 鍵盤彈出時縮小間距
      ],
    );
  }
}