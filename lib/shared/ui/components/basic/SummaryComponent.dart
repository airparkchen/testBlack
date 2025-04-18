import 'package:flutter/material.dart';

class SummaryComponent extends StatelessWidget {
  // 接收所有設定的資料
  final String username;
  final String connectionType;
  final String ssid;
  final String securityOption;
  final String password;

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
    this.onNextPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 建立一個密碼顯示字串，只顯示星號
    final maskedPassword = password.isNotEmpty
        ? '•' * password.length
        : '(未設置)';

    return Container(
      width: screenSize.width * 0.9,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '設定摘要',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),

          // 使用者資訊區塊
          if (username.isNotEmpty) _buildSectionTitle('帳戶資訊'),
          if (username.isNotEmpty) _buildInfoItem('使用者名稱', username),
          if (username.isNotEmpty) const SizedBox(height: 20),

          // 連線方式區塊
          if (connectionType.isNotEmpty) _buildSectionTitle('網路連線'),
          if (connectionType.isNotEmpty) _buildInfoItem('連線類型', connectionType),
          if (connectionType.isNotEmpty) const SizedBox(height: 20),

          // 無線網路設定區塊
          if (ssid.isNotEmpty || securityOption.isNotEmpty) _buildSectionTitle('無線網路'),
          if (ssid.isNotEmpty) _buildInfoItem('SSID', ssid),
          if (securityOption.isNotEmpty) _buildInfoItem('安全選項', securityOption),
          if (password.isNotEmpty) _buildInfoItem('密碼', maskedPassword),

          const SizedBox(height: 30),

          // 底部提示
          const Text(
            '按「完成」鍵確認以上設定',
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

  // 建立區段標題
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // 建立資訊項目
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}