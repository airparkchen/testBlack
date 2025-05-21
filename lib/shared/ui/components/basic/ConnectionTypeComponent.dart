import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

// 定義 PPPoE 配置類
class PPPoEConfig {
  String username = '';
  String password = '';

  // 檢查必填項是否有值
  bool isValid() {
    return username.isNotEmpty && password.isNotEmpty;
  }
}

class ConnectionTypeComponent extends StatefulWidget {
  final String? initialConnectionType;
  final StaticIpConfig? initialStaticIpConfig;
  final String? initialPppoeUsername;
  final String? initialPppoePassword;

  final dynamic onSelectionChanged;

  final dynamic onNextPressed;

  final dynamic onBackPressed;

  final dynamic displayOptions;

  const ConnectionTypeComponent({
    Key? key,
    this.onSelectionChanged,
    this.onNextPressed,
    this.onBackPressed,
    this.displayOptions = const ['DHCP', 'Static IP', 'PPPoE'],
    this.initialConnectionType,
    this.initialStaticIpConfig,
    this.initialPppoeUsername,
    this.initialPppoePassword,
  }) : super(key: key);

  @override
  State<ConnectionTypeComponent> createState() => _ConnectionTypeComponentState();
}

class _ConnectionTypeComponentState extends State<ConnectionTypeComponent> {
  String _selectedConnectionType = '';
  bool _isFormComplete = false;
  StaticIpConfig _staticIpConfig = StaticIpConfig();
  PPPoEConfig _pppoeConfig = PPPoEConfig(); // Added PPPoE configuration

  final AppTheme _appTheme = AppTheme();
  // Controllers for IP-related inputs
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _subnetController = TextEditingController();
  final TextEditingController _gatewayController = TextEditingController();
  final TextEditingController _primaryDnsController = TextEditingController();
  final TextEditingController _secondaryDnsController = TextEditingController();

  // Controllers for PPPoE-related inputs
  final TextEditingController _pppoeUsernameController = TextEditingController();
  final TextEditingController _pppoePasswordController = TextEditingController();
  bool _pppoePasswordVisible = false; // Control password visibility

  // Scroll controller
  late ScrollController _scrollController;

  // Error state flags
  bool _isIpError = false;
  bool _isSubnetError = false;
  bool _isGatewayError = false;
  bool _isPrimaryDnsError = false;
  bool _isSecondaryDnsError = false;
  bool _isPppoeUsernameError = false;
  bool _isPppoePasswordError = false;

  // Error message texts
  String _ipErrorText = '';
  String _subnetErrorText = '';
  String _gatewayErrorText = '';
  String _primaryDnsErrorText = '';
  String _secondaryDnsErrorText = '';
  String _pppoeUsernameErrorText = '';
  String _pppoePasswordErrorText = '';

  @override
  void initState() {
    super.initState();

    // 初始化選擇第一個選項或使用提供的初始值
    if (widget.initialConnectionType != null) {
      _selectedConnectionType = widget.initialConnectionType!;
    } else if (widget.displayOptions.isNotEmpty) {
      _selectedConnectionType = widget.displayOptions.first;
    }

    // 初始化表單完成狀態
    _isFormComplete = _selectedConnectionType != 'Static IP' && _selectedConnectionType != 'PPPoE';

    // 初始化靜態IP配置
    if (widget.initialStaticIpConfig != null && _selectedConnectionType == 'Static IP') {
      _staticIpConfig = widget.initialStaticIpConfig!;
      _ipController.text = _staticIpConfig.ipAddress;
      _subnetController.text = _staticIpConfig.subnetMask;
      _gatewayController.text = _staticIpConfig.gateway;
      _primaryDnsController.text = _staticIpConfig.primaryDns;
      _secondaryDnsController.text = _staticIpConfig.secondaryDns;

      // 驗證所有字段，更新表單狀態
      _validateForm();
    }

    // 初始化PPPoE配置
    if (widget.initialPppoeUsername != null &&
        widget.initialPppoePassword != null &&
        _selectedConnectionType == 'PPPoE') {
      _pppoeConfig.username = widget.initialPppoeUsername!;
      _pppoeConfig.password = widget.initialPppoePassword!;
      _pppoeUsernameController.text = _pppoeConfig.username;
      _pppoePasswordController.text = _pppoeConfig.password;

      // 驗證所有字段，更新表單狀態
      _validateForm();
    }

    // 初始化滾動控制器
    _scrollController = ScrollController();

    // 設置監聽器，在輸入變化時更新表單狀態
    _setupControllerListeners();

    // 使用 addPostFrameCallback 避免在 build 期間調用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySelectionChanged();
    });
  }

  @override
  void dispose() {
    // 釋放所有控制器
    _ipController.dispose();
    _subnetController.dispose();
    _gatewayController.dispose();
    _primaryDnsController.dispose();
    _secondaryDnsController.dispose();
    _pppoeUsernameController.dispose();
    _pppoePasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Set up listeners for all input controllers
  void _setupControllerListeners() {
    _ipController.addListener(() {
      _staticIpConfig.ipAddress = _ipController.text;
      _validateIpField(_ipController.text, 'IP Address');
      _validateForm();
    });

    _subnetController.addListener(() {
      _staticIpConfig.subnetMask = _subnetController.text;
      _validateIpField(_subnetController.text, 'Subnet Mask');
      _validateForm();
    });

    _gatewayController.addListener(() {
      _staticIpConfig.gateway = _gatewayController.text;
      _validateIpField(_gatewayController.text, 'Gateway');
      _validateForm();
    });

    _primaryDnsController.addListener(() {
      _staticIpConfig.primaryDns = _primaryDnsController.text;
      _validateIpField(_primaryDnsController.text, 'Primary DNS');
      _validateForm();
    });

    _secondaryDnsController.addListener(() {
      _staticIpConfig.secondaryDns = _secondaryDnsController.text;
      if (_secondaryDnsController.text.isNotEmpty) {
        _validateIpField(_secondaryDnsController.text, 'Secondary DNS');
      } else {
        setState(() {
          _isSecondaryDnsError = false;
          _secondaryDnsErrorText = '';
        });
      }
      _validateForm();
    });

    // Add listeners for PPPoE-related controllers
    _pppoeUsernameController.addListener(() {
      _pppoeConfig.username = _pppoeUsernameController.text;
      _validatePppoeUsername();
      _validateForm();
    });

    _pppoePasswordController.addListener(() {
      _pppoeConfig.password = _pppoePasswordController.text;
      _validatePppoePassword();
      _validateForm();
    });
  }

  // Validate PPPoE username
  void _validatePppoeUsername() {
    setState(() {
      if (_pppoeUsernameController.text.isEmpty) {
        _isPppoeUsernameError = true;
        _pppoeUsernameErrorText = 'Please enter a username';
      } else {
        _isPppoeUsernameError = false;
        _pppoeUsernameErrorText = '';
      }
    });
  }

  // Validate PPPoE password
  void _validatePppoePassword() {
    setState(() {
      if (_pppoePasswordController.text.isEmpty) {
        _isPppoePasswordError = true;
        _pppoePasswordErrorText = 'Please enter a password';
      } else {
        _isPppoePasswordError = false;
        _pppoePasswordErrorText = '';
      }
    });
  }

  // Validate IP format
  void _validateIpField(String ip, String fieldName) {
    final bool isValid = _validateIpFormat(ip);

    setState(() {
      switch (fieldName) {
        case 'IP Address':
          _isIpError = ip.isNotEmpty && !isValid;
          _ipErrorText = _isIpError ? 'Please enter a valid IP address' : '';
          break;
        case 'Subnet Mask':
          _isSubnetError = ip.isNotEmpty && !isValid;
          _subnetErrorText = _isSubnetError ? 'Please enter a valid subnet mask' : '';
          break;
        case 'Gateway':
          _isGatewayError = ip.isNotEmpty && !isValid;
          _gatewayErrorText = _isGatewayError ? 'Please enter a valid gateway address' : '';
          break;
        case 'Primary DNS':
          _isPrimaryDnsError = ip.isNotEmpty && !isValid;
          _primaryDnsErrorText = _isPrimaryDnsError ? 'Please enter a valid DNS address' : '';
          break;
        case 'Secondary DNS':
          _isSecondaryDnsError = ip.isNotEmpty && !isValid;
          _secondaryDnsErrorText = _isSecondaryDnsError ? 'Please enter a valid DNS address' : '';
          break;
      }
    });
  }

  // 驗證表單
  void _validateForm() {
    bool isValid = true;

    if (_selectedConnectionType == 'Static IP') {
      // 檢查必填項是否為空
      final bool hasEmptyFields =
          _staticIpConfig.ipAddress.isEmpty ||
              _staticIpConfig.subnetMask.isEmpty ||
              _staticIpConfig.gateway.isEmpty ||
              _staticIpConfig.primaryDns.isEmpty;

      if (hasEmptyFields) {
        isValid = false;
      } else {
        // 檢查所有必填項格式是否正確
        isValid = _validateIpFormat(_staticIpConfig.ipAddress) &&
            _validateIpFormat(_staticIpConfig.subnetMask) &&
            _validateIpFormat(_staticIpConfig.gateway) &&
            _validateIpFormat(_staticIpConfig.primaryDns);

        // 次要 DNS 是選填的，只有填了才檢查格式
        if (_staticIpConfig.secondaryDns.isNotEmpty && !_validateIpFormat(_staticIpConfig.secondaryDns)) {
          isValid = false;
        }
      }
    } else if (_selectedConnectionType == 'PPPoE') {
      // 驗證 PPPoE 配置
      isValid = _pppoeConfig.username.isNotEmpty && _pppoeConfig.password.isNotEmpty;
    }

    if (isValid != _isFormComplete) {
      setState(() {
        _isFormComplete = isValid;
      });
      _notifySelectionChanged();
    }
  }

  // 檢查 IP 格式是否正確
  bool _validateIpFormat(String ip) {
    if (ip.isEmpty) return false;

    // 確認格式為 xxx.xxx.xxx.xxx
    RegExp ipRegex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    if (!ipRegex.hasMatch(ip)) return false;

    // 檢查每個部分是否在 0-255 範圍內
    List<String> parts = ip.split('.');
    for (String part in parts) {
      int? value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) return false;
    }

    return true;
  }

  void _notifySelectionChanged() {
    if (widget.onSelectionChanged != null) {
      widget.onSelectionChanged!(
        _selectedConnectionType,
        _isFormComplete,
        _selectedConnectionType == 'Static IP' ? _staticIpConfig : null,
        _selectedConnectionType == 'PPPoE' ? _pppoeConfig : null,
      );
    }
  }

  // Get current Static IP error message
  String? _getErrorMessage() {
    if (_selectedConnectionType != 'Static IP') return null;

    if (_staticIpConfig.ipAddress.isEmpty) {
      return 'Please enter an IP address';
    } else if (_isIpError) {
      return _ipErrorText;
    }

    if (_staticIpConfig.subnetMask.isEmpty) {
      return 'Please enter a subnet mask';
    } else if (_isSubnetError) {
      return _subnetErrorText;
    }

    if (_staticIpConfig.gateway.isEmpty) {
      return 'Please enter a gateway address';
    } else if (_isGatewayError) {
      return _gatewayErrorText;
    }

    if (_staticIpConfig.primaryDns.isEmpty) {
      return 'Please enter a primary DNS';
    } else if (_isPrimaryDnsError) {
      return _primaryDnsErrorText;
    }

    if (_isSecondaryDnsError) {
      return _secondaryDnsErrorText;
    }

    return null;
  }

  // Get current PPPoE error message
  String? _getPppoeErrorMessage() {
    if (_selectedConnectionType != 'PPPoE') return null;

    if (_pppoeConfig.username.isEmpty) {
      return 'Please enter a username';
    } else if (_isPppoeUsernameError) {
      return _pppoeUsernameErrorText;
    }

    if (_pppoeConfig.password.isEmpty) {
      return 'Please enter a password';
    } else if (_isPppoePasswordError) {
      return _pppoePasswordErrorText;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 獲取當前錯誤訊息
    final String? staticIpError = _getErrorMessage();
    final String? pppoeError = _getPppoeErrorMessage();

    // 使用 buildStandardCard 替代原始的 Container
    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9, // 寬度 90%
      height: _selectedConnectionType == 'Static IP' || _selectedConnectionType == 'PPPoE'
          ? screenSize.height * 0.75  // 靜態 IP 或 PPPoE 時，增加高度
          : screenSize.height * 0.25,  // 基本高度
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        // 使用 LayoutBuilder 來獲取父容器約束
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // 確保始終可滾動
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // 給內容一個最小高度，確保可以滾動
                  minHeight: _selectedConnectionType == 'Static IP' || _selectedConnectionType == 'PPPoE'
                      ? screenSize.height * 0.7
                      : screenSize.height * 0.25,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Internet',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Connection Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildConnectionTypeDropdown(screenSize),

                      // 如果選擇了 Static IP，顯示額外的輸入欄位
                      if (_selectedConnectionType == 'Static IP') ...[
                        const SizedBox(height: 20),

                        // IP Address
                        _buildLabelAndField(
                          label: 'IP Address',
                          isError: _isIpError,
                          child: _buildIpInputField(_ipController, '            .            .            .            ', _isIpError),
                          errorText: _isIpError ? _ipErrorText : null,
                        ),

                        const SizedBox(height: 20),

                        // Subnet Mask
                        _buildLabelAndField(
                          label: 'IP Subnet Mask',
                          isError: _isSubnetError,
                          child: _buildIpInputField(_subnetController, '            .            .            .            ', _isSubnetError),
                          errorText: _isSubnetError ? _subnetErrorText : null,
                        ),

                        const SizedBox(height: 20),

                        // Gateway
                        _buildLabelAndField(
                          label: 'Gateway IP Address',
                          isError: _isGatewayError,
                          child: _buildIpInputField(_gatewayController, '            .            .            .            ', _isGatewayError),
                          errorText: _isGatewayError ? _gatewayErrorText : null,
                        ),

                        const SizedBox(height: 20),

                        // Primary DNS
                        _buildLabelAndField(
                          label: 'Primary DNS',
                          isError: _isPrimaryDnsError,
                          child: _buildIpInputField(_primaryDnsController, '            .            .            .            ', _isPrimaryDnsError),
                          errorText: _isPrimaryDnsError ? _primaryDnsErrorText : null,
                        ),

                        // Secondary DNS (Optional) 已被註釋掉，保持原樣

                        // 顯示表單錯誤訊息
                        if (staticIpError != null && !_isFormComplete) ...[
                          const SizedBox(height: 20),
                          _buildErrorContainer(staticIpError),
                        ],

                        // 添加額外的底部空間，確保滾動到底部時看得到最後一個輸入框
                        const SizedBox(height: 250),
                      ],

                      // 如果選擇了 PPPoE，顯示用戶名和密碼輸入欄位
                      if (_selectedConnectionType == 'PPPoE') ...[
                        const SizedBox(height: 20),

                        // 用戶名
                        _buildLabelAndField(
                          label: 'User',
                          isError: _isPppoeUsernameError,
                          child: _buildPppoeTextField(
                            controller: _pppoeUsernameController,
                            isError: _isPppoeUsernameError,
                          ),
                          errorText: _isPppoeUsernameError ? _pppoeUsernameErrorText : null,
                        ),

                        const SizedBox(height: 20),

                        // 密碼
                        _buildLabelAndField(
                          label: 'Password',
                          isError: _isPppoePasswordError,
                          child: _buildPppoePasswordField(
                            controller: _pppoePasswordController,
                            isVisible: _pppoePasswordVisible,
                            isError: _isPppoePasswordError,
                          ),
                          errorText: _isPppoePasswordError ? _pppoePasswordErrorText : null,
                        ),

                        // 顯示表單錯誤訊息
                        if (pppoeError != null && !_isFormComplete) ...[
                          const SizedBox(height: 20),
                          _buildErrorContainer(pppoeError),
                        ],

                        // 添加額外的底部空間，確保滾動到底部時看得到最後一個輸入框
                        const SizedBox(height: 250),
                      ]
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

// ========== 以下為輔助方法 ==========

// 構建連接類型下拉選擇框
  Widget _buildConnectionTypeDropdown(Size screenSize) {
    return SizedBox(
      width: screenSize.width * 0.9,
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
          value: _selectedConnectionType,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          iconSize: 24,
          elevation: 16,
          dropdownColor: Colors.black.withOpacity(0.8),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedConnectionType) {
              setState(() {
                _selectedConnectionType = newValue;
                _isFormComplete = (newValue != 'Static IP') && (newValue != 'PPPoE');

                // 重置所有錯誤狀態
                _isIpError = false;
                _isSubnetError = false;
                _isGatewayError = false;
                _isPrimaryDnsError = false;
                _isSecondaryDnsError = false;
                _isPppoeUsernameError = false;
                _isPppoePasswordError = false;
              });
              _notifySelectionChanged();
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

// 構建 PPPoE 文本輸入框
  Widget _buildPppoeTextField({
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

// 構建 PPPoE 密碼輸入框
  Widget _buildPppoePasswordField({
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
                    _pppoePasswordVisible = !_pppoePasswordVisible;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// 構建一體式 IP 輸入欄位，包含點分隔顯示
  Widget _buildIpInputField(TextEditingController controller, String hintText, bool isError) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
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
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        style: TextStyle(
          fontSize: 16,
          color: isError ? const Color(0xFFFF00E5) : Colors.white,
        ),
        inputFormatters: [
          _IpAddressInputFormatter(),
        ],
      ),
    );
  }
}
// Custom input formatter to handle IP address input and automatically add dots
class _IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // If deletion operation, allow delete
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text;

    // Remove all non-digits and dots
    text = text.replaceAll(RegExp(r'[^\d.]'), '');

    // Ensure no more than one consecutive dot
    text = text.replaceAll(RegExp(r'\.{2,}'), '.');

    // Split into parts
    List<String> parts = text.split('.');

    // Maximum 4 parts allowed
    if (parts.length > 4) {
      parts = parts.sublist(0, 4);
    }

    // Limit each part to maximum 3 digits and max value 255
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].length > 3) {
        parts[i] = parts[i].substring(0, 3);
      }

      // Ensure value is within 0-255 range
      int? value = int.tryParse(parts[i]);
      if (value != null && value > 255) {
        parts[i] = '255';
      }
    }

    // Recombine text
    text = parts.join('.');

    // Ensure the last character is not a dot if it was already a dot
    if (text.endsWith('.') && oldValue.text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }

    // Automatically add dot if input reached 3 digits and not the last part
    if (parts.length < 4 && parts.last.length == 3 && !text.endsWith('.') &&
        parts.last != oldValue.text.split('.').last) {
      text = '$text.';
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}