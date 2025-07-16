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
  final double? height; // 新增高度參數

  const SetSSIDComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
    this.displayOptions = const ['no authentication', 'Enhanced Open (OWE)', 'WPA2 Personal', 'WPA3 Personal', 'WPA2/WPA3 Personal', 'WPA2 Enterprise'],
    this.initialSsid,
    this.initialSecurityOption,
    this.initialPassword,
    this.height, // 高度參數可選
  }) : super(key: key);

  @override
  State<SetSSIDComponent> createState() => _SetSSIDComponentState();
}

class _SetSSIDComponentState extends State<SetSSIDComponent> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AppTheme _appTheme = AppTheme();
  final ScrollController _scrollController = ScrollController();
  bool _isSsidError = false;  // SSID 錯誤狀態

  // 焦點節點
  final FocusNode _ssidFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  String _selectedSecurityOption = ''; // Initial empty value, will be set to first option
  bool _passwordVisible = false;
  bool _showPasswordField = true;

  // Error state flags
  bool _isPasswordError = false;

  // Error message texts
  String _ssidErrorText = '';
  String _passwordErrorText = '';

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

    // 添加焦點監聽
    _ssidFocusNode.addListener(_handleSsidFocus);
    _passwordFocusNode.addListener(_handlePasswordFocus);

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
    _ssidFocusNode.removeListener(_handleSsidFocus);
    _passwordFocusNode.removeListener(_handlePasswordFocus);
    _ssidFocusNode.dispose();
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    _ssidController.removeListener(_notifyFormChanged);
    _passwordController.removeListener(_notifyFormChanged);
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 處理SSID輸入框獲得焦點
  void _handleSsidFocus() {
    if (_ssidFocusNode.hasFocus) {
      // 延遲執行，確保鍵盤已完全彈出
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // 滾動到合適的位置
          _scrollController.animateTo(
            0.0, // SSID在頂部，不需要太多滾動
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // 處理密碼輸入框獲得焦點
  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus) {
      // 延遲執行，確保鍵盤已完全彈出
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // 滾動到合適的位置，這個值需要根據您的UI調整
          _scrollController.animateTo(
            150.0, // 密碼欄位位置
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
      if (ssid.isNotEmpty) {
        // 檢查長度 - 32 字元限制
        if (ssid.length > 32) {
          _isSsidError = true;
        }
        // 檢查字符有效性
        else if (!_isValidCharacters(ssid)) {
          _isSsidError = true;
        }
        else {
          _isSsidError = false;
        }
      } else {
        _isSsidError = false;
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
      } else if (password.length > 63) {
        _isPasswordError = true;
        _passwordErrorText = 'Password must be 63 characters or less';
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

  // 動態 SSID 提示方法（類似密碼提示）
  String _getSsidHintText(String ssid, bool isError) {
    if (ssid.isEmpty) {
      return 'SSID must be 32 characters or less';
    }

    if (ssid.length > 32) {
      return 'SSID too long (current: ${ssid.length}, max: 32 characters)';
    }

    if (ssid.length >= 30) {
      return 'SSID meets requirements (${ssid.length}/32 characters)';
    }

    if (!_isValidCharacters(ssid)) {
      return 'SSID contains invalid characters';
    }

    return 'SSID meets requirements (${ssid.length}/32 characters)';
  }

// 動態密碼提示方法
  String _getPasswordHintText(String password, bool isError) {
    if (!_showPasswordField) {
      return '';
    }

    if (password.isEmpty) {
      return 'Password must be at least 8 characters';
    }

    if (password.length < 8) {
      return 'Password too short (minimum 8 characters)';
    }

    if (password.length > 63) {
      return 'Password too long (maximum 63 characters)';
    }

    if (!_isValidCharacters(password)) {
      return 'Password contains invalid characters';
    }

    return 'Password meets requirements';
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
      cardHeight = screenSize.height - bottomInset - 190; // 保留上方空間
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
                'Set SSID',
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
          // SSID 輸入欄位
          _buildLabelAndField(
            label: 'SSID',
            isError: _isSsidError,
            child: _buildTextField(
              controller: _ssidController,
              isError: _isSsidError,
              focusNode: _ssidFocusNode,
            ),
            hintText: _getSsidHintText(_ssidController.text, _isSsidError),
            errorText: _isSsidError ? _ssidErrorText : null,
            bottomInset: bottomInset,
          ),

          SizedBox(height: bottomInset > 0 ? 10 : 20),

          // 安全選項下拉選單
          _buildLabelAndField(
            label: 'Security Option',
            isError: false,
            child: _buildSecurityOptionDropdown(),
            bottomInset: bottomInset,
          ),

          // 如果需要顯示密碼欄位
          if (_showPasswordField) ...[
            SizedBox(height: bottomInset > 0 ? 10 : 20),

            // 密碼輸入欄位
            _buildLabelAndField(
              label: 'Password',
              isError: _isPasswordError,
              child: _buildPasswordField(
                controller: _passwordController,
                isVisible: _passwordVisible,
                isError: _isPasswordError,
                focusNode: _passwordFocusNode,
              ),
              hintText: _getPasswordHintText(_passwordController.text, _isPasswordError),
              bottomInset: bottomInset,
            ),
          ],

          // 鍵盤彈出時的額外空間
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
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
    String? hintText,
    required double bottomInset,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bottomInset > 0 ? 16 : 18,
            fontWeight: FontWeight.normal,
            color: isError ? const Color(0xFFFF00E5) : Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 4),
        // 🔧 修改：顯示動態提示文字
        Text(
          hintText ?? (errorText ?? ''),
          style: TextStyle(
            color: isError ? const Color(0xFFFF00E5) : Colors.white,
            fontSize: bottomInset > 0 ? 10 : 12,
          ),
        ),
      ],
    );
  }

  // 構建基本文本輸入框
  Widget _buildTextField({
    required TextEditingController controller,
    required bool isError,
    FocusNode? focusNode,
    bool obscureText = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
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
    FocusNode? focusNode,
  }) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: Stack(
        children: [
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            obscureText: !isVisible,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black.withOpacity(0.4),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 50, 16), // 右側留 34px 空間給圖示
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
}