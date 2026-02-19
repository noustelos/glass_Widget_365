import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('el_GR', null).then((_) {
    runApp(const OrthodoxyApp());
  });
}

class OrthodoxyApp extends StatelessWidget {
  const OrthodoxyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue, 
        fontFamily: 'GFSDidot',
        canvasColor: Colors.transparent,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const OrthodoxyHomePage(),
    );
  }
}

class OrthodoxyHomePage extends StatefulWidget {
  const OrthodoxyHomePage({super.key});
  @override
  State<OrthodoxyHomePage> createState() => _OrthodoxyHomePageState();
}

class _OrthodoxyHomePageState extends State<OrthodoxyHomePage> {
  Map<String, dynamic>? todayData;
  Map<String, dynamic>? selectedResult; 
  List<dynamic> searchResultsList = []; 
  bool isLoading = true;
  bool showModernMain = false;
  bool showModernSearch = false; 
  bool isMicroDrawerOpen = false;
  bool isMacroDrawerOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> allYearData = []; 
  List<dynamic> extraQuotesData = [];
  String sunrise = "--:--", sunset = "--:--", moonIcon = "🌑", formattedDate = "";
  final Color primaryGold = const Color(0xFFD4AF37), lightGold = const Color(0xFFF7E29F);

  @override
  void initState() {
    super.initState();
    _calculateAstroData();
    loadDailyData();
    loadAllDataSources();
  }

  void _calculateAstroData() {
    final now = DateTime.now();
    final times = AstroEngine.getSunTimes(now, 37.98, 23.72);
    setState(() {
      sunrise = times['sunrise']!; sunset = times['sunset']!;
      moonIcon = AstroEngine.getMoonPhaseIcon(now);
      formattedDate = DateFormat('EEEE, d MMMM yyyy', 'el_GR').format(now);
    });
  }

  List<Shadow> get laserEngravedShadows => [
    Shadow(color: Colors.white.withOpacity(0.2), offset: const Offset(0, 0.5), blurRadius: 0.5),
    Shadow(color: Colors.black.withOpacity(0.6), offset: const Offset(0, -1.0), blurRadius: 1.0),
  ];

  String _normalizeGreek(String text) {
    var str = text.toLowerCase();
    const accents = {'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω'};
    accents.forEach((key, value) => str = str.replaceAll(key, value));
    return str.toUpperCase();
  }

  void _advancedSearch(String query) {
    if (query.isEmpty) {
      setState(() { searchResultsList = []; selectedResult = null; });
      return;
    }
    String normalizedQuery = _normalizeGreek(query).trim();

    final Map<String, List<String>> nicknameMap = {
      "ΓΕΩΡΓΙΟΣ": ["ΓΙΩΡΓΟΣ", "ΓΙΩΡΓΗΣ"], 
      "ΙΩΑΝΝΗΣ": ["ΓΙΑΝΝΗΣ"],
      "ΚΩΝΣΤΑΝΤΙΝΟΣ": ["ΚΩΣΤΑΣ", "ΚΩΣΤΗΣ", "ΝΤΙΝΟΣ"], 
      "ΔΗΜΗΤΡΙΟΣ": ["ΔΗΜΗΤΡΗΣ"],
      "ΝΙΚΟΛΑΟΣ": ["ΝΙΚΟΣ", "ΝΙΚΟΛΑΣ"], 
      "ΠΑΝΑΓΙΩΤΗΣ": ["ΠΑΝΟΣ"],
      "ΒΑΣΙΛΕΙΟΣ": ["ΒΑΣΙΛΗΣ"], 
      "ΕΜΜΑΝΟΥΗΛ": ["ΜΑΝΩΛΗΣ", "ΜΑΝΟΣ"],
      "ΜΙΧΑΗΛ": ["ΜΙΧΑΛΗΣ"], 
      "ΑΘΑΝΑΣΙΟΣ": ["ΘΑΝΑΣΗΣ"],
      "ΜΑΡΙΑ": ["ΜΑΙΡΗ", "ΜΑΡΙΩ", "ΜΑΡΙΤΣΑ", "ΜΑΡΟΥΛΑ", "ΠΑΝΑΓΙΑ", "ΔΕΣΠΟΙΝΑ"],
      "ΕΛΕΝΗ": ["ΛΕΝΑ", "ΈΛΕΝΑ", "ΛΕΝΙΩ"], 
    };

    List<Map<String, dynamic>> scoredResults = [];
    dynamic stNicholasItem;
    dynamic mariaItem;

    for (var item in allYearData) {
      String saintName = _normalizeGreek(item['saint'].toString());
      String dateStr = item['date'].toString(); 
      int score = 0;
      
      String monthDay = "";
      if (dateStr.length >= 10) {
        monthDay = dateStr.substring(5, 10);
      }

      if (monthDay == "12-06") stNicholasItem = item;
      if (monthDay == "08-15") mariaItem = item;

      int priority = item['priority'] ?? 0;
      score += priority * 2000;

      nicknameMap.forEach((official, nicknames) {
        bool isMatch = official.startsWith(normalizedQuery) || nicknames.any((nick) => nick.startsWith(normalizedQuery));
        if (isMatch && saintName.contains(official)) {
          score += 10000;
          if (official == "ΜΑΡΙΑ") {
            if (monthDay == "08-15") score += 50000; 
            if (monthDay == "11-21") score += 30000; 
          }
        }
      });

      if (saintName.contains(normalizedQuery)) {
        score += 1000;
        if (saintName.startsWith(normalizedQuery)) score += 2000;
      }

      if (score > 0) scoredResults.add({'data': item, 'score': score});
    }

    scoredResults.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    List<dynamic> finalResults = scoredResults.map((e) => e['data']).toList();

    if (normalizedQuery.startsWith("ΝΙΚ") && stNicholasItem != null) {
      finalResults.removeWhere((e) => e['date'] == stNicholasItem['date']);
      finalResults.insert(0, stNicholasItem);
    }
    if (normalizedQuery.startsWith("ΜΑΡ") && mariaItem != null) {
      finalResults.removeWhere((e) => e['date'] == mariaItem['date']);
      finalResults.insert(0, mariaItem);
    }

    setState(() { 
      selectedResult = null; 
      searchResultsList = finalResults; 
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2027, 12, 31),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(primary: primaryGold, onPrimary: Colors.black, surface: const Color(0xFF1A1A1A)),
          ),
          child: Center(child: SizedBox(width: 320, child: Transform.scale(scale: 0.9, child: child!))),
        );
      },
    );
    if (picked != null) {
      final String pickedMMDD = DateFormat('MM-dd').format(picked);
      final result = allYearData.firstWhere(
        (item) => item['date'].toString().contains(pickedMMDD), 
        orElse: () => null
      );
      if (result != null) {
        setState(() { selectedResult = Map.from(result); _searchController.clear(); searchResultsList = []; });
      }
    }
  }

  Future<void> loadDailyData() async {
    final now = DateTime.now();
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    try {
      final String response = await rootBundle.loadString('assets/data/${months[now.month - 1]}.json');
      final List<dynamic> data = json.decode(response);
      final String todayMMDD = DateFormat('MM-dd').format(now);
      setState(() {
        todayData = data.firstWhere(
          (item) => item['date'].toString().contains(todayMMDD), 
          orElse: () => data.isNotEmpty ? data.first : null
        );
        isLoading = false;
      });
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> loadAllDataSources() async {
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    List<dynamic> tempYear = [];
    for (var month in months) {
      try {
        final String resp = await rootBundle.loadString('assets/data/$month.json');
        tempYear.addAll(json.decode(resp));
      } catch (e) {}
    }
    setState(() { allYearData = tempYear; });
    try {
      final extra = await rootBundle.loadString('assets/data/extra_quotes.json');
      setState(() { extraQuotesData = json.decode(extra); });
    } catch (e) {}
  }

  void _launchURL(String? url) async {
    if (url == null || url.isEmpty) return;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _getNewRandomQuote() {
    if (extraQuotesData.isEmpty) return;
    final random = Random();
    setState(() {
      _searchController.clear(); searchResultsList = [];
      selectedResult = Map.from(extraQuotesData[random.nextInt(extraQuotesData.length)]);
    });
  }

  @override
  Widget build(BuildContext context) {
    const double w = 330, h = 280;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Container(
          color: Colors.transparent, 
          width: w, height: 600,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(duration: const Duration(milliseconds: 500), top: 20, left: 0,
                child: AnimatedOpacity(duration: const Duration(milliseconds: 500), opacity: isMacroDrawerOpen ? 0.0 : 1.0, child: IgnorePointer(ignoring: isMacroDrawerOpen, child: _buildMainCard(w, h)))),
              Positioned(top: 20 + h + 10, left: 0,
                child: AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: (isMicroDrawerOpen && !isMacroDrawerOpen) ? 1.0 : 0.0, child: IgnorePointer(ignoring: !isMicroDrawerOpen || isMacroDrawerOpen, child: _buildMicroDrawer(w)))),
              _buildMacroDrawerIntegrated(w, 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(double w, double h) {
    if (isLoading) return CircularProgressIndicator(color: primaryGold);
    return GlassWidget(width: w, height: h, child: Column(children: [
      Text(todayData?['display_date'] ?? "", style: TextStyle(color: primaryGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.4, shadows: laserEngravedShadows)),
      const SizedBox(height: 5),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(child: Text(todayData?['saint'] ?? "", textAlign: TextAlign.center, style: TextStyle(fontSize: 21, color: Colors.white, fontWeight: FontWeight.bold, shadows: laserEngravedShadows))),
        IconButton(icon: const Icon(Icons.info_outline, color: Colors.white38, size: 16), onPressed: () => _launchURL(todayData?['wiki_url'])),
      ]),
      Divider(color: primaryGold.withOpacity(0.3), thickness: 0.5, indent: 60, endIndent: 60),
      const Spacer(),
      Text(showModernMain ? (todayData?['translation'] ?? "") : (todayData?['quote'] ?? ""), textAlign: TextAlign.center, maxLines: 5, style: TextStyle(fontSize: 21, fontStyle: FontStyle.italic, color: lightGold, height: 1.25, shadows: laserEngravedShadows)),
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const SizedBox(width: 40),
        Text(todayData?['reference'] ?? "", style: const TextStyle(color: Colors.white38, fontSize: 12)),
        IconButton(icon: Icon(isMicroDrawerOpen ? Icons.keyboard_arrow_up : Icons.menu, color: Colors.white70, size: 20), onPressed: () => setState(() => isMicroDrawerOpen = !isMicroDrawerOpen)),
      ]),
    ]));
  }

  Widget _buildMicroDrawer(double w) {
    return GlassWidget(height: 65, width: w, radius: 20, isLight: true, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _buildCustomSwitch(showModernMain, (v) => setState(() => showModernMain = v)),
      IconButton(icon: const Icon(Icons.share, color: Colors.white70, size: 20), onPressed: () {}),
      IconButton(icon: const Icon(Icons.copy, color: Colors.white70, size: 20), onPressed: () => Clipboard.setData(ClipboardData(text: "${todayData?['quote']}\n${todayData?['reference']}"))),
      IconButton(icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22), onPressed: () => setState(() { isMicroDrawerOpen = false; isMacroDrawerOpen = true; })),
    ]));
  }

  Widget _buildMacroDrawerIntegrated(double w, double topPos) {
    return Stack(children: [
      if (isMacroDrawerOpen) 
        Positioned.fill(child: GestureDetector(onTap: () => setState(() => isMacroDrawerOpen = false), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: Container(color: Colors.transparent)))),
      AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart, top: topPos, left: 0,
        child: IgnorePointer(ignoring: !isMacroDrawerOpen, child: AnimatedOpacity(duration: const Duration(milliseconds: 400), opacity: isMacroDrawerOpen ? 1.0 : 0.0,
          child: GlassWidget(width: w, height: 550, radius: 32, child: Column(children: [
            Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 5),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wb_sunny_outlined, color: primaryGold, size: 14), const SizedBox(width: 4),
              Text(sunrise, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 15), Text(moonIcon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 15), Text(sunset, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white, size: 22), onPressed: () => _selectDate(context)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18), onPressed: () => setState(() => isMacroDrawerOpen = false)),
              TextButton.icon(onPressed: _getNewRandomQuote, icon: Icon(Icons.auto_awesome, color: primaryGold, size: 18), label: const Text("Νέο", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
            ]),
            Container(margin: const EdgeInsets.symmetric(vertical: 10), height: 45, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryGold.withOpacity(0.8), width: 1.5)),
              child: TextField(controller: _searchController, style: const TextStyle(color: Colors.white, fontSize: 14), onChanged: _advancedSearch,
                decoration: InputDecoration(hintText: "Αναζήτηση...", hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
            const Divider(color: Colors.white24, height: 1),
            Expanded(child: (selectedResult == null && searchResultsList.isEmpty) ? const Center(child: Text("Αναζητήστε όνομα...", style: TextStyle(color: Colors.white24, fontSize: 13))) : (selectedResult != null) ? _buildSelectionView() : _buildSearchResultsList()),
            
            Column(
              children: [
                Container(width: 80, height: 2, margin: const EdgeInsets.only(top: 15, bottom: 5),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, const Color(0xFFC5A059).withOpacity(0.8), Colors.transparent])),
                ),
                TextButton(
                  onPressed: () => _launchURL("https://365orthodoxy.com"),
                  child: Text("365orthodoxy.com", style: TextStyle(color: const Color(0xFFC5A059).withOpacity(0.7), fontSize: 12, letterSpacing: 1.1)),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ]))))),
    ]);
  }

  Widget _buildSearchResultsList() {
    return ListView.separated(controller: _scrollController, padding: const EdgeInsets.only(top: 10), itemCount: searchResultsList.length,
      separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final item = searchResultsList[index];
        return ListTile(dense: true, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(item['display_date'], style: TextStyle(color: primaryGold.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
          Text(item['saint'], style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]), onTap: () => setState(() { selectedResult = Map.from(item); }));
      });
  }

  Widget _buildSelectionView() {
    return SingleChildScrollView(padding: const EdgeInsets.only(top: 10), child: Column(children: [
      SelectableText(selectedResult!['display_date'] ?? "", textAlign: TextAlign.center, style: TextStyle(color: primaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
      Text(selectedResult!['saint'] ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)),
      Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5), child: Text(showModernSearch ? (selectedResult!['translation'] ?? "") : (selectedResult!['quote'] ?? ""), textAlign: TextAlign.center, style: TextStyle(color: lightGold, fontStyle: FontStyle.italic, fontSize: 20, height: 1.25))),
      _buildCustomSwitch(showModernSearch, (v) => setState(() => showModernSearch = v), withGlobe: true, withBorder: true),
    ]));
  }

  Widget _buildCustomSwitch(bool value, Function(bool) onChanged, {bool withGlobe = false, bool withBorder = false}) {
    return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (withGlobe) const Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.public, color: Colors.white54, size: 20)),
      GestureDetector(onTap: () => onChanged(!value), child: Container(width: 52, height: 28, padding: const EdgeInsets.all(3), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: withBorder ? primaryGold.withOpacity(0.6) : Colors.white30, width: 1.5), color: value ? Colors.white.withOpacity(0.15) : Colors.black38),
        child: AnimatedAlign(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))]))))),
    ]);
  }
}

class GlassWidget extends StatelessWidget {
  final Widget child; final double width, height, radius; final bool isLight;
  const GlassWidget({super.key, required this.child, required this.width, required this.height, this.radius = 28, this.isLight = false});
  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30, spreadRadius: -5, offset: const Offset(0, 15)), BoxShadow(color: Colors.white.withOpacity(0.08), blurRadius: 20, spreadRadius: -12, offset: const Offset(0, -5))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: Stack(children: [
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(isLight ? 0.12 : 0.06), borderRadius: BorderRadius.circular(radius)))),
        Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), border: Border.all(color: Colors.white.withOpacity(isLight ? 0.25 : 0.15), width: 1.4), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.15), Colors.transparent, Colors.black.withOpacity(0.1)]))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: child),
      ])));
  }
}

class AstroEngine {
  static double degToRad(double d) => d * pi / 180;
  static double radToDeg(double r) => r * 180 / pi;
  static Map<String, String> getSunTimes(DateTime date, double lat, double lon) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    double lngHour = lon / 15, tRise = dayOfYear + ((6 - lngHour) / 24), tSet = dayOfYear + ((18 - lngHour) / 24);
    double? calc(double t, bool isRise) {
      double M = (0.9856 * t) - 3.289, L = M + (1.916 * sin(degToRad(M))) + (0.020 * sin(2 * degToRad(M))) + 282.634;
      L = (L + 360) % 360; double RA = radToDeg(atan(0.91764 * tan(degToRad(L)))); RA = (RA + 360) % 360;
      double LQ = (L / 90).floor() * 90, RQ = (RA / 90).floor() * 90; RA = (RA + (LQ - RQ)) / 15;
      double sinDec = 0.39782 * sin(degToRad(L)), cosDec = cos(asin(sinDec));
      double cosH = (cos(degToRad(90.833)) - (sinDec * sin(degToRad(lat)))) / (cosDec * cos(degToRad(lat)));
      if (cosH > 1 || cosH < -1) return null;
      double H = (isRise ? 360 - radToDeg(acos(cosH)) : radToDeg(acos(cosH))) / 15;
      double UT = (H + RA - (0.06571 * t) - 6.622 - lngHour) % 24;
      return (UT < 0) ? UT + 24 : UT;
    }
    String fmt(double? ut) {
      if (ut == null) return "--:--";
      double lt = (ut + DateTime.now().timeZoneOffset.inHours) % 24;
      return "${lt.floor().toString().padLeft(2, '0')}:${((lt - lt.floor()) * 60).floor().toString().padLeft(2, '0')}";
    }
    return {'sunrise': fmt(calc(tRise, true)), 'sunset': fmt(calc(tSet, false))};
  }
  static String getMoonPhaseIcon(DateTime date) {
    double diff = date.difference(DateTime(2000, 1, 6, 18, 14)).inSeconds / 86400.0;
    double p = (diff % 29.53059) / 29.53059;
    if (p < 0.06) return "🌑"; if (p < 0.20) return "🌒"; if (p < 0.30) return "🌓"; if (p < 0.45) return "🌔";
    if (p < 0.55) return "🌕"; if (p < 0.70) return "🌖"; if (p < 0.80) return "🌗"; if (p < 0.94) return "🌘";
    return "🌑";
  }
}