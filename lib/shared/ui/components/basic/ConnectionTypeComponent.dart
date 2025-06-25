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
  final double? height; // 新增高度參數

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
    this.height, // 高度參數可選
  }) : super(key: key);

  @override
  State<ConnectionTypeComponent> createState() => _ConnectionTypeComponentState();
}

class _ConnectionTypeComponentState extends State<ConnectionTypeComponent> {
  String _selectedConnectionType = '';
  bool _isFormComplete = false;
  StaticIpConfig _staticIpConfig = StaticIpConfig();
  PPPoEConfig _pppoeConfig = PPPoEConfig();

  final AppTheme _appTheme = AppTheme();
  final ScrollController _scrollController = ScrollController();

  // Controllers for IP-related inputs
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _subnetController = TextEditingController();
  final TextEditingController _gatewayController = TextEditingController();
  final TextEditingController _primaryDnsController = TextEditingController();
  final TextEditingController _secondaryDnsController = TextEditingController();

  // Controllers for PPPoE-related inputs
  final TextEditingController _pppoeUsernameController = TextEditingController();
  final TextEditingController _pppoePasswordController = TextEditingController();
  bool _pppoePasswordVisible = false;

  // 焦點節點
  final FocusNode _ipFocusNode = FocusNode();
  final FocusNode _subnetFocusNode = FocusNode();
  final FocusNode _gatewayFocusNode = FocusNode();
  final FocusNode _primaryDnsFocusNode = FocusNode();
  final FocusNode _secondaryDnsFocusNode = FocusNode();
  final FocusNode _pppoeUsernameFocusNode = FocusNode();
  final FocusNode _pppoePasswordFocusNode = FocusNode();

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

    // 設置監聽器，在輸入變化時更新表單狀態
    _setupControllerListeners();

    // 添加焦點監聽
    _setupFocusListeners();

    // 使用 addPostFrameCallback 避免在 build 期間調用 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySelectionChanged();
    });
  }

  @override
  void dispose() {
    // 移除焦點監聽
    _removeFocusListeners();

    // 釋放焦點節點
    _ipFocusNode.dispose();
    _subnetFocusNode.dispose();
    _gatewayFocusNode.dispose();
    _primaryDnsFocusNode.dispose();
    _secondaryDnsFocusNode.dispose();
    _pppoeUsernameFocusNode.dispose();
    _pppoePasswordFocusNode.dispose();

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

  // 設置焦點監聽器
  void _setupFocusListeners() {
    _ipFocusNode.addListener(() => _handleFieldFocus(_ipFocusNode, 80.0));
    _subnetFocusNode.addListener(() => _handleFieldFocus(_subnetFocusNode, 140.0));
    _gatewayFocusNode.addListener(() => _handleFieldFocus(_gatewayFocusNode, 200.0));
    _primaryDnsFocusNode.addListener(() => _handleFieldFocus(_primaryDnsFocusNode, 260.0));
    _secondaryDnsFocusNode.addListener(() => _handleFieldFocus(_secondaryDnsFocusNode, 320.0));
    _pppoeUsernameFocusNode.addListener(() => _handleFieldFocus(_pppoeUsernameFocusNode, 80.0));
    _pppoePasswordFocusNode.addListener(() => _handleFieldFocus(_pppoePasswordFocusNode, 140.0));
  }

  // 移除焦點監聽器
  void _removeFocusListeners() {
    _ipFocusNode.removeListener(() => _handleFieldFocus(_ipFocusNode, 80.0));
    _subnetFocusNode.removeListener(() => _handleFieldFocus(_subnetFocusNode, 140.0));
    _gatewayFocusNode.removeListener(() => _handleFieldFocus(_gatewayFocusNode, 200.0));
    _primaryDnsFocusNode.removeListener(() => _handleFieldFocus(_primaryDnsFocusNode, 260.0));
    _secondaryDnsFocusNode.removeListener(() => _handleFieldFocus(_secondaryDnsFocusNode, 320.0));
    _pppoeUsernameFocusNode.removeListener(() => _handleFieldFocus(_pppoeUsernameFocusNode, 80.0));
    _pppoePasswordFocusNode.removeListener(() => _handleFieldFocus(_pppoePasswordFocusNode, 140.0));
  }

  // 處理輸入框獲得焦點
  void _handleFieldFocus(FocusNode focusNode, double scrollPosition) {
    if (focusNode.hasFocus) {
      // 延遲執行，確保鍵盤已完全彈出
      Future.delayed(Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          // 滾動到合適的位置
          _scrollController.animateTo(
            scrollPosition,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
      } else if (!_isValidPppoeUsername(_pppoeUsernameController.text)) {
        _isPppoeUsernameError = true;
        _pppoeUsernameErrorText = 'Username can only contain letters, numbers, dots, underscores, hyphens, and @ symbol';
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
      } else if (!_isValidPppoePassword(_pppoePasswordController.text)) {
        _isPppoePasswordError = true;
        _pppoePasswordErrorText = 'Password contains invalid characters';
      } else {
        _isPppoePasswordError = false;
        _pppoePasswordErrorText = '';
      }
    });
  }

  // Validate IP format
  void _validateIpField(String ip, String fieldName) {
    bool isValid = true;
    String errorMessage = '';

    if (ip.isNotEmpty) {
      switch (fieldName) {
        case 'Subnet Mask':
          if (!_validateSubnetMask(ip)) {
            isValid = false;
            errorMessage = 'Please enter a valid subnet mask';
          }
          break;
        default:
          if (!_validateIpFormat(ip)) {
            isValid = false;
            errorMessage = 'Please enter a valid IP address';
          }
          break;
      }
    }

    setState(() {
      switch (fieldName) {
        case 'IP Address':
          _isIpError = !isValid;
          _ipErrorText = errorMessage;
          break;
        case 'Subnet Mask':
          _isSubnetError = !isValid;
          _subnetErrorText = errorMessage;
          break;
        case 'Gateway':
          _isGatewayError = !isValid;
          _gatewayErrorText = errorMessage;
          break;
        case 'Primary DNS':
          _isPrimaryDnsError = !isValid;
          _primaryDnsErrorText = errorMessage;
          break;
        case 'Secondary DNS':
          _isSecondaryDnsError = !isValid;
          _secondaryDnsErrorText = errorMessage;
          break;
      }
    });
  }


  // 驗證表單
  void _validateForm() {
    bool isValid = true;

    if (_selectedConnectionType == 'Static IP') {
      // 檢查所有必填項是否已填寫
      final bool hasEmptyRequiredFields =
          _staticIpConfig.ipAddress.isEmpty ||
              _staticIpConfig.subnetMask.isEmpty ||
              _staticIpConfig.gateway.isEmpty ||
              _staticIpConfig.primaryDns.isEmpty;

      if (hasEmptyRequiredFields) {
        isValid = false;
      } else {
        // 檢查所有必填項格式是否正確
        bool ipValid = _validateIpFormat(_staticIpConfig.ipAddress);
        bool subnetValid = _validateSubnetMask(_staticIpConfig.subnetMask);
        bool gatewayValid = _validateIpFormat(_staticIpConfig.gateway);
        bool primaryDnsValid = _validateIpFormat(_staticIpConfig.primaryDns);

        // 檢查 IP 和 Gateway 是否在同一子網
        bool sameSubnet = true;
        if (ipValid && subnetValid && gatewayValid) {
          sameSubnet = _isInSameSubnet(_staticIpConfig.ipAddress, _staticIpConfig.gateway, _staticIpConfig.subnetMask);
        }

        // 次要 DNS 是選填的，只有填了才檢查格式
        bool secondaryDnsValid = true;
        if (_staticIpConfig.secondaryDns.isNotEmpty) {
          secondaryDnsValid = _validateIpFormat(_staticIpConfig.secondaryDns);
        }

        isValid = ipValid && subnetValid && gatewayValid && primaryDnsValid && secondaryDnsValid && sameSubnet;

        // 如果 IP 和 Gateway 不在同一子網，顯示錯誤
        if (!sameSubnet && ipValid && subnetValid && gatewayValid) {
          setState(() {
            _isGatewayError = true;
            _gatewayErrorText = 'Gateway must be in the same subnet as IP address';
          });
        }
      }
    } else if (_selectedConnectionType == 'PPPoE') {
      // 驗證 PPPoE 配置
      bool usernameValid = _isValidPppoeUsername(_pppoeConfig.username);
      bool passwordValid = _isValidPppoePassword(_pppoeConfig.password);

      isValid = usernameValid && passwordValid;
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

    // 基本格式檢查：四個用點分隔的數字
    final RegExp ipRegex = RegExp(r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');

    if (!ipRegex.hasMatch(ip)) return false;

    // 額外檢查：確保每個段都在 0-255 範圍內
    List<String> segments = ip.split('.');
    if (segments.length != 4) return false;

    for (String segment in segments) {
      int? value = int.tryParse(segment);
      if (value == null || value < 0 || value > 255) return false;
    }

    return true;
  }



  // 子網掩碼驗證方法
  bool _validateSubnetMask(String mask) {
    if (!_validateIpFormat(mask)) return false;

    // 檢查是否為有效的子網掩碼
    List<String> segments = mask.split('.');
    List<int> bytes = segments.map((s) => int.parse(s)).toList();

    // 轉換為二進制並檢查是否為連續的1後跟連續的0
    String binary = '';
    for (int byte in bytes) {
      binary += byte.toRadixString(2).padLeft(8, '0');
    }

    // 檢查模式：應該是1...10...0或全1或全0
    if (!RegExp(r'^1*0*$').hasMatch(binary)) return false;

    return true;
  }

  // 檢查 IP 是否在同一子網
  bool _isInSameSubnet(String ip1, String ip2, String mask) {
    if (!_validateIpFormat(ip1) || !_validateIpFormat(ip2) || !_validateSubnetMask(mask)) {
      return false;
    }

    List<int> ip1Bytes = ip1.split('.').map((s) => int.parse(s)).toList();
    List<int> ip2Bytes = ip2.split('.').map((s) => int.parse(s)).toList();
    List<int> maskBytes = mask.split('.').map((s) => int.parse(s)).toList();

    for (int i = 0; i < 4; i++) {
      if ((ip1Bytes[i] & maskBytes[i]) != (ip2Bytes[i] & maskBytes[i])) {
        return false;
      }
    }

    return true;
  }

// PPPoE 用戶名驗證（返回布爾值的版本）
  bool _isValidPppoeUsername(String username) {
    if (username.isEmpty) return false;
    if (username.length > 64) return false;

    // PPPoE 用戶名通常允許字母、數字、點、下劃線、連字符和@符號
    final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._@-]+$');
    return usernameRegex.hasMatch(username);
  }

// PPPoE 密碼驗證（返回布爾值的版本）
  bool _isValidPppoePassword(String password) {
    if (password.isEmpty) return false;
    if (password.length > 64) return false;

    // PPPoE 密碼允許大部分可打印字符，使用十六進制範圍定義
    // 包含: 空格(0x20) + 所有可打印字符(0x21-0x7E)
    final RegExp passwordRegex = RegExp(
        r'^[\x20-\x7E]+$'
    );
    return passwordRegex.hasMatch(password);
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
                'Set Internet',
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
          // 連接類型選擇
          Text(
            'Connection Type',
            style: TextStyle(
              fontSize: bottomInset > 0 ? 16 : 18,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _buildConnectionTypeDropdown(),
          SizedBox(height: bottomInset > 0 ? 10 : 20), // 鍵盤彈出時減少間距

          // 根據選擇的連接類型顯示不同的輸入部分
          if (_selectedConnectionType == 'Static IP')
            _buildStaticIpSection(bottomInset),

          if (_selectedConnectionType == 'PPPoE')
            _buildPPPoESection(bottomInset),

          // 鍵盤彈出時的額外空間
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
      ),
    );
  }

  // 建立靜態IP相關欄位區域
  Widget _buildStaticIpSection(double bottomInset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // IP Address
        _buildLabelAndField(
          label: 'IP Address',
          isError: _isIpError,
          child: _buildIpInputField(
            _ipController,
            '            .            .            .            ',
            _isIpError,
            _ipFocusNode,
          ),
          errorText: _isIpError ? _ipErrorText : null,
          bottomInset: bottomInset,
        ),

        SizedBox(height: bottomInset > 0 ? 10 : 20),

        // Subnet Mask
        _buildLabelAndField(
          label: 'IP Subnet Mask',
          isError: _isSubnetError,
          child: _buildIpInputField(
            _subnetController,
            '            .            .            .            ',
            _isSubnetError,
            _subnetFocusNode,
          ),
          errorText: _isSubnetError ? _subnetErrorText : null,
          bottomInset: bottomInset,
        ),

        SizedBox(height: bottomInset > 0 ? 10 : 20),

        // Gateway
        _buildLabelAndField(
          label: 'Gateway IP Address',
          isError: _isGatewayError,
          child: _buildIpInputField(
            _gatewayController,
            '            .            .            .            ',
            _isGatewayError,
            _gatewayFocusNode,
          ),
          errorText: _isGatewayError ? _gatewayErrorText : null,
          bottomInset: bottomInset,
        ),

        SizedBox(height: bottomInset > 0 ? 10 : 20),

        // Primary DNS
        _buildLabelAndField(
          label: 'Primary DNS',
          isError: _isPrimaryDnsError,
          child: _buildIpInputField(
            _primaryDnsController,
            '            .            .            .            ',
            _isPrimaryDnsError,
            _primaryDnsFocusNode,
          ),
          errorText: _isPrimaryDnsError ? _primaryDnsErrorText : null,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // 建立PPPoE相關欄位區域
  Widget _buildPPPoESection(double bottomInset) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 用戶名
        _buildLabelAndField(
          label: 'User',
          isError: _isPppoeUsernameError,
          child: _buildPppoeTextField(
            controller: _pppoeUsernameController,
            isError: _isPppoeUsernameError,
            focusNode: _pppoeUsernameFocusNode,
          ),
          errorText: _isPppoeUsernameError ? _pppoeUsernameErrorText : null,
          bottomInset: bottomInset,
        ),

        SizedBox(height: bottomInset > 0 ? 10 : 20),

        // 密碼
        _buildLabelAndField(
          label: 'Password',
          isError: _isPppoePasswordError,
          child: _buildPppoePasswordField(
            controller: _pppoePasswordController,
            isVisible: _pppoePasswordVisible,
            isError: _isPppoePasswordError,
            focusNode: _pppoePasswordFocusNode,
          ),
          errorText: _isPppoePasswordError ? _pppoePasswordErrorText : null,
          bottomInset: bottomInset,
        ),
      ],
    );
  }

  // ========== 以下為輔助方法 ==========

  // 構建連接類型下拉選擇框
  Widget _buildConnectionTypeDropdown() {
    final screenSize = MediaQuery.of(context).size;

    return Container(
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
    );
  }

  // 構建標籤和輸入字段
  Widget _buildLabelAndField({
    required String label,
    required bool isError,
    required Widget child,
    String? errorText,
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

  // 構建 PPPoE 文本輸入框
  Widget _buildPppoeTextField({
    required TextEditingController controller,
    required bool isError,
    required FocusNode focusNode,
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

  // 構建 PPPoE 密碼輸入框
  Widget _buildPppoePasswordField({
    required TextEditingController controller,
    required bool isVisible,
    required bool isError,
    required FocusNode focusNode,
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
  Widget _buildIpInputField(
      TextEditingController controller,
      String hintText,
      bool isError,
      FocusNode focusNode,
      ) {
    return SizedBox(
      width: double.infinity,
      height: AppDimensions.inputHeight,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
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