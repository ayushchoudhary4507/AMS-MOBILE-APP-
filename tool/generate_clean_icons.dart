import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Generates crystal-clear Attendance Pro squircle launcher & splash icons
void main() {
  const masterSize = 1024;
  final masterImg = img.Image(width: masterSize, height: masterSize, numChannels: 4);

  // Background: Transparent
  img.fill(masterImg, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw rounded squircle
  final pad = 40;
  final sqSize = masterSize - pad * 2; // 944x944
  final cornerRadius = (sqSize * 0.24).round(); // 226px

  // Draw gradient squircle: Indigo to Violet gradient
  final c1 = [99, 102, 241]; // #6366F1
  final c2 = [79, 70, 229];  // #4F46E5
  final c3 = [124, 58, 237]; // #7C3AED

  for (int y = pad; y < pad + sqSize; y++) {
    for (int x = pad; x < pad + sqSize; x++) {
      // Check rounded corner distance
      int dx = 0;
      int dy = 0;
      if (x < pad + cornerRadius) {
        dx = (pad + cornerRadius) - x;
      } else if (x > pad + sqSize - cornerRadius) dx = x - (pad + sqSize - cornerRadius);

      if (y < pad + cornerRadius) {
        dy = (pad + cornerRadius) - y;
      } else if (y > pad + sqSize - cornerRadius) dy = y - (pad + sqSize - cornerRadius);

      if (dx > 0 && dy > 0) {
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > cornerRadius) continue; // outside corner
        if (dist > cornerRadius - 1.5) {
          // Antialias edge
          final alpha = ((cornerRadius - dist) / 1.5).clamp(0.0, 1.0);
          final t = ((x - pad) + (y - pad)) / (sqSize * 2.0);
          final r = (c1[0] * (1 - t) + c3[0] * t).round();
          final g = (c1[1] * (1 - t) + c3[1] * t).round();
          final b = (c1[2] * (1 - t) + c3[2] * t).round();
          masterImg.setPixel(x, y, img.ColorRgba8(r, g, b, (alpha * 255).round()));
          continue;
        }
      }

      final t = ((x - pad) + (y - pad)) / (sqSize * 2.0);
      final r = (c1[0] * (1 - t) + c3[0] * t).round();
      final g = (c1[1] * (1 - t) + c3[1] * t).round();
      final b = (c1[2] * (1 - t) + c3[2] * t).round();
      masterImg.setPixel(x, y, img.ColorRgba8(r, g, b, 255));
    }
  }

  // Draw White Fingerprint Arcs & Text
  // Center is (512, 420)
  final cx = 512.0;
  final cy = 390.0;
  final white = img.ColorRgba8(255, 255, 255, 255);

  void drawThickArc(double radiusX, double radiusY, double startAngle, double endAngle, int thickness) {
    for (double a = startAngle; a <= endAngle; a += 0.005) {
      final px = cx + radiusX * math.cos(a);
      final py = cy + radiusY * math.sin(a);
      for (int tx = -thickness; tx <= thickness; tx++) {
        for (int ty = -thickness; ty <= thickness; ty++) {
          if (tx * tx + ty * ty <= thickness * thickness) {
            final ix = (px + tx).round();
            final iy = (py + ty).round();
            if (ix >= 0 && ix < masterSize && iy >= 0 && iy < masterSize) {
              masterImg.setPixel(ix, iy, white);
            }
          }
        }
      }
    }
  }

  // Outer Arc
  drawThickArc(200, 180, math.pi, math.pi * 2, 18);
  // Middle Arc
  drawThickArc(140, 125, math.pi * 0.95, math.pi * 2.05, 18);
  // Inner Loop Arc
  drawThickArc(80, 75, math.pi * 0.9, math.pi * 2.1, 18);

  // Vertical center bar
  for (int y = 390; y <= 520; y++) {
    for (int x = 512 - 18; x <= 512 + 18; x++) {
      masterImg.setPixel(x, y, white);
    }
  }
  // Side loop bars
  for (int y = 390; y <= 500; y++) {
    for (int x = (512 - 80 - 18); x <= (512 - 80 + 18); x++) {
      masterImg.setPixel(x, y, white);
    }
    for (int x = (512 + 80 - 18); x <= (512 + 80 + 18); x++) {
      masterImg.setPixel(x, y, white);
    }
  }

  // Draw AMS Text block
  // Draw A
  void drawBlock(int x1, int y1, int x2, int y2) {
    for (int y = y1; y <= y2; y++) {
      for (int x = x1; x <= x2; x++) {
        if (x >= 0 && x < masterSize && y >= 0 && y < masterSize) {
          masterImg.setPixel(x, y, white);
        }
      }
    }
  }

  // Render AMS block lettering at bottom (Y ~ 620 to 780)
  // 'A' (X: 250 to 390)
  drawBlock(250, 620, 285, 780); // left bar
  drawBlock(355, 620, 390, 780); // right bar
  drawBlock(250, 620, 390, 655); // top bar
  drawBlock(250, 695, 390, 730); // cross bar

  // 'M' (X: 430 to 594)
  drawBlock(430, 620, 465, 780); // left bar
  drawBlock(559, 620, 594, 780); // right bar
  drawBlock(495, 660, 530, 780); // center bar
  drawBlock(430, 620, 594, 655); // top bar

  // 'S' (X: 635 to 775)
  drawBlock(635, 620, 775, 655); // top bar
  drawBlock(635, 620, 670, 700); // top left
  drawBlock(635, 685, 775, 720); // middle bar
  drawBlock(740, 705, 775, 780); // bottom right
  drawBlock(635, 745, 775, 780); // bottom bar

  // Save clean assets
  final logoFile = File('assets/images/attendance_pro_logo.png');
  logoFile.writeAsBytesSync(img.encodePng(masterImg));
  File('assets/images/app_logo.png').writeAsBytesSync(img.encodePng(masterImg));
  print('Saved clean master logo to ${logoFile.path}');

  // Generate mipmaps
  final standardSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  final foregroundSizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };

  final resDir = Directory('android/app/src/main/res');

  standardSizes.forEach((folder, size) {
    final folderDir = Directory('${resDir.path}/$folder');
    if (!folderDir.existsSync()) folderDir.createSync(recursive: true);

    final resized = img.copyResize(masterImg, width: size, height: size, interpolation: img.Interpolation.linear);
    File('${folderDir.path}/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));
    File('${folderDir.path}/ic_launcher_round.png').writeAsBytesSync(img.encodePng(resized));
  });

  foregroundSizes.forEach((folder, fgSize) {
    final folderDir = Directory('${resDir.path}/$folder');
    if (!folderDir.existsSync()) folderDir.createSync(recursive: true);

    final fgCanvas = img.Image(width: fgSize, height: fgSize, numChannels: 4);
    final iconInnerSize = (fgSize * 0.76).round();
    final resizedInner = img.copyResize(masterImg, width: iconInnerSize, height: iconInnerSize, interpolation: img.Interpolation.linear);

    final posX = ((fgSize - iconInnerSize) / 2).round();
    final posY = ((fgSize - iconInnerSize) / 2).round();

    img.compositeImage(fgCanvas, resizedInner, dstX: posX, dstY: posY);
    File('${folderDir.path}/ic_launcher_foreground.png').writeAsBytesSync(img.encodePng(fgCanvas));
  });

  print('Clean brand launcher icons generated successfully!');
}
