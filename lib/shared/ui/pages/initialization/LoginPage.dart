import 'package:flutter/material.dart';
import 'package:whitebox/shared/theme/app_theme.dart';
import 'package:whitebox/shared/api/wifi_api_service.dart';
import 'package:whitebox/shared/ui/pages/home/DashboardPage.dart';
import 'package:whitebox/shared/services/api_preloader_service.dart';
import 'package:whitebox/shared/utils/jwt_auto_relogin.dart';

class LoginPage extends StatefulWidget {
  final Function()? onLoginSuccess;
  final Function()? onBackPressed;
  final bool showBackButton;
  final String fixedAccount;

  const LoginPage({
    Key? key,
    this.onLoginSuccess,
    this.onBackPressed,
    this.showBackButton = true,
    this.fixedAccount = 'admin',
  }) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AppTheme _appTheme = AppTheme();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 焦點節點
  final FocusNode _passwordFocusNode = FocusNode();

  bool _passwordVisible = false;
  bool _isPasswordError = false;
  bool _isFormValid = false;
  bool _isLoggingIn = false;
  String _ellipsis = '';
  String _errorMessage = '';

  // 所有比例參數保持不變...
  final double _topSpaceRatio = 0.06;
  final double _titleHeightRatio = 0.06;
  final double _titleSpaceRatio = 0.03;
  final double _cardHeightRatio = 0.40;
  final double _cardToButtonSpaceRatio = 0.15;
  final double _cardPaddingRatio = 0.05;
  final double _userTitleToAccountSpaceRatio = 0.025;
  final double _inputFieldsSpaceRatio = 0.025;
  final double _labelToInputSpaceRatio = 0.008;
  final double _inputExtraBottomSpaceRatio = 0.015;
  final double _inputFieldHeightRatio = 0.06;
  final double _mainTitleFontSize = 28.0;
  final double _userTitleFontSize = 24.0;
  final double _labelFontSize = 18.0;
  final double _inputTextFontSize = 16.0;
  final double _errorTextFontSize = 12.0;
  final double _buttonHeightRatio = 0.07;
  final double _buttonSpacingRatio = 0.02;
  final double _bottomMarginRatio = 0.02;
  final double _horizontalPaddingRatio = 0.05;
  final double _buttonBorderRadius = 8.0;
  final double _buttonTextFontSize = 18.0;
  final double _visibilityIconSize = 25.0;

  @override
  void initState() {
    super.initState();
    _accountController.text = widget.fixedAccount;
    _passwordController.addListener(() {
      _validatePassword();
      _validateForm();
    });
    _passwordFocusNode.addListener(_handlePasswordFocus);
    _validateForm();
  }

  @override
  void dispose() {
    _passwordFocusNode.removeListener(_handlePasswordFocus);
    _passwordFocusNode.dispose();
    _scrollController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 省略號動畫
  void _startEllipsisAnimation() {
    if (_isLoggingIn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isLoggingIn) {
          setState(() {
            _ellipsis = _ellipsis.length < 3 ? _ellipsis + '.' : '';
          });
          _startEllipsisAnimation();
        }
      });
    }
  }

  void _handlePasswordFocus() {
    if (_passwordFocusNode.hasFocus) {
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            80.0,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _validatePassword() {
    final password = _passwordController.text;
    setState(() {
      // 清除錯誤訊息當用戶開始輸入時
      if (password.isNotEmpty && _errorMessage.isNotEmpty) {
        _errorMessage = '';
      }
    });
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _passwordController.text.isNotEmpty;
    });
  }

  // 解析錯誤訊息
  String _parseErrorMessage(dynamic error) {
    String errorString = error.toString().toLowerCase();

    if (errorString.contains('invalid username or password')) {
      return 'Invalid username or password';
    } else if (errorString.contains('connection') || errorString.contains('network')) {
      return 'Network connection failed';
    } else if (errorString.contains('timeout')) {
      return 'Connection timeout';
    } else if (errorString.contains('unauthorized')) {
      return 'Unauthorized access';
    } else if (errorString.contains('forbidden')) {
      return 'Access forbidden';
    } else if (errorString.contains('500')) {
      return 'Invalid username or password';
    } else {
      return 'Login failed';
    }
  }

  // 測試 Mesh Topology API
  Future<void> _testMeshTopologyAPI() async {
    try {
      print('=== 開始測試 Mesh Topology HTTPS API ===');

      // 獲取 Mesh 網路拓撲資訊
      final meshResult = await WifiApiService.getMeshTopology();

      print('=== Mesh Topology HTTPS API 測試結果 ===');

      // 檢查響應類型並相應處理
      if (meshResult is List) {
        print('✅ 響應是 List 類型，包含 ${meshResult.length} 個元素');

        // 不再重複印出完整內容，因為 getMeshTopology 已經詳細輸出了
        print('📊 數據概覽:');
        for (int i = 0; i < meshResult.length; i++) {
          if (meshResult[i] is Map) {
            final node = meshResult[i] as Map;
            print('  節點 ${i + 1}: ${node['type'] ?? 'unknown'} - ${node['macAddr'] ?? 'no-mac'}');
          }
        }
      } else if (meshResult is Map) {
        if (meshResult.containsKey('error')) {
          print('❌ HTTPS API 調用錯誤: ${meshResult['error']}');
        } else {
          print('✅ HTTPS API 調用成功!');

          // 如果響應包含特定欄位，則進一步解析
          if (meshResult.containsKey('nodes')) {
            print('🔍 發現節點資訊: ${meshResult['nodes']}');
          }

          if (meshResult.containsKey('topology')) {
            print('🔍 發現拓撲資訊: ${meshResult['topology']}');
          }

          if (meshResult.containsKey('connections')) {
            print('🔍 發現連接資訊: ${meshResult['connections']}');
          }
        }
      } else {
        print('⚠️ 響應類型未知: ${meshResult.runtimeType}');
      }

      print('=== Mesh Topology HTTPS API 測試完成 ===');

    } catch (e) {
      print('=== Mesh Topology HTTPS API 測試異常 ===');
      print('異常詳情: $e');
      print('=== 異常測試結束 ===');
    }
  }

  void _handleLogin() async {
    if (_passwordController.text.isEmpty) {
      // 添加沒有輸入密碼的提示 (參考其他地方的提視窗)
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: const Color(0xFF9747FF).withOpacity(0.5),
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: const Color(0xFFFF00E5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Password Required',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Please enter your password to continue.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // 關閉對話框
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9747FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          );
        },
      );
      return; // 停止登入流程
    }

    if (!_isFormValid) {
      _validatePassword();
      return;
    }

    setState(() {
      _isLoggingIn = true;
      _ellipsis = '';
      _errorMessage = '';
      _isPasswordError = false;
    });
    _startEllipsisAnimation();

    try {
      final loginResult = await WifiApiService.loginWithSRP(
        widget.fixedAccount,
        _passwordController.text,
      );

      print('Login result: success=${loginResult.success}, message=${loginResult.message}');

      // 如果 API 返回成功但實際上應該失敗（基於您觀察到的行為）
      // 我們可以通過檢查特定條件來判斷
      bool shouldTreatAsFailure = false;

      // 檢查 message 中是否包含失敗指示
      if (loginResult.message != null) {
        String msg = loginResult.message!.toLowerCase();
        if (msg.contains('invalid username or password') ||
            msg.contains('status_code: 500') ||
            msg.contains('警告: 伺服器回應中未找到jwt令牌')) {
          shouldTreatAsFailure = true;
        }
      }

      // 檢查 JWT token 是否真的有效
      if (loginResult.jwtToken == null ||
          loginResult.jwtToken!.isEmpty ||
          loginResult.jwtToken!.length < 20) {
        shouldTreatAsFailure = true;
      }

      if (loginResult.success == true && !shouldTreatAsFailure) {
        // 🔥 登入成功：JWT token 和憑證已由 WifiApiService.loginWithSRP 自動處理

        print('✅ 登入成功！JWT 自動重新登入已啟用');
        print('🔐 憑證已儲存，JWT 過期時將自動重新登入');

        // 開始預載入 API 資料
        print('📡 開始預載入 API 資料...');
        await ApiPreloaderService.preloadAllAPIs();

        setState(() {
          _isLoggingIn = false;
        });

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DashboardPage(
                showBottomNavigation: true,
                initialNavigationIndex: 1, // 1 = NetworkTopo 頁面
              ),
            ),
          );
        }

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        }
      }else {
        // 登入失敗
        String errorMsg = 'Invalid username or password';

        setState(() {
          _isLoggingIn = false;
          _isPasswordError = true;
          _errorMessage = errorMsg;
        });

        print('Login treated as failure: $errorMsg');
      }
    } catch (e) {
      print('Login exception: $e');

      setState(() {
        _isLoggingIn = false;
        _isPasswordError = true;
        _errorMessage = 'Login failed';
      });
    }
  }

  Widget _buildNavigationButtons({
    required double buttonHeight,
    required double buttonSpacing,
    required double horizontalPadding,
    required double buttonBorderRadius,
    required double buttonTextFontSize,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(horizontalPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back 按鈕 - 只有在 showBackButton 為 true 時顯示
          if (widget.showBackButton)
            Expanded(
              child: GestureDetector(
                onTap: _isLoggingIn ? null : widget.onBackPressed,
                child: Container(
                  width: double.infinity,
                  height: buttonHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(buttonBorderRadius),
                    color: _isLoggingIn
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.2),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Back',
                      style: AppTextStyles.buttonText.copyWith( // 使用主題樣式
                        fontSize: buttonTextFontSize,
                        color: _isLoggingIn
                            ? Colors.white.withOpacity(0.5)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 如果有 Back 按鈕，則添加間距
          if (widget.showBackButton)
            SizedBox(width: buttonSpacing),

          // Login 按鈕
          Expanded(
            child: GestureDetector(
              onTap: _isLoggingIn ? null : _handleLogin,
              child: _appTheme.whiteBoxTheme.buildSimpleColorButton(
                width: double.infinity,
                height: buttonHeight,
                borderRadius: BorderRadius.circular(buttonBorderRadius),
                child: Center(
                  child: Text(
                    'Login',
                    style: AppTextStyles.buttonText.copyWith( // 使用主題樣式
                      fontSize: buttonTextFontSize,
                      color: _isLoggingIn
                          ? Colors.white.withOpacity(0.5)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 主要內容
          SafeArea(
            child: SingleChildScrollView(
              child: Container(
                width: screenSize.width,
                height: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 標題 - 使用 heading1 樣式
                    Container(
                      height: screenSize.height * _titleHeightRatio,
                      alignment: Alignment.center,
                      child: Text(
                        "Login",
                        style: AppTextStyles.heading1, // 使用 heading1 樣式
                      ),
                    ),

                    SizedBox(height: screenSize.height * _titleSpaceRatio),

                    // 中間區域 - 使用 StandardCard
                    _appTheme.whiteBoxTheme.buildStandardCard(
                      width: screenSize.width * 0.9,
                      height: screenSize.height * _cardHeightRatio,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Padding(
                          padding: EdgeInsets.all(screenSize.width * _cardPaddingRatio),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User 標籤 - 使用 heading2 樣式
                              Text(
                                "User",
                                style: AppTextStyles.heading2, // 使用 heading2 樣式
                              ),

                              SizedBox(height: screenSize.height * _userTitleToAccountSpaceRatio),

                              // Account 標籤和輸入框（固定並禁用）
                              _buildDisabledUserField(),

                              SizedBox(height: screenSize.height * _inputFieldsSpaceRatio),

                              // Password 標籤和輸入框
                              _buildLabelWithPasswordField(
                                label: 'Password',
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                isVisible: _passwordVisible,
                                isError: _isPasswordError,
                                errorText: _errorMessage.isNotEmpty ? _errorMessage : 'Please enter password',
                                labelFontSize: _labelFontSize,
                                errorFontSize: _errorTextFontSize,
                                labelToInputSpace: screenSize.height * _labelToInputSpaceRatio,
                                inputHeight: screenSize.height * _inputFieldHeightRatio,
                                iconSize: _visibilityIconSize,
                                onVisibilityChanged: (visible) {
                                  setState(() {
                                    _passwordVisible = visible;
                                  });
                                },
                              ),

                              SizedBox(height: screenSize.height * _inputExtraBottomSpaceRatio),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: screenSize.height * _cardToButtonSpaceRatio),

                    // 底部導航按鈕
                    _buildNavigationButtons(
                      buttonHeight: screenSize.height * _buttonHeightRatio,
                      buttonSpacing: screenSize.width * _buttonSpacingRatio,
                      horizontalPadding: screenSize.width * _horizontalPaddingRatio,
                      buttonBorderRadius: _buttonBorderRadius,
                      buttonTextFontSize: _buttonTextFontSize,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 登入動畫遮罩層
          if (_isLoggingIn)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Logging in$_ellipsis',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

// 構建帶標籤的密碼輸入框
  Widget _buildLabelWithPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required bool isError,
    required String errorText,
    required Function(bool) onVisibilityChanged,
    required double labelFontSize,
    required double errorFontSize,
    required double labelToInputSpace,
    required double inputHeight,
    required double iconSize,
    FocusNode? focusNode,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 標籤 - 使用 heading3 樣式
        Text(
          label,
          style: AppTextStyles.heading3.copyWith(
            color: isError ? Color(0xFFFF00E5) : AppTextStyles.heading3.color, // 保持錯誤顏色邏輯
          ),
        ),

        SizedBox(height: labelToInputSpace),

        // 輸入框
        Container(
          width: double.infinity,
          height: inputHeight,
          child: Stack(
            children: [
              CustomTextField(
                width: double.infinity,
                height: inputHeight,
                controller: controller,
                focusNode: focusNode,
                obscureText: !isVisible,
                enabled: !_isLoggingIn, // 登入期間禁用輸入
                borderColor: isError ? Color(0xFFFF00E5) : AppColors.primary, // 使用正確的邊框顏色
                borderOpacity: 0.7,
                backgroundColor: Colors.black, // 使用黑色背景
                backgroundOpacity: 0.4, // 設置透明度
                textStyle: TextStyle(
                  fontSize: _inputTextFontSize,
                  color: _isLoggingIn ? Colors.white.withOpacity(0.5) : Colors.white,
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
                      color: _isLoggingIn
                          ? (isError ? Color(0xFFFF00E5).withOpacity(0.5) : Colors.white.withOpacity(0.5))
                          : (isError ? Color(0xFFFF00E5) : Colors.white), // 使用正確的圖標顏色
                      size: iconSize,
                    ),
                    onPressed: _isLoggingIn ? null : () {
                      onVisibilityChanged(!isVisible);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 4),

        // 錯誤提示或密碼要求說明 - 使用 bodySmall 樣式
        if (isError && _errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errorMessage,
              style: AppTextStyles.bodySmall.copyWith(
                color: Color(0xFFFF00E5), // 保持錯誤顏色
              ),
            ),
          )
      ],
    );
  }

// 修改構建固定且禁用的帳號輸入框
  Widget _buildDisabledUserField() {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account 標籤 - 使用 heading3 樣式
        Text(
          'Account',
          style: AppTextStyles.heading3, // 使用 heading3 樣式
        ),

        SizedBox(height: screenSize.height * _labelToInputSpaceRatio),

        // 使用自定義的輸入框，設置為禁用狀態
        CustomTextField(
          width: double.infinity,
          height: screenSize.height * _inputFieldHeightRatio,
          controller: _accountController,
          enabled: false, // 禁用輸入
          borderColor: AppColors.primary,
          borderOpacity: 0.7,
          backgroundColor: Colors.grey, // 禁用狀態使用灰色背景
          backgroundOpacity: 0.3, // 降低透明度
          enableBlur: false, // 不使用模糊效果
          textStyle: TextStyle(
            fontSize: _inputTextFontSize,
            color: Colors.grey[400], // 使用灰色文字
          ),
        ),
      ],
    );
  }

}