import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CityResult {
  final String name;
  final double lat;
  final double lon;
  CityResult(this.name, this.lat, this.lon);
}

class CityPickerSheet extends StatefulWidget {
  final void Function(CityResult) onSelected;
  const CityPickerSheet({super.key, required this.onSelected});

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final ctrl = TextEditingController();
  Timer? _debounce;
  List<dynamic> items = [];
  bool loading = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(()=>items=[]); return; }
    setState(()=>loading = true);
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?format=json&limit=8&addressdetails=1&accept-language=ru'
      '&q=${Uri.encodeComponent(q)}'
    );
    final res = await http.get(uri, headers: {'User-Agent':'Vibe/1.0'});
    final arr = json.decode(res.body) as List;
    setState(() { items = arr; loading = false; });
  }

  @override
  void dispose() { _debounce?.cancel(); ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.black26, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                labelText: 'Город или населённый пункт',
                border: const OutlineInputBorder(),
                suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)),
                    )
                  : const Icon(Icons.search),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), ()=>_search(v));
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i];
                  final display = (it['display_name'] as String?) ?? '';
                  final city = it['address']?['city']
                            ?? it['address']?['town']
                            ?? it['address']?['village']
                            ?? display;
                  return ListTile(
                    title: Text(city.toString()),
                    subtitle: Text(display, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      widget.onSelected(
                        CityResult(
                          city.toString(),
                          double.parse(it['lat']),
                          double.parse(it['lon']),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
