// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Nyaya';

  @override
  String get appTagline => 'भारतीय कानून सीखें, रोज़ एक केस';

  @override
  String get navHome => 'होम';

  @override
  String get navJourney => 'सफ़र';

  @override
  String get navAskAi => 'AI से पूछें';

  @override
  String get navUpdates => 'अपडेट';

  @override
  String get commonContinue => 'जारी रखें';

  @override
  String get reviewTitle => 'Review';

  @override
  String get reviewMistakesTab => 'Mistakes';

  @override
  String get reviewSavedTab => 'Saved';

  @override
  String get reviewPractise => 'Practise mistakes';

  @override
  String get reviewPractiseFree => 'Free · up to 10 questions · earns XP';

  @override
  String get reviewEmptyMistakes =>
      'No mistakes to review. Questions you get wrong appear here until you answer them right.';

  @override
  String get reviewEmptySaved =>
      'Nothing saved yet. After answering a question, tap Save to keep it here.';

  @override
  String get reviewSignIn =>
      'Sign in to see your mistakes and saved questions.';

  @override
  String reviewWrongTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wrong $count times',
      one: 'Wrong once',
    );
    return '$_temp0';
  }

  @override
  String get reviewUpdatedSince =>
      'Updated since you answered it. Shown as you saw it.';

  @override
  String get reviewUnavailable => 'This question is no longer available.';

  @override
  String reviewCardBody(int mistakes, int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      mistakes,
      locale: localeName,
      other: '$mistakes mistakes',
      one: '1 mistake',
    );
    return '$_temp0 · $saved saved';
  }

  @override
  String get questionSave => 'Save';

  @override
  String get questionSaved => 'Saved';

  @override
  String get questionReport => 'Report';

  @override
  String get questionSaveFailed =>
      'Couldn\'t save. Check your connection and try again.';

  @override
  String get reportTitle => 'Report a problem';

  @override
  String get reportReasonWrongAnswer => 'The answer is wrong';

  @override
  String get reportReasonUnclear => 'The question is unclear';

  @override
  String get reportReasonOutdatedLaw => 'The law has changed';

  @override
  String get reportReasonTypo => 'Typo or wording';

  @override
  String get reportReasonOther => 'Something else';

  @override
  String get reportComment => 'Anything else? (optional)';

  @override
  String get reportSend => 'Send report';

  @override
  String get reportSent => 'Thanks. Our legal team will check this question.';

  @override
  String get reportAlready => 'You already reported this question.';

  @override
  String get reportLimit =>
      'You\'ve sent many reports today. Please try again tomorrow.';

  @override
  String get commonBack => 'वापस';

  @override
  String get commonNext => 'आगे';

  @override
  String get commonSkip => 'छोड़ें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get commonStart => 'शुरू करें';

  @override
  String get commonRetry => 'फिर कोशिश करें';

  @override
  String get commonDone => 'हो गया';

  @override
  String get commonSeeAll => 'सभी देखें';

  @override
  String get commonLater => 'बाद में';

  @override
  String get commonOk => 'ठीक है';

  @override
  String get commonComingSoon => 'जल्द आ रहा है';

  @override
  String get commonSomethingWrong => 'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।';

  @override
  String get onbChooseLanguage => 'अपनी भाषा चुनें';

  @override
  String get onbChooseLanguageSub => 'आप इसे कभी भी सेटिंग्स में बदल सकते हैं।';

  @override
  String get onbSlide1Title => 'कानून, आसान भाषा में';

  @override
  String get onbSlide1Body =>
      'संविधान, BNS, BNSS और रोज़मर्रा के कानूनों पर छोटे-छोटे क्विज़।';

  @override
  String get onbSlide2Title => 'केस पथ खेलें';

  @override
  String get onbSlide2Body =>
      'लेवल-दर-लेवल आगे बढ़ें, स्टार कमाएँ, संदूक खोलें और नए अध्याय अनलॉक करें।';

  @override
  String get onbSlide3Title => 'रोज़ की आदत बनाएँ';

  @override
  String get onbSlide3Body =>
      'अपनी स्ट्रीक बनाए रखें, साप्ताहिक न्यायालय लीग में ऊपर चढ़ें और हमारे AI से कानून से जुड़ा कुछ भी पूछें।';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbGetStarted => 'Get Started';

  @override
  String get onbBrandTagline => 'Learn Law. Live It.';

  @override
  String get onbIntro1Title => 'Your Guide to Indian Law';

  @override
  String get onbIntro1Body =>
      'Learn with clarity, practise with purpose, and understand the law that shapes your everyday life.';

  @override
  String get onbIntro2Label => 'Structured learning';

  @override
  String get onbIntro2Title => 'Learn at Your Own Pace';

  @override
  String get onbIntro2Body =>
      'Explore the Constitution, BNS, BNSS, BSA and more with structured lessons, notes and real-world examples.';

  @override
  String get onbIntro3Label => 'Practice & apply';

  @override
  String get onbIntro3Title => 'Build Real Understanding';

  @override
  String get onbIntro3Body =>
      'Test your knowledge with quizzes, read the latest legal updates, and see how law applies in real life.';

  @override
  String get onbDemoChapter => 'Fundamental Rights';

  @override
  String get onbDemoChapterSub => 'Constitution of India · Chapter 3';

  @override
  String get onbDemoProgress => '5 of 8 lessons completed';

  @override
  String get onbDemoContinue => 'Continue Learning';

  @override
  String get onbDemoLesson1 => 'Introduction';

  @override
  String get onbDemoLesson2 => 'Right to Equality';

  @override
  String get onbDemoLesson3 => 'Right to Freedom';

  @override
  String get onbDemoLesson4 => 'Right against Exploitation';

  @override
  String get onbDemoQuiz => 'Daily Quiz';

  @override
  String get onbDemoQuizSub => '3 of 5 activities';

  @override
  String get onbDemoUpdates => 'Legal Updates';

  @override
  String get onbDemoUpdatesSub =>
      'Stay informed with important judgments and developments.';

  @override
  String get onbDemoScenarios => 'Real Life Scenarios';

  @override
  String get onbDemoScenariosSub =>
      'Understand how law works in everyday life.';

  @override
  String get onbWhoAreYou => 'आप किस रूप में सीख रहे हैं?';

  @override
  String get onbWhoAreYouSub => 'हम आपके लिए कठिनाई और सुझाव तय करेंगे।';

  @override
  String get personaAdvocate => 'अधिवक्ता';

  @override
  String get personaAdvocateDesc =>
      'प्रैक्टिस करने वाले वकील, याददाश्त तेज़ करें';

  @override
  String get personaAspirant => 'कानून के अभ्यर्थी';

  @override
  String get personaAspirantDesc => 'CLAT, AIBE या न्यायिक सेवा की तैयारी';

  @override
  String get personaCitizen => 'नागरिक';

  @override
  String get personaCitizenDesc => 'अपने अधिकार और रोज़मर्रा का कानून जानें';

  @override
  String get onbDailyGoal => 'रोज़ का लक्ष्य चुनें';

  @override
  String get onbDailyGoalSub =>
      'लक्ष्य तय करने वाले सीखने वाले इसे कहीं ज़्यादा निभाते हैं।';

  @override
  String get goalCasual => 'आराम से';

  @override
  String get goalRegular => 'नियमित';

  @override
  String get goalSerious => 'गंभीर';

  @override
  String goalQuizzesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'रोज़ $count क्विज़',
      one: 'रोज़ 1 क्विज़',
    );
    return '$_temp0';
  }

  @override
  String get onbYourName => 'हम आपको किस नाम से बुलाएँ?';

  @override
  String get onbYourNameSub => 'लीडरबोर्ड पर दिखाया जाएगा।';

  @override
  String get onbNameHint => 'आपका नाम';

  @override
  String get onbCommit => 'लक्ष्य तय करें';

  @override
  String onbReadyTitle(String name) {
    return 'सब तैयार है, $name!';
  }

  @override
  String get onbReadyBody => 'आपका पहला केस केस पथ पर इंतज़ार कर रहा है।';

  @override
  String get greetingMorning => 'सुप्रभात';

  @override
  String get greetingAfternoon => 'नमस्कार';

  @override
  String get greetingEvening => 'शुभ संध्या';

  @override
  String get homeContinueJourney => 'अपना केस पथ जारी रखें';

  @override
  String get homeContinueLeftOff => 'Continue where you left off';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'अध्याय $chapter · लेवल $level';
  }

  @override
  String get homeChestReady => 'एक संदूक आपका इंतज़ार कर रहा है!';

  @override
  String get homeAllDone =>
      'आपने सभी अध्याय पूरे कर लिए। नए अध्याय जल्द आ रहे हैं!';

  @override
  String get homePlay => 'खेलें';

  @override
  String get homeDailyGoal => 'रोज़ का लक्ष्य';

  @override
  String homeGoalProgress(int done, int goal) {
    return '$goal में से $done क्विज़';
  }

  @override
  String get homeGoalDone => 'लक्ष्य पूरा — शाबाश!';

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन की स्ट्रीक',
      one: '1 दिन की स्ट्रीक',
      zero: 'आज से स्ट्रीक शुरू करें',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakAtRisk =>
      'अपनी स्ट्रीक बचाने के लिए आज एक क्विज़ खेलें!';

  @override
  String get homeStreakSafe => 'आज की स्ट्रीक सुरक्षित';

  @override
  String get homeModesTitle => 'क्विज़ मोड';

  @override
  String get homeLeagueTitle => 'इस हफ़्ते की लीग';

  @override
  String homeLeagueRank(int rank, String tier) {
    return '$tier में आप #$rank पर हैं';
  }

  @override
  String homeLeagueEnds(String time) {
    return '$time में समाप्त';
  }

  @override
  String get homeFactTitle => 'आज का कानूनी तथ्य';

  @override
  String get homeUpdatesTitle => 'ताज़ा कानूनी अपडेट';

  @override
  String get homeGoPremium => 'असीमित ऊर्जा पाएँ';

  @override
  String get homeGoPremiumSub => 'Nyaya प्रीमियम · 7 दिन का मुफ़्त ट्रायल';

  @override
  String get modeCasePath => 'केस पथ';

  @override
  String get modeCasePathDesc => 'लेवल-दर-लेवल सफ़र';

  @override
  String get modeDailyDocket => 'दैनिक डॉकेट';

  @override
  String get modeDailyDocketDesc => '5 सवाल · सबके लिए एक जैसे';

  @override
  String get modeDuel => 'मूट कोर्ट मुक़ाबला';

  @override
  String get modeDuelDesc => '1v1 · 7 सवाल · घड़ी को हराएँ';

  @override
  String get modeExam => 'परीक्षा कक्ष';

  @override
  String get modeExamDesc => '20 सवाल · 20 मिनट · नेगेटिव मार्किंग';

  @override
  String get modeExamDescCitizen => '20 सवाल · 20 मिनट · अपने अधिकार जानें';

  @override
  String get modeFree => 'मुफ़्त';

  @override
  String modeEnergyCost(int count) {
    return '$count ⚡';
  }

  @override
  String get docketDoneToday => 'आज के लिए पूरा';

  @override
  String docketNextIn(String time) {
    return 'अगला डॉकेट $time में';
  }

  @override
  String get energyTitle => 'ऊर्जा';

  @override
  String energyLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ऊर्जा बची',
      one: '1 ऊर्जा बची',
      zero: 'ऊर्जा खत्म',
    );
    return '$_temp0';
  }

  @override
  String get energyUnlimited => 'असीमित';

  @override
  String get energyOutTitle => 'आपकी ऊर्जा खत्म हो गई';

  @override
  String energyOutBody(String time) {
    return 'ऊर्जा आधी रात को भरती है — $time में।';
  }

  @override
  String energyRefillCoins(int coins) {
    return '$coins सिक्कों में 1 ⚡ भरें';
  }

  @override
  String get energyGoUnlimited => 'असीमित ऊर्जा पाएँ';

  @override
  String get energyFreeOptions => 'मुफ़्त में आप ये कर सकते हैं';

  @override
  String get energyPlayDocket => 'आज का दैनिक डॉकेट खेलें (मुफ़्त)';

  @override
  String get energyAskAi => 'AI से कानूनी सवाल पूछें';

  @override
  String get energyReadUpdates => 'कानूनी अपडेट पढ़ें';

  @override
  String get energyNotEnoughCoins =>
      'अभी पर्याप्त सिक्के नहीं हैं — स्टार और संदूकों से कमाएँ।';

  @override
  String get energyRefilled => '+1 ऊर्जा!';

  @override
  String get journeyTitle => 'केस पथ';

  @override
  String get journeySubtitle => 'Your journey through Indian law';

  @override
  String get journeyKeepGoing => 'Keep going!';

  @override
  String journeyStars(int count) {
    return '$count ★';
  }

  @override
  String journeyChapter(int number) {
    return 'अध्याय $number';
  }

  @override
  String journeyLevel(int number) {
    return 'लेवल $number';
  }

  @override
  String get journeyLandmark => 'ख़ास लेवल';

  @override
  String get journeyLocked => 'लॉक है';

  @override
  String get journeyLockedBody => 'इसे अनलॉक करने के लिए पिछला लेवल पूरा करें।';

  @override
  String journeyQuestions(int count) {
    return '$count सवाल';
  }

  @override
  String get journeyBestStars => 'आपका सर्वश्रेष्ठ';

  @override
  String get journeyReplay => 'फिर खेलें';

  @override
  String get journeyChest => 'अध्याय संदूक';

  @override
  String get journeyChestBody =>
      'आपने अध्याय पूरा कर लिया! बोनस सिक्कों के लिए संदूक खोलें।';

  @override
  String get journeyOpenChest => 'संदूक खोलें';

  @override
  String journeyChestOpened(int coins) {
    return '+$coins सिक्के!';
  }

  @override
  String get journeyChestLocked =>
      'संदूक खोलने के लिए इस अध्याय के सभी लेवल पूरे करें।';

  @override
  String get journeyJumpToCurrent => 'मौजूदा लेवल पर जाएँ';

  @override
  String get journeyYou => 'आप';

  @override
  String get journeyPassHint =>
      'पास के लिए 50% · 2 स्टार के लिए 80% · 3 स्टार के लिए 100%';

  @override
  String quizQuestionOf(int current, int total) {
    return 'सवाल $current / $total';
  }

  @override
  String get quizCorrect => 'सही!';

  @override
  String get quizWrong => 'सही नहीं';

  @override
  String get quizTimeUp => 'समय खत्म';

  @override
  String quizAnswerWas(String answer) {
    return 'उत्तर: $answer';
  }

  @override
  String get quizWhy => 'क्यों';

  @override
  String get quizReference => 'संदर्भ';

  @override
  String get quizOpenSource => 'आधिकारिक पाठ पढ़ें';

  @override
  String get quizOpenSourceFailed => 'लिंक नहीं खुल सका';

  @override
  String quizCombo(int count) {
    return '$count× कॉम्बो!';
  }

  @override
  String get quizFinish => 'समाप्त';

  @override
  String get quizSubmit => 'परीक्षा जमा करें';

  @override
  String get quizSkipQuestion => 'छोड़ें';

  @override
  String get quizSelectAnswer => 'एक उत्तर चुनें';

  @override
  String get quizQuitTitle => 'क्विज़ छोड़ें?';

  @override
  String get quizQuitBody => 'इस क्विज़ में आपकी प्रगति खो जाएगी।';

  @override
  String get quizQuitBodyRefund =>
      'आपने अभी कोई उत्तर नहीं दिया है, इसलिए आपकी ऊर्जा वापस मिल जाएगी।';

  @override
  String get quizQuitStay => 'खेलते रहें';

  @override
  String get quizQuitLeave => 'छोड़ें';

  @override
  String get quizLoading => 'आपका केस तैयार हो रहा है…';

  @override
  String get quizEmpty => 'यहाँ अभी कोई सवाल उपलब्ध नहीं है।';

  @override
  String get quizOpponent => 'प्रतिद्वंद्वी';

  @override
  String quizOpponentAnswered(String name, int seconds) {
    return '$name ने $seconds सेकंड में उत्तर दिया';
  }

  @override
  String get quizVs => 'VS';

  @override
  String get quizFindingOpponent => 'प्रतिद्वंद्वी ढूँढ रहे हैं…';

  @override
  String quizMarkedAnswers(int answered, int total) {
    return '$total में से $answered उत्तर दिए';
  }

  @override
  String get resultPerfect => 'परफ़ेक्ट केस!';

  @override
  String get resultGreat => 'बहुत बढ़िया!';

  @override
  String get resultGood => 'लेवल पूरा!';

  @override
  String get resultTryAgain => 'बस थोड़ा और';

  @override
  String get resultTryAgainBody =>
      'यह लेवल पास करने के लिए कम से कम 50% अंक लाएँ। व्याख्याएँ देखें और फिर कोशिश करें।';

  @override
  String resultScore(int correct, int total) {
    return '$total में से $correct सही';
  }

  @override
  String get resultAccuracy => 'सटीकता';

  @override
  String get resultXp => 'XP';

  @override
  String get resultCoins => 'सिक्के';

  @override
  String get resultTime => 'समय';

  @override
  String resultStreakExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'स्ट्रीक बढ़कर $count दिन हुई!',
      one: 'आपकी स्ट्रीक शुरू हो गई — पहला दिन!',
    );
    return '$_temp0';
  }

  @override
  String resultMilestone(int count) {
    return '$count दिन की स्ट्रीक का पड़ाव!';
  }

  @override
  String get resultGoalReached => 'रोज़ का लक्ष्य पूरा!';

  @override
  String resultEnergyBonus(int count) {
    return '3-स्टार बोनस: +$count ⚡';
  }

  @override
  String resultLeagueUp(int rank) {
    return 'आप अपनी लीग में #$rank पर पहुँच गए';
  }

  @override
  String get resultReview => 'उत्तर देखें';

  @override
  String get resultNextLevel => 'अगला लेवल';

  @override
  String get resultBackToMap => 'मैप पर वापस';

  @override
  String get resultBackHome => 'होम पर वापस';

  @override
  String get resultPlayAgain => 'फिर खेलें';

  @override
  String resultExamScore(String score, int max) {
    return 'अंक: $score / $max';
  }

  @override
  String resultExamBreakdown(int correct, int wrong, int skipped) {
    return '$correct सही · $wrong गलत · $skipped छोड़े';
  }

  @override
  String get resultDuelWon => 'आपने मुक़ाबला जीत लिया!';

  @override
  String get resultDuelLost => 'कड़ी टक्कर!';

  @override
  String get resultDuelDraw => 'मुक़ाबला बराबर!';

  @override
  String resultDuelPoints(int you, int them) {
    return '$you बनाम $them';
  }

  @override
  String get resultDocketShare => 'नतीजा शेयर करें';

  @override
  String get resultYourAnswer => 'आपका उत्तर';

  @override
  String get resultCorrectAnswer => 'सही उत्तर';

  @override
  String get resultSkipped => 'छोड़ा गया';

  @override
  String get leaderboardTitle => 'लीडरबोर्ड';

  @override
  String get leaderboardWeekly => 'साप्ताहिक लीग';

  @override
  String get leaderboardAllTime => 'अब तक';

  @override
  String get leaderboardPromotionZone => 'प्रमोशन ज़ोन';

  @override
  String get leaderboardDemotionZone => 'डिमोशन ज़ोन';

  @override
  String leaderboardEndsIn(String time) {
    return 'हफ़्ता $time में समाप्त';
  }

  @override
  String leaderboardTopPromote(int count, String tier) {
    return 'शीर्ष $count $tier में जाएँगे';
  }

  @override
  String get leaderboardNoDemotion => 'इस लीग में डिमोशन नहीं — बस सीखते रहें!';

  @override
  String get leaderboardEarnToJoin =>
      'लीग में शामिल होने के लिए इस हफ़्ते एक क्विज़ पूरा करें।';

  @override
  String leaderboardXp(int xp) {
    return '$xp XP';
  }

  @override
  String get leaderboardPractice => 'Practice player';

  @override
  String get leaderboardYou => 'आप';

  @override
  String get leaderboardTiers => 'लीग स्तर';

  @override
  String leagueOutcomePromoted(String tier) {
    return '$tier में प्रमोशन!';
  }

  @override
  String leagueOutcomeDemoted(String tier) {
    return '$tier में भेजे गए';
  }

  @override
  String leagueOutcomeStayed(String tier) {
    return 'आप $tier में ही रहे';
  }

  @override
  String leagueOutcomeRank(int rank) {
    return 'पिछले हफ़्ते आप #$rank पर रहे।';
  }

  @override
  String get tier_nyayaPanchayat => 'न्याय पंचायत';

  @override
  String get tier_gramNyayalaya => 'ग्राम न्यायालय';

  @override
  String get tier_munsiffCourt => 'मुंसिफ़ न्यायालय';

  @override
  String get tier_magistrateCourt => 'मजिस्ट्रेट न्यायालय';

  @override
  String get tier_districtCourt => 'ज़िला न्यायालय';

  @override
  String get tier_sessionsCourt => 'सत्र न्यायालय';

  @override
  String get tier_highCourt => 'उच्च न्यायालय';

  @override
  String get tier_supremeCourt => 'सर्वोच्च न्यायालय';

  @override
  String get chatTitle => 'Nyaya AI';

  @override
  String get chatSubtitle => 'आपका कानूनी जानकारी सहायक';

  @override
  String get chatDisclaimer =>
      'यह सामान्य कानूनी जानकारी है, कानूनी सलाह नहीं। अपने मामले के लिए किसी अधिवक्ता से सलाह लें या NALSA की हेल्पलाइन 15100 पर कॉल करें।';

  @override
  String get chatHint => 'किसी भी भारतीय कानून के बारे में पूछें…';

  @override
  String get chatWelcome =>
      'नमस्ते! मैं भारतीय कानून, आपके अधिकार, कानूनी प्रक्रियाएँ और नए आपराधिक कानून (BNS, BNSS, BSA) समझा सकता हूँ। आप क्या जानना चाहेंगे?';

  @override
  String get chatSuggest1 => 'ज़ीरो FIR क्या है?';

  @override
  String get chatSuggest2 => 'गिरफ़्तारी होने पर मेरे अधिकार';

  @override
  String get chatSuggest3 => 'RTI कैसे दायर करें?';

  @override
  String get chatSuggest4 => 'उपभोक्ता शिकायत कैसे दर्ज करें?';

  @override
  String get chatThinking => 'कानून खोजा जा रहा है…';

  @override
  String chatLimitLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count मुफ़्त सवाल बचे हैं',
      one: 'आज 1 मुफ़्त सवाल बचा है',
    );
    return '$_temp0';
  }

  @override
  String get chatLimitReached =>
      'आज के मुफ़्त सवाल खत्म हो गए। कल फिर आएँ या असीमित AI के लिए प्रीमियम लें।';

  @override
  String get chatLimitReachedToday =>
      'आज के सवाल पूरे हो गए। कल फिर पूछ सकते हैं।';

  @override
  String get chatError =>
      'अभी AI से संपर्क नहीं हो पाया। कृपया अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get chatOfflineNote =>
      'ऑफ़लाइन मोड — पूरे उत्तरों के लिए AI कुंजी जोड़ें।';

  @override
  String get chatClear => 'चैट साफ़ करें';

  @override
  String get chatCopy => 'कॉपी हो गया';

  @override
  String get updatesTitle => 'कानूनी अपडेट';

  @override
  String get updatesSubtitle => 'निर्णय, नए कानून और व्याख्याएँ';

  @override
  String get updatesAll => 'सभी';

  @override
  String get updatesSupremeCourt => 'सर्वोच्च न्यायालय';

  @override
  String get updatesHighCourts => 'उच्च न्यायालय';

  @override
  String get updatesLegislation => 'विधान';

  @override
  String get updatesExplainer => 'व्याख्याएँ';

  @override
  String updatesReadTime(int minutes) {
    return '$minutes मिनट में पढ़ें';
  }

  @override
  String get updatesKeyPoints => 'मुख्य बातें';

  @override
  String get updatesWhyItMatters => 'यह क्यों ज़रूरी है';

  @override
  String get updatesSource => 'स्रोत';

  @override
  String get updatesAskAi => 'इसके बारे में AI से पूछें';

  @override
  String get updatesEmpty => 'इस श्रेणी में अभी कोई अपडेट नहीं है।';

  @override
  String get updatesSave => 'Save update';

  @override
  String get updatesUnsave => 'Remove from saved';

  @override
  String get updatesInEnglish => 'अंग्रेज़ी में दिखाया गया';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get settingsProfile => 'प्रोफ़ाइल';

  @override
  String get settingsEditName => 'नाम बदलें';

  @override
  String get settingsLearningAs => 'किस रूप में सीख रहे हैं';

  @override
  String get settingsLanguage => 'भाषा';

  @override
  String get settingsDailyGoal => 'रोज़ का लक्ष्य';

  @override
  String get settingsAppearance => 'रूप-रंग';

  @override
  String get settingsThemeSystem => 'सिस्टम';

  @override
  String get settingsThemeLight => 'लाइट';

  @override
  String get settingsThemeDark => 'डार्क';

  @override
  String get settingsSound => 'साउंड इफ़ेक्ट';

  @override
  String get settingsHaptics => 'हैप्टिक फ़ीडबैक';

  @override
  String get settingsReminders => 'रोज़ का रिमाइंडर';

  @override
  String get settingsRemindersSub => 'स्ट्रीक बनाए रखने के लिए एक याद';

  @override
  String get settingsStore => 'स्टोर';

  @override
  String get settingsStreakFreeze => 'स्ट्रीक फ़्रीज़';

  @override
  String settingsStreakFreezeSub(int owned, int max) {
    return 'एक दिन छूटने पर आपकी स्ट्रीक बचाता है · $owned/$max लगे हैं';
  }

  @override
  String settingsBuyFor(int coins) {
    return '$coins सिक्के';
  }

  @override
  String get settingsFreezeBought => 'स्ट्रीक फ़्रीज़ लग गया!';

  @override
  String get settingsFreezeFull => 'आपके पास पहले से अधिकतम फ़्रीज़ लगे हैं।';

  @override
  String get settingsPremium => 'Nyaya प्रीमियम';

  @override
  String get settingsPremiumActive => 'प्रीमियम सक्रिय';

  @override
  String get settingsPremiumUpgrade => 'प्रीमियम लें';

  @override
  String get settingsStats => 'आपके आँकड़े';

  @override
  String get settingsTotalXp => 'कुल XP';

  @override
  String get settingsLongestStreak => 'सबसे लंबी स्ट्रीक';

  @override
  String get settingsQuizzes => 'क्विज़';

  @override
  String get settingsAccuracy => 'सटीकता';

  @override
  String get settingsDuelRecord => 'जीते मुक़ाबले';

  @override
  String get settingsAbout => 'जानकारी';

  @override
  String get settingsDisclaimer => 'कानूनी अस्वीकरण';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya एक शैक्षिक ऐप है। सवाल, व्याख्याएँ, अपडेट और AI के उत्तर सामान्य जानकारी हैं, कानूनी सलाह नहीं। कानून बदलते रहते हैं — हमेशा आधिकारिक राजपत्र से पुष्टि करें या किसी अधिवक्ता से सलाह लें।';

  @override
  String get settingsPrivacy => 'गोपनीयता';

  @override
  String get settingsPrivacyBody =>
      'आपकी प्रगति इसी डिवाइस पर सहेजी जाती है। AI सवाल केवल उत्तर तैयार करने के लिए हमारे AI प्रदाता को भेजे जाते हैं।';

  @override
  String settingsVersion(String version) {
    return 'संस्करण $version';
  }

  @override
  String get settingsReset => 'प्रगति रीसेट करें';

  @override
  String get settingsResetConfirm =>
      'इससे इस डिवाइस के सभी XP, स्टार, स्ट्रीक और सिक्के मिट जाएँगे। इसे वापस नहीं लाया जा सकता।';

  @override
  String get settingsResetAction => 'सब मिटाएँ';

  @override
  String get premiumTitle => 'Nyaya प्रीमियम';

  @override
  String get premiumHeadline => 'बिना सीमा के सीखें';

  @override
  String get premiumBenefitEnergy => 'असीमित ऊर्जा';

  @override
  String get premiumBenefitEnergySub => 'जितने चाहें उतने क्विज़ खेलें';

  @override
  String get premiumBenefitAi => 'असीमित Nyaya AI';

  @override
  String get premiumBenefitAiSub => 'अपना हर कानूनी सवाल पूछें';

  @override
  String get premiumBenefitFreeze => 'स्ट्रीक फ़्रीज़ शामिल';

  @override
  String get premiumBenefitFreezeSub => 'व्यस्त दिन में भी स्ट्रीक न टूटे';

  @override
  String get premiumBenefitExam => 'पूरी मॉक परीक्षाएँ';

  @override
  String get premiumBenefitExamSub => 'CLAT, AIBE और न्यायिक सेवा जैसा अभ्यास';

  @override
  String get premiumFair => 'निष्पक्ष खेल: प्रीमियम से लीग XP कभी नहीं बढ़ता।';

  @override
  String get premiumYearly => 'सालाना';

  @override
  String get premiumMonthly => 'मासिक';

  @override
  String get premiumYearlyPrice => '₹999 / साल';

  @override
  String get premiumMonthlyPrice => '₹149 / महीना';

  @override
  String get premiumPerMonth => 'सिर्फ़ ₹83 / महीना';

  @override
  String get premiumSave => '44% बचाएँ';

  @override
  String get premiumBestValue => 'सबसे फ़ायदेमंद';

  @override
  String get premiumStartTrial => '7 दिन का मुफ़्त ट्रायल शुरू करें';

  @override
  String get premiumTrialNote =>
      'ट्रायल खत्म होने से पहले कभी भी रद्द करें, आपसे कोई शुल्क नहीं लिया जाएगा।';

  @override
  String get premiumRestore => 'खरीदारी बहाल करें';

  @override
  String get premiumActivated => 'Nyaya प्रीमियम में आपका स्वागत है!';

  @override
  String get premiumAlready => 'आप प्रीमियम सदस्य हैं';

  @override
  String get premiumNothingToRestore => 'कोई पिछली खरीदारी नहीं मिली।';

  @override
  String get statXp => 'XP';

  @override
  String get statStreak => 'स्ट्रीक';

  @override
  String get statCoins => 'सिक्के';

  @override
  String get statEnergy => 'ऊर्जा';

  @override
  String get statStars => 'स्टार';

  @override
  String get exploreTitle => 'Explore Law';

  @override
  String get exploreSubtitle => 'Build your understanding of Indian law';

  @override
  String get exploreStartHere => 'Start here';

  @override
  String get exploreFeatured => 'Featured';

  @override
  String get exploreButton => 'Explore';

  @override
  String get exploreCoreLaws => 'Core Laws';

  @override
  String get exploreViewAll => 'View All';

  @override
  String get exploreLegacy => 'Legacy';

  @override
  String get exploreAskAi => 'Ask AI';

  @override
  String exploreAskPrompt(String law) {
    return 'Explain the $law in simple terms: what it covers and the key provisions I should know.';
  }

  @override
  String get lawConstitutionTitle => 'Constitution of India';

  @override
  String get lawConstitutionDesc =>
      'Fundamental rights, directive principles, duties and more.';

  @override
  String get lawBnsTitle => 'Bharatiya Nyaya Sanhita (BNS)';

  @override
  String get lawBnsShort => 'Bharatiya Nyaya Sanhita';

  @override
  String get lawBnsDesc => 'Substantive criminal law';

  @override
  String get lawBnsFeatured =>
      'Offences and punishments under India\'s new criminal code.';

  @override
  String get lawBnssTitle => 'Bharatiya Nagarik Suraksha Sanhita (BNSS)';

  @override
  String get lawBnssDesc => 'Criminal procedure law';

  @override
  String get lawBsaTitle => 'Bharatiya Sakshya Adhiniyam (BSA)';

  @override
  String get lawBsaDesc => 'Law of evidence';

  @override
  String get lawEverydayTitle => 'Everyday Law';

  @override
  String get lawEverydayDesc => 'Know your rights in daily life';

  @override
  String get lawEverydayFeatured =>
      'Consumer, tenancy, workplace and family rights, explained simply.';

  @override
  String get lawLegacyTitle => 'IPC & CrPC (Legacy)';

  @override
  String get lawLegacyDesc => 'Older laws for reference';

  @override
  String get chapterConstitutionTitle => 'संविधान की मूल बातें';

  @override
  String get chapterConstitutionSubtitle =>
      'प्रस्तावना, संसद, न्यायालय, संशोधन';

  @override
  String get chapterRightsTitle => 'अधिकार और कर्तव्य';

  @override
  String get chapterRightsSubtitle => 'मौलिक अधिकार, नीति निदेशक तत्व और रिट';

  @override
  String get chapterCriminalTitle => 'आपराधिक कानून (BNS)';

  @override
  String get chapterCriminalSubtitle => 'नई संहिता के अंतर्गत अपराध';

  @override
  String get chapterProcedureTitle => 'प्रक्रिया और साक्ष्य';

  @override
  String get chapterProcedureSubtitle => 'BNSS, BSA, FIR, गिरफ़्तारी, ज़मानत';

  @override
  String get chapterCivilTitle => 'संविदा और उपभोक्ता';

  @override
  String get chapterCivilSubtitle => 'संविदा, उपभोक्ता अधिकार, उपचार';

  @override
  String get chapterEverydayTitle => 'रोज़मर्रा का कानून';

  @override
  String get chapterEverydaySubtitle => 'दैनिक जीवन के लिए कानून';

  @override
  String get authCreateTitle => 'Create your free account';

  @override
  String get authCreateSubtitle =>
      'Questions come from Nyaya\'s reviewed library, and your results are saved to your account.';

  @override
  String get authSignInTitle => 'Welcome back';

  @override
  String get authSignInSubtitle => 'Sign in to keep practising.';

  @override
  String get authName => 'Your name';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authPasswordHint => 'At least 8 characters';

  @override
  String get authCreate => 'CREATE ACCOUNT';

  @override
  String get authSignIn => 'SIGN IN';

  @override
  String get authHaveAccount => 'I already have an account';

  @override
  String get authNeedAccount => 'New here? Create an account';

  @override
  String get authErrorCredentials => 'Email or password is incorrect.';

  @override
  String get authErrorEmailTaken =>
      'An account with this email already exists. Sign in instead.';

  @override
  String get authErrorNetwork =>
      'Can\'t reach Nyaya right now. Check your connection and try again.';

  @override
  String get authErrorRateLimited =>
      'Too many attempts. Wait a minute and try again.';

  @override
  String get authErrorInvalid =>
      'Enter a valid email and a password of at least 8 characters.';

  @override
  String get authErrorName => 'Enter your name.';

  @override
  String get settingsAccount => 'Account';

  @override
  String settingsSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get settingsSignIn => 'Sign in or create an account';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDeleteAccount => 'खाता हटाएँ';

  @override
  String get settingsDeleteAccountBody =>
      'इससे आपका खाता और उस पर मौजूद सब कुछ हमेशा के लिए हट जाएगा: प्रगति, XP, सिक्के, सहेजे गए सवाल और लीग में आपकी जगह। इसे वापस नहीं किया जा सकता। पुष्टि के लिए अपना पासवर्ड दर्ज करें।';

  @override
  String get settingsDeleteAccountPassword => 'पासवर्ड';

  @override
  String get settingsDeleteAccountAction => 'मेरा खाता हटाएँ';

  @override
  String get settingsDeleteAccountWrong => 'यह पासवर्ड सही नहीं है।';

  @override
  String get settingsDeleteAccountFailed =>
      'खाता नहीं हटाया जा सका। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get quizSendFailed =>
      'Couldn\'t send your answer. Check your connection and tap again.';

  @override
  String get quizSubmitFailed =>
      'Couldn\'t get your result. Check your connection.';

  @override
  String get quizRetry => 'TRY AGAIN';

  @override
  String get quizScoring => 'Scoring your case…';

  @override
  String get quizOffline =>
      'Can\'t reach Nyaya. Check your connection and try again.';

  @override
  String get quizSignedOut => 'Your session ended. Sign in again to play.';
}
