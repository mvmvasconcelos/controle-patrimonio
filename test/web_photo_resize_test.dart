import 'package:controle_patrimonio/services/web_photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fitWithin keeps small images untouched', () {
    expect(fitWithin(800, 600), (width: 800, height: 600));
  });

  test('fitWithin scales landscape images to 1280 wide keeping the ratio', () {
    expect(fitWithin(4000, 3000), (width: 1280, height: 960));
  });

  test('fitWithin scales portrait images to 1280 high keeping the ratio', () {
    expect(fitWithin(3000, 4000), (width: 960, height: 1280));
  });

  test('fitWithin never returns a zero dimension', () {
    expect(fitWithin(100000, 10), (width: 1280, height: 1));
  });
}
