import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class MemoryStore {
  Future<List<Map<String,dynamic>>> read() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getString('jarvis_memory');
    if(raw==null||raw.isEmpty)return [];
    try{return (jsonDecode(raw) as List).map((e)=>Map<String,dynamic>.from(e)).toList();}catch(_){return [];}
  }
  Future<void> write(List<Map<String,dynamic>> memories) async {
    final p=await SharedPreferences.getInstance();
    await p.setString('jarvis_memory',jsonEncode(memories));
  }
}
