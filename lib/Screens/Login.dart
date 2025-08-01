import 'package:finmanager/Screens/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'dart:convert'; // Import for json encoding/decoding

class LoginPageDesign extends StatefulWidget {
  const LoginPageDesign({super.key});

  @override
  State<LoginPageDesign> createState() => _LoginPageDesignState();
}

class _LoginPageDesignState extends State<LoginPageDesign> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables for loading indicator and password visibility
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    // First, validate the form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show a loading indicator
    setState(() {
      _isLoading = true;
    });

    // --- CRITICAL: Use your computer's actual network IP address ---
    const String apiUrl =AppConfig.loginEndpoint;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );
      
      if (!mounted) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        // --- THIS IS THE FIX for the back button ---
        // Replace the login screen instead of just pushing the home screen on top.
        // This removes the back arrow on the HomeScreen AppBar.
        Navigator.pushReplacementNamed(context, '/home', arguments: {
          'user_id': responseData['user_id'], 
          'name': responseData['name'],
          'email': responseData['email'], // Ensure your Flask login endpoint returns this
          'phone_no': responseData['phone_no'], // Ensure Flask login endpoint returns this
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'An unknown error occurred.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to the server. Please check your IP and network.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Hide the loading indicator
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text("Login"),
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueGrey[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- MODIFIED: Increased height to 65% of the screen ---
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              width: double.infinity,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/login_image.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Login Form
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: "Email"),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible, // Use state variable
                      decoration: InputDecoration(
                        labelText: "Password",
                        // --- NEW: Password visibility toggle for better UX ---
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),

                    // Login Button
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 10,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
                            : const Text("Login"),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Register Redirect
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text("Don't have an account? Register"),
                    ),
                    const SizedBox(height: 20), // Extra padding at the bottom
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}