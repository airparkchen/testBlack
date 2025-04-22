import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';

class ConnectionTypeComponent extends StatefulWidget {
  final Function(String, bool, StaticIpConfig?)? onSelectionChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;
  // 新增顯示選項參數
  final List<String> displayOptions;

  const ConnectionTypeComponent({
    Key? key,
    this.onSelectionChanged,
    this.onNextPressed,
    this.onBackPressed,
    // 預設顯示所有選項
    this.displayOptions = const ['DHCP', 'Static IP', 'PPPoE'],
  }) : super(key: key);

  @override
  State<ConnectionTypeComponent> createState() => _ConnectionTypeComponentState();
}

class _ConnectionTypeComponentState extends State<ConnectionTypeComponent> {
  String _selectedConnectionType = '';
  bool _isFormComplete = false;
  StaticIpConfig _staticIpConfig = StaticIpConfig();

  // 用於 IP 相關輸入的控制器
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _subnetController = TextEditingController();
  final TextEditingController _gatewayController = TextEditingController();
  final TextEditingController _primaryDnsController = TextEditingController();
  final TextEditingController _secondaryDnsController = TextEditingController();

  // 滾動控制器
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    // 初始化選擇第一個選項
    if (widget.displayOptions.isNotEmpty) {
      _selectedConnectionType = widget.displayOptions.first;
      _isFormComplete = true;
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
    _scrollController.dispose();
    super.dispose();
  }

  // 為所有輸入控制器設置監聽器
  void _setupControllerListeners() {
    _ipController.addListener(() {
      _staticIpConfig.ipAddress = _ipController.text;
      _validateForm();
    });

    _subnetController.addListener(() {
      _staticIpConfig.subnetMask = _subnetController.text;
      _validateForm();
    });

    _gatewayController.addListener(() {
      _staticIpConfig.gateway = _gatewayController.text;
      _validateForm();
    });

    _primaryDnsController.addListener(() {
      _staticIpConfig.primaryDns = _primaryDnsController.text;
      _validateForm();
    });

    _secondaryDnsController.addListener(() {
      _staticIpConfig.secondaryDns = _secondaryDnsController.text;
      _validateForm();
    });
  }

  // 驗證表單
  void _validateForm() {
    bool isValid = true;

    if (_selectedConnectionType == 'Static IP') {
      isValid = _validateIpFormat(_staticIpConfig.ipAddress) &&
          _validateIpFormat(_staticIpConfig.subnetMask) &&
          _validateIpFormat(_staticIpConfig.gateway) &&
          _validateIpFormat(_staticIpConfig.primaryDns);

      // 次要 DNS 是選填的，只有填了才檢查格式
      if (_staticIpConfig.secondaryDns.isNotEmpty && !_validateIpFormat(_staticIpConfig.secondaryDns)) {
        isValid = false;
      }
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
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 移除固定高度，改用 ConstrainedBox 限制最小高度
    return Container(
      width: screenSize.width * 0.9, // 寬度 90%
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      // 使用 LayoutBuilder 來獲取父容器約束
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 計算可用高度
          final availableHeight = constraints.maxHeight;

          return LimitedBox(
            maxHeight: _selectedConnectionType == 'Static IP'
                ? screenSize.height * 0.75  // 靜態 IP 時，增加最大高度限制
                : screenSize.height * 0.25,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(), // 確保始終可滾動
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // 給內容一個最小高度，確保可以滾動
                  minHeight: _selectedConnectionType == 'Static IP'
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
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Connection Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: screenSize.width * 0.9, // 限制輸入框寬度，適應縮放
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
                            value: _selectedConnectionType,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                            iconSize: 24,
                            elevation: 16,
                            dropdownColor: const Color(0xFFEFEFEF),
                            onChanged: (String? newValue) {
                              if (newValue != null && newValue != _selectedConnectionType) {
                                setState(() {
                                  _selectedConnectionType = newValue;
                                  _isFormComplete = newValue != 'Static IP'; // 如果不是靜態 IP，則表單完成
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
                      ),

                      // 如果選擇了 Static IP，顯示額外的輸入欄位
                      if (_selectedConnectionType == 'Static IP') ...[
                        const SizedBox(height: 20),

                        // IP Address
                        const Text(
                          'IP Address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIpInputField(_ipController, '            .            .            .            '),

                        const SizedBox(height: 20),

                        // Subnet Mask
                        const Text(
                          'IP Subnet Mask',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIpInputField(_subnetController, '            .            .            .            '),

                        const SizedBox(height: 20),

                        // Gateway
                        const Text(
                          'Gateway IP Address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIpInputField(_gatewayController, '            .            .            .            '),

                        const SizedBox(height: 20),

                        // Primary DNS
                        const Text(
                          'Primary DNS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIpInputField(_primaryDnsController, '            .            .            .            '),

                        const SizedBox(height: 20),

                        // Secondary DNS
                        const Text(
                          'Secondary DNS (Optional)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildIpInputField(_secondaryDnsController, '            .            .            .            '),

                        // 添加額外的底部空間，確保滾動到底部時看得到最後一個輸入框
                        const SizedBox(height: 250),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 構建一體式 IP 輸入欄位，包含點分隔顯示
  Widget _buildIpInputField(TextEditingController controller, String hintText) {
    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFEFEFEF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(2),
          ),
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        style: const TextStyle(fontSize: 16),
        inputFormatters: [
          _IpAddressInputFormatter(),
        ],
      ),
    );
  }
}

// 自定義輸入格式化器，處理 IP 地址輸入並自動加入點分隔符
class _IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // 如果刪除操作，允許刪除
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    String text = newValue.text;

    // 移除所有非數字和點的字符
    text = text.replaceAll(RegExp(r'[^\d.]'), '');

    // 保證不會有兩個以上的連續點
    text = text.replaceAll(RegExp(r'\.{2,}'), '.');

    // 拆分為各部分
    List<String> parts = text.split('.');

    // 最多只能有 4 個部分
    if (parts.length > 4) {
      parts = parts.sublist(0, 4);
    }

    // 限制每個部分最多 3 個字符，且最大值為 255
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].length > 3) {
        parts[i] = parts[i].substring(0, 3);
      }

      // 確保數值在 0-255 範圍內
      int? value = int.tryParse(parts[i]);
      if (value != null && value > 255) {
        parts[i] = '255';
      }
    }

    // 重新組合文本
    text = parts.join('.');

    // 確保最後一個字符不是點
    if (text.endsWith('.') && oldValue.text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }

    // 如果輸入的數字達到了 3 位且不是最後一部分，自動添加點
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