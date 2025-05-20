import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isFormValid = false;

  // 比例參數 - 可以統一調整
  final double _topSpaceRatio = 0.2;        // 頂部空白高度比例
  final double _titleHeightRatio = 0.05;     // 標題高度比例
  final double _titleSpaceRatio = 0.01;      // 標題下方間距比例
  final double _grayAreaHeightRatio = 0.4;  // 灰色區域高度比例
  final double _grayAreaMarginRatio = 0.04;  // 灰色區域水平邊距比例
  final double _innerPaddingRatio = 0.05;    // 內部元素邊距比例
  final double _labelSpaceRatio = 0.035;     // 標籤之間的間距比例
  final double _inputFieldHeightRatio = 0.06; // 輸入框高度比例
  final double _inputLabelSpaceRatio = 0.01; // 標籤與輸入框間距比例
  final double _buttonHeightRatio = 0.07;    // 按鈕高度比例
  final double _buttonSpaceRatio = 0.02;     // 按鈕間距比例
  final double _bottomMarginRatio = 0.02;    // 底部邊距比例

  @override
  void initState() {
    super.initState();
    _accountController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _accountController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    setState(() {
      _isFormValid = _accountController.text.isNotEmpty && _passwordController.text.isNotEmpty;
    });
  }

  void _handleLogin() {
    if (!_isFormValid) {
      // 如果表單無效，顯示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accountController.text.isEmpty ? '請輸入帳號' : '請輸入密碼',
          ),
        ),
      );
      return;
    }

    // 導航到下一個頁面或執行登入邏輯
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('登入成功！')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenHeight = size.height;
    final screenWidth = size.width;

    // 計算實際尺寸
    final double topSpace = screenHeight * _topSpaceRatio;
    final double titleHeight = screenHeight * _titleHeightRatio;
    final double titleSpace = screenHeight * _titleSpaceRatio;
    final double grayAreaHeight = screenHeight * _grayAreaHeightRatio;
    final double grayAreaMargin = screenWidth * _grayAreaMarginRatio;
    final double innerPadding = screenWidth * _innerPaddingRatio;
    final double labelSpace = screenHeight * _labelSpaceRatio;
    final double inputFieldHeight = screenHeight * _inputFieldHeightRatio;
    final double inputLabelSpace = screenHeight * _inputLabelSpaceRatio;
    final double buttonHeight = screenHeight * _buttonHeightRatio;
    final double buttonVerticalSpace = screenHeight * _buttonSpaceRatio;
    final double bottomMargin = screenHeight * _bottomMarginRatio;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 頂部空白區域
            SizedBox(height: topSpace),

            // Account 標題
            Container(
              height: titleHeight,
              alignment: Alignment.center,
              child: const Text(
                "Account",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
            ),

            // Account 標題與灰色區域之間的間距
            SizedBox(height: titleSpace),

            // 中間區域 - 灰色背景，含 User 標籤和輸入框
            Container(
              height: grayAreaHeight,
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: grayAreaMargin),
              color: const Color(0xFFEFEFEF),
              padding: EdgeInsets.all(innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User 標籤
                  const Text(
                    "User",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: labelSpace),

                  // Account 標籤
                  const Text(
                    "Account",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: inputLabelSpace),

                  // Account 輸入框
                  Container(
                    height: inputFieldHeight,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFEFEF),
                      border: Border.all(color: Colors.black),
                    ),
                    child: TextField(
                      controller: _accountController,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  SizedBox(height: labelSpace),

                  // Password 標籤
                  const Text(
                    "Password",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: inputLabelSpace),

                  // Password 輸入框
                  Container(
                    height: inputFieldHeight,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFEFEF),
                      border: Border.all(color: Colors.black),
                    ),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: InputBorder.none,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible ? Icons.visibility : Icons.visibility_off,
                            color: Colors.grey,
                            size: 24,
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
              ),
            ),

            // 灰色區域與底部按鈕之間的間距 (剩餘空間)
            Spacer(),

            // 底部導航按鈕
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * _innerPaddingRatio,
                vertical: buttonVerticalSpace,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 返回按鈕
                  Container(
                    width: (screenWidth - (screenWidth * _innerPaddingRatio * 2) - 10) / 2, // 計算寬度
                    height: buttonHeight,
                    color: Color(0xFFD9D9D9),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),

                  // 下一步按鈕
                  Container(
                    width: (screenWidth - (screenWidth * _innerPaddingRatio * 2) - 10) / 2, // 計算寬度
                    height: buttonHeight,
                    color: Color(0xFFD9D9D9),
                    child: TextButton(
                      onPressed: _handleLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(0),
                        ),
                      ),
                      child: const Text(
                        'Next',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 底部邊距
            SizedBox(height: bottomMargin),
          ],
        ),
      ),
    );
  }
}