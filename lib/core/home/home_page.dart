import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Intent;
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syno/core/components/CustomBottomSheet.dart';
import 'package:syno/core/components/WebgeneratedContent.dart';
import 'package:syno/core/components/custom_app_bar.dart';
import 'package:syno/core/components/custom_web_sidebar.dart';
import 'package:syno/core/components/web_app_bar.dart';
// import 'package:toasta/toasta.dart';

import '../../app/constants/constants.dart';
import '../../helpers/duration_parsers.dart';
import '../../helpers/thumbnail_helper.dart';
import '../components/animated_loading_state.dart';
import '../components/build_base_sheet.dart';
import 'package:syno/core/components/generated_content_view.dart';
import '../components/webgenerated_content.dart';
import '../components/web_custom_app_bar.dart';
import '../components/web_custom_sidebar.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late Timer _timer;
  int _elapsedSeconds = 0;
  late final AnimationController _controller;
  String _elapsedTimeText = "";
  TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  bool _componentsVisible = false;
  String _title = '';
  String _summary = '';
  String _introduction = '';
  List<String>? _bulletPoints = [];
  String _conclusion = '';
  String _thumbnailUrl = '';
  String _duration = "";
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    initDeepLinks();
    _urlController.addListener(_onTextChanged);
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _componentsVisible = _urlController.text.isNotEmpty;
    });
  }

  Future<void> initDeepLinks() async {
    _appLinks = AppLinks();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      setState(() {
        _urlController.text = uri.toString().trim();
      });
      // // final toast = Toast(
      // //   status: ToastStatus.success,
      //   title: "Success",
      //   subtitle: "Pasted from Youtube",
      // );
      // // Toasta(context).toast(toast);
    });
  }

  Future<void> _getSummary() async {
    _startTimer();
    setState(() {
      _isLoading = true;
    });

    final supabase = Supabase.instance.client;

    String duration = await getVideoDurationFromUrl(
        _urlController.text.trim(), YT_API_KEY);

    final durationParts = duration.split(':');
    if (durationParts.length >= 2) {
      final minutes = int.tryParse(durationParts[1]);
      if (minutes != null && minutes >= 10) {
        print('Error: Video duration is greater than or equal to 10 minutes');
        showDurationErrorDialog(context);
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } else {
      print('Error: Invalid duration format');
      setState(() {
        _isLoading = false;
      });

      return;
    }

    final response = await supabase
    .from('syno_main')
    .select('summary, youtube_url')
    .eq('youtube_url', _urlController.text.trim())
    .single();

if (response != null && response.isNotEmpty) {
  print("Found in DB");
  final summaryData = jsonDecode(response['summary'] as String);
  final thumbnailUrl = await getYoutubeThumbnail(_urlController.text);
  setState(() {
    _duration = duration;
    _title = summaryData['title'];
    _summary = summaryData['summary'];
    _introduction = summaryData['introduction'];
    _bulletPoints = summaryData['bullet points'] != null
        ? List<String>.from(summaryData['bullet points'])
        : null;
    _conclusion = summaryData['conclusion'];
    _thumbnailUrl = thumbnailUrl;
    _componentsVisible = true;
    _isLoading = false;

    _timer.cancel();
  });
  _timer.cancel(); // Stop the timer
  setState(() {
    _elapsedTimeText = calculateElapsedTime(_elapsedSeconds);
  });
  return;
}

    print("Not in Db so fetching from Server");
    final body = json.encode({'youtube_link': _urlController.text.trim()});
    final headers = {'Content-type': 'application/json'};
    final uri = Uri.parse(MAIN_BACKEND_URL_DEBUG);
    final apiResponse = await http.post(uri, headers: headers, body: body);
    print(apiResponse.body);
    final summaryString = json.decode(apiResponse.body)['summary'];
    final summaryData = json.decode(summaryString);
    final thumbnailUrl = await getYoutubeThumbnail(_urlController.text);

    final supabaseResponse = await supabase.from('syno_main').insert({
      'user_id': supabase.auth.currentUser?.id,
      'youtube_url': _urlController.text.trim(),
      'summary': summaryString,
      'thumbnail_url': thumbnailUrl,
    }).single();

    setState(() {
      _duration = duration;
      _title = summaryData['title'];
      _summary = summaryData['summary'];
      _introduction = summaryData['introduction'];
      _bulletPoints = summaryData['bullet points'] != null
          ? List<String>.from(summaryData['bullet points'])
          : null;
      _conclusion = summaryData['conclusion'];
      _thumbnailUrl = thumbnailUrl;
      _componentsVisible = true;
      _isLoading = false;

      _timer.cancel();
    });
    _timer.cancel(); // Stop the timer
    setState(() {
      _elapsedTimeText = calculateElapsedTime(_elapsedSeconds);
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _getClipboardText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    String? clipboardText = clipboardData?.text;
    setState(() {
      _urlController.text = clipboardText ?? "No Text in Clipboard";
    });
  }

  void showDurationErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xff101010),
        title: Text(
          "🕒 Duration Exceeded",
          style: GoogleFonts.ibmPlexSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 23.sp,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                text: "Syno restricts the acceptance of videos exceeding a duration of ",
                style: GoogleFonts.ibmPlexMono(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.sp,
                ),
                children: [
                  TextSpan(
                    text: "10 minutes",


                    style: GoogleFonts.ibmPlexMono(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12.sp,
                    ),
                  ),
                  const TextSpan(
                    text:
                        " solely for free accounts. As part of our service offering, free account holders are limited to summarize videos that adhere to a maximum duration of 10 minutes.",
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Dismiss",
                    style: GoogleFonts.ibmPlexMono(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xff0b0b0d),
        body: Row(
          children: [
            kIsWeb ? const WebSideBar() : Container(),
            Expanded(
              flex: 2,
              child: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  kIsWeb ? const WebCustomAppBar() : const CustomAppBar(),
                  SliverFillRemaining(
                    child: SingleChildScrollView(
                      physics: _componentsVisible
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.only(top: 30.h),
                        child: Center(
                          child: _isLoading
                              ? const AnimatedLoadingState()
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.symmetric(horizontal: 10.w),
                                      decoration: BoxDecoration(boxShadow: [
                                        BoxShadow(
                                          offset: const Offset(3, 3),
                                          spreadRadius: -13,
                                          blurRadius: 50,
                                          color: const Color.fromRGBO(146, 99, 233, 0.45),
                                        )
                                      ]),
                                      child: TextField(
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w200,
                                          color: Colors.white,
                                        ),
                                        controller: _urlController,
                                        decoration: InputDecoration(
                                          hintText: 'Paste Link to Summarize',
                                          suffixIconConstraints: BoxConstraints(
                                            maxHeight: 70.h,
                                          ),
                                          suffixIcon: Visibility(
                                            visible: !_componentsVisible,
                                            replacement: GestureDetector(
                                              onTap: _getClipboardText,
                                              child: Padding(
                                                padding: EdgeInsets.only(right: 12.w),
                                                child: Container(
                                                  width: 70.h,
                                                  height: 30.h,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(color: const Color(0xff2e2e2e)),
                                                    color: const Color(0xff2e2e2e).withOpacity(0.4),
                                                    borderRadius: BorderRadius.circular(10.r),
                                                  ),
                                                  child: Text(
                                                    "Paste",
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                _urlController.clear();
                                                setState(() {
                                                  _componentsVisible = false;
                                                });
                                              },
                                              child: Padding(
                                                padding: EdgeInsets.only(right: 12.w),
                                                child: CircleAvatar(
                                                  backgroundColor: const Color(0xff2e2e2e).withOpacity(0.4),
                                                  radius: 13.h,
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white60,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          hintStyle: const TextStyle(color: Color(0xffbcb9b9)),
                                          prefixIcon: Lottie.asset(
                                            'assets/lottie/Link.json',
                                            controller: _controller,
                                            height: 10.h,
                                            onLoaded: (composition) {
                                              _controller
                                                ..duration = composition.duration
                                                ..forward();
                                              _controller.addStatusListener((status) {
                                                if (status == AnimationStatus.completed) {
                                                  _controller..reset()..forward();
                                                }
                                              });
                                            },
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xD3181818),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(7.r),
                                            borderSide: const BorderSide(width: 1, color: Color(0xff2e2e2e)),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(7.r),
                                            borderSide: const BorderSide(width: 1, color: Color(0xff9263E9)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    if (_urlController.text.trim().isNotEmpty)
                                      Shimmer(
                                        duration: const Duration(seconds: 3),
                                        interval: const Duration(seconds: 2),
                                        color: Colors.white,
                                        colorOpacity: 0,
                                        enabled: true,
                                        direction: const ShimmerDirection.fromLTRB(),
                                        child: GestureDetector(
                                          onTap: _componentsVisible ? null : _getSummary,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8.r),
                                            child: Container(
                                              height: 45.h,
                                              width: 200.w,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8.r),
                                                border: Border.all(color: const Color(0xff2e2e2e)),
                                              ),
                                              child: ElevatedButton(
                                                onPressed: _componentsVisible ? null : _getSummary,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xff2f2f2f33),
                                                ),
                                                child: const Text('Get Summary ✨'),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    if (_componentsVisible)
                                      kIsWeb
                                          ? WebGeneratedContentView(
                                              thumbnailUrl: _thumbnailUrl,
                                              elapsedTimeText: _elapsedTimeText,
                                              title: _title,
                                              summary: _summary,
                                              introduction: _introduction,
                                              bulletPoints: _bulletPoints,
                                              conclusion: _conclusion,
                                              duration: _duration,
                                              videourl: _urlController.text,
                                            )
                                          : GeneratedContentView(
                                              thumbnailUrl: _thumbnailUrl,
                                              elapsedTimeText: _elapsedTimeText,
                                              title: _title,
                                              summary: _summary,
                                              introduction: _introduction,
                                              bulletPoints: _bulletPoints,
                                              conclusion: _conclusion,
                                              duration: _duration,
                                            ),
                                    if (!_componentsVisible) const BuildBaseSheet(),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Move the _componentsVisible class to the top-level scope
class _componentsVisible {
}

String calculateElapsedTime(int elapsedSeconds) {
  final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
