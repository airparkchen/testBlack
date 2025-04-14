import 'package:flutter/material.dart';

class ConnectionTypeComponent extends StatefulWidget {
  final Function(String, bool)? onSelectionChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;

  const ConnectionTypeComponent({
    Key? key,
    this.onSelectionChanged,
    this.onNextPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  State<ConnectionTypeComponent> createState() => _ConnectionTypeComponentState();
}

class _ConnectionTypeComponentState extends State<ConnectionTypeComponent> {
  String _selectedConnectionType = 'DHCP';
  bool _isFormComplete = true;

  final List<String> _connectionTypes = ['DHCP', 'Static IP', 'PPPoE'];

  @override
  void initState() {
    super.initState();
    // Using addPostFrameCallback to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifySelectionChanged();
    });
  }

  void _notifySelectionChanged() {
    if (widget.onSelectionChanged != null) {
      widget.onSelectionChanged!(
        _selectedConnectionType,
        _isFormComplete,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      width: screenSize.width * 0.9, // 寬度 90%
      height: screenSize.height * 0.25, // 高度 35%，比AccountPasswordComponent更簡潔
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: FittedBox(
        fit: BoxFit.scaleDown, // 內容超出時按比例縮小
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
              'Security Option',
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(2),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                  value: _selectedConnectionType,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.black),
                  iconSize: 24,
                  elevation: 16,
                  dropdownColor: Colors.white,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedConnectionType = newValue;
                      });
                      _notifySelectionChanged();
                    }
                  },
                  items: _connectionTypes.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}