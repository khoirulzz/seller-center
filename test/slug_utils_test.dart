import 'package:flutter_test/flutter_test.dart';
import 'package:nalaro_seller_center/core/config/slug_utils.dart';
void main(){
 test('normalizes shop slugs',(){expect(NsSlugUtils.normalize('Toko Batik Pekalongan'),'toko-batik-pekalongan');});
 test('rejects reserved slugs',(){expect(NsSlugUtils.isValid('admin'),isFalse);});
 test('accepts normal merchant slug',(){expect(NsSlugUtils.isValid('batik-pekalongan'),isTrue);});
}
