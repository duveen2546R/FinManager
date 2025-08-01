import 'package:finmanager/Screens/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Import the http package
import 'dart:convert'; // Import for json encoding/decoding

class RegisterPageDesign extends StatefulWidget {
  const RegisterPageDesign({super.key});

  @override
  State<RegisterPageDesign> createState() => _RegisterPageDesignState();
}

class _RegisterPageDesignState extends State<RegisterPageDesign> {
  // A GlobalKey to uniquely identify the Form widget and allow validation.
  final _formKey = GlobalKey<FormState>();

  // Controllers to get the text from the input fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // State variables for loading indicator and password visibility
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _register() async {
    // Validate the form. If it's not valid, do nothing.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Show a loading indicator
    setState(() {
      _isLoading = true;
    });

    // !! IMPORTANT !!
    // Replace with your computer's local IP address.
    const String apiUrl = AppConfig.registerEndpoint; // <--- USE YOUR IP

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text,
          'phone_no': _phoneController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
        }),
      );

      // Check if the widget is still mounted before using context
      if (!mounted) return;

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) { // 201 Created is the standard for successful POST requests
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
        // Go back to the previous screen (login/first page) after successful registration
        Navigator.of(context).pop();
      } else {
        // Show an error message from the backend (e.g., "User already exists")
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message'] ?? 'Registration failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not connect to the server. Please try again later.'),
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
    // Clean up the controllers to free up resources
    _nameController.dispose();
    _phoneController.dispose();
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
        title: const Text("Register"),
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.blueGrey,
        foregroundColor: Colors.white,
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
                    // Assuming you have an image named 'register_image.png' in your assets
                    image: AssetImage("assets/register_image.png"), 
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Form Fields
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: "Name"),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone Number"),
                      // Phone number validation is optional as per the schema
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Email"),
                      validator: (value) {
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: "Password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDarkMode ? Colors.grey[850] : Colors.blueGrey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 10,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Register"),
                      ),
                    ),
                    const SizedBox(height: 20), // Extra padding at the bottom for better scrolling
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