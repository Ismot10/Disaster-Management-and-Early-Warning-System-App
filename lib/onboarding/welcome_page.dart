import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme colors for easier usage
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo (emoji for now)
              const Text("🌍", style: TextStyle(fontSize: 64)),
              const SizedBox(height: 60),

              // Welcome word in bar
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withAlpha(25), // dark-mode safe
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "Welcome",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "AlertNova 1.0 - Disaster Prediction & Early Warning System\n\n\nWelcome to AlertNova 1.0 !",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.redAccent,
                ), // adapts to theme
              ),

              const SizedBox(height: 2),

              Text(
                "\n\nTo work optimally, this app requires some permissions. This process should only take a minute. Tap Next to proceed.",
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurface, // dark-mode safe
                ),
              ),

              const Spacer(),

              // Next button bar at bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.66, // 2/3 width
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary, // theme aware
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/location');
                    },
                    child: Text(
                      "Next",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white, // contrasts primary
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
