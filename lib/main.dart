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
        // Εφαρμογή της γραμματοσειράς που δήλωσες στο pubspec
        fontFamily: 'GFSDidot', 
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

  String sunrise = "--:--";
  String sunset = "--:--";
  String moonIcon = "🌑";
  String formattedDate = "";

  // Παλέτα "Modern Crystal"
  final Color primaryGold = const Color(0xFFD4AF37);
  final Color lightGold = const Color(0xFFF7E29F);

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
      sunrise = times['sunrise']!;
      sunset = times['sunset']!;
      moonIcon = AstroEngine.getMoonPhaseIcon(now);
      formattedDate = DateFormat('EEEE, d MMMM yyyy', 'el_GR').format(now);
    });
  }

  // --- LASER ENGRAVED EFFECT (V4.0) ---
  // Βελτιωμένο για μέγιστη ευκρίνεια στη Didot
  List<Shadow> get laserEngravedShadows => [
    Shadow(
      color: Colors.white.withOpacity(0.3),
      offset: const Offset(0, 0.6),
      blurRadius: 0.4,
    ),
    Shadow(
      color: Colors.black.withOpacity(0.8),
      offset: const Offset(0, -1.2),
      blurRadius: 1.2,
    ),
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
    List<Map<String, dynamic>> scoredResults = [];
    for (var item in allYearData) {
      String name = _normalizeGreek(item['saint'].toString());
      int score = 0;
      if (name.contains(normalizedQuery)) {
        score += 10;
        if (name.startsWith(normalizedQuery)) score += 500;
      }
      if (score > 0) scoredResults.add({'data': item, 'score': score});
    }
    scoredResults.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    setState(() { selectedResult = null; searchResultsList = scoredResults.map((e) => e['data']).toList(); });
  }

  Future<void> loadDailyData() async {
    final now = DateTime.now();
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    try {
      final String response = await rootBundle.loadString('assets/data/${months[now.month - 1]}.json');
      final List<dynamic> data = json.decode(response);
      final String todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      setState(() {
        todayData = data.firstWhere((item) => item['date'] == todayStr, orElse: () => data[now.day - 1]);
        isLoading = false;
      });
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> loadAllDataSources() async {
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    List<dynamic> tempYear = [];
    for (var month in months) {
      try {
        final String response = await rootBundle.loadString('assets/data/$month.json');
        tempYear.addAll(json.decode(response));
      } catch (e) {}
    }
    try {
      final extra = await rootBundle.loadString('assets/data/extra_quotes.json');
      setState(() { allYearData = tempYear; extraQuotesData = json.decode(extra); });
    } catch (e) { setState(() => allYearData = tempYear); }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _getNewRandomQuote() {
    if (extraQuotesData.isEmpty) return;
    final random = Random();
    setState(() {
      _searchController.clear();
      searchResultsList = [];
      selectedResult = Map.from(extraQuotesData[random.nextInt(extraQuotesData.length)]);
      selectedResult!['type'] = 'quote';
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    setState(() { selectedResult = null; searchResultsList = []; _searchController.clear(); });
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(primary: primaryGold, onPrimary: Colors.black, surface: const Color(0xFF1A2A6C)),
                ),
                child: CalendarDatePicker(
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2026, 12, 31),
                  onDateChanged: (date) => Navigator.pop(context, date),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (picked != null) {
      final dateStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      final result = allYearData.firstWhere((item) => item['date'] == dateStr, orElse: () => null);
      setState(() {
        if (result != null) {
          selectedResult = Map.from(result);
          selectedResult!['type'] = 'saint';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double w = 310; const double h = 240; const double mockupW = 400; const double topPos = 70;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: mockupW, height: 750,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(45), border: Border.all(color: Colors.white12, width: 2)),
          child: Stack(
            children: [
              Container(color: const Color(0xFF1A2A6C)),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                top: topPos, left: (mockupW - w) / 2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: isMacroDrawerOpen ? 0.0 : 1.0,
                  child: IgnorePointer(ignoring: isMacroDrawerOpen, child: _buildMainCard(w, h)),
                ),
              ),
              Positioned(
                top: topPos + h + 15,
                left: (mockupW - w) / 2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: (isMicroDrawerOpen && !isMacroDrawerOpen) ? 1.0 : 0.0,
                  child: IgnorePointer(ignoring: !isMicroDrawerOpen || isMacroDrawerOpen, child: _buildMicroDrawer(w)),
                ),
              ),
              _buildMacroDrawerIntegrated(w, mockupW, topPos),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(double w, double h) {
    if (isLoading) return CircularProgressIndicator(color: primaryGold);
    return GlassWidget(
      width: w, height: h, radius: 28,
      child: Column(
        children: [
          Text(
            todayData?['display_date'] ?? "", 
            style: TextStyle(
              color: primaryGold, fontSize: 13, fontWeight: FontWeight.bold,
              letterSpacing: 1.4, shadows: laserEngravedShadows,
            )
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  todayData?['saint'] ?? "", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                    fontSize: 21, color: lightGold, fontWeight: FontWeight.bold, 
                    shadows: laserEngravedShadows, letterSpacing: 0.5,
                  )
                ),
              ),
              IconButton(icon: const Icon(Icons.info_outline, color: Colors.white70, size: 16), onPressed: () => _launchURL(todayData?['wiki_url'] ?? "")),
            ],
          ),
          Divider(color: primaryGold.withOpacity(0.3), thickness: 0.5, indent: 60, endIndent: 60),
          const Spacer(),
          Text(
            showModernMain ? (todayData?['translation'] ?? "") : (todayData?['quote'] ?? ""),
            textAlign: TextAlign.center, maxLines: 4,
            style: TextStyle(
              fontSize: 22, fontStyle: FontStyle.italic, color: primaryGold.withOpacity(0.95), 
              height: 1.15, fontWeight: FontWeight.w400, shadows: laserEngravedShadows,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              Text(todayData?['reference'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              IconButton(
                icon: Icon(isMicroDrawerOpen ? Icons.keyboard_arrow_up : Icons.menu, color: primaryGold, size: 20),
                onPressed: () => setState(() => isMicroDrawerOpen = !isMicroDrawerOpen),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Τα υπόλοιπα Widgets παραμένουν Glass ---
  Widget _buildMicroDrawer(double w) {
    return GlassWidget(
      height: 65, width: w, radius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(children: [
            Switch(value: showModernMain, activeColor: primaryGold, onChanged: (v) => setState(() => showModernMain = v)), 
            const Icon(Icons.public, color: Colors.white70, size: 18)
          ]),
          IconButton(icon: const Icon(Icons.share, color: Colors.white70, size: 20), onPressed: () {}),
          IconButton(icon: const Icon(Icons.copy, color: Colors.white70, size: 20), onPressed: () {
             Clipboard.setData(ClipboardData(text: "${todayData?['quote']}\n${todayData?['reference']}"));
          }),
          IconButton(icon: Icon(Icons.grid_view_rounded, color: primaryGold, size: 22), onPressed: () => setState(() { isMicroDrawerOpen = false; isMacroDrawerOpen = true; })),
        ],
      ),
    );
  }

  Widget _buildMacroDrawerIntegrated(double w, double mockupW, double top) {
    return Stack(
      children: [
        if (isMacroDrawerOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => isMacroDrawerOpen = false),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15), child: Container(color: Colors.black.withOpacity(0.3))),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          top: top, left: (mockupW - w) / 2,
          child: IgnorePointer(
            ignoring: !isMacroDrawerOpen,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400), opacity: isMacroDrawerOpen ? 1.0 : 0.0,
              child: GlassWidget(
                width: w, height: isMacroDrawerOpen ? 550 : 240, radius: 32,
                child: Column(
                  children: [
                    Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny_outlined, color: primaryGold, size: 14),
                        Icon(Icons.arrow_upward, color: primaryGold, size: 10),
                        const SizedBox(width: 4),
                        Text(sunrise, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 15),
                        Text(moonIcon, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 15),
                        const Icon(Icons.wb_sunny_outlined, color: Colors.white70, size: 14),
                        const Icon(Icons.arrow_downward, color: Colors.white70, size: 10),
                        const SizedBox(width: 4),
                        Text(sunset, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white, size: 22), onPressed: () => _selectDate(context)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18), onPressed: () => setState(() => isMacroDrawerOpen = false)),
                        TextButton.icon(onPressed: _getNewRandomQuote, icon: Icon(Icons.auto_awesome, color: primaryGold, size: 18), label: const Text("Νέο", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10), height: 45,
                      child: TextField(
                        controller: _searchController, 
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'sans-serif'),
                        onChanged: _advancedSearch,
                        decoration: InputDecoration(
                          hintText: "Αναζήτηση Αγίου...", hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                          filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white24, height: 1),
                    Expanded(
                      child: (selectedResult == null && searchResultsList.isEmpty)
                      ? const Center(child: Text("Επιλέξτε Ημερομηνία, Όνομα ή 'Νέο'", textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 13)))
                      : (selectedResult != null) ? _buildSelectionView() : _buildSearchResultsList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsList() {
    return RawScrollbar(
      controller: _scrollController, thumbColor: primaryGold, radius: const Radius.circular(10), thickness: 4, thumbVisibility: true,
      child: ListView.separated(
        controller: _scrollController, padding: const EdgeInsets.only(top: 10, right: 10), itemCount: searchResultsList.length,
        separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
        itemBuilder: (context, index) {
          final item = searchResultsList[index];
          return ListTile(
            dense: true,
            title: Text(item['saint'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            trailing: Text(item['display_date'], style: TextStyle(color: primaryGold, fontSize: 13)),
            onTap: () => setState(() { selectedResult = Map.from(item); selectedResult!['type'] = 'saint'; }),
          );
        },
      ),
    );
  }

  Widget _buildSelectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(child: Text(selectedResult!['saint'] ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19))),
              if (selectedResult!['type'] == 'saint') IconButton(icon: Icon(Icons.info_outline, color: primaryGold, size: 18), onPressed: () => _launchURL(selectedResult!['wiki_url'] ?? "")),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
            child: Text(showModernSearch ? (selectedResult!['translation'] ?? "") : (selectedResult!['quote'] ?? ""), textAlign: TextAlign.center, style: TextStyle(color: primaryGold, fontStyle: FontStyle.italic, fontSize: 20, height: 1.25, shadows: laserEngravedShadows)),
          ),
          Text(selectedResult!['reference'] ?? "", style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Switch(value: showModernSearch, activeColor: primaryGold, onChanged: (v) => setState((){ showModernSearch = v; })),
              const Icon(Icons.public, color: Colors.white54, size: 18),
              const SizedBox(width: 30),
              IconButton(icon: const Icon(Icons.copy, color: Colors.white54, size: 20), onPressed: () { 
                Clipboard.setData(ClipboardData(text: "${selectedResult!['quote']}\n${selectedResult!['reference']}")); 
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class GlassWidget extends StatelessWidget {
  final Widget child; final double width; final double height; final double radius;
  const GlassWidget({super.key, required this.child, required this.width, required this.height, this.radius = 28});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 20))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(radius))),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(0.2), Colors.transparent, Colors.black.withOpacity(0.15)],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            CustomPaint(painter: CrystalBorderPainter(radius: radius), child: SizedBox(width: width, height: height)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: child),
          ],
        ),
      ),
    );
  }
}

class CrystalBorderPainter extends CustomPainter {
  final double radius;
  CrystalBorderPainter({required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..strokeWidth = 1.4 ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(0.8), Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.4)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- ASTRO ENGINE ---
class AstroEngine {
  static double degToRad(double d) => d * pi / 180;
  static double radToDeg(double r) => r * 180 / pi;
  static Map<String, String> getSunTimes(DateTime date, double lat, double lon) {
    int dayOfYear = int.parse(DateFormat("D").format(date));
    double lngHour = lon / 15;
    double tRise = dayOfYear + ((6 - lngHour) / 24);
    double tSet = dayOfYear + ((18 - lngHour) / 24);
    double? calcTime(double t, bool isRise) {
      double M = (0.9856 * t) - 3.289;
      double L = M + (1.916 * sin(degToRad(M))) + (0.020 * sin(2 * degToRad(M))) + 282.634;
      L = (L + 360) % 360;
      double RA = radToDeg(atan(0.91764 * tan(degToRad(L))));
      RA = (RA + 360) % 360;
      double Lquadrant = (L / 90).floor() * 90;
      double RAquadrant = (RA / 90).floor() * 90;
      RA = (RA + (Lquadrant - RAquadrant)) / 15;
      double sinDec = 0.39782 * sin(degToRad(L));
      double cosDec = cos(asin(sinDec));
      double cosH = (cos(degToRad(90.833)) - (sinDec * sin(degToRad(lat)))) / (cosDec * cos(degToRad(lat)));
      if (cosH > 1 || cosH < -1) return null;
      double H = isRise ? 360 - radToDeg(acos(cosH)) : radToDeg(acos(cosH));
      H = H / 15;
      double T = H + RA - (0.06571 * t) - 6.622;
      double UT = (T - lngHour) % 24;
      if (UT < 0) UT += 24;
      return UT;
    }
    String formatTime(double? ut) {
      if (ut == null) return "--:--";
      double localOffset = DateTime.now().timeZoneOffset.inHours.toDouble();
      double localTime = (ut + localOffset) % 24;
      int h = localTime.floor(); int m = ((localTime - h) * 60).floor();
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
    }
    return {'sunrise': formatTime(calcTime(tRise, true)), 'sunset': formatTime(calcTime(tSet, false))};
  }
  static String getMoonPhaseIcon(DateTime date) {
    DateTime refDate = DateTime(2000, 1, 6, 18, 14); 
    double diff = date.difference(refDate).inSeconds / 86400.0;
    double phase = (diff % 29.53059) / 29.53059;
    if (phase < 0.06) return "🌑"; if (phase < 0.20) return "🌒"; if (phase < 0.30) return "🌓"; if (phase < 0.45) return "🌔"; 
    if (phase < 0.55) return "🌕"; if (phase < 0.70) return "🌖"; if (phase < 0.80) return "🌗"; if (phase < 0.94) return "🌘"; 
    return "🌑";
  }
}