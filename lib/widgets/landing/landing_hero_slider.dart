import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class BannerSlideData {
  final String imagePath;
  final String title;
  final String subtitle;
  final String badge;

  const BannerSlideData({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}

class LandingHeroSlider extends StatefulWidget {
  const LandingHeroSlider({super.key});

  @override
  State<LandingHeroSlider> createState() => _LandingHeroSliderState();
}

class _LandingHeroSliderState extends State<LandingHeroSlider> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isHovered = false;
  Timer? _timer;

  static const List<BannerSlideData> _slides = [
    BannerSlideData(
      imagePath: 'assets/images/ams1.png',
      title: 'AI Facial Recognition Attendance Scanner',
      subtitle: 'Lightning-fast contactless identity verification with real-time sync',
      badge: '⚡ AI Face Recognition Scanner',
    ),
    BannerSlideData(
      imagePath: 'assets/images/ams2.png',
      title: 'Smart Biometric & NFC Check-In Terminal',
      subtitle: 'Enterprise-grade biometric access point with cloud synchronization',
      badge: '💳 Smart Biometric Card Terminal',
    ),
    BannerSlideData(
      imagePath: 'assets/images/ams3.png',
      title: 'Contactless Mobile QR Code Attendance',
      subtitle: 'Dynamic QR geo-fenced check-in for modern workplace teams',
      badge: '📱 Mobile QR Attendance System',
    ),
    BannerSlideData(
      imagePath: 'assets/images/ams4.png',
      title: 'Enterprise Live Analytics & Fleet Monitor',
      subtitle: 'Instant workforce distribution insights and activity heatmaps',
      badge: '📊 Real-Time Operations Hub',
    ),
    BannerSlideData(
      imagePath: 'assets/images/ams5.png',
      title: 'Automated Shift & Leave Management',
      subtitle: 'AI-assisted scheduling with automated overtime calculation',
      badge: '⏱️ Automated Shift Engine',
    ),
    BannerSlideData(
      imagePath: 'assets/images/ams6.png',
      title: 'Bank-Grade Encrypted Cloud Security',
      subtitle: 'Role-based access governance with audit trails & compliance',
      badge: '🔒 Enterprise Cloud Security',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final next = (_currentIndex + 1) % _slides.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _prevSlide() {
    _timer?.cancel();
    final prev = (_currentIndex - 1 + _slides.length) % _slides.length;
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _startTimer();
  }

  void _nextSlide() {
    _timer?.cancel();
    final next = (_currentIndex + 1) % _slides.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                  : const Color(0xFF4F46E5).withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // PageView Slides
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background Image
                      Image.asset(
                        slide.imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                                    : [const Color(0xFFE0E7FF), const Color(0xFFC7D2FE)],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.devices_rounded,
                                size: 48,
                                color: AppColors.primary.withValues(alpha: 0.6),
                              ),
                            ),
                          );
                        },
                      ),

                      // Ambient Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),

                      // Slide Content
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                slide.badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Title
                            Text(
                              slide.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),

                            // Subtitle
                            Text(
                              slide.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Left arrow (Shows on Hover)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: !_isHovered,
                      child: InkWell(
                        onTap: _prevSlide,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Right arrow (Shows on Hover)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: IgnorePointer(
                      ignoring: !_isHovered,
                      child: InkWell(
                        onTap: _nextSlide,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Indicator Dots
            Positioned(
              right: 16,
              top: 14,
              child: Row(
                children: List.generate(_slides.length, (idx) {
                  final isActive = idx == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: isActive ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
