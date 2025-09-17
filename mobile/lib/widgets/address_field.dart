import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddressPickResult {
  final String displayName;
  final double lat;
  final double lon;
  final String city;
  AddressPickResult(this.displayName, this.lat, this.lon, this.city);
}

class AddressField extends StatefulWidget {
  final void Function(AddressPickResult) onSelected;
  const AddressField({super.key, required this.onSelected});
  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  final ctrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> suggestions = [];
  bool loading = false;

  Future<void> _search(String q) async {
    if (q.length < 3) { setState(()=>suggestions=[]); return; }
    setState(()=>loading=true);
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&addressdetails=1&limit=5');
    final res = await http.get(uri, headers: {'User-Agent': 'EventHub/1.0'});
    final arr = json.decode(res.body) as List;
    setState(() { suggestions = arr; loading = false; });
  }

  @override
  void dispose() { _debounce?.cancel(); ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: 'Адрес места проведения',
          border: const OutlineInputBorder(),
          suffixIcon: loading ? const Padding(
            padding: EdgeInsets.all(8.0), child: SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)))
            : const Icon(Icons.search),
        ),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 400), ()=>_search(v));
        },
      ),
      const SizedBox(height: 8),
      ...suggestions.map((s) {
        final name = s['display_name'] as String;
        final city = (s['address']?['city'] ?? s['address']?['town'] ?? s['address']?['village'] ?? '') as String;
        return ListTile(
          dense: true,
          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () {
            final lat = double.parse(s['lat']);
            final lon = double.parse(s['lon']);
            widget.onSelected(AddressPickResult(name, lat, lon, city));
            setState(()=>suggestions=[]);
            ctrl.text = name;
          },
        );
      }),
    ]);
  }
}
