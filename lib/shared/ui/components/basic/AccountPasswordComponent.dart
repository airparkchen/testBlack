import 'package:flutter/material.dart';

class AccountPasswordComponent extends StatefulWidget {
  final Function(String, String, String, bool)? onFormChanged;
  final Function()? onNextPressed;
  final Function()? onBackPressed;

  const AccountPasswordComponent({
    Key? key,
    this.onFormChanged,
    this.onNextPressed,
    this.onBackPressed,
  }) : super(key: key);

  @override
  State<AccountPasswordComponent> createState() => _AccountPasswordComponentState();
}

class _AccountPasswordComponentState extends State<AccountPasswordComponent> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _userController.addListener(_notifyFormChanged);
    _passwordController.addListener(_notifyFormChanged);
    _confirmPasswordController.addListener(_notifyFormChanged);
  }

  @override
  void dispose() {
    _userController.removeListener(_notifyFormChanged);
    _passwordController.removeListener(_notifyFormChanged);
    _confirmPasswordController.removeListener(_notifyFormChanged);
    _userController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _notifyFormChanged() {
    if (widget.onFormChanged != null) {
      widget.onFormChanged!(
        _userController.text,
        _passwordController.text,
        _confirmPasswordController.text,
        false, // 不再傳遞表單完成狀態，交由 TestPage 控制
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Container(
      width: screenSize.width * 0.9,
      height: screenSize.height * 0.50,
      color: const Color(0xFFEFEFEF),
      padding: const EdgeInsets.all(25.0),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: screenSize.width * 0.9,
              child: TextFormField(
                controller: _userController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  errorStyle: const TextStyle(fontSize: 12),
                ),
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: screenSize.width * 0.9,
              child: TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  errorStyle: const TextStyle(fontSize: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passwordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                      size: 20,
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
            const SizedBox(height: 24),
            const Text(
              'Confirm Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: screenSize.width * 0.9,
              child: TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_confirmPasswordVisible,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Color(0xFFEFEFEF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                  errorStyle: const TextStyle(fontSize: 12),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _confirmPasswordVisible = !_confirmPasswordVisible;
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
    );
  }
}