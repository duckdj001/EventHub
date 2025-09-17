import 'package:flutter/material.dart';
import '../services/api_client.dart';

class AddressResult {
  final String label;
  final String city;
  final double lat;
  final double lon;

  AddressResult({required this.label, required this.city, required this.lat, required this.lon});
}

class AddressPickerField extends StatefulWidget {
  final ApiClient api;
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final void Function(double lat, double lon) onLatLon;

  const AddressPickerField({
    super.key,
    required this.api,
    required this.addressCtrl,
    required this.cityCtrl,
    required this.onLatLon,
  });

  @override
  State<AddressPickerField> createState() => _AddressPickerFieldState();
}

class _AddressPickerFieldState extends State<AddressPickerField> {
  Future<void> _openPicker() async {
    final result = await showModalBottomSheet<AddressResult?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _AddressPickerSheet(api: widget.api),
    );
    if (result != null) {
      widget.addressCtrl.text = result.label;
      widget.cityCtrl.text = result.city;
      widget.onLatLon(result.lat, result.lon);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.addressCtrl,
      readOnly: true,
      onTap: _openPicker,
      decoration: const InputDecoration(
        labelText: 'Адрес (улица, дом, город)',
        suffixIcon: Icon(Icons.search),
      ),
      validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Укажите адрес',
    );
  }
}

class _AddressPickerSheet extends StatefulWidget {
  final ApiClient api;
  const _AddressPickerSheet({required this.api});

  @override
  State<_AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<_AddressPickerSheet> {
  final _qCtrl = TextEditingController();
  List<AddressResult> _items = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() => _items = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await widget.api.get('/geo/search?q=$q');
      final list = (res as List)
          .map((j) => AddressResult(
                label: j['label'],
                city: j['city'] ?? '',
                lat: (j['lat'] as num).toDouble(),
                lon: (j['lon'] as num).toDouble(),
              ))
          .toList();
      setState(() => _items = list);
    } catch (e) {
      // игнорируем ошибку, но можно показать SnackBar
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _qCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Введите адрес',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _qCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _qCtrl.clear(); _search(''); })
                      : null,
                ),
                onChanged: _search,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final it = _items[i];
                  return ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(it.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: it.city.isNotEmpty ? Text(it.city) : null,
                    onTap: () => Navigator.of(context).pop(it),
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
