import 'package:flutter_test/flutter_test.dart';
import 'package:jarvis_neo_mobile/core/token_budget.dart';
void main(){test('token budget compacts oversized context',(){final input='x'*6000; final out=TokenBudget.compact(input); expect(out.length, lessThanOrEqualTo(5060)); expect(out, contains('contexte réduit'));});}
