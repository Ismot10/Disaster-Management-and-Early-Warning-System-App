import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_gradient_text/simple_gradient_text.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // fade-in duration
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Auto move to WelcomePage after fade-out
    Future.delayed(const Duration(seconds: 10), () async {
      await _controller.reverse(); // fade-out
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          Navigator.pushReplacementNamed(context, '/welcome');
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFEF39EB), Color(0xFF4539D2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Center Title (FlutterFlow style)
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: GradientText(
                    'AlertNova 1.0',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        const Shadow(
                          color: Color(0xFF1B1414),
                          offset: Offset(2.0, 2.0),
                          blurRadius: 2.0,
                        ),
                      ],
                    ),
                    colors: const [
                      Color(0xFFEF39B2),
                      Color(0xFF9A00FF),
                      Color(0xFF6139EF),
                      Colors.blue,
                      Color(0xFF367CF4),
                      Color(0xFF0082FF),
                      Color(0xFF3AA1B7),
                      Color(0xFF21F2F3),
                      Color(0xFF36F4DA),
                      Color(0xFFFF007D),
                    ],
                  ),
                ),
              ),
              // Bottom "tap anywhere"
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Text(
                    "<< tap anywhere to continue >>",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      fontSize: 16,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
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
