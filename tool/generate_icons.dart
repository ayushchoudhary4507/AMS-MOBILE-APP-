import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final logoFile = File('assets/images/attendance_pro_logo.png');
  if (!logoFile.existsSync()) {
    print('Logo file not found at ${logoFile.path}');
    return;
  }

  final bytes = logoFile.readAsBytesSync();
  final image = img.decodeImage(bytes);
  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // Target sizes for launcher icons
  final standardSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  // Target sizes for adaptive foreground icons (base 108dp with 72dp safe area)
  final foregroundSizes = {
    'mipmap-mdpi': 108,
    'mipmap-hdpi': 162,
    'mipmap-xhdpi': 216,
    'mipmap-xxhdpi': 324,
    'mipmap-xxxhdpi': 432,
  };

  final resDir = Directory('android/app/src/main/res');

  // 1. Generate standard launcher icons & round icons
  standardSizes.forEach((folder, size) {
    final folderDir = Directory('${resDir.path}/$folder');
    if (!folderDir.existsSync()) {
      folderDir.createSync(recursive: true);
    }

    final resized = img.copyResize(image, width: size, height: size, interpolation: img.Interpolation.linear);
    
    // Save ic_launcher.png
    final launcherPath = '${folderDir.path}/ic_launcher.png';
    File(launcherPath).writeAsBytesSync(img.encodePng(resized));
    print('Generated: $launcherPath ($size x $size)');

    // Save ic_launcher_round.png
    final roundPath = '${folderDir.path}/ic_launcher_round.png';
    File(roundPath).writeAsBytesSync(img.encodePng(resized));
    print('Generated: $roundPath ($size x $size)');
  });

  // 2. Generate adaptive foreground icons with proper padding
  foregroundSizes.forEach((folder, fgSize) {
    final folderDir = Directory('${resDir.path}/$folder');
    if (!folderDir.existsSync()) {
      folderDir.createSync(recursive: true);
    }

    // Create transparent canvas of fgSize x fgSize
    final fgCanvas = img.Image(width: fgSize, height: fgSize, numChannels: 4);
    // Draw centered icon within safe area (approx 66% of fgSize)
    final iconInnerSize = (fgSize * 0.72).round();
    final resizedInner = img.copyResize(image, width: iconInnerSize, height: iconInnerSize, interpolation: img.Interpolation.linear);
    
    final posX = ((fgSize - iconInnerSize) / 2).round();
    final posY = ((fgSize - iconInnerSize) / 2).round();

    img.compositeImage(fgCanvas, resizedInner, dstX: posX, dstY: posY);

    final fgPath = '${folderDir.path}/ic_launcher_foreground.png';
    File(fgPath).writeAsBytesSync(img.encodePng(fgCanvas));
    print('Generated Adaptive Foreground: $fgPath ($fgSize x $fgSize)');
  });

  print('All Android launcher icons successfully updated!');
}
