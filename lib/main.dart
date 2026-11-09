import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() => runApp(const MizanApp());

class MizanApp extends StatelessWidget {
  const MizanApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ميزان الأسماك',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB88935)),
          scaffoldBackgroundColor: const Color(0xFFF5F3EE),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF151A20),
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        home: const WeightsHome(),
      );
}

class FishRecord {
  FishRecord({required this.name, List<List<double>>? batches, this.note = ''})
      : batches = batches ?? <List<double>>[];
  final String name;
  final List<List<double>> batches;
  String note;
  double get total =>
      batches.fold(0, (sum, batch) => sum + batch.fold(0, (s, w) => s + w));
  Map<String, dynamic> toJson() => {'name': name, 'batches': batches, 'note': note};
  factory FishRecord.fromJson(Map<String, dynamic> json) => FishRecord(
        name: json['name'] as String,
        note: (json['note'] as String?) ?? '',
        batches: (json['batches'] as List? ?? [])
            .map((b) => (b as List).map((v) => (v as num).toDouble()).toList())
            .toList(),
      );
}

class WeightsHome extends StatefulWidget {
  const WeightsHome({super.key});
  @override
  State<WeightsHome> createState() => _WeightsHomeState();
}

class _WeightsHomeState extends State<WeightsHome> {
  final _fishController = TextEditingController();
  final _weightController = TextEditingController();
  final List<FishRecord> _fish = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fishController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('fish_weights_v1');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _fish.addAll(list.map((e) =>
            FishRecord.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'fish_weights_v1', jsonEncode(_fish.map((e) => e.toJson()).toList()));
  }

  Future<void> _addWeight() async {
    final name = _fishController.text.trim();
    final weight = double.tryParse(
        _weightController.text.trim().replaceAll(',', '.'));
    if (name.isEmpty || weight == null || weight <= 0) {
      _message('أدخل اسم السمك ووزناً صحيحاً أكبر من صفر');
      return;
    }
    setState(() {
      var index =
          _fish.indexWhere((f) => f.name.toLowerCase() == name.toLowerCase());
      if (index == -1) {
        _fish.add(FishRecord(name: name));
        index = _fish.length - 1;
      }
      final record = _fish[index];
      if (record.batches.isEmpty || record.batches.last.length == 10) {
        record.batches.add(<double>[]);
      }
      record.batches.last.add(weight);
    });
    await _save();
    _weightController.clear();
    FocusScope.of(context).unfocus();
    _message('تم تسجيل الوزن وحفظه تلقائياً');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Future<Uint8List> _makePdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/NotoSansArabic.ttf');
    final arabicFont = pw.Font.ttf(fontData);
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
      build: (context) => pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(child: pw.Text('التقرير الإجمالي لأوزان الأسماك',
                style: pw.TextStyle(font: arabicFont, fontSize: 20))),
            pw.SizedBox(height: 18),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600, width: .7),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    for (final label in ['نوع السمك', 'عدد الوزنات', 'مجموع الوزن (كجم)'])
                      pw.Padding(padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(label, textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: arabicFont))),
                  ],
                ),
                for (final fish in _fish)
                  pw.TableRow(children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(9),
                      child: pw.Text(fish.name, textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(9),
                      child: pw.Text('${fish.batches.fold<int>(0, (n, b) => n + b.length)}',
                        textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(9),
                      child: pw.Text(_number(fish.total), textAlign: pw.TextAlign.center)),
                  ]),
              ],
            ),
          ],
        ),
      ),
    ));
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Text('كشف أوزان الأسماك',
                  style: pw.TextStyle(font: arabicFont, fontSize: 20)),
            ),
          ),
          pw.SizedBox(height: 14),
        ];
        for (final fish in _fish) {
          widgets.add(pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('${fish.name} — الإجمالي: ${_number(fish.total)} كجم',
                    style: pw.TextStyle(font: arabicFont, fontSize: 14)),
                pw.SizedBox(height: 5),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600, width: .5),
                  children: [
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        for (var i = 0; i < fish.batches.length; i++)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('العمود ${i + 1}',
                                textAlign: pw.TextAlign.center,
                                style: pw.TextStyle(font: arabicFont)),
                          ),
                      ],
                    ),
                    for (var row = 0; row < 10; row++)
                      pw.TableRow(children: [
                        for (final batch in fish.batches)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              row < batch.length
                                  ? '${_number(batch[row])} كجم'
                                  : '—',
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                      ]),
                    pw.TableRow(
                      decoration:
                          const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        for (final batch in fish.batches)
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              'المجموع: ${_number(batch.fold<double>(0, (s, w) => s + w))}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(font: arabicFont),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
              ],
            ),
          ));
        }
        if (_fish.isEmpty) {
          widgets.add(pw.Center(child: pw.Text('لا توجد أوزان مسجلة بعد')));
        }
        return widgets;
      },
    ));
    return pdf.save();
  }

  Future<void> _editNote(FishRecord fish) async {
    final controller = TextEditingController(text: fish.note);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظات ${fish.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'اكتب ملاحظات هذا النوع هنا',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ الملاحظة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      setState(() => fish.note = value);
      await _save();
      _message('تم حفظ الملاحظة');
    }
  }

  void _openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          fish: _fish,
          number: _number,
          onSavePdf: _sharePdf,
          onPrint: _printPdf,
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_fish.isEmpty) return _message('لا توجد بيانات لتصديرها');
    await Printing.sharePdf(
        bytes: await _makePdf(), filename: 'كشف_اوزان_الاسماك.pdf');
  }

  Future<void> _printPdf() async {
    if (_fish.isEmpty) return _message('لا توجد بيانات للطباعة');
    final bytes = await _makePdf();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جميع البيانات؟'),
        content: const Text('سيتم حذف جميع أنواع الأسماك والأوزان المحفوظة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(_fish.clear);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ميزان الأسماك'),
          actions: [
            IconButton(
                tooltip: 'معاينة التقرير الكامل',
                onPressed: _openPreview,
                icon: const Icon(Icons.preview)),
            IconButton(
                tooltip: 'حفظ / مشاركة PDF',
                onPressed: _sharePdf,
                icon: const Icon(Icons.share)),
            IconButton(
                tooltip: 'طباعة',
                onPressed: _printPdf,
                icon: const Icon(Icons.print)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'clear') _clearAll();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'clear', child: Text('حذف جميع البيانات'))
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                _entryPanel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openPreview,
                        icon: const Icon(Icons.preview),
                        label: const Text('معاينة الأصناف'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _sharePdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('حفظ PDF'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF263746),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ]),
                ),
                Expanded(
                  child: _fish.isEmpty
                      ? const Center(
                          child: Text('ابدأ بإدخال اسم السمك والوزن',
                              style: TextStyle(color: Colors.black54)))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: _fish.length,
                          itemBuilder: (_, i) => _fishSection(_fish[i]),
                        ),
                ),
              ]),
        bottomNavigationBar: null,
      );

  Widget _entryPanel() => Card(
        margin: const EdgeInsets.all(12),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تسجيل وزن جديد',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 10),
              TextField(
                controller: _fishController,
                textDirection: TextDirection.rtl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم السمك',
                  hintText: 'مثال: تمد',
                  prefixIcon: Icon(Icons.set_meal),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الوزن بالكيلو',
                  hintText: 'مثال: 150',
                  suffixText: 'كجم',
                  prefixIcon: Icon(Icons.scale),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _addWeight(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addWeight,
                icon: const Icon(Icons.add),
                label: const Text('تسجيل الوزن'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB88935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
              const SizedBox(height: 4),
              const Text('كل 10 أوزان تُغلق في عمود مستقل ويُحسب مجموعها تلقائياً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      );

  Widget _fishSection(FishRecord fish) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                const Icon(Icons.set_meal, color: Color(0xFFB88935)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(fish.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Text('${_number(fish.total)} كجم',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF87601F))),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < fish.batches.length; i++)
                      _batchColumn(fish.batches[i], i),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  onPressed: () => _editNote(fish),
                  icon: const Icon(Icons.note_alt_outlined),
                  label: Text(fish.note.isEmpty ? 'إضافة ملاحظة' : 'تعديل الملاحظة'),
                ),
              ),
              if (fish.note.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('ملاحظات: ${fish.note}', textDirection: TextDirection.rtl),
                ),
            ],
          ),
        ),
      );

  Widget _batchColumn(List<double> batch, int index) {
    final sum = batch.fold<double>(0, (s, w) => s + w);
    return Container(
      width: 112,
      margin: const EdgeInsetsDirectional.only(end: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD6C7A9)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFF263746),
            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Text('العمود ${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        for (var row = 0; row < 10; row++)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
            decoration: BoxDecoration(
              color: row.isEven ? Colors.white : const Color(0xFFF8F6F1),
              border:
                  const Border(bottom: BorderSide(color: Color(0xFFE8E1D5))),
            ),
            child: Text(
              '${row + 1}.  ${row < batch.length ? _number(batch[row]) : '—'}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0D2),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
          ),
          child: Text('المجموع\n${_number(sum)} كجم',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF684713))),
        ),
      ]),
    );
  }
}


class ReportPreviewPage extends StatelessWidget {
  const ReportPreviewPage({
    super.key,
    required this.fish,
    required this.number,
    required this.onSavePdf,
    required this.onPrint,
  });

  final List<FishRecord> fish;
  final String Function(double) number;
  final VoidCallback onSavePdf;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final count = fish.fold<int>(
      0,
      (sum, item) => sum + item.batches.fold<int>(0, (n, b) => n + b.length),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاينة كشف الأصناف'),
        actions: [
          IconButton(tooltip: 'حفظ PDF', onPressed: onSavePdf, icon: const Icon(Icons.picture_as_pdf)),
          IconButton(tooltip: 'طباعة', onPressed: onPrint, icon: const Icon(Icons.print)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('التقرير الإجمالي', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('عدد الأنواع', '${fish.length}'),
                      _stat('عدد الوزنات', '$count'),
                      _stat('الإجمالي كجم', number(total)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('مجموع كل نوع من الأسماك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final item in fish)
                  ListTile(
                    leading: const Icon(Icons.set_meal, color: Color(0xFFB88935)),
                    title: Text(item.name),
                    subtitle: Text('${item.batches.fold<int>(0, (n, b) => n + b.length)} وزنة'),
                    trailing: Text('${number(item.total)} كجم', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                const Divider(height: 1),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('تفاصيل الأعمدة والملاحظات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          for (final item in fish)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('مجموع الصنف: ${number(item.total)} كجم'),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < item.batches.length; i++)
                            Container(
                              width: 112,
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD6C7A9)), borderRadius: BorderRadius.circular(8)),
                              child: Column(
                                children: [
                                  Text('العمود ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  for (var j = 0; j < 10; j++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Text(j < item.batches[i].length ? number(item.batches[i][j]) : '—'),
                                    ),
                                  const Divider(),
                                  Text('المجموع: ${number(item.batches[i].fold<double>(0, (s, w) => s + w))}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('ملاحظات: ${item.note}', textDirection: TextDirection.rtl),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onSavePdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('حفظ ومشاركة التقرير PDF')),
          OutlinedButton.icon(onPressed: onPrint, icon: const Icon(Icons.print), label: const Text('طباعة التقرير')),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    children: [
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.black54)),
    ],
  );
}
