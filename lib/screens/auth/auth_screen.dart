import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _landmarkCtl = TextEditingController();
  final _pincodeCtl = TextEditingController();
  final _areaCtl = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _landmarkCtl.dispose();
    _pincodeCtl.dispose();
    _areaCtl.dispose();
    super.dispose();
  }

  Future<void> _fetchAreaFromPincode(String pincode) async {
    if (pincode.length != 6) return;
    try {
      final response = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pincode'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOfficeList = data[0]['PostOffice'] as List;
          if (postOfficeList.isNotEmpty) {
            String areaName = postOfficeList[0]['Name'];
            setState(() {
              _areaCtl.text = areaName;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching area: $e");
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    
    // Validation
    if (!_isLogin) {
      if (_nameCtl.text.trim().isEmpty ||
          _emailCtl.text.trim().isEmpty ||
          _passwordCtl.text.isEmpty ||
          _phoneCtl.text.trim().isEmpty ||
          _addressCtl.text.trim().isEmpty ||
          _landmarkCtl.text.trim().isEmpty ||
          _pincodeCtl.text.trim().isEmpty ||
          _areaCtl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All fields are mandatory for signup')));
        setState(() => _isLoading = false);
        return;
      }
    } else {
      if (_emailCtl.text.trim().isEmpty || _passwordCtl.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email and Password are required')));
        setState(() => _isLoading = false);
        return;
      }
    }

    try {
      final auth = context.read<AuthProvider>();
      if (_isLogin) {
        await auth.signIn(email: _emailCtl.text.trim(), password: _passwordCtl.text);
      } else {
        final res = await auth.signUp(
          email: _emailCtl.text.trim(),
          password: _passwordCtl.text,
          fullName: _nameCtl.text.trim(),
          phone: _phoneCtl.text.trim(),
          address: _addressCtl.text.trim(),
          landmark: _landmarkCtl.text.trim(),
          pincode: _pincodeCtl.text.trim(),
          area: _areaCtl.text.trim(),
        );

        if (res.session == null && res.user != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Signup successful. Please verify your account via email to login.'),
            duration: Duration(seconds: 5),
          ));
          setState(() {
            _isLogin = true;
          });
          return;
        }
      }
      
      if (!mounted) return;
      await auth.fetchProfile();
      if (!mounted) return;
      
      if (auth.isAdmin) {
        context.go('/admin');
      } else {
        context.go('/customer');
      }
    } on AuthException catch (e) {
      if (e.message.contains('Email not confirmed') || e.message.contains('email_not_confirmed')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Account not verified. Please check your email to verify your account.'),
          backgroundColor: Colors.redAccent,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo.png', width: 80, height: 80),
                const SizedBox(height: 16),
                Text(
                  _isLogin ? 'SAAPADU BOX' : 'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_isLogin)
                  TextField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                if (!_isLogin)
                  TextField(
                    controller: _phoneCtl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                if (!_isLogin)
                  TextField(
                    controller: _addressCtl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                if (!_isLogin)
                  TextField(
                    controller: _landmarkCtl,
                    decoration: const InputDecoration(labelText: 'Landmark', border: OutlineInputBorder()),
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                if (!_isLogin)
                  TextField(
                    controller: _pincodeCtl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(labelText: 'Pincode', border: OutlineInputBorder(), counterText: ''),
                    onChanged: (val) {
                      if (val.length == 6) {
                        _fetchAreaFromPincode(val);
                      }
                    },
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                if (!_isLogin)
                  TextField(
                    controller: _areaCtl,
                    decoration: const InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                  ),
                if (!_isLogin) const SizedBox(height: 16),
                TextField(
                  controller: _emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordCtl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Text(_isLogin ? 'Login' : 'Sign Up'),
                      ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Don\'t have an account? Sign Up' : 'Already have an account? Login'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
