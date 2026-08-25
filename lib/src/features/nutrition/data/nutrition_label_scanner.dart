import 'package:cycle_ready/src/features/nutrition/domain/nutrition_label.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class NutritionLabelScanner {
  Future<NutritionLabel> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final image = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(image);
      final fragments = result.blocks.expand((block) => block.lines).map(
            (line) => NutritionTextFragment(
              text: line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              right: line.boundingBox.right,
              bottom: line.boundingBox.bottom,
            ),
          );
      return parseNutritionLabel(result.text, fragments: fragments);
    } finally {
      await recognizer.close();
    }
  }
}
