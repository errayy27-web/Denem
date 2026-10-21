import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() { WidgetsFlutterBinding.ensureInitialized(); runApp(const StockApp()); }
class StockApp extends StatelessWidget {
  const StockApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false,title:'SS OIL Stok Kontrol',theme:ThemeData(colorSchemeSeed:Colors.indigo,useMaterial3:true),home:const Home());
}
class Product {
  final String code,name,barcode,price,stock;
  const Product(this.code,this.name,this.barcode,this.price,this.stock);
  Map<String,dynamic> toJson()=>{'code':code,'name':name,'barcode':barcode,'price':price,'stock':stock};
  factory Product.fromJson(Map<String,dynamic> j)=>Product('${j['code']??''}','${j['name']??''}','${j['barcode']??''}','${j['price']??''}','${j['stock']??''}');
}
class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home> {
  final Map<String,Product> catalog={};
  final Map<String,Map<String,dynamic>> issues={};
  final Map<String,Product> orders={};
  Product? current;
  static const bridge=MethodChannel("ssoil.popis/bridge");
  Future<void> _checkPopis() async {
    try {
      final raw=await bridge.invokeMethod<String>("readPopis");
      if(raw==null||raw.isEmpty){_msg("Popis ekranından henüz veri alınmadı");return;}
      final m=Map<String,dynamic>.from(jsonDecode(raw));
      final p=Product("${m['code']??''}","${m['name']??''}","${m['barcode']??''}","${m['price']??''}","${m['stock']??''}");
      if(p.code.isEmpty){_msg("Popis ekranındaki ürün alanları çözümlenemedi");return;}
      setState((){current=p;count.clear();});
    }catch(e){_msg("Popis erişimi: $e");}
  }
  Future<void> _openAccess() async {try{await bridge.invokeMethod("accessibilitySettings");}catch(e){_msg("Ayarlar açılamadı: $e");}}
  Future<void> _returnPopis() async {try{await bridge.invokeMethod("returnPopis");}catch(e){_msg("Popis dönüşü başarısız: $e");}}
  final count=TextEditingController();
  final search=TextEditingController();
  String status='Ürün listesi yükleyin veya barkod okutun';
  @override void initState(){super.initState();_load();}
  @override void dispose(){count.dispose();search.dispose();super.dispose();}
  Future<void> _load() async {
    final p=await SharedPreferences.getInstance();
    try {
      final c=jsonDecode(p.getString('catalog')??'[]') as List;
      final i=jsonDecode(p.getString('issues')??'[]') as List;
      final o=jsonDecode(p.getString('orders')??'[]') as List;
      setState((){
        for(final x in c){final a=Product.fromJson(Map<String,dynamic>.from(x));catalog[a.barcode]=a;}
        for(final x in i){final m=Map<String,dynamic>.from(x);issues['${m['code']}']=m;}
        for(final x in o){final a=Product.fromJson(Map<String,dynamic>.from(x));orders[a.code]=a;}
      });
    } catch(_){setState(()=>status='Kayıt okuma hatası');}
  }
  Future<void> _save() async {
    final p=await SharedPreferences.getInstance();
    await p.setString('catalog',jsonEncode(catalog.values.map((x)=>x.toJson()).toList()));
    await p.setString('issues',jsonEncode(issues.values.toList()));
    await p.setString('orders',jsonEncode(orders.values.map((x)=>x.toJson()).toList()));
  }
  void _msg(String s){if(mounted){setState(()=>status=s);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),duration:const Duration(seconds:1)));}}
  Future<void> _scan() async {
    final code=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>const ScanPage()));
    if(code==null)return;
    final p=catalog[code] ?? catalog.values.where((p)=>p.code==code).firstOrNull;
    if(p==null){_msg('Barkod listede bulunamadı: $code');return;}
    setState((){current=p;count.clear();status='Ürün bulundu';});
  }
  Future<void> _import() async {
    final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['csv']);
    if(r==null||r.files.single.path==null)return;
    try {
      final raw=await File(r.files.single.path!).readAsString();
      final delimiter=raw.split('\n').first.contains(';')?';':',';
      final rows=CsvToListConverter(fieldDelimiter:delimiter,shouldParseNumbers:false).convert(raw);
      if(rows.length<2)throw Exception('Dosyada ürün satırı bulunamadı');
      final h=rows.first.map((x)=>x.toString().trim().toLowerCase()).toList();
      int idx(List<String> options){for(final s in options){final n=h.indexOf(s);if(n>=0)return n;}return -1;}
      final ci=idx(['code','urun kodu','ürün kodu','artikal id','sifra','šifra']);
      final ni=idx(['name','urun adi','ürün adı','naziv','artikal']);
      final bi=idx(['barcode','barkod','ean']);
      final pi=idx(['price','fiyat','cijena','prodajna cijena']);
      final si=idx(['stock','stok','stanje','kolicina','količina']);
      if(ci<0||ni<0||bi<0)throw Exception('CSV başlıkları: code,name,barcode,price,stock');
      String cell(List row,int i)=>i<0||i>=row.length?'':row[i].toString().trim();
      int n=0;
      for(final row in rows.skip(1)){
        final p=Product(cell(row,ci),cell(row,ni),cell(row,bi),cell(row,pi),cell(row,si));
        if(p.code.isEmpty||p.barcode.isEmpty)continue;
        catalog[p.barcode]=p;n++;
      }
      await _save();_msg('$n ürün içe aktarıldı');setState((){});
    } catch(e){_msg('İçe aktarma hatası: $e');}
  }
  void _issue(String type) {
    final p=current;if(p==null)return;
    final existing=issues[p.code]??{'code':p.code,'name':p.name,'barcode':p.barcode,'price':p.price,'stock':p.stock,'count':'','types':<String>[]};
    final types=List<String>.from(existing['types'] as List);
    if(type=='Eksik'||type=='Fazla'){
      final q=double.tryParse(count.text.replaceAll(',','.'));
      final s=double.tryParse(p.stock.replaceAll(',','.'));
      if(q==null||q<0||s==null){_msg('Geçerli sayılan miktar ve sistem stoku gerekli');return;}
      if(type=='Eksik'&&q>=s || type=='Fazla'&&q<=s){_msg('Sayılan stok ile seçilen durum uyuşmuyor');return;}
      types.remove('Eksik');types.remove('Fazla');existing['count']=count.text;
    }
    if(type=='Sorun Yok'){types.clear();existing['count']='';}else{types.remove('Sorun Yok');}
    if(!types.contains(type))types.add(type);
    existing['types']=types;
    issues[p.code]=existing;
    _save();_msg('$type kaydedildi / mevcut kayıt güncellendi');setState((){});
  }
  void _ok(){_issue('Sorun Yok');}
  void _order(){final p=current;if(p==null)return;orders[p.code]=p;_save();_msg('Sipariş listesine eklendi / güncellendi');setState((){});}
  Future<void> _export() async {
    final book=xl.Excel.createExcel();
    final a=book['Stok Kontrol'];final b=book['Siparis Listesi'];
    void row(xl.Sheet s,List<String> vals)=>s.appendRow(vals.map((v)=>xl.TextCellValue(v)).toList());
    row(a,['Ürün Kodu','Ürün Adı','Barkod','Satış Fiyatı','Sistem Stoku','Sayılan Stok','Fark','Sorunlar']);
    for(final m in issues.values){
      final st=double.tryParse('${m['stock']}'.replaceAll(',','.'));
      final co=double.tryParse('${m['count']}'.replaceAll(',','.'));
      final types=List<String>.from(m['types'] as List);
      row(a,['${m['code']}','${m['name']}','${m['barcode']}','${m['price']}','${m['stock']}','${m['count']}',types.any((t)=>t=='Eksik'||t=='Fazla')&&st!=null&&co!=null?'${co-st}':'',types.join(', ')]);
    }
    row(b,['Ürün Kodu','Ürün Adı','Barkod']);
    for(final p in orders.values){row(b,[p.code,p.name,p.barcode]);}
    book.delete('Sheet1');
    final bytes=book.encode();if(bytes==null){_msg('Excel oluşturulamadı');return;}
    final dir=await getTemporaryDirectory();
    final now=DateTime.now();
    final stamp='${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour}${now.minute}${now.second}';
    final f=File('${dir.path}/SS_OIL_Kontrol_$stamp.xlsx');await f.writeAsBytes(bytes,flush:true);
    await Share.shareXFiles([XFile(f.path)],text:'SS OIL Stok Kontrol ve Sipariş Listesi');
  }
  Future<void> _clear() async {
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Kayıtları temizle?'),content:const Text('Stok kontrol ve sipariş kayıtları silinir. Önceden dışarı aktarılan Excel dosyaları silinmez. Ürün kataloğu korunur.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Temizle'))]));
    if(ok!=true)return;setState((){issues.clear();orders.clear();current=null;count.clear();});await _save();_msg('Yeni kontrol dönemi başladı');
  }
  Future<void> _lists() async {await Navigator.push(context,MaterialPageRoute(builder:(_)=>ListPage(issues:issues,orders:orders,onChanged:() async {await _save();setState((){});})));setState((){});}
  @override Widget build(BuildContext context){final p=current;return Scaffold(appBar:AppBar(title:const Text('SS OIL • Stok Kontrol')),body:ListView(padding:const EdgeInsets.all(16),children:[
    Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:_openAccess,icon:const Icon(Icons.accessibility_new),label:const Text('Erişilebilirlik Ayarı')),OutlinedButton.icon(onPressed:_checkPopis,icon:const Icon(Icons.sync),label:const Text('Popis Verisini Dene')),FilledButton.icon(onPressed:_scan,icon:const Icon(Icons.qr_code_scanner),label:const Text('Barkod Oku')),OutlinedButton.icon(onPressed:_import,icon:const Icon(Icons.file_open),label:const Text('Ürün CSV Yükle')),OutlinedButton.icon(onPressed:_lists,icon:const Icon(Icons.list),label:Text('Listeler (${issues.length} / ${orders.length})'))]),
    const SizedBox(height:12),Text(status,style:Theme.of(context).textTheme.bodySmall),const SizedBox(height:12),
    TextField(controller:search,decoration:InputDecoration(labelText:'Barkod veya ürün kodunu elle gir',suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:(){final v=search.text.trim();final match=catalog[v]??catalog.values.where((x)=>x.code==v).firstOrNull;if(match==null){_msg('Ürün bulunamadı');return;}setState((){current=match;count.clear();});})),onSubmitted:(v){final match=catalog[v.trim()]??catalog.values.where((x)=>x.code==v.trim()).firstOrNull;if(match!=null)setState((){current=match;count.clear();});else _msg('Ürün bulunamadı');}),
    const SizedBox(height:12),if(p!=null)...[
      Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Kod: ${p.code}'),Text(p.name,style:Theme.of(context).textTheme.titleMedium),Text('Barkod: ${p.barcode}'),Text('Satış: ${p.price} KM     Stok: ${p.stock}',style:Theme.of(context).textTheme.titleSmall)]))),
      const SizedBox(height:12),TextField(controller:count,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Gerçek sayılan stok')),
      const SizedBox(height:8),Row(children:[Expanded(child:FilledButton.tonal(onPressed:()=>_issue('Eksik'),child:const Text('Eksik'))),const SizedBox(width:8),Expanded(child:FilledButton.tonal(onPressed:()=>_issue('Fazla'),child:const Text('Fazla')))]),
      for(final label in ['Yanlış Barkod','Yanlış Fiyat','Etiket Yok']) Padding(padding:const EdgeInsets.only(top:8),child:OutlinedButton(onPressed:()=>_issue(label),child:Text(label))),
      const SizedBox(height:10),OutlinedButton(onPressed:_ok,child:const Text('Sorun Yok – Kaydet')),FilledButton.icon(onPressed:_order,icon:const Icon(Icons.shopping_cart),label:const Text('Sipariş Listesine Ekle')),
    ]else const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('Ürün seçmek için barkod okutun veya ürün kodunu girin.'))),
    const SizedBox(height:8),OutlinedButton(onPressed:_returnPopis,child:const Text('Popis’e Dön (test)')),const Divider(height:32),FilledButton.icon(onPressed:_export,icon:const Icon(Icons.table_view),label:const Text('Excel’e Aktar (2 Sayfa)')),
    const SizedBox(height:8),OutlinedButton.icon(onPressed:_clear,icon:const Icon(Icons.delete_outline),label:const Text('Önceki Kayıtları Temizle')),
  ]));}
}
class ScanPage extends StatefulWidget {const ScanPage({super.key});@override State<ScanPage> createState()=>_ScanPageState();}
class _ScanPageState extends State<ScanPage>{bool done=false;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Barkod Tara')),body:MobileScanner(onDetect:(capture){if(done)return;final code=capture.barcodes.firstOrNull?.rawValue;if(code==null||code.isEmpty)return;done=true;Navigator.pop(context,code);}));}
class ListPage extends StatefulWidget {final Map<String,Map<String,dynamic>> issues;final Map<String,Product> orders;final Future<void> Function() onChanged;const ListPage({super.key,required this.issues,required this.orders,required this.onChanged});@override State<ListPage> createState()=>_ListPageState();}
class _ListPageState extends State<ListPage>{@override Widget build(BuildContext context)=>DefaultTabController(length:2,child:Scaffold(appBar:AppBar(title:const Text('Kayıt Listeleri'),bottom:const TabBar(tabs:[Tab(text:'Stok / Hatalar'),Tab(text:'Sipariş')])),body:TabBarView(children:[ListView(children:widget.issues.entries.map((e)=>ListTile(title:Text('${e.value['name']}'),subtitle:Text('Kod: ${e.key} • ${e.value['types'].join(', ')} • Sayılan: ${e.value['count']}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{setState(()=>widget.issues.remove(e.key));await widget.onChanged();}))).toList()),ListView(children:widget.orders.entries.map((e)=>ListTile(title:Text(e.value.name),subtitle:Text('Kod: ${e.value.code} • Barkod: ${e.value.barcode}'),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{setState(()=>widget.orders.remove(e.key));await widget.onChanged();}))).toList())])));}

