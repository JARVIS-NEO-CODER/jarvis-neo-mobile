import 'network_policy.dart';
import 'token_budget.dart';
class ContextRouter {
  final NetworkPolicy network;
  ContextRouter(this.network);
  String prepare(String text,{bool sensitive=false}) {
    if(!network.canUseCloud(sensitive:sensitive)) return '';
    return TokenBudget.compact(text,maxChars:4000);
  }
}
