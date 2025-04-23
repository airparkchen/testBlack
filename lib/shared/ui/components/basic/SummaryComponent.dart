import 'package:flutter/material.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';

class SummaryComponent extends StatefulWidget {
  // 接收所有設定的資料
  final String username;
  final String connectionType;
  final String ssid;
  final String securityOption;
  final String password;
  final StaticIpConfig? staticIpConfig; // 靜態 IP 配置

  // 新增 PPPoE 相關資訊
  final String? pppoeUsername;
  final String? pppoePassword;

  // 可選的回調函數
  final Function()? onNextPressed;
  final Function()? onBackPressed;

  const SummaryComponent({
    Key? key,
    this.username = '',
    this.connectionType = '',
    this.ssid = '',
    this.securityOption = '',
    this.password = '',
    this.staticIpConfig,
    this.pppoeUsername,
    this.pppoePassword,
    this.onNextPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  State<SummaryComponent> createState() => _SummaryComponentState();
}

class _SummaryComponentState extends State<SummaryComponent> {
  // 添加用於控制密碼可見性的狀態變數
  bool _wifiPasswordVisible = false;
  bool _pppoePasswordVisible = false;

  // 分隔線顏色
  final Color _dividerColor = const Color(0x1A000000); // #0000001A

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 根據可見性狀態決定如何顯示密碼
    final wifiPassword = widget.password.isNotEmpty
        ? (_wifiPasswordVisible ? widget.password : '•' * widget.password.length)
        : '(Not Set)';

    // PPPoE 密碼也使用星號顯示
    final pppoePassword = widget.pppoePassword != null && widget.pppoePassword!.isNotEmpty
        ? (_pppoePasswordVisible ? widget.pppoePassword! : '•' * widget.pppoePassword!.length)
        : '(Not Set)';

    return Container(
      width: screenSize.width * 0.9,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 使用者資訊
          if (widget.username.isNotEmpty) ...[
            _buildSettingTitle('Username'),
            _buildSettingValue(widget.username),
            _buildDivider(),
          ],

          // 連線類型
          if (widget.connectionType.isNotEmpty) ...[
            _buildSettingTitle('Connection Type'),
            _buildSettingValue(widget.connectionType),
            _buildDivider(),
          ],

          // 靜態 IP 相關設定
          if (widget.connectionType == 'Static IP' && widget.staticIpConfig != null) ...[
            _buildSettingTitle('IP Address'),
            _buildSettingValue(widget.staticIpConfig!.ipAddress),
            _buildDivider(),

            _buildSettingTitle('Subnet Mask'),
            _buildSettingValue(widget.staticIpConfig!.subnetMask),
            _buildDivider(),

            _buildSettingTitle('Gateway'),
            _buildSettingValue(widget.staticIpConfig!.gateway),
            _buildDivider(),

            _buildSettingTitle('Primary DNS'),
            _buildSettingValue(widget.staticIpConfig!.primaryDns),
            _buildDivider(),

            if (widget.staticIpConfig!.secondaryDns.isNotEmpty) ...[
              _buildSettingTitle('Secondary DNS'),
              _buildSettingValue(widget.staticIpConfig!.secondaryDns),
              _buildDivider(),
            ],
          ],

          // PPPoE 相關設定
          if (widget.connectionType == 'PPPoE' && widget.pppoeUsername != null) ...[
            _buildSettingTitle('PPPoE Username'),
            _buildSettingValue(widget.pppoeUsername!),
            _buildDivider(),

            _buildSettingTitle('PPPoE Password'),
            _buildSettingValueWithVisibility(
                pppoePassword,
                _pppoePasswordVisible,
                    () {
                  setState(() {
                    _pppoePasswordVisible = !_pppoePasswordVisible;
                  });
                }
            ),
            _buildDivider(),
          ],

          // 無線網路設定
          if (widget.ssid.isNotEmpty) ...[
            _buildSettingTitle('SSID'),
            _buildSettingValue(widget.ssid),
            _buildDivider(),
          ],

          if (widget.securityOption.isNotEmpty) ...[
            _buildSettingTitle('Security Option'),
            _buildSettingValue(widget.securityOption),
            _buildDivider(),
          ],

          if (widget.password.isNotEmpty) ...[
            _buildSettingTitle('Password'),
            _buildSettingValueWithVisibility(
                wifiPassword,
                _wifiPasswordVisible,
                    () {
                  setState(() {
                    _wifiPasswordVisible = !_wifiPasswordVisible;
                  });
                }
            ),
            // 最後一個項目後不需要分隔線
          ],

          const SizedBox(height: 30),

          // 底部提示
          const Text(
            'Press "Finish" to confirm the settings above',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 建立設定標題
  Widget _buildSettingTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // 建立設定值（縮進顯示）
  Widget _buildSettingValue(String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 15.0),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
        ),
      ),
    );
  }

  // 建立帶有顯示/隱藏功能的設定值（適用於密碼）
  Widget _buildSettingValueWithVisibility(String value, bool isVisible, VoidCallback onToggle) {
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, bottom: 15.0, right: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
          // 添加顯示/隱藏密碼的按鈕
          IconButton(
            icon: Icon(
              isVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }

  // 建立分隔線
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Divider(
        height: 1,
        thickness: 1,
        color: _dividerColor,
      ),
    );
  }
}