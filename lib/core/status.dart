enum JarvisPresence { offline, online, busy, away, driving, walking, custom }
class PresenceState { JarvisPresence state=JarvisPresence.offline; String? customLabel; bool visibleToOthers=false; }
