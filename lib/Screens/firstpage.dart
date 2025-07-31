import 'package:finmanager/Screens/Login.dart';
import 'package:finmanager/Screens/register.dart';
import 'package:flutter/material.dart';

class FirstPageDesign extends StatelessWidget {
  const FirstPageDesign({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Column(
        children: [
          // Logo Image Section
          Expanded(
            flex: 60,
            child: SizedBox(
              width: double.infinity,
              child: Image.asset("assets/logo.png", fit: BoxFit.fill),
            ),
          ),

          // Description Text Section
          Expanded(
            flex: 10,
            child: Container(
              width: double.infinity,
              color: isDarkMode ? Colors.grey[900] : Colors.orange[100],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Center(
                child: Text(
                  "Track your expenses, manage budgets, and visualize financial stats with your AI-powered FinManager.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: "Helvetica",
                    fontSize: 15,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ),

          // Login & Register Buttons Section
          Expanded(
            flex: 30,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Login Button
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPageDesign()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.deepOrange : Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      textStyle: const TextStyle(
                        fontFamily: "Helvetica",
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                      shadowColor: Colors.orangeAccent.withOpacity(0.5),
                    ),
                    child: const Text("Login"),
                  ),
                ),

                const SizedBox(height: 30),

                // Register Button
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context,'/register'
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.deepOrange : Colors.grey[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 10,
                      shadowColor: Colors.orangeAccent.withOpacity(0.5),
                    ),
                    child: const Text("Register"),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}