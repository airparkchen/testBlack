import 'package:flutter/material.dart';
import 'package:whitebox/shared/models/StaticIpConfig.dart';
import 'package:whitebox/shared/theme/app_theme.dart';

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

  // 新增高度參數
  final double? height;

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
    this.height, // 高度參數可選
  }) : super(key: key);

  @override
  State<SummaryComponent> createState() => _SummaryComponentState();
}

class _SummaryComponentState extends State<SummaryComponent> {
  // 添加用於控制密碼可見性的狀態變數
  bool _wifiPasswordVisible = false;
  bool _pppoePasswordVisible = false;
  final AppTheme _appTheme = AppTheme();
  final ScrollController _scrollController = ScrollController();

  // 密碼隱藏時顯示的固定數量星號
  final int _fixedHiddenSymbolsCount = 8;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 使用傳入的高度參數或默認值
    double cardHeight = widget.height ?? (screenSize.height * 0.45);

    // 鍵盤彈出時調整卡片高度（與 AccountPasswordComponent 保持一致）
    if (bottomInset > 0) {
      // 根據鍵盤高度調整卡片高度
      cardHeight = screenSize.height - bottomInset - 190; // 保留上方空間，這個值需要根據您的UI調整
      // 確保最小高度
      cardHeight = cardHeight < 300 ? 300 : cardHeight;
    }

    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight, // 確保使用計算後的高度
      child: Column(
        children: [
          // 標題區域(固定) - 與 AccountPasswordComponent 保持一致
          Container(
            padding: EdgeInsets.fromLTRB(25, bottomInset > 0 ? 15 : 25, 25, bottomInset > 0 ? 5 : 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Summary',
                style: TextStyle(
                  fontSize: bottomInset > 0 ? 18 : 22, // 鍵盤彈出時縮小字體
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // 可滾動的內容區域 - 與 AccountPasswordComponent 保持一致
          Expanded(
            child: _buildContent(bottomInset),
          ),
        ],
      ),
    );
  }

  // 分離內容構建，專注於可滾動性 - 與 AccountPasswordComponent 保持一致
  Widget _buildContent(double bottomInset) {
    // 根據可見性狀態決定如何顯示密碼 - 隱藏時固定顯示8個星號
    final wifiPassword = widget.password.isNotEmpty
        ? (_wifiPasswordVisible ? widget.password : '•' * _fixedHiddenSymbolsCount)
        : '(Not Set)';

    // PPPoE 密碼也使用固定長度星號顯示
    final pppoePassword = widget.pppoeUsername != null && widget.pppoePassword!.isNotEmpty
        ? (_pppoePasswordVisible ? widget.pppoePassword! : '•' * _fixedHiddenSymbolsCount)
        : '(Not Set)';

    return Padding(
      padding: EdgeInsets.fromLTRB(25, 10, 25, bottomInset > 0 ? 10 : 25), // 與 AccountPasswordComponent 保持一致
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ..._buildContentItems(wifiPassword, pppoePassword),

          // 鍵盤彈出時的額外空間 - 與 AccountPasswordComponent 保持一致
          if (bottomInset > 0)
            SizedBox(height: bottomInset * 0.5),
        ],
      ),
    );
  }

  // 構建內容項目列表
  List<Widget> _buildContentItems(String wifiPassword, String pppoePassword) {
    List<Widget> items = [];
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // 使用者資訊
    if (widget.username.isNotEmpty) {
      items.add(_buildSettingTitle('Username', bottomInset));
      items.add(_buildSettingValue(widget.username, bottomInset));
      items.add(_buildDivider(bottomInset));
    }

    // 連線類型
    if (widget.connectionType.isNotEmpty) {
      items.add(_buildSettingTitle('Connection Type', bottomInset));
      items.add(_buildSettingValue(widget.connectionType, bottomInset));
      items.add(_buildDivider(bottomInset));
    }

    // 靜態 IP 相關設定
    if (widget.connectionType == 'Static IP' && widget.staticIpConfig != null) {
      items.add(_buildSettingTitle('IP Address', bottomInset));
      items.add(_buildSettingValue(widget.staticIpConfig!.ipAddress, bottomInset));
      items.add(_buildDivider(bottomInset));

      items.add(_buildSettingTitle('Subnet Mask', bottomInset));
      items.add(_buildSettingValue(widget.staticIpConfig!.subnetMask, bottomInset));
      items.add(_buildDivider(bottomInset));

      items.add(_buildSettingTitle('Gateway', bottomInset));
      items.add(_buildSettingValue(widget.staticIpConfig!.gateway, bottomInset));
      items.add(_buildDivider(bottomInset));

      items.add(_buildSettingTitle('Primary DNS', bottomInset));
      items.add(_buildSettingValue(widget.staticIpConfig!.primaryDns, bottomInset));
      items.add(_buildDivider(bottomInset));

      if (widget.staticIpConfig!.secondaryDns.isNotEmpty) {
        items.add(_buildSettingTitle('Secondary DNS', bottomInset));
        items.add(_buildSettingValue(widget.staticIpConfig!.secondaryDns, bottomInset));
        items.add(_buildDivider(bottomInset));
      }
    }

    // PPPoE 相關設定
    if (widget.connectionType == 'PPPoE' && widget.pppoeUsername != null) {
      items.add(_buildSettingTitle('PPPoE Username', bottomInset));
      items.add(_buildSettingValue(widget.pppoeUsername!, bottomInset));
      items.add(_buildDivider(bottomInset));

      items.add(_buildSettingTitle('PPPoE Password', bottomInset));
      items.add(_buildSettingValueWithVisibility(
        pppoePassword,
        _pppoePasswordVisible,
            () {
          setState(() {
            _pppoePasswordVisible = !_pppoePasswordVisible;
          });
        },
        bottomInset,
      ));
      items.add(_buildDivider(bottomInset));
    }

    // 無線網路設定
    if (widget.ssid.isNotEmpty) {
      items.add(_buildSettingTitle('SSID', bottomInset));
      items.add(_buildSettingValue(widget.ssid, bottomInset));
      items.add(_buildDivider(bottomInset));
    }

    if (widget.securityOption.isNotEmpty) {
      items.add(_buildSettingTitle('Security Option', bottomInset));
      items.add(_buildSettingValue(widget.securityOption, bottomInset));
      items.add(_buildDivider(bottomInset));
    }

    if (widget.password.isNotEmpty) {
      items.add(_buildSettingTitle('Password', bottomInset));
      items.add(_buildSettingValueWithVisibility(
        wifiPassword,
        _wifiPasswordVisible,
            () {
          setState(() {
            _wifiPasswordVisible = !_wifiPasswordVisible;
          });
        },
        bottomInset,
      ));
      // 最後一個項目後不需要分隔線
    }

    return items;
  }

  // 建立設定標題 - 新增響應式字體大小
  Widget _buildSettingTitle(String title, double bottomInset) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: bottomInset > 0 ? 14 : 16, // 鍵盤彈出時縮小字體
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // 建立設定值（縮進顯示）- 新增響應式字體大小
  Widget _buildSettingValue(String value, double bottomInset) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        bottom: bottomInset > 0 ? 10.0 : 15.0, // 鍵盤彈出時縮小間距
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: bottomInset > 0 ? 14 : 16, // 鍵盤彈出時縮小字體
          color: Colors.white,
        ),
      ),
    );
  }

  // 建立帶有顯示/隱藏功能的設定值（適用於密碼）- 新增響應式設計
  Widget _buildSettingValueWithVisibility(String value, bool isVisible, VoidCallback onToggle, double bottomInset) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.0,
        bottom: bottomInset > 0 ? 10.0 : 15.0, // 鍵盤彈出時縮小間距
        right: 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: bottomInset > 0 ? 14 : 16, // 鍵盤彈出時縮小字體
                color: Colors.white,
              ),
            ),
          ),
          // 添加顯示/隱藏密碼的按鈕
          IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white,
              size: bottomInset > 0 ? 22 : 25, // 鍵盤彈出時縮小圖標
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
  Widget _buildDivider(double bottomInset) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset > 0 ? 10.0 : 15.0), // 鍵盤彈出時縮小間距
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.primary.withOpacity(0.7), // 使用 AppColors.primary 半透明顏色
      ),
    );
  }
}