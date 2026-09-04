enum AiRoute { local, pc, groq }
class AiRouter {
  AiRoute choose({required bool needsWeb,required bool needsPcControl,required bool sensitive,required bool localAvailable}) {
    if(needsPcControl) return AiRoute.pc;
    if(sensitive && localAvailable) return AiRoute.local;
    if(needsWeb) return AiRoute.groq;
    return localAvailable ? AiRoute.local : AiRoute.groq;
  }
}
