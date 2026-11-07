// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'Nyaya Kural';

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
  String get reviewTitle => 'समीक्षा';

  @override
  String get reviewMistakesTab => 'गलतियाँ';

  @override
  String get reviewSavedTab => 'सहेजे गए';

  @override
  String get reviewPractise => 'गलतियों का अभ्यास करें';

  @override
  String get reviewPractiseFree => 'मुफ़्त · 10 सवाल तक · XP मिलेगा';

  @override
  String get reviewEmptyMistakes =>
      'दोहराने के लिए कोई गलती नहीं है। जो सवाल आप गलत करते हैं, वे सही उत्तर देने तक यहाँ दिखते हैं।';

  @override
  String get reviewEmptySaved =>
      'अभी कुछ सहेजा नहीं गया है। किसी सवाल का उत्तर देने के बाद उसे यहाँ रखने के लिए सहेजें पर टैप करें।';

  @override
  String get reviewSignIn =>
      'अपनी गलतियाँ और सहेजे गए सवाल देखने के लिए साइन इन करें।';

  @override
  String reviewWrongTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार गलत',
      one: 'एक बार गलत',
    );
    return '$_temp0';
  }

  @override
  String get reviewUpdatedSince =>
      'आपके उत्तर देने के बाद इसमें बदलाव हुआ है। यह वैसा ही दिख रहा है जैसा आपने देखा था।';

  @override
  String get reviewUnavailable => 'यह सवाल अब उपलब्ध नहीं है।';

  @override
  String reviewCardBody(int mistakes, int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      mistakes,
      locale: localeName,
      other: '$mistakes गलतियाँ',
      one: '1 गलती',
    );
    return '$_temp0 · $saved सहेजे गए';
  }

  @override
  String get questionSave => 'सहेजें';

  @override
  String get questionSaved => 'सहेजा गया';

  @override
  String get questionReport => 'रिपोर्ट करें';

  @override
  String get questionSaveFailed =>
      'सहेज नहीं सके। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get reportTitle => 'समस्या बताएँ';

  @override
  String get reportReasonWrongAnswer => 'उत्तर गलत है';

  @override
  String get reportReasonUnclear => 'सवाल साफ़ नहीं है';

  @override
  String get reportReasonOutdatedLaw => 'कानून बदल गया है';

  @override
  String get reportReasonTypo => 'वर्तनी या शब्दों की गलती';

  @override
  String get reportReasonOther => 'कुछ और';

  @override
  String get reportComment => 'कुछ और बताना है? (वैकल्पिक)';

  @override
  String get reportSend => 'रिपोर्ट भेजें';

  @override
  String get reportSent => 'धन्यवाद। हमारी कानूनी टीम इस सवाल को जाँचेगी।';

  @override
  String get reportAlready => 'आप इस सवाल की रिपोर्ट पहले ही कर चुके हैं।';

  @override
  String get reportLimit =>
      'आज आपने बहुत सारी रिपोर्ट भेज दी हैं। कृपया कल फिर कोशिश करें।';

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
  String get onbSlide2Title => 'सीखने के पथ पर चलें';

  @override
  String get onbSlide2Body =>
      'लेवल-दर-लेवल आगे बढ़ें, स्टार कमाएँ, संदूक खोलें और नए अध्याय अनलॉक करें।';

  @override
  String get onbSlide3Title => 'रोज़ की आदत बनाएँ';

  @override
  String get onbSlide3Body =>
      'अपनी स्ट्रीक बनाए रखें, साप्ताहिक न्यायालय लीग में ऊपर चढ़ें और हमारे AI से कानून से जुड़ा कुछ भी पूछें।';

  @override
  String get onbSkip => 'छोड़ें';

  @override
  String onbSlidePosition(int current, int total) {
    return 'स्लाइड $current / $total';
  }

  @override
  String get onbGetStarted => 'शुरू करें';

  @override
  String get onbBrandTagline => 'कानून सीखें। उसे जिएँ।';

  @override
  String get onbIntro1Title => 'भारतीय कानून के लिए आपका साथी';

  @override
  String get onbIntro1Body =>
      'साफ़ समझ के साथ सीखें, मकसद के साथ अभ्यास करें और उस कानून को समझें जो आपकी रोज़मर्रा की ज़िंदगी को आकार देता है।';

  @override
  String get onbIntro2Label => 'क्रम से सीखना';

  @override
  String get onbIntro2Title => 'अपनी रफ़्तार से सीखें';

  @override
  String get onbIntro2Body =>
      'संविधान, BNS, BNSS, BSA और बहुत कुछ क्रम से बने पाठों, नोट्स और असल ज़िंदगी के उदाहरणों के साथ जानें।';

  @override
  String get onbIntro3Label => 'अभ्यास करें और लागू करें';

  @override
  String get onbIntro3Title => 'सच्ची समझ बनाएँ';

  @override
  String get onbIntro3Body =>
      'क्विज़ से अपनी जानकारी परखें, ताज़ा कानूनी अपडेट पढ़ें और देखें कि कानून असल ज़िंदगी में कैसे काम करता है।';

  @override
  String get onbDemoChapter => 'मौलिक अधिकार';

  @override
  String get onbDemoChapterSub => 'भारत का संविधान · अध्याय 3';

  @override
  String get onbDemoProgress => '8 में से 5 पाठ पूरे';

  @override
  String get onbDemoContinue => 'सीखना जारी रखें';

  @override
  String get onbDemoLesson1 => 'परिचय';

  @override
  String get onbDemoLesson2 => 'समानता का अधिकार';

  @override
  String get onbDemoLesson3 => 'स्वतंत्रता का अधिकार';

  @override
  String get onbDemoLesson4 => 'शोषण के विरुद्ध अधिकार';

  @override
  String get onbDemoQuiz => 'रोज़ का क्विज़';

  @override
  String get onbDemoQuizSub => '5 में से 3 गतिविधियाँ';

  @override
  String get onbDemoUpdates => 'कानूनी अपडेट';

  @override
  String get onbDemoUpdatesSub =>
      'ज़रूरी फ़ैसलों और बदलावों की जानकारी पाते रहें।';

  @override
  String get onbDemoScenarios => 'असल ज़िंदगी के मामले';

  @override
  String get onbDemoScenariosSub =>
      'समझें कि रोज़मर्रा की ज़िंदगी में कानून कैसे काम करता है।';

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
  String get onbReadyBody => 'आपका पहला पाठ सीखने के पथ पर इंतज़ार कर रहा है।';

  @override
  String get greetingMorning => 'सुप्रभात';

  @override
  String get greetingAfternoon => 'नमस्कार';

  @override
  String get greetingEvening => 'शुभ संध्या';

  @override
  String get homeContinueJourney => 'अपना सीखने का पथ जारी रखें';

  @override
  String get homeContinueLeftOff => 'जहाँ छोड़ा था, वहीं से शुरू करें';

  @override
  String get homeStartTitle => 'अपनी सीखने की यात्रा शुरू करें';

  @override
  String get homeStartBody => 'भारतीय कानून को एक-एक अवधारणा के साथ समझें।';

  @override
  String get homeStartRecommended => 'शुरुआत के लिए सुझाव';

  @override
  String get homeStartLawDesc =>
      'मौलिक अधिकार, कर्तव्य और संवैधानिक सिद्धांत समझें।';

  @override
  String get homeStartLearning => 'सीखना शुरू करें';

  @override
  String homeLevelsDone(int done, int total) {
    return '$total में से $done स्तर पूरे';
  }

  @override
  String get homeFeatured => 'विशेष';

  @override
  String get homeViewOnMap => 'नक्शे पर देखें';

  @override
  String get homeReviewMistakes => 'अपनी गलतियाँ दोहराएँ';

  @override
  String get homeReviewSaved => 'आपके सहेजे सवाल';

  @override
  String get homeReviewNow => 'अभी दोहराएँ';

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
  String get modeCasePath => 'सीखने का पथ';

  @override
  String get modeCasePathDesc => 'लेवल-दर-लेवल सफ़र';

  @override
  String get modeDailyDocket => 'आज के सवाल';

  @override
  String get modeDailyDocketDesc => '5 सवाल · सबके लिए एक जैसे';

  @override
  String get modeDuel => 'क्विक क्विज़';

  @override
  String get modeDuelDesc => '1v1 · 7 सवाल · घड़ी को हराएँ';

  @override
  String get modeExam => 'परीक्षा अभ्यास';

  @override
  String get modeExamDesc => '20 सवाल · 20 मिनट · नेगेटिव मार्किंग';

  @override
  String get modeExamDescCitizen => '20 सवाल · 20 मिनट · अपने अधिकार जानें';

  @override
  String get modeFree => 'मुफ़्त';

  @override
  String modeEnergyCost(int count) {
    return '$count ऊर्जा';
  }

  @override
  String get docketDoneToday => 'आज के लिए पूरा';

  @override
  String docketNextIn(String time) {
    return 'नए सवाल $time में';
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
    return '$coins सिक्कों में 1 ऊर्जा भरें';
  }

  @override
  String get energyGoUnlimited => 'असीमित ऊर्जा पाएँ';

  @override
  String get energyFreeOptions => 'मुफ़्त में आप ये कर सकते हैं';

  @override
  String get energyPlayDocket => 'आज के सवाल खेलें (मुफ़्त)';

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
  String get journeyTitle => 'सीखने का पथ';

  @override
  String get journeySubtitle => 'भारतीय कानून के साथ आपका सफ़र';

  @override
  String get journeyKeepGoing => 'चलते रहिए!';

  @override
  String get journeyQuote =>
      'छोटे-छोटे कदम कानून की समझ को और मज़बूत बनाते हैं।';

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
  String get journeyOpenChest => 'संदूक खोलें';

  @override
  String get journeyJumpToCurrent => 'मौजूदा लेवल पर जाएँ';

  @override
  String get journeyYou => 'आप';

  @override
  String get journeyNext => 'अगला कदम';

  @override
  String get journeyDone => 'पूरा हुआ';

  @override
  String journeyStarsOf(int count, int total) {
    return '$total में से $count स्टार';
  }

  @override
  String journeyLockedNext(String step) {
    return 'लेवल क्रम से खुलते हैं। आपका अगला कदम $step है।';
  }

  @override
  String get journeyGoToNext => 'मेरा अगला कदम दिखाएँ';

  @override
  String journeyStartCost(int count) {
    return 'शुरू करें · $count ऊर्जा';
  }

  @override
  String journeyReplayCost(int count) {
    return 'फिर से खेलें · $count ऊर्जा';
  }

  @override
  String get journeyNoTimer => 'कोई समय सीमा नहीं';

  @override
  String get journeyStarsTitle => 'आप कितने स्टार पा सकते हैं';

  @override
  String journeyPassMark(int percent) {
    return '$percent% · पास';
  }

  @override
  String journeyStarMark(int percent) {
    return '$percent%';
  }

  @override
  String get journeyHowScoring => 'अंक कैसे मिलते हैं';

  @override
  String journeyRuleEnergy(int count) {
    return 'हर कोशिश में $count ऊर्जा लगती है। पहले उत्तर से पहले छोड़ने पर यह वापस मिल जाती है।';
  }

  @override
  String get journeyRuleRetry =>
      'पास नहीं हुए? जितनी बार चाहें फिर से कोशिश करें।';

  @override
  String get journeyRuleBest =>
      'आपका सबसे अच्छा स्कोर रखा जाता है। कम स्कोर से स्टार कभी नहीं घटते।';

  @override
  String get journeyRuleNoMinus => 'गलत उत्तर पर अंक नहीं कटते।';

  @override
  String journeyRuleBonus(int count, int coins) {
    return 'किसी लेवल पर पहली बार 3 स्टार पाने पर $count ऊर्जा वापस मिलती है। हर नए स्टार पर $coins सिक्के मिलते हैं।';
  }

  @override
  String get journeyChestLockedTitle => 'अध्याय संदूक बंद है';

  @override
  String get journeyChestLockedText =>
      'अपना इनाम खोलने के लिए इस अध्याय के सभी लेवल पूरे करें।';

  @override
  String get journeyChestReadyTitle => 'आपका अध्याय इनाम तैयार है';

  @override
  String get journeyChestReadyText =>
      'बहुत बढ़िया! आपने यह अध्याय पूरा कर लिया।';

  @override
  String journeyChestReward(int coins) {
    return 'इनाम: $coins सिक्के';
  }

  @override
  String get journeyChestCollectedTitle => 'अध्याय इनाम मिल गया';

  @override
  String journeyChestCollectedText(int coins) {
    return 'आपको $coins सिक्के मिले।';
  }

  @override
  String get journeyChestFailed =>
      'संदूक नहीं खुल सका। अपना कनेक्शन जाँचें और फिर कोशिश करें। आपका इनाम सुरक्षित है।';

  @override
  String get journeyContinueLearning => 'सीखना जारी रखें';

  @override
  String get journeyBackToMap => 'नक्शे पर वापस';

  @override
  String journeyChapterProgress(int number, int done, int total) {
    return 'अध्याय $number · $done/$total पूरे';
  }

  @override
  String journeyStarsInfo(int one, int two) {
    return 'हर लेवल पर 3 स्टार तक पाएँ: 1 स्टार के लिए $one%, 2 के लिए $two% और 3 के लिए 100%। हर लेवल पर आपका सबसे अच्छा स्कोर गिना जाता है।';
  }

  @override
  String journeyEnergyInfo(int cost, int free, String time) {
    return 'सीखने के पथ के हर लेवल में $cost ऊर्जा लगती है। हर दिन आपको $free ऊर्जा मुफ़्त मिलती है। यह आधी रात को भरती है — $time में।';
  }

  @override
  String get journeyCoinsInfo =>
      'नए स्टार, अध्याय संदूक, आज के सवाल, रोज़ का लक्ष्य और स्ट्रीक पड़ावों से सिक्के कमाएँ। इन्हें स्टोर में ऊर्जा भरने और स्ट्रीक फ़्रीज़ पर खर्च करें।';

  @override
  String get journeyOpenStore => 'स्टोर खोलें';

  @override
  String get journeyListView => 'लेवल सूची के रूप में दिखाएँ';

  @override
  String get journeyAllLevels => 'सभी लेवल';

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
  String get quizQuitStay => 'खेलते रहें';

  @override
  String get quizQuitLeave => 'छोड़ें';

  @override
  String get quizTapToCheck => 'जाँचने के लिए किसी उत्तर पर टैप करें।';

  @override
  String get quizChecking => 'आपका उत्तर जाँचा जा रहा है…';

  @override
  String quizTimedHint(int seconds) {
    return '$seconds सेकंड में उत्तर दें। समय पर उत्तर न देने पर उसे गलत माना जाएगा।';
  }

  @override
  String get quizDuelHint =>
      'सही उत्तर पर 1,000 तक अंक मिलते हैं — जितनी जल्दी, उतने ज़्यादा। गलत उत्तर पर 0।';

  @override
  String get quizExamHint =>
      'एक उत्तर चुनें, फिर आगे बढ़ें। आप किसी प्रश्न पर वापस नहीं जा सकते।';

  @override
  String quizSecondsLeft(int seconds) {
    return '$seconds सेकंड बचे';
  }

  @override
  String quizTimeLeft(String time) {
    return 'बचा समय: $time';
  }

  @override
  String get quizNoExplanation => 'इस प्रश्न की व्याख्या अभी उपलब्ध नहीं है।';

  @override
  String quizQuitRefund(int count) {
    return 'आपने अभी उत्तर नहीं दिया है, इसलिए आपकी $count ऊर्जा वापस मिल जाएगी।';
  }

  @override
  String get quizQuitFree =>
      'आपने अभी उत्तर नहीं दिया है, इसलिए कुछ नहीं खोया। आप बाद में फिर शुरू कर सकते हैं।';

  @override
  String get quizQuitAnswered =>
      'यह प्रयास खत्म हो जाएगा और बाद में जारी नहीं रहेगा। अब तक के उत्तर नहीं गिने जाएँगे।';

  @override
  String quizQuitAnsweredEnergy(int count) {
    return 'यह प्रयास खत्म हो जाएगा और बाद में जारी नहीं रहेगा। अब तक के उत्तर नहीं गिने जाएँगे और $count ऊर्जा वापस नहीं मिलेगी।';
  }

  @override
  String get quizRefundFailed =>
      'Nyaya से जुड़ नहीं सके, इसलिए आपकी ऊर्जा वापस नहीं मिली।';

  @override
  String get quizOptionCorrect => 'सही उत्तर';

  @override
  String get quizOptionWrong => 'आपका उत्तर, गलत';

  @override
  String get quizOptionSelected => 'चुना गया';

  @override
  String get quizOptionChecking => 'जाँच हो रही है';

  @override
  String get resultNoAnswer => 'कोई उत्तर नहीं';

  @override
  String get resultHideReview => 'उत्तर छिपाएँ';

  @override
  String get reportSending => 'भेजा जा रहा है…';

  @override
  String get reportFailed =>
      'रिपोर्ट नहीं भेज सके। आपका लिखा सुरक्षित है, फिर कोशिश करें।';

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
  String get resultKeepPractising => 'अभ्यास जारी रखें';

  @override
  String get resultNewExam => 'नई परीक्षा';

  @override
  String get levelUpTitle => 'लेवल अप!';

  @override
  String levelUpCleared(int number) {
    return 'लेवल $number पूरा';
  }

  @override
  String levelUpNextLevel(int number) {
    return 'लेवल $number अब खुल गया';
  }

  @override
  String get levelUpChest => 'अध्याय का संदूक खोलने के लिए तैयार है';

  @override
  String levelUpNewChapter(String chapter) {
    return 'नया अध्याय: $chapter';
  }

  @override
  String levelUpRank(int before, int after) {
    return 'लीग रैंक #$before → #$after';
  }

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
    return '3-स्टार बोनस: +$count ऊर्जा';
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
  String get leaderboardPractice => 'अभ्यास खिलाड़ी';

  @override
  String leaderboardLearners(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'बोर्ड पर $count शिक्षार्थी',
      one: 'बोर्ड पर 1 शिक्षार्थी',
    );
    return '$_temp0';
  }

  @override
  String get leaderboardAllTimeJoin =>
      'ऑल-टाइम बोर्ड पर आने के लिए एक क्विज़ पूरा करें।';

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
      'आज के मुफ़्त सवाल खत्म हो गए। कल फिर आएँ या ज़्यादा AI सवालों के लिए प्रीमियम लें।';

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
  String get updatesSavedFilter => 'सहेजे गए';

  @override
  String get updatesSavedEmpty =>
      'अभी कुछ सहेजा नहीं गया। किसी भी अपडेट पर बुकमार्क दबाएँ, वह यहाँ रहेगा।';

  @override
  String get updatesEmpty => 'इस श्रेणी में अभी कोई अपडेट नहीं है।';

  @override
  String get updatesSave => 'अपडेट सहेजें';

  @override
  String get updatesUnsave => 'सहेजे हुए से हटाएँ';

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
  String get reminderTitle => 'आज के अभ्यास का समय';

  @override
  String reminderStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'अपनी $count दिन की स्ट्रीक जारी रखें: बस एक छोटी क्विज़ काफ़ी है।',
    );
    return '$_temp0';
  }

  @override
  String get reminderLearn =>
      'रोज़ एक छोटी क्विज़ से कानून की असली समझ बनती है।';

  @override
  String get reminderJourney =>
      'आपका सीखने का पथ इंतज़ार कर रहा है। अगले पड़ाव के लिए तैयार?';

  @override
  String get reminderRights =>
      'अपने अधिकार जानें: दो मिनट की एक क्विज़ आपके लिए तैयार है।';

  @override
  String get settingsReminderTime => 'रिमाइंडर का समय';

  @override
  String get settingsRemindersBlocked =>
      'Nyaya के लिए सूचनाएँ बंद हैं। रिमाइंडर पाने के लिए फ़ोन की सेटिंग्स में इन्हें चालू करें।';

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
  String get settingsDuelRecord => 'जीते क्विक क्विज़';

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
      'आपकी प्रगति आपके खाते में सहेजी जाती है, साथ ही वे दिन भी जब आप ऐप खोलते हैं, ताकि हम देख सकें कि लोग वापस आते हैं या नहीं। आप AI से जो सवाल पूछते हैं, वे केवल उत्तर लिखने के लिए हमारे AI प्रदाता को भेजे जाते हैं। ऐप क्रैश होने पर हमें उसे ठीक करने में मदद के लिए एक छोटी तकनीकी रिपोर्ट भेजी जाती है (उसमें आपके उत्तर या निजी जानकारी नहीं होती)। आप सेटिंग्स में अपना खाता हटा सकते हैं।';

  @override
  String settingsVersion(String version) {
    return 'संस्करण $version';
  }

  @override
  String get settingsReset => 'इस फ़ोन को रीसेट करें';

  @override
  String get settingsResetConfirm =>
      'इससे स्वागत के चरण फिर से शुरू होंगे और इस फ़ोन की सेटिंग्स साफ़ हो जाएँगी। आपके XP, स्टार, सिक्के और स्ट्रीक आपके खाते में सुरक्षित रहते हैं।';

  @override
  String get settingsResetAction => 'रीसेट करें';

  @override
  String get premiumTitle => 'Nyaya प्रीमियम';

  @override
  String get premiumHeadline => 'हर दिन ज़्यादा सीखें';

  @override
  String get premiumBenefitEnergy => 'असीमित ऊर्जा';

  @override
  String premiumBenefitEnergySub(int free) {
    return 'मुफ़्त: रोज़ $free ऊर्जा। प्रीमियम: जितने चाहें उतने क्विज़ खेलें।';
  }

  @override
  String get premiumBenefitAi => 'ज़्यादा Nyaya AI';

  @override
  String premiumBenefitAiSub(int free, int premium) {
    return 'मुफ़्त: रोज़ $free सवाल। प्रीमियम: रोज़ $premium सवाल।';
  }

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
  String get searchTitle => 'खोजें';

  @override
  String get searchHint => 'कानून, विषय और अपडेट खोजें';

  @override
  String get searchTopics => 'विषय';

  @override
  String get searchLaws => 'कानून';

  @override
  String get searchUpdates => 'अपडेट';

  @override
  String searchAskAi(String query) {
    return 'AI से पूछें: “$query”';
  }

  @override
  String searchNoResults(String query) {
    return '“$query” से अभी कुछ मेल नहीं खाता। AI से पूछें।';
  }

  @override
  String get exploreTitle => 'कानून खोजें';

  @override
  String get exploreSubtitle => 'भारतीय कानून की अपनी समझ बढ़ाएँ';

  @override
  String get exploreStartHere => 'यहाँ से शुरू करें';

  @override
  String get exploreFeatured => 'ख़ास';

  @override
  String get exploreButton => 'खोजें';

  @override
  String get exploreCoreLaws => 'मुख्य कानून';

  @override
  String get exploreViewAll => 'सभी देखें';

  @override
  String get exploreLegacy => 'पुराने कानून';

  @override
  String get exploreAskAi => 'AI से पूछें';

  @override
  String exploreAskPrompt(String law) {
    return '$law को आसान भाषा में समझाइए: इसमें क्या-क्या आता है और मुझे कौन-से मुख्य प्रावधान जानने चाहिए।';
  }

  @override
  String get lawConstitutionTitle => 'भारत का संविधान';

  @override
  String get lawConstitutionDesc =>
      'मौलिक अधिकार, नीति निदेशक तत्व, कर्तव्य और बहुत कुछ।';

  @override
  String get lawBnsTitle => 'भारतीय न्याय संहिता (BNS)';

  @override
  String get lawBnsShort => 'भारतीय न्याय संहिता';

  @override
  String get lawBnsDesc => 'मूल आपराधिक कानून';

  @override
  String get lawBnsFeatured =>
      'भारत की नई आपराधिक संहिता के अंतर्गत अपराध और सज़ाएँ।';

  @override
  String get lawBnssTitle => 'भारतीय नागरिक सुरक्षा संहिता (BNSS)';

  @override
  String get lawBnssDesc => 'आपराधिक प्रक्रिया कानून';

  @override
  String get lawBsaTitle => 'भारतीय साक्ष्य अधिनियम (BSA)';

  @override
  String get lawBsaDesc => 'साक्ष्य का कानून';

  @override
  String get lawEverydayTitle => 'रोज़मर्रा का कानून';

  @override
  String get lawEverydayDesc => 'रोज़ की ज़िंदगी में अपने अधिकार जानें';

  @override
  String get lawEverydayFeatured =>
      'उपभोक्ता, किराएदारी, कार्यस्थल और परिवार के अधिकार, आसान भाषा में।';

  @override
  String get lawLegacyTitle => 'IPC और CrPC (पुराने कानून)';

  @override
  String get lawLegacyDesc =>
      'जुलाई 2024 में बदले गए। संदर्भ और तुलना के लिए रखे गए हैं।';

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
  String get authCreateTitle => 'अपना मुफ़्त खाता बनाएँ';

  @override
  String get authCreateSubtitle =>
      'सवाल Nyaya की जाँची हुई लाइब्रेरी से आते हैं, और आपके नतीजे आपके खाते में सहेजे जाते हैं।';

  @override
  String get authSignInTitle => 'फिर से स्वागत है';

  @override
  String get authSignInSubtitle => 'अभ्यास जारी रखने के लिए साइन इन करें।';

  @override
  String get authName => 'आपका नाम';

  @override
  String get authEmail => 'ईमेल';

  @override
  String get authPassword => 'पासवर्ड';

  @override
  String get authPasswordHint => 'कम से कम 8 अक्षर';

  @override
  String get authCreate => 'खाता बनाएँ';

  @override
  String get authSignIn => 'साइन इन करें';

  @override
  String get authHaveAccount => 'मेरा खाता पहले से है';

  @override
  String get authNeedAccount => 'नए हैं? खाता बनाएँ';

  @override
  String get authErrorCredentials => 'ईमेल या पासवर्ड सही नहीं है।';

  @override
  String get authErrorEmailTaken =>
      'इस ईमेल से खाता पहले से मौजूद है। इसके बजाय साइन इन करें।';

  @override
  String get authErrorNetwork =>
      'अभी Nyaya से संपर्क नहीं हो पा रहा। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get authErrorRateLimited =>
      'बहुत ज़्यादा कोशिशें हो गईं। कुछ मिनट रुकें और फिर कोशिश करें।';

  @override
  String get authErrorInvalid =>
      'सही ईमेल और कम से कम 8 अक्षर का पासवर्ड दर्ज करें।';

  @override
  String get authErrorName => 'अपना नाम दर्ज करें।';

  @override
  String get authForgot => 'पासवर्ड भूल गए?';

  @override
  String get authResetTitle => 'अपना पासवर्ड बदलें';

  @override
  String get authResetSubtitle =>
      'अपने खाते का ईमेल डालें, हम आपको 6 अंकों का कोड भेजेंगे।';

  @override
  String get authResetSend => 'कोड भेजें';

  @override
  String authResetSentTo(String email) {
    return 'अगर $email से कोई खाता है, तो हमने उस पर 6 अंकों का कोड भेजा है। यह 15 मिनट तक काम करेगा। न दिखे तो स्पैम फ़ोल्डर देखें।';
  }

  @override
  String get authResetCode => '6 अंकों का कोड';

  @override
  String get authResetNewPassword => 'नया पासवर्ड';

  @override
  String get authResetSave => 'नया पासवर्ड सेट करें';

  @override
  String get authResetResend => 'नया कोड भेजें';

  @override
  String get authResetErrorCode =>
      'यह कोड गलत है या इसकी समय-सीमा खत्म हो गई है। नया कोड मँगाएँ।';

  @override
  String get authResetUnavailable =>
      'पासवर्ड बदलना अभी उपलब्ध नहीं है। कृपया बाद में कोशिश करें।';

  @override
  String get authResetErrorInvalid =>
      '6 अंकों का कोड और कम से कम 8 अक्षरों का नया पासवर्ड डालें।';

  @override
  String get authResetDone => 'आपका पासवर्ड बदल दिया गया है।';

  @override
  String get settingsAccount => 'खाता';

  @override
  String settingsSignedInAs(String email) {
    return '$email के रूप में साइन इन हैं';
  }

  @override
  String get settingsSignIn => 'साइन इन करें या खाता बनाएँ';

  @override
  String get settingsSignOut => 'साइन आउट करें';

  @override
  String get updateRequiredTitle => 'कृपया Nyaya अपडेट करें';

  @override
  String get updateRequiredBody =>
      'ऐप का यह संस्करण अब बहुत पुराना हो गया है और आगे काम नहीं करेगा। जारी रखने के लिए इसे अपडेट करें। आपकी प्रगति आपके खाते में सहेजी है, इसलिए कुछ नहीं खोएगा।';

  @override
  String get updateRequiredAction => 'अपडेट करें';

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
      'आपका उत्तर भेज नहीं सके। अपना कनेक्शन जाँचें और फिर टैप करें।';

  @override
  String get quizSubmitFailed =>
      'आपका नतीजा नहीं मिल सका। अपना कनेक्शन जाँचें।';

  @override
  String get quizRetry => 'फिर कोशिश करें';

  @override
  String get quizScoring => 'आपके केस के अंक गिने जा रहे हैं…';

  @override
  String get quizOffline =>
      'Nyaya से संपर्क नहीं हो पा रहा। अपना कनेक्शन जाँचें और फिर कोशिश करें।';

  @override
  String get quizSignedOut =>
      'आपका सत्र खत्म हो गया। खेलने के लिए फिर से साइन इन करें।';
}
