import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

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
  final AppTheme _appTheme = AppTheme();
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

    // 使用 buildStandardCard 替代原始的 Container
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: _showPasswordField
          ? screenSize.height * 0.5  // 顯示密碼欄位時，增加高度
          : screenSize.height * 0.35, // 基本高度
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Set SSID',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // SSID 輸入欄位
              _buildLabelAndField(
                label: 'SSID',
                isError: _isSsidError,
                child: _buildTextField(
                  controller: _ssidController,
                  isError: _isSsidError,
                ),
                errorText: _isSsidError ? _ssidErrorText : null,
              ),

              const SizedBox(height: 20),

              // 安全選項下拉選單
              _buildLabelAndField(
                label: 'Security Option',
                isError: false,
                child: _buildSecurityOptionDropdown(),
              ),

              // 如果需要顯示密碼欄位
              if (_showPasswordField) ...[
                const SizedBox(height: 20),

                // 密碼輸入欄位
                _buildLabelAndField(
                  label: 'Password',
                  isError: _isPasswordError,
                  child: _buildPasswordField(
                    controller: _passwordController,
                    isVisible: _passwordVisible,
                    isError: _isPasswordError,
                  ),
                  errorText: _isPasswordError ? _passwordErrorText : null,
                ),
              ],

              // 顯示表單錯誤訊息
              if (errorMessage != null && !_validateForm()) ...[
                const SizedBox(height: 20),
                _buildErrorContainer(errorMessage),
              ],
            ],
          ),
        ),
      ),
    );
  }

// ========== 以下為輔助方法 ==========

// 構建標籤和輸入字段
  Widget _buildLabelAndField({
    required String label,
    required bool isError,
    required Widget child,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.normal,
            color: isError ? const Color(0xFFFF00E5) : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        child,
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Color(0xFFFF00E5),
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

// 構建基本文本輸入框
  Widget _buildTextField({
    required TextEditingController controller,
    required bool isError,
    bool obscureText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.black.withOpacity(0.4),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(
              color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(
              color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(
              color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
            ),
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          color: isError ? const Color(0xFFFF00E5) : Colors.white,
        ),
      ),
    );
  }

// 構建密碼輸入框
  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool isVisible,
    required bool isError,
  }) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            obscureText: !isVisible,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(
                  color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(
                  color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(2),
                borderSide: BorderSide(
                  color: isError ? const Color(0xFFFF00E5) : AppColors.primary.withOpacity(0.7),
                ),
              ),
            ),
            style: TextStyle(
              fontSize: 16,
              color: isError ? const Color(0xFFFF00E5) : Colors.white,
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: isError ? const Color(0xFFFF00E5) : Colors.white,
                  size: 25,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// 構建安全選項下拉選單
  Widget _buildSecurityOptionDropdown() {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.4),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(2),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.7),
              ),
            ),
          ),
          style: const TextStyle(fontSize: 16, color: Colors.white),
          value: _selectedSecurityOption,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          iconSize: 24,
          elevation: 16,
          dropdownColor: Colors.black.withOpacity(0.8),
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
    );
  }

// 構建錯誤容器
  Widget _buildErrorContainer(String errorText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: const Color(0xFFFF00E5).withOpacity(0.1),
      child: Text(
        errorText,
        style: const TextStyle(
          color: Color(0xFFFF00E5),
          fontSize: 14,
        ),
      ),
    );
  }
}