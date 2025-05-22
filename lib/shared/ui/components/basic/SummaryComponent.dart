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
  final ScrollController _scrollController = ScrollController(); // 添加滾動控制器

  // 密碼隱藏時顯示的固定數量星號
  final int _fixedHiddenSymbolsCount = 8;

  // 分隔線顏色
  final Color _dividerColor = const Color(0x1A000000); // #0000001A

  @override
  void dispose() {
    _scrollController.dispose(); // 處理滾動控制器
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 使用傳入的高度參數或默認值
    double cardHeight = widget.height ?? (screenSize.height * 0.45); // 與其他組件保持一致的高度比例

    // 根據可見性狀態決定如何顯示密碼 - 隱藏時固定顯示8個星號
    final wifiPassword = widget.password.isNotEmpty
        ? (_wifiPasswordVisible ? widget.password : '•' * _fixedHiddenSymbolsCount)
        : '(Not Set)';

    // PPPoE 密碼也使用固定長度星號顯示
    final pppoePassword = widget.pppoePassword != null && widget.pppoePassword!.isNotEmpty
        ? (_pppoePasswordVisible ? widget.pppoePassword! : '•' * _fixedHiddenSymbolsCount)
        : '(Not Set)';

    return _appTheme.whiteBoxTheme.buildStandardCard(
      width: screenSize.width * 0.9,
      height: cardHeight,
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _buildContentItems(wifiPassword, pppoePassword),
          ),
        ),
      ),
    );
  }

// 構建內容項目列表
  List<Widget> _buildContentItems(String wifiPassword, String pppoePassword) {
    List<Widget> items = [];

    // 使用者資訊
    if (widget.username.isNotEmpty) {
      items.add(_buildSettingTitle('Username'));
      items.add(_buildSettingValue(widget.username));
      items.add(_buildDivider());
    }

    // 連線類型
    if (widget.connectionType.isNotEmpty) {
      items.add(_buildSettingTitle('Connection Type'));
      items.add(_buildSettingValue(widget.connectionType));
      items.add(_buildDivider());
    }

    // 靜態 IP 相關設定
    if (widget.connectionType == 'Static IP' && widget.staticIpConfig != null) {
      items.add(_buildSettingTitle('IP Address'));
      items.add(_buildSettingValue(widget.staticIpConfig!.ipAddress));
      items.add(_buildDivider());

      items.add(_buildSettingTitle('Subnet Mask'));
      items.add(_buildSettingValue(widget.staticIpConfig!.subnetMask));
      items.add(_buildDivider());

      items.add(_buildSettingTitle('Gateway'));
      items.add(_buildSettingValue(widget.staticIpConfig!.gateway));
      items.add(_buildDivider());

      items.add(_buildSettingTitle('Primary DNS'));
      items.add(_buildSettingValue(widget.staticIpConfig!.primaryDns));
      items.add(_buildDivider());

      if (widget.staticIpConfig!.secondaryDns.isNotEmpty) {
        items.add(_buildSettingTitle('Secondary DNS'));
        items.add(_buildSettingValue(widget.staticIpConfig!.secondaryDns));
        items.add(_buildDivider());
      }
    }

    // PPPoE 相關設定
    if (widget.connectionType == 'PPPoE' && widget.pppoeUsername != null) {
      items.add(_buildSettingTitle('PPPoE Username'));
      items.add(_buildSettingValue(widget.pppoeUsername!));
      items.add(_buildDivider());

      items.add(_buildSettingTitle('PPPoE Password'));
      items.add(_buildSettingValueWithVisibility(
        pppoePassword,
        _pppoePasswordVisible,
            () {
          setState(() {
            _pppoePasswordVisible = !_pppoePasswordVisible;
          });
        },
      ));
      items.add(_buildDivider());
    }

    // 無線網路設定
    if (widget.ssid.isNotEmpty) {
      items.add(_buildSettingTitle('SSID'));
      items.add(_buildSettingValue(widget.ssid));
      items.add(_buildDivider());
    }

    if (widget.securityOption.isNotEmpty) {
      items.add(_buildSettingTitle('Security Option'));
      items.add(_buildSettingValue(widget.securityOption));
      items.add(_buildDivider());
    }

    if (widget.password.isNotEmpty) {
      items.add(_buildSettingTitle('Password'));
      items.add(_buildSettingValueWithVisibility(
        wifiPassword,
        _wifiPasswordVisible,
            () {
          setState(() {
            _wifiPasswordVisible = !_wifiPasswordVisible;
          });
        },
      ));
      // 最後一個項目後不需要分隔線
    }

    return items;
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
          color: Colors.white,
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
          color: Colors.white,
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
                color: Colors.white,
              ),
            ),
          ),
          // 添加顯示/隱藏密碼的按鈕
          IconButton(
            icon: Icon(
              isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.white,
              size: 25,
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
        color: AppColors.primary.withOpacity(0.7), // 使用 AppColors.primary 半透明顏色
      ),
    );
  }
}