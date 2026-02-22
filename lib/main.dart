import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

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
  Map<String, dynamic>? tomorrowData;
  Map<String, dynamic>? selectedResult; 
  List<dynamic> searchResultsList = []; 
  bool isLoading = true;
  bool showModernMain = false;
  bool showModernSearch = false; 
  bool isMicroDrawerOpen = false;
  bool isMacroDrawerOpen = false;
  
  SharedPreferences? _prefs;
  Set<String> _scheduledDates = {};

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> allYearData = []; 
  List<dynamic> extraQuotesData = [];
  String sunrise = "--:--", sunset = "--:--", moonIcon = "🌑", formattedDate = "";
  final Color primaryGold = const Color(0xFFD4AF37), lightGold = const Color(0xFFF7E29F);

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _initializeNotifications();
    _calculateAstroData();
    loadDailyData();
    loadAllDataSources();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _scheduledDates = _prefs!.getKeys();
    });
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await notificationsPlugin.initialize(settings);
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
    const diacritics = {
      'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
      'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ',
      'ἀ': 'α', 'ἁ': 'α', 'ἂ': 'α', 'ἃ': 'α', 'ἄ': 'α', 'ἅ': 'α', 'ἆ': 'α', 'ἇ': 'α',
      'ἐ': 'ε', 'ἑ': 'ε', 'ἒ': 'ε', 'ἓ': 'ε', 'ἔ': 'ε', 'ἕ': 'ε',
      'ἠ': 'η', 'ἡ': 'η', 'ἢ': 'η', 'ἣ': 'η', 'ἤ': 'η', 'ἥ': 'η', 'ἦ': 'η', 'ἧ': 'η',
      'ἰ': 'ι', 'ἱ': 'ι', 'ἲ': 'ι', 'ἳ': 'ι', 'ἴ': 'ι', 'ἵ': 'ι', 'ἶ': 'ι', 'ἷ': 'ι',
      'ὀ': 'ο', 'ὁ': 'ο', 'ὂ': 'ο', 'ὃ': 'ο', 'ὄ': 'ο', 'ὅ': 'ο',
      'ὐ': 'υ', 'ὑ': 'υ', 'ὒ': 'υ', 'ὓ': 'υ', 'ὔ': 'υ', 'ὕ': 'υ', 'ὖ': 'υ', 'ὗ': 'υ',
      'ὠ': 'ω', 'ὡ': 'ω', 'ὢ': 'ω', 'ὣ': 'ω', 'ὤ': 'ω', 'ὥ': 'ω', 'ὦ': 'ω', 'ὧ': 'ω',
    };
    diacritics.forEach((key, value) => str = str.replaceAll(key, value));
    return str.toUpperCase();
  }

  void _advancedSearch(String query) {
    if (query.isEmpty) {
      setState(() { searchResultsList = []; selectedResult = null; });
      return;
    }
    String normalizedQuery = _normalizeGreek(query).trim();
    final Map<String, List<String>> nicknameMap = {
      "ΓΕΩΡΓΙΟΣ": ["ΓΙΩΡΓΟΣ", "ΓΙΩΡΓΗΣ"], "ΙΩΑΝΝΗΣ": ["ΓΙΑΝΝΗΣ"],
      "ΚΩΝΣΤΑΝΤΙΝΟΣ": ["ΚΩΣΤΑΣ", "ΚΩΣΤΗΣ", "ΝΤΙΝΟΣ"], "ΔΗΜΗΤΡΙΟΣ": ["ΔΗΜΗΤΡΗΣ"],
      "ΝΙΚΟΛΑΟΣ": ["ΝΙΚΟΣ", "ΝΙΚΟΛΑΣ"], "ΠΑΝΑΓΙΩΤΗΣ": ["ΠΑΝΟΣ"],
      "ΒΑΣΙΛΕΙΟΣ": ["ΒΑΣΙΛΗΣ"], "ΕΜΜΑΝΟΥΗΛ": ["ΜΑΝΩΛΗΣ", "ΜΑΝΟΣ"],
      "ΜΙΧΑΗΛ": ["ΜΙΧΑΛΗΣ"], "ΑΘΑΝΑΣΙΟΣ": ["ΘΑΝΑΣΗΣ"],
      "ΜΑΡΙΑ": ["ΜΑΙΡΗ", "ΜΑΡΙΩ", "ΜΑΡΙΤΣΑ", "ΜΑΡΟΥΛΑ", "ΠΑΝΑΓΙΑ", "ΔΕΣΠΟΙΝΑ"],
      "ΕΛΕΝΗ": ["ΛΕΝΑ", "ΈΛΕΝΑ", "ΛΕΝΙΩ"], 
    };

    List<Map<String, dynamic>> scoredResults = [];
    for (var item in allYearData) {
      String saintName = _normalizeGreek(item['saint'].toString());
      int score = 0; bool hasMatch = false;
      nicknameMap.forEach((official, nicknames) {
        if ((official.startsWith(normalizedQuery) || nicknames.any((nick) => nick.startsWith(normalizedQuery))) && saintName.contains(official)) {
          hasMatch = true; score += 10000;
        }
      });
      if (saintName.contains(normalizedQuery)) {
        hasMatch = true; score += 1000;
        if (saintName.startsWith(normalizedQuery)) score += 2000;
      }
      if (hasMatch) {
        int priority = item['priority'] ?? 0;
        score += priority * 2000;
        scoredResults.add({'data': item, 'score': score});
      }
    }
    scoredResults.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    setState(() { selectedResult = null; searchResultsList = scoredResults.map((e) => e['data']).toList(); });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030, 12, 31),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: primaryGold, onPrimary: Colors.black, surface: const Color(0xFF1A1A1A)),
          dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
        ),
        child: Center(child: SizedBox(width: 340, child: child!)),
      ),
    );
    if (picked != null) {
      final String pickedMMDD = DateFormat('MM-dd').format(picked);
      final result = allYearData.firstWhere((item) => item['date'].toString().contains(pickedMMDD), orElse: () => {});
      if (result.isNotEmpty) { setState(() { selectedResult = Map.from(result); _searchController.clear(); searchResultsList = []; }); }
    }
  }

  Future<void> _scheduleReminder(dynamic item) async {
    if (item == null) return;
    String dateKey = item['date'].toString();
    if (_scheduledDates.contains(dateKey)) {
      await _prefs?.remove(dateKey);
      setState(() { _scheduledDates.remove(dateKey); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Η υπενθύμιση ακυρώθηκε.")));
    } else {
      final DateTime saintDate = DateTime.parse(item['date']);
      final DateTime reminderTime = saintDate.subtract(const Duration(days: 1)).add(const Duration(hours: 9));
      if (reminderTime.isAfter(DateTime.now())) {
        await notificationsPlugin.zonedSchedule(item.hashCode, "Υπενθύμιση", "Αύριο εορτάζει ο ${item['saint']}", tz.TZDateTime.from(reminderTime, tz.local),
          const NotificationDetails(android: AndroidNotificationDetails('saint_channel', 'Reminders', importance: Importance.max, priority: Priority.high), iOS: DarwinNotificationDetails()),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle);
      }
      await _prefs?.setBool(dateKey, true);
      setState(() { _scheduledDates.add(dateKey); });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: primaryGold, content: Text("Η υπενθύμιση αποθηκεύτηκε!", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))));
    }
  }

  Future<void> loadDailyData() async {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    try {
      final String response = await rootBundle.loadString('assets/data/${months[now.month - 1]}.json');
      final List<dynamic> data = json.decode(response);
      final String todayMMDD = DateFormat('MM-dd').format(now);
      final String tomorrowMMDD = DateFormat('MM-dd').format(tomorrow);
      setState(() { 
        todayData = data.firstWhere((item) => item['date'].toString().contains(todayMMDD), orElse: () => data.isNotEmpty ? data.first : null);
        tomorrowData = data.firstWhere((item) => item['date'].toString().contains(tomorrowMMDD), orElse: () => null);
        isLoading = false; 
      });
    } catch (e) { setState(() => isLoading = false); }
  }

  Future<void> loadAllDataSources() async {
    final months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
    List<dynamic> tempYear = [];
    for (var month in months) { try { final String resp = await rootBundle.loadString('assets/data/$month.json'); tempYear.addAll(json.decode(resp)); } catch (e) {} }
    setState(() { allYearData = tempYear; });
    try { final extra = await rootBundle.loadString('assets/data/extra_quotes.json'); setState(() { extraQuotesData = json.decode(extra); }); } catch (e) {}
  }

  void _launchURL(String? url) async { if (url == null || url.isEmpty) return; final Uri uri = Uri.parse(url); if (await canLaunchUrl(uri)) await launchUrl(uri); }

  void _getNewRandomQuote() {
    if (extraQuotesData.isEmpty) return;
    final random = Random();
    setState(() { _searchController.clear(); searchResultsList = []; selectedResult = Map.from(extraQuotesData[random.nextInt(extraQuotesData.length)]); });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // 1️⃣ ADAPTIVE RADIUS (0.085 for mature Apple feel)
    const double minWidgetWidth = 300;
    const double maxWidgetWidth = 380;
    final double w = screenWidth.clamp(minWidgetWidth, maxWidgetWidth).toDouble();
    final double dynamicRadius = w * 0.085;

    // PROPORTIONAL REFACTOR
    final double mainCardH = w * 0.75;
    final double macroHeight = w * 1.6;
    final double widgetTopPos = w * 0.05; 
    final double containerHeight = macroHeight + (w * 0.35);

    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Transform.scale(
          scale: isLargeScreen ? 0.92 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SizedBox(
              width: w, 
              height: containerHeight, 
              child: Stack(
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                children: [
                  // MAIN CARD
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 500), 
                    top: widgetTopPos, 
                    left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 500), 
                      opacity: isMacroDrawerOpen ? 0.0 : 1.0, 
                      child: IgnorePointer(
                        ignoring: isMacroDrawerOpen, 
                        child: _buildMainCard(w, mainCardH, dynamicRadius)
                      )
                    )
                  ),
                  // MICRO DRAWER
                  Positioned(
                    top: widgetTopPos + mainCardH + (w * 0.04), 
                    left: 0, right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300), 
                      opacity: (isMicroDrawerOpen && !isMacroDrawerOpen) ? 1.0 : 0.0, 
                      child: IgnorePointer(
                        ignoring: !isMicroDrawerOpen || isMacroDrawerOpen, 
                        child: _buildMicroDrawer(w, dynamicRadius * 0.8)
                      )
                    )
                  ),
                  // MACRO DRAWER
                  _buildMacroDrawerIntegrated(w, macroHeight, widgetTopPos, dynamicRadius * 1.15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(double w, double h, double radius) {
    if (isLoading) return Center(child: CircularProgressIndicator(color: primaryGold));
    bool isMajorHoliday = tomorrowData != null && tomorrowData!['priority'] == 1;
    bool isUserReminder = tomorrowData != null && _scheduledDates.contains(tomorrowData!['date'].toString());

    return GlassWidget(
      width: w, height: h, radius: radius, 
      child: Column(children: [
        if (tomorrowData != null && (isMajorHoliday || isUserReminder))
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            decoration: BoxDecoration(
              color: isUserReminder ? Colors.redAccent.withOpacity(0.15) : primaryGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isUserReminder ? Colors.redAccent.withOpacity(0.3) : primaryGold.withOpacity(0.3), width: 0.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isUserReminder ? Icons.alarm_on : Icons.notification_important_rounded, color: isUserReminder ? Colors.redAccent : primaryGold, size: 14),
              const SizedBox(width: 6),
              Text("Αύριο: ${tomorrowData!['saint']}", style: TextStyle(color: isUserReminder ? Colors.white70 : lightGold, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        Text(todayData?['display_date'] ?? "", style: TextStyle(color: primaryGold, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.4, shadows: laserEngravedShadows)),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // 5️⃣ OPTICAL TYPOGRAPHY SCALING (Saint name)
          Flexible(child: Text(todayData?['saint'] ?? "", textAlign: TextAlign.center, style: TextStyle(fontSize: w * 0.055, color: Colors.white, fontWeight: FontWeight.bold, shadows: laserEngravedShadows))),
          IconButton(icon: const Icon(Icons.info_outline, color: Colors.white38, size: 16), onPressed: () => _launchURL(todayData?['wiki_url'])),
        ]),
        Divider(color: primaryGold.withOpacity(0.3), thickness: 0.5, indent: 60, endIndent: 60),
        const Spacer(),
        // 5️⃣ OPTICAL TYPOGRAPHY SCALING (Quote)
        Text(showModernMain ? (todayData?['translation'] ?? "") : (todayData?['quote'] ?? ""), textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: w * 0.05, fontStyle: FontStyle.italic, color: lightGold, height: 1.2, shadows: laserEngravedShadows)),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const SizedBox(width: 40),
          Text(todayData?['reference'] ?? "", style: const TextStyle(color: Colors.white38, fontSize: 11)),
          // 7️⃣ ANIMATED ICON POLISH
          IconButton(
            onPressed: () => setState(() => isMicroDrawerOpen = !isMicroDrawerOpen),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child: Icon(
                isMicroDrawerOpen ? Icons.keyboard_arrow_up : Icons.menu,
                key: ValueKey(isMicroDrawerOpen),
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ]),
      ])
    );
  }

  Widget _buildMicroDrawer(double w, double radius) {
    // 4️⃣ PROPORTIONAL MICRO DRAWER HEIGHT
    return GlassWidget(
      height: w * 0.18, width: w, radius: radius, isLight: true, 
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildCustomSwitch(showModernMain, (v) => setState(() => showModernMain = v)),
        IconButton(icon: const Icon(Icons.share, color: Colors.white70, size: 20), onPressed: () => Share.share("${todayData?['quote']}\n${todayData?['reference']}")),
        IconButton(icon: const Icon(Icons.copy, color: Colors.white70, size: 20), onPressed: () => Clipboard.setData(ClipboardData(text: "${todayData?['quote']}\n${todayData?['reference']}"))),
        IconButton(icon: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22), onPressed: () => setState(() { isMicroDrawerOpen = false; isMacroDrawerOpen = true; })),
      ])
    );
  }

  Widget _buildMacroDrawerIntegrated(double w, double h, double topPos, double radius) {
    return Stack(children: [
      if (isMacroDrawerOpen) 
        Positioned.fill(child: GestureDetector(onTap: () => setState(() => isMacroDrawerOpen = false), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: w * 0.04, sigmaY: w * 0.04), child: Container(color: Colors.transparent)))),
      AnimatedPositioned(duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart, top: topPos, left: 0, right: 0,
        child: IgnorePointer(ignoring: !isMacroDrawerOpen, child: AnimatedOpacity(duration: const Duration(milliseconds: 400), opacity: isMacroDrawerOpen ? 1.0 : 0.0,
          child: GlassWidget(
            width: w, height: h, radius: radius, 
            child: Column(children: [
              Text(formattedDate, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 5),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.wb_sunny_outlined, color: primaryGold, size: 14), const SizedBox(width: 4),
                Text(sunrise, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 15), Text(moonIcon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 15), Text(sunset, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white, size: 22), onPressed: () => _selectDate(context)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 18), onPressed: () => setState(() => isMacroDrawerOpen = false)),
                TextButton.icon(onPressed: _getNewRandomQuote, icon: Icon(Icons.auto_awesome, color: primaryGold, size: 18), label: const Text("Νέο", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
              ]),
              Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: primaryGold.withOpacity(0.8), width: 1.5)),
                child: TextField(controller: _searchController, style: const TextStyle(color: Colors.white, fontSize: 14), onChanged: _advancedSearch,
                  decoration: InputDecoration(hintText: "Αναζήτηση...", hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
              const Divider(color: Colors.white24, height: 1),
              Expanded(child: (selectedResult == null && searchResultsList.isEmpty) ? const Center(child: Text("Αναζητήστε όνομα...", style: TextStyle(color: Colors.white24, fontSize: 13))) : (selectedResult != null) ? _buildSelectionView() : _buildSearchResultsList()),
              const SizedBox(height: 8),
              TextButton(onPressed: () => _launchURL("https://365orthodoxy.com"), child: Text("365orthodoxy.com", style: TextStyle(color: const Color(0xFFC5A059).withOpacity(0.7), fontSize: 11, letterSpacing: 1.1))),
            ])
          )))),
    ]);
  }

  Widget _buildSearchResultsList() {
    return ListView.separated(controller: _scrollController, padding: const EdgeInsets.only(top: 10), itemCount: searchResultsList.length,
      separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
      itemBuilder: (context, index) {
        final item = searchResultsList[index];
        bool isScheduled = _scheduledDates.contains(item['date'].toString());
        return ListTile(dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8), title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SelectableText(item['display_date'], style: TextStyle(color: primaryGold.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: Icon(isScheduled ? Icons.notifications_active : Icons.notifications_active_outlined, color: isScheduled ? primaryGold : Colors.white38, size: 18), onPressed: () => _scheduleReminder(item)),
          ]),
          Text(item['saint'], style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]), onTap: () => setState(() { selectedResult = Map.from(item); }));
      });
  }

  Widget _buildSelectionView() {
    bool isScheduled = selectedResult != null && _scheduledDates.contains(selectedResult!['date'].toString());
    return SingleChildScrollView(padding: const EdgeInsets.only(top: 10), child: Column(children: [
      SelectableText(selectedResult!['display_date'] ?? "", textAlign: TextAlign.center, style: TextStyle(color: primaryGold, fontSize: 11, fontWeight: FontWeight.bold)),
      Text(selectedResult!['saint'] ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5), child: Text(showModernSearch ? (selectedResult!['translation'] ?? "") : (selectedResult!['quote'] ?? ""), textAlign: TextAlign.center, style: TextStyle(color: lightGold, fontStyle: FontStyle.italic, fontSize: 18, height: 1.2))),
      if (selectedResult!['reference'] != null) Text(selectedResult!['reference'], style: const TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: Icon(isScheduled ? Icons.notifications_active : Icons.notifications_active_outlined, color: isScheduled ? primaryGold : Colors.white70, size: 18), onPressed: () => _scheduleReminder(selectedResult)),
        IconButton(icon: const Icon(Icons.copy, color: Colors.white70, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: "${selectedResult!['quote']}\n${selectedResult!['reference'] ?? ''}"))),
        IconButton(icon: const Icon(Icons.share, color: Colors.white70, size: 18), onPressed: () => Share.share("${selectedResult!['quote']}\n${selectedResult!['reference'] ?? ''}")),
      ]),
      const SizedBox(height: 8),
      _buildCustomSwitch(showModernSearch, (v) => setState(() => showModernSearch = v), withGlobe: true, withBorder: true),
    ]));
  }

  Widget _buildCustomSwitch(bool value, Function(bool) onChanged, {bool withGlobe = false, bool withBorder = false}) {
    return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (withGlobe) const Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.public, color: Colors.white54, size: 18)),
      GestureDetector(onTap: () => onChanged(!value), child: Container(width: 48, height: 26, padding: const EdgeInsets.all(3), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: withBorder ? primaryGold.withOpacity(0.6) : Colors.white30, width: 1.5), color: value ? Colors.white.withOpacity(0.15) : Colors.black38),
        child: AnimatedAlign(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white))))),
    ]);
  }
}

class GlassWidget extends StatelessWidget {
  final Widget child; final double width, height, radius; final bool isLight;
  const GlassWidget({super.key, required this.child, required this.width, required this.height, this.radius = 28, this.isLight = false});
  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = width * 0.06;
    final double verticalPadding = width * 0.045;
    final double blurSigma = width * 0.07;

    return Container(
      width: width, height: height, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius), 
        // 3️⃣ REFINED SHADOW PHYSICS (Grounded depth)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isLight ? 0.18 : 0.28),
            blurRadius: width * 0.10,
            spreadRadius: -width * 0.02,
            offset: Offset(0, width * 0.06),
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius), 
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            color: Colors.white.withOpacity(isLight ? 0.14 : 0.045),
            child: Stack(
              children: [
                if (!isLight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            stops: const [0.0, 0.3, 0.7, 1.0],
                            colors: [Colors.white.withOpacity(0.18), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.08)],
                          ),
                        ),
                      ),
                    ),
                  ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        // 2️⃣ PROPORTIONAL BORDER THICKNESS
                        border: Border.all(color: Colors.white.withOpacity(isLight ? 0.25 : 0.15), width: width * 0.0035),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          stops: const [0.0, 0.15, 0.6, 1.0],
                          colors: [Colors.white.withOpacity(isLight ? 0.35 : 0.25), Colors.white.withOpacity(isLight ? 0.12 : 0.08), Colors.transparent, Colors.black.withOpacity(0.06)],
                        ),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                  child: child,
                ),
              ],
            ),
          ),
        )
      )
    );
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