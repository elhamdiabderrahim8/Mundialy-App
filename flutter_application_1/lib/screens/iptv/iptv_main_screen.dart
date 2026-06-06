import 'package:flutter/material.dart';
import '../../services/iptv_service.dart';
import 'iptv_login_screen.dart';
import 'iptv_categories_screen.dart';

class IptvMainScreen extends StatefulWidget {
  const IptvMainScreen({super.key});

  @override
  State<IptvMainScreen> createState() => _IptvMainScreenState();
}

class _IptvMainScreenState extends State<IptvMainScreen> {
  final IptvService _iptvService = IptvService();
  bool _isInitialized = false;
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    await _iptvService.init();
    setState(() {
      _isConfigured = _iptvService.isConfigured;
      _isInitialized = true;
    });
  }

  void _onLoginSuccess() {
    setState(() {
      _isConfigured = true;
    });
  }

  void _onLogout() async {
    await _iptvService.logout();
    setState(() {
      _isConfigured = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isConfigured) {
      return IptvCategoriesScreen(
        iptvService: _iptvService,
        onLogout: _onLogout,
      );
    } else {
      return IptvLoginScreen(
        iptvService: _iptvService,
        onLoginSuccess: _onLoginSuccess,
      );
    }
  }
}
