// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class AppLocalizationsMl extends AppLocalizations {
  AppLocalizationsMl([String locale = 'ml']) : super(locale);

  @override
  String get appName => 'Nyaya Kural';

  @override
  String get appTagline => 'ദിവസം ഒരു കേസ്, ഇന്ത്യൻ നിയമം പഠിക്കാം';

  @override
  String get navHome => 'ഹോം';

  @override
  String get navJourney => 'യാത്ര';

  @override
  String get navAskAi => 'AI-യോട് ചോദിക്കൂ';

  @override
  String get navUpdates => 'പുതിയവ';

  @override
  String get commonContinue => 'തുടരുക';

  @override
  String get reviewTitle => 'അവലോകനം';

  @override
  String get reviewMistakesTab => 'തെറ്റുകൾ';

  @override
  String get reviewSavedTab => 'സേവ് ചെയ്തവ';

  @override
  String get reviewPractise => 'തെറ്റുകൾ പരിശീലിക്കുക';

  @override
  String get reviewPractiseFree => 'സൗജന്യം · 10 ചോദ്യങ്ങൾ വരെ · XP നേടാം';

  @override
  String get reviewEmptyMistakes =>
      'അവലോകനം ചെയ്യാൻ തെറ്റുകളില്ല. നിങ്ങൾ തെറ്റിച്ച ചോദ്യങ്ങൾ ശരിയായി ഉത്തരം നൽകുന്നതുവരെ ഇവിടെ കാണും.';

  @override
  String get reviewEmptySaved =>
      'ഇതുവരെ ഒന്നും സേവ് ചെയ്തിട്ടില്ല. ഒരു ചോദ്യത്തിന് ഉത്തരം നൽകിയ ശേഷം സേവ് അമർത്തിയാൽ അത് ഇവിടെ സൂക്ഷിക്കും.';

  @override
  String get reviewSignIn =>
      'നിങ്ങളുടെ തെറ്റുകളും സേവ് ചെയ്ത ചോദ്യങ്ങളും കാണാൻ സൈൻ ഇൻ ചെയ്യുക.';

  @override
  String reviewWrongTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count തവണ തെറ്റി',
      one: 'ഒരു തവണ തെറ്റി',
    );
    return '$_temp0';
  }

  @override
  String get reviewUpdatedSince =>
      'നിങ്ങൾ ഉത്തരം നൽകിയ ശേഷം ഇത് പുതുക്കിയിട്ടുണ്ട്. നിങ്ങൾ കണ്ട രൂപത്തിലാണ് കാണിക്കുന്നത്.';

  @override
  String get reviewUnavailable => 'ഈ ചോദ്യം ഇപ്പോൾ ലഭ്യമല്ല.';

  @override
  String reviewCardBody(int mistakes, int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      mistakes,
      locale: localeName,
      other: '$mistakes തെറ്റുകൾ',
      one: '1 തെറ്റ്',
    );
    return '$_temp0 · $saved സേവ് ചെയ്തു';
  }

  @override
  String get questionSave => 'സേവ്';

  @override
  String get questionSaved => 'സേവ് ചെയ്തു';

  @override
  String get questionReport => 'റിപ്പോർട്ട്';

  @override
  String get questionSaveFailed =>
      'സേവ് ചെയ്യാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get reportTitle => 'പ്രശ്നം റിപ്പോർട്ട് ചെയ്യുക';

  @override
  String get reportReasonWrongAnswer => 'ഉത്തരം തെറ്റാണ്';

  @override
  String get reportReasonUnclear => 'ചോദ്യം വ്യക്തമല്ല';

  @override
  String get reportReasonOutdatedLaw => 'നിയമം മാറിയിട്ടുണ്ട്';

  @override
  String get reportReasonTypo => 'അക്ഷരത്തെറ്റ് അല്ലെങ്കിൽ വാക്കുകൾ';

  @override
  String get reportReasonOther => 'മറ്റെന്തെങ്കിലും';

  @override
  String get reportComment => 'മറ്റെന്തെങ്കിലും പറയാനുണ്ടോ? (ഐച്ഛികം)';

  @override
  String get reportSend => 'റിപ്പോർട്ട് അയയ്ക്കുക';

  @override
  String get reportSent => 'നന്ദി. ഞങ്ങളുടെ നിയമ സംഘം ഈ ചോദ്യം പരിശോധിക്കും.';

  @override
  String get reportAlready =>
      'ഈ ചോദ്യം നിങ്ങൾ ഇതിനകം റിപ്പോർട്ട് ചെയ്തിട്ടുണ്ട്.';

  @override
  String get reportLimit =>
      'ഇന്ന് നിങ്ങൾ ഒരുപാട് റിപ്പോർട്ടുകൾ അയച്ചു. ദയവായി നാളെ വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get commonBack => 'തിരികെ';

  @override
  String get commonNext => 'അടുത്തത്';

  @override
  String get commonSkip => 'ഒഴിവാക്കുക';

  @override
  String get commonCancel => 'റദ്ദാക്കുക';

  @override
  String get commonClose => 'അടയ്ക്കുക';

  @override
  String get commonStart => 'തുടങ്ങുക';

  @override
  String get commonRetry => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get commonDone => 'പൂർത്തിയായി';

  @override
  String get commonSeeAll => 'എല്ലാം കാണുക';

  @override
  String get commonLater => 'പിന്നീട്';

  @override
  String get commonOk => 'ശരി';

  @override
  String get commonComingSoon => 'ഉടൻ വരുന്നു';

  @override
  String get commonSomethingWrong =>
      'എന്തോ പിശക് സംഭവിച്ചു. ദയവായി വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get onbChooseLanguage => 'നിങ്ങളുടെ ഭാഷ തിരഞ്ഞെടുക്കുക';

  @override
  String get onbChooseLanguageSub =>
      'ഇത് എപ്പോൾ വേണമെങ്കിലും ക്രമീകരണങ്ങളിൽ മാറ്റാം.';

  @override
  String get onbSlide1Title => 'നിയമം, ലളിതമായി';

  @override
  String get onbSlide1Body =>
      'ഭരണഘടന, BNS, BNSS എന്നിവയെക്കുറിച്ചും ദിവസവും കാണുന്ന നിയമങ്ങളെക്കുറിച്ചും ചെറിയ ക്വിസുകൾ.';

  @override
  String get onbSlide2Title => 'പഠന പാതയിലൂടെ മുന്നേറൂ';

  @override
  String get onbSlide2Body =>
      'ഓരോ ലെവലും കയറി, നക്ഷത്രങ്ങൾ നേടി, പെട്ടികൾ തുറന്ന് പുതിയ അധ്യായങ്ങൾ തുറക്കൂ.';

  @override
  String get onbSlide3Title => 'ദിവസേനയുള്ള ശീലം വളർത്തൂ';

  @override
  String get onbSlide3Body =>
      'സ്ട്രീക്ക് നിലനിർത്തൂ, ആഴ്ചതോറുമുള്ള കോടതി ലീഗുകളിൽ മുന്നേറൂ, നിയമപരമായ എന്തും ഞങ്ങളുടെ AI-യോട് ചോദിക്കൂ.';

  @override
  String get onbSkip => 'ഒഴിവാക്കുക';

  @override
  String onbSlidePosition(int current, int total) {
    return 'സ്ലൈഡ് $current / $total';
  }

  @override
  String get onbGetStarted => 'തുടങ്ങാം';

  @override
  String get onbBrandTagline => 'നിയമം പഠിക്കൂ. ജീവിതത്തിൽ പകർത്തൂ.';

  @override
  String get onbIntro1Title => 'ഇന്ത്യൻ നിയമത്തിലേക്കുള്ള വഴികാട്ടി';

  @override
  String get onbIntro1Body =>
      'വ്യക്തതയോടെ പഠിക്കൂ, ലക്ഷ്യത്തോടെ പരിശീലിക്കൂ, നിങ്ങളുടെ ദൈനംദിന ജീവിതത്തെ രൂപപ്പെടുത്തുന്ന നിയമം മനസ്സിലാക്കൂ.';

  @override
  String get onbIntro2Label => 'ക്രമമായ പഠനം';

  @override
  String get onbIntro2Title => 'നിങ്ങളുടെ വേഗത്തിൽ പഠിക്കൂ';

  @override
  String get onbIntro2Body =>
      'ഭരണഘടന, BNS, BNSS, BSA തുടങ്ങിയവ ക്രമമായ പാഠങ്ങൾ, കുറിപ്പുകൾ, യഥാർത്ഥ ഉദാഹരണങ്ങൾ എന്നിവയിലൂടെ പഠിക്കൂ.';

  @override
  String get onbIntro3Label => 'പരിശീലിക്കൂ, പ്രയോഗിക്കൂ';

  @override
  String get onbIntro3Title => 'ശരിയായ ധാരണ വളർത്തൂ';

  @override
  String get onbIntro3Body =>
      'ക്വിസുകളിലൂടെ നിങ്ങളുടെ അറിവ് പരീക്ഷിക്കൂ, പുതിയ നിയമ വാർത്തകൾ വായിക്കൂ, നിയമം യഥാർത്ഥ ജീവിതത്തിൽ എങ്ങനെ ബാധകമാകുന്നു എന്ന് കാണൂ.';

  @override
  String get onbDemoChapter => 'മൗലികാവകാശങ്ങൾ';

  @override
  String get onbDemoChapterSub => 'ഇന്ത്യൻ ഭരണഘടന · അധ്യായം 3';

  @override
  String get onbDemoProgress => '8 പാഠങ്ങളിൽ 5 എണ്ണം പൂർത്തിയായി';

  @override
  String get onbDemoContinue => 'പഠനം തുടരുക';

  @override
  String get onbDemoLesson1 => 'ആമുഖം';

  @override
  String get onbDemoLesson2 => 'സമത്വത്തിനുള്ള അവകാശം';

  @override
  String get onbDemoLesson3 => 'സ്വാതന്ത്ര്യത്തിനുള്ള അവകാശം';

  @override
  String get onbDemoLesson4 => 'ചൂഷണത്തിനെതിരായ അവകാശം';

  @override
  String get onbDemoQuiz => 'ഡെയ്‌ലി ക്വിസ്';

  @override
  String get onbDemoQuizSub => '5 പ്രവർത്തനങ്ങളിൽ 3 എണ്ണം';

  @override
  String get onbDemoUpdates => 'നിയമ വാർത്തകൾ';

  @override
  String get onbDemoUpdatesSub =>
      'പ്രധാന വിധികളും സംഭവവികാസങ്ങളും അറിഞ്ഞിരിക്കൂ.';

  @override
  String get onbDemoScenarios => 'യഥാർത്ഥ ജീവിത സാഹചര്യങ്ങൾ';

  @override
  String get onbDemoScenariosSub =>
      'നിത്യജീവിതത്തിൽ നിയമം എങ്ങനെ പ്രവർത്തിക്കുന്നു എന്ന് മനസ്സിലാക്കൂ.';

  @override
  String get onbWhoAreYou => 'നിങ്ങൾ ആരായി പഠിക്കുന്നു?';

  @override
  String get onbWhoAreYouSub =>
      'നിങ്ങൾക്കനുസരിച്ച് ബുദ്ധിമുട്ടും നിർദ്ദേശങ്ങളും ക്രമീകരിക്കാം.';

  @override
  String get personaAdvocate => 'അഭിഭാഷകൻ';

  @override
  String get personaAdvocateDesc =>
      'ഓർമ്മ പുതുക്കുന്ന പ്രാക്ടീസ് ചെയ്യുന്ന അഭിഭാഷകർ';

  @override
  String get personaAspirant => 'നിയമ വിദ്യാർത്ഥി';

  @override
  String get personaAspirantDesc =>
      'CLAT, AIBE അല്ലെങ്കിൽ ജുഡീഷ്യറി തയ്യാറെടുപ്പ്';

  @override
  String get personaCitizen => 'പൗരൻ';

  @override
  String get personaCitizenDesc =>
      'നിങ്ങളുടെ അവകാശങ്ങളും ദൈനംദിന നിയമവും അറിയുക';

  @override
  String get onbDailyGoal => 'ദിവസേനയുള്ള ലക്ഷ്യം തിരഞ്ഞെടുക്കുക';

  @override
  String get onbDailyGoalSub =>
      'ലക്ഷ്യം വെക്കുന്നവർ പഠനം തുടരാൻ സാധ്യത വളരെ കൂടുതലാണ്.';

  @override
  String get goalCasual => 'സാധാരണ';

  @override
  String get goalRegular => 'പതിവ്';

  @override
  String get goalSerious => 'ഗൗരവമായി';

  @override
  String goalQuizzesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ദിവസം $count ക്വിസുകൾ',
      one: 'ദിവസം 1 ക്വിസ്',
    );
    return '$_temp0';
  }

  @override
  String get onbYourName => 'ഞങ്ങൾ നിങ്ങളെ എന്ത് വിളിക്കണം?';

  @override
  String get onbYourNameSub => 'ലീഡർബോർഡിൽ കാണിക്കും.';

  @override
  String get onbNameHint => 'നിങ്ങളുടെ പേര്';

  @override
  String get onbCommit => 'ലക്ഷ്യം ഉറപ്പിക്കുക';

  @override
  String onbReadyTitle(String name) {
    return 'എല്ലാം തയ്യാർ, $name!';
  }

  @override
  String get onbReadyBody => 'നിങ്ങളുടെ ആദ്യ പാഠം പഠന പാതയിൽ കാത്തിരിക്കുന്നു.';

  @override
  String get greetingMorning => 'സുപ്രഭാതം';

  @override
  String get greetingAfternoon => 'ശുഭ ഉച്ച';

  @override
  String get greetingEvening => 'ശുഭ സന്ധ്യ';

  @override
  String get homeContinueJourney => 'നിങ്ങളുടെ പഠന പാത തുടരൂ';

  @override
  String get homeContinueLeftOff => 'നിർത്തിയിടത്തു നിന്ന് തുടരുക';

  @override
  String get homeStartTitle => 'നിങ്ങളുടെ പഠനയാത്ര തുടങ്ങൂ';

  @override
  String get homeStartBody => 'ഇന്ത്യൻ നിയമം ഓരോ ആശയമായി മനസ്സിലാക്കൂ.';

  @override
  String get homeStartRecommended => 'തുടങ്ങാൻ നിർദ്ദേശം';

  @override
  String get homeStartLawDesc =>
      'മൗലികാവകാശങ്ങൾ, കടമകൾ, ഭരണഘടനാ തത്വങ്ങൾ എന്നിവ മനസ്സിലാക്കൂ.';

  @override
  String get homeStartLearning => 'പഠനം തുടങ്ങൂ';

  @override
  String homeLevelsDone(int done, int total) {
    return '$total ലെവലുകളിൽ $done പൂർത്തിയായി';
  }

  @override
  String get homeFeatured => 'പ്രത്യേകം';

  @override
  String get homeViewOnMap => 'മാപ്പിൽ കാണൂ';

  @override
  String get homeReviewMistakes => 'നിങ്ങളുടെ തെറ്റുകൾ വീണ്ടും നോക്കൂ';

  @override
  String get homeReviewSaved => 'നിങ്ങൾ സേവ് ചെയ്ത ചോദ്യങ്ങൾ';

  @override
  String get homeReviewNow => 'ഇപ്പോൾ നോക്കൂ';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'അധ്യായം $chapter · ലെവൽ $level';
  }

  @override
  String get homeChestReady => 'ഒരു പെട്ടി നിങ്ങളെ കാത്തിരിക്കുന്നു!';

  @override
  String get homeAllDone =>
      'നിങ്ങൾ എല്ലാ അധ്യായങ്ങളും പൂർത്തിയാക്കി. പുതിയ അധ്യായങ്ങൾ ഉടൻ വരുന്നു!';

  @override
  String get homePlay => 'കളിക്കുക';

  @override
  String get homeDailyGoal => 'ദിവസേനയുള്ള ലക്ഷ്യം';

  @override
  String homeGoalProgress(int done, int goal) {
    return '$goal-ൽ $done ക്വിസുകൾ';
  }

  @override
  String get homeGoalDone => 'ലക്ഷ്യം പൂർത്തിയായി — മികച്ച പ്രകടനം!';

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ദിവസത്തെ സ്ട്രീക്ക്',
      one: '1 ദിവസത്തെ സ്ട്രീക്ക്',
      zero: 'ഇന്ന് ഒരു സ്ട്രീക്ക് തുടങ്ങൂ',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakAtRisk =>
      'സ്ട്രീക്ക് നിലനിർത്താൻ ഇന്ന് ഒരു ക്വിസ് കളിക്കൂ!';

  @override
  String get homeStreakSafe => 'ഇന്നത്തെ സ്ട്രീക്ക് സുരക്ഷിതം';

  @override
  String get homeModesTitle => 'ക്വിസ് മോഡുകൾ';

  @override
  String get homeLeagueTitle => 'ഈ ആഴ്ചത്തെ ലീഗ്';

  @override
  String homeLeagueRank(int rank, String tier) {
    return '$tier-ൽ നിങ്ങൾ #$rank ആണ്';
  }

  @override
  String homeLeagueEnds(String time) {
    return '$time-ൽ അവസാനിക്കും';
  }

  @override
  String get homeFactTitle => 'ഇന്നത്തെ നിയമ വസ്തുത';

  @override
  String get homeUpdatesTitle => 'പുതിയ നിയമ വാർത്തകൾ';

  @override
  String get homeGoPremium => 'പരിധിയില്ലാത്ത എനർജി നേടൂ';

  @override
  String get homeGoPremiumSub => 'Nyaya Kural Premium · 7 ദിവസം സൗജന്യ ട്രയൽ';

  @override
  String get modeCasePath => 'പഠന പാത';

  @override
  String get modeCasePathDesc => 'ലെവൽ തോറുമുള്ള യാത്ര';

  @override
  String get modeDailyDocket => 'ഇന്നത്തെ ചോദ്യങ്ങൾ';

  @override
  String get modeDailyDocketDesc => '5 ചോദ്യങ്ങൾ · എല്ലാവർക്കും ഒരേത്';

  @override
  String get modeDuel => 'ക്വിക്ക് ക്വിസ്';

  @override
  String get modeDuelDesc => '1v1 · 7 ചോദ്യങ്ങൾ · സമയത്തെ തോൽപ്പിക്കൂ';

  @override
  String get modeExam => 'പരീക്ഷാ പരിശീലനം';

  @override
  String get modeExamDesc => '20 ചോദ്യങ്ങൾ · 20 മിനിറ്റ് · നെഗറ്റീവ് മാർക്ക്';

  @override
  String get modeExamDescCitizen =>
      '20 ചോദ്യങ്ങൾ · 20 മിനിറ്റ് · അവകാശങ്ങൾ അറിയൂ';

  @override
  String get modeFree => 'സൗജന്യം';

  @override
  String modeEnergyCost(int count) {
    return '$count എനർജി';
  }

  @override
  String get docketDoneToday => 'ഇന്നത്തേത് കഴിഞ്ഞു';

  @override
  String docketNextIn(String time) {
    return 'പുതിയ ചോദ്യങ്ങൾ $timeൽ';
  }

  @override
  String get energyTitle => 'എനർജി';

  @override
  String energyLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count എനർജി ബാക്കി',
      one: '1 എനർജി ബാക്കി',
      zero: 'എനർജി ബാക്കിയില്ല',
    );
    return '$_temp0';
  }

  @override
  String get energyUnlimited => 'പരിധിയില്ല';

  @override
  String get energyOutTitle => 'നിങ്ങളുടെ എനർജി തീർന്നു';

  @override
  String energyOutBody(String time) {
    return 'അർദ്ധരാത്രിയിൽ എനർജി നിറയും — $time-ൽ.';
  }

  @override
  String energyRefillCoins(int coins) {
    return '$coins നാണയങ്ങൾക്ക് 1 എനർജി നിറയ്ക്കുക';
  }

  @override
  String get energyGoUnlimited => 'പരിധിയില്ലാത്ത എനർജി നേടുക';

  @override
  String get energyFreeOptions => 'ഇപ്പോഴും സൗജന്യമായി ചെയ്യാവുന്നവ';

  @override
  String get energyPlayDocket => 'ഇന്നത്തെ ചോദ്യങ്ങൾ കളിക്കൂ (സൗജന്യം)';

  @override
  String get energyAskAi => 'AI-യോട് ഒരു നിയമ ചോദ്യം ചോദിക്കൂ';

  @override
  String get energyReadUpdates => 'നിയമ വാർത്തകൾ വായിക്കൂ';

  @override
  String get energyNotEnoughCoins =>
      'ആവശ്യത്തിന് നാണയങ്ങളില്ല — നക്ഷത്രങ്ങളിൽ നിന്നും പെട്ടികളിൽ നിന്നും നേടൂ.';

  @override
  String get energyRefilled => '+1 എനർജി!';

  @override
  String get journeyTitle => 'പഠന പാത';

  @override
  String get journeySubtitle => 'ഇന്ത്യൻ നിയമത്തിലൂടെയുള്ള നിങ്ങളുടെ യാത്ര';

  @override
  String get journeyKeepGoing => 'മുന്നോട്ട് പോകൂ!';

  @override
  String get journeyQuote =>
      'ചെറിയ ചുവടുകൾ നിയമത്തെക്കുറിച്ചുള്ള അറിവ് കൂടുതൽ ശക്തമാക്കുന്നു.';

  @override
  String journeyStars(int count) {
    return '$count ★';
  }

  @override
  String journeyChapter(int number) {
    return 'അധ്യായം $number';
  }

  @override
  String journeyLevel(int number) {
    return 'ലെവൽ $number';
  }

  @override
  String get journeyLandmark => 'നാഴികക്കല്ല് ലെവൽ';

  @override
  String get journeyLocked => 'ലോക്ക് ചെയ്തു';

  @override
  String journeyQuestions(int count) {
    return '$count ചോദ്യങ്ങൾ';
  }

  @override
  String get journeyBestStars => 'നിങ്ങളുടെ മികച്ചത്';

  @override
  String get journeyReplay => 'വീണ്ടും കളിക്കുക';

  @override
  String get journeyChest => 'അധ്യായ പെട്ടി';

  @override
  String get journeyOpenChest => 'പെട്ടി തുറക്കുക';

  @override
  String get journeyJumpToCurrent => 'ഇപ്പോഴത്തെ ലെവലിലേക്ക് പോകുക';

  @override
  String get journeyYou => 'നിങ്ങൾ';

  @override
  String get journeyNext => 'അടുത്ത ചുവട്';

  @override
  String get journeyDone => 'പൂർത്തിയായി';

  @override
  String journeyStarsOf(int count, int total) {
    return '$totalൽ $count നക്ഷത്രങ്ങൾ';
  }

  @override
  String journeyLockedNext(String step) {
    return 'ലെവലുകൾ ക്രമത്തിൽ തുറക്കും. നിങ്ങളുടെ അടുത്ത ചുവട് $step.';
  }

  @override
  String get journeyGoToNext => 'എന്റെ അടുത്ത ചുവട് കാണിക്കുക';

  @override
  String journeyStartCost(int count) {
    return 'തുടങ്ങുക · $count എനർജി';
  }

  @override
  String journeyReplayCost(int count) {
    return 'വീണ്ടും കളിക്കുക · $count എനർജി';
  }

  @override
  String get journeyNoTimer => 'സമയപരിധി ഇല്ല';

  @override
  String get journeyStarsTitle => 'നിങ്ങൾക്ക് നേടാവുന്ന നക്ഷത്രങ്ങൾ';

  @override
  String journeyPassMark(int percent) {
    return '$percent% · ജയം';
  }

  @override
  String journeyStarMark(int percent) {
    return '$percent%';
  }

  @override
  String get journeyHowScoring => 'സ്കോർ എങ്ങനെ കണക്കാക്കുന്നു';

  @override
  String journeyRuleEnergy(int count) {
    return 'ഓരോ ശ്രമത്തിനും $count എനർജി ചെലവാകും. ആദ്യ ഉത്തരത്തിന് മുമ്പ് വിട്ടാൽ അത് തിരികെ ലഭിക്കും.';
  }

  @override
  String get journeyRuleRetry =>
      'ജയിച്ചില്ലേ? എത്ര തവണ വേണമെങ്കിലും വീണ്ടും ശ്രമിക്കാം.';

  @override
  String get journeyRuleBest =>
      'നിങ്ങളുടെ മികച്ച സ്കോർ സൂക്ഷിക്കും. കുറഞ്ഞ സ്കോർ ഒരിക്കലും നക്ഷത്രങ്ങൾ കുറയ്ക്കില്ല.';

  @override
  String get journeyRuleNoMinus => 'തെറ്റായ ഉത്തരങ്ങൾക്ക് മാർക്ക് കുറയില്ല.';

  @override
  String journeyRuleBonus(int count, int coins) {
    return 'ഒരു ലെവലിൽ ആദ്യമായി 3 നക്ഷത്രം നേടിയാൽ $count എനർജി തിരികെ ലഭിക്കും. ഓരോ പുതിയ നക്ഷത്രത്തിനും $coins നാണയങ്ങൾ.';
  }

  @override
  String get journeyChestLockedTitle => 'അധ്യായ പെട്ടി പൂട്ടിയിരിക്കുന്നു';

  @override
  String get journeyChestLockedText =>
      'നിങ്ങളുടെ സമ്മാനം തുറക്കാൻ ഈ അധ്യായത്തിലെ എല്ലാ ലെവലുകളും പൂർത്തിയാക്കുക.';

  @override
  String get journeyChestReadyTitle => 'നിങ്ങളുടെ അധ്യായ സമ്മാനം തയ്യാർ';

  @override
  String get journeyChestReadyText =>
      'മികച്ചത്! നിങ്ങൾ ഈ അധ്യായം പൂർത്തിയാക്കി.';

  @override
  String journeyChestReward(int coins) {
    return 'സമ്മാനം: $coins നാണയങ്ങൾ';
  }

  @override
  String get journeyChestCollectedTitle => 'അധ്യായ സമ്മാനം ലഭിച്ചു';

  @override
  String journeyChestCollectedText(int coins) {
    return 'നിങ്ങൾക്ക് $coins നാണയങ്ങൾ ലഭിച്ചു.';
  }

  @override
  String get journeyChestFailed =>
      'പെട്ടി തുറക്കാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക. നിങ്ങളുടെ സമ്മാനം കാത്തിരിക്കുന്നു.';

  @override
  String get journeyContinueLearning => 'പഠനം തുടരുക';

  @override
  String get journeyBackToMap => 'മാപ്പിലേക്ക് മടങ്ങുക';

  @override
  String journeyChapterProgress(int number, int done, int total) {
    return 'അധ്യായം $number · $done/$total പൂർത്തിയായി';
  }

  @override
  String journeyStarsInfo(int one, int two) {
    return 'ഓരോ ലെവലിലും 3 നക്ഷത്രങ്ങൾ വരെ നേടാം: 1 നക്ഷത്രത്തിന് $one%, 2ന് $two%, 3ന് 100%. ഓരോ ലെവലിലെയും നിങ്ങളുടെ മികച്ച സ്കോർ കണക്കാക്കും.';
  }

  @override
  String journeyEnergyInfo(int cost, int free, String time) {
    return 'പഠന പാതയിലെ ഓരോ ലെവലിനും $cost എനർജി ചെലവാകും. ദിവസവും $free എനർജി സൗജന്യം. അർധരാത്രി വീണ്ടും നിറയും — $timeൽ.';
  }

  @override
  String get journeyCoinsInfo =>
      'പുതിയ നക്ഷത്രങ്ങൾ, അധ്യായ പെട്ടികൾ, ഇന്നത്തെ ചോദ്യങ്ങൾ, ദിവസ ലക്ഷ്യം, സ്ട്രീക്ക് നാഴികക്കല്ലുകൾ എന്നിവയിൽ നിന്ന് നാണയങ്ങൾ നേടുക. സ്റ്റോറിൽ എനർജി നിറയ്ക്കാനും സ്ട്രീക്ക് ഫ്രീസിനും ചെലവാക്കുക.';

  @override
  String get journeyOpenStore => 'സ്റ്റോർ തുറക്കുക';

  @override
  String get journeyListView => 'ലെവലുകൾ ലിസ്റ്റായി കാണിക്കുക';

  @override
  String get journeyAllLevels => 'എല്ലാ ലെവലുകളും';

  @override
  String quizQuestionOf(int current, int total) {
    return 'ചോദ്യം $current / $total';
  }

  @override
  String get quizCorrect => 'ശരി!';

  @override
  String get quizWrong => 'തെറ്റി';

  @override
  String get quizTimeUp => 'സമയം കഴിഞ്ഞു';

  @override
  String quizAnswerWas(String answer) {
    return 'ഉത്തരം: $answer';
  }

  @override
  String get quizWhy => 'എന്തുകൊണ്ട്';

  @override
  String get quizReference => 'അവലംബം';

  @override
  String get quizOpenSource => 'ഔദ്യോഗിക രേഖ വായിക്കുക';

  @override
  String get quizOpenSourceFailed => 'ലിങ്ക് തുറക്കാനായില്ല';

  @override
  String quizCombo(int count) {
    return '$count× കോംബോ!';
  }

  @override
  String get quizFinish => 'പൂർത്തിയാക്കുക';

  @override
  String get quizSubmit => 'പരീക്ഷ സമർപ്പിക്കുക';

  @override
  String get quizSkipQuestion => 'ഒഴിവാക്കുക';

  @override
  String get quizSelectAnswer => 'ഒരു ഉത്തരം തിരഞ്ഞെടുക്കുക';

  @override
  String get quizQuitTitle => 'ഈ ക്വിസ് ഉപേക്ഷിക്കണോ?';

  @override
  String get quizQuitStay => 'കളി തുടരുക';

  @override
  String get quizQuitLeave => 'ഉപേക്ഷിക്കുക';

  @override
  String get quizTapToCheck => 'പരിശോധിക്കാൻ ഒരു ഉത്തരം തൊടുക.';

  @override
  String get quizChecking => 'നിങ്ങളുടെ ഉത്തരം പരിശോധിക്കുന്നു…';

  @override
  String quizTimedHint(int seconds) {
    return '$seconds സെക്കൻഡിനുള്ളിൽ ഉത്തരം നൽകുക. സമയത്ത് ഉത്തരമില്ലെങ്കിൽ തെറ്റായി കണക്കാക്കും.';
  }

  @override
  String get quizDuelHint =>
      'ശരിയുത്തരത്തിന് 1,000 പോയിന്റ് വരെ — വേഗം ഉത്തരം നൽകുംതോറും കൂടുതൽ. തെറ്റിന് 0.';

  @override
  String get quizExamHint =>
      'ഒരു ഉത്തരം തിരഞ്ഞെടുത്ത് മുന്നോട്ട് പോകുക. മുമ്പത്തെ ചോദ്യത്തിലേക്ക് മടങ്ങാനാവില്ല.';

  @override
  String quizSecondsLeft(int seconds) {
    return '$seconds സെക്കൻഡ് ബാക്കി';
  }

  @override
  String quizTimeLeft(String time) {
    return 'ബാക്കി സമയം: $time';
  }

  @override
  String get quizNoExplanation => 'ഈ ചോദ്യത്തിന് വിശദീകരണം ഇതുവരെ ലഭ്യമല്ല.';

  @override
  String quizQuitRefund(int count) {
    return 'നിങ്ങൾ ഇതുവരെ ഉത്തരം നൽകിയിട്ടില്ല, അതിനാൽ നിങ്ങളുടെ $count എനർജി തിരികെ ലഭിക്കും.';
  }

  @override
  String get quizQuitFree =>
      'നിങ്ങൾ ഇതുവരെ ഉത്തരം നൽകിയിട്ടില്ല, അതിനാൽ ഒന്നും നഷ്ടമില്ല. പിന്നീട് വീണ്ടും തുടങ്ങാം.';

  @override
  String get quizQuitAnswered =>
      'ഈ ശ്രമം അവസാനിക്കും, പിന്നീട് തുടരാനാവില്ല. ഇതുവരെയുള്ള ഉത്തരങ്ങൾ കണക്കാക്കില്ല.';

  @override
  String quizQuitAnsweredEnergy(int count) {
    return 'ഈ ശ്രമം അവസാനിക്കും, പിന്നീട് തുടരാനാവില്ല. ഇതുവരെയുള്ള ഉത്തരങ്ങൾ കണക്കാക്കില്ല, $count എനർജി തിരികെ ലഭിക്കില്ല.';
  }

  @override
  String get quizRefundFailed =>
      'Nyaya Kural-യിൽ എത്താനായില്ല, അതിനാൽ നിങ്ങളുടെ എനർജി തിരികെ ലഭിച്ചില്ല.';

  @override
  String get quizOptionCorrect => 'ശരിയുത്തരം';

  @override
  String get quizOptionWrong => 'നിങ്ങളുടെ ഉത്തരം, തെറ്റ്';

  @override
  String get quizOptionSelected => 'തിരഞ്ഞെടുത്തു';

  @override
  String get quizOptionChecking => 'പരിശോധിക്കുന്നു';

  @override
  String get resultNoAnswer => 'ഉത്തരമില്ല';

  @override
  String get resultHideReview => 'ഉത്തരങ്ങൾ മറയ്ക്കുക';

  @override
  String get reportSending => 'അയയ്ക്കുന്നു…';

  @override
  String get reportFailed =>
      'റിപ്പോർട്ട് അയയ്ക്കാനായില്ല. നിങ്ങൾ എഴുതിയത് സൂക്ഷിച്ചിട്ടുണ്ട്, വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get quizLoading => 'നിങ്ങളുടെ കേസ് തയ്യാറാക്കുന്നു…';

  @override
  String get quizEmpty => 'ഇവിടെ ഇതുവരെ ചോദ്യങ്ങളില്ല.';

  @override
  String get quizOpponent => 'എതിരാളി';

  @override
  String quizOpponentAnswered(String name, int seconds) {
    return '$name $seconds സെക്കൻഡിൽ ഉത്തരം നൽകി';
  }

  @override
  String get quizVs => 'VS';

  @override
  String get quizFindingOpponent => 'എതിരാളിയെ തിരയുന്നു…';

  @override
  String quizMarkedAnswers(int answered, int total) {
    return '$total-ൽ $answered ഉത്തരം നൽകി';
  }

  @override
  String get resultPerfect => 'സമ്പൂർണ്ണ കേസ്!';

  @override
  String get resultGreat => 'മികച്ച പ്രകടനം!';

  @override
  String get resultGood => 'ലെവൽ പൂർത്തിയായി!';

  @override
  String get resultTryAgain => 'ഏതാണ്ട് എത്തി';

  @override
  String get resultKeepPractising => 'പരിശീലനം തുടരൂ';

  @override
  String get resultNewExam => 'പുതിയ പരീക്ഷ';

  @override
  String get levelUpTitle => 'ലെവൽ അപ്പ്!';

  @override
  String levelUpCleared(int number) {
    return 'ലെവൽ $number പൂർത്തിയായി';
  }

  @override
  String levelUpNextLevel(int number) {
    return 'ലെവൽ $number ഇപ്പോൾ തുറന്നു';
  }

  @override
  String get levelUpChest => 'അധ്യായ പെട്ടി തുറക്കാൻ തയ്യാർ';

  @override
  String levelUpNewChapter(String chapter) {
    return 'പുതിയ അധ്യായം: $chapter';
  }

  @override
  String levelUpRank(int before, int after) {
    return 'ലീഗ് റാങ്ക് #$before → #$after';
  }

  @override
  String get resultTryAgainBody =>
      'ഈ ലെവൽ ജയിക്കാൻ കുറഞ്ഞത് 50% നേടണം. വിശദീകരണങ്ങൾ വായിച്ച് വീണ്ടും ശ്രമിക്കൂ.';

  @override
  String resultScore(int correct, int total) {
    return '$total-ൽ $correct ശരി';
  }

  @override
  String get resultAccuracy => 'കൃത്യത';

  @override
  String get resultXp => 'XP';

  @override
  String get resultCoins => 'നാണയങ്ങൾ';

  @override
  String get resultTime => 'സമയം';

  @override
  String resultStreakExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'സ്ട്രീക്ക് $count ദിവസമായി നീണ്ടു!',
      one: 'നിങ്ങളുടെ സ്ട്രീക്ക് തുടങ്ങി — ഒന്നാം ദിവസം!',
    );
    return '$_temp0';
  }

  @override
  String resultMilestone(int count) {
    return '$count ദിവസത്തെ സ്ട്രീക്ക് നാഴികക്കല്ല്!';
  }

  @override
  String get resultGoalReached => 'ദിവസേനയുള്ള ലക്ഷ്യം നേടി!';

  @override
  String resultEnergyBonus(int count) {
    return '3 നക്ഷത്ര ബോണസ്: +$count എനർജി';
  }

  @override
  String resultLeagueUp(int rank) {
    return 'നിങ്ങളുടെ ലീഗിൽ #$rank-ലേക്ക് ഉയർന്നു';
  }

  @override
  String get resultReview => 'ഉത്തരങ്ങൾ പരിശോധിക്കുക';

  @override
  String get resultNextLevel => 'അടുത്ത ലെവൽ';

  @override
  String get resultBackToMap => 'മാപ്പിലേക്ക്';

  @override
  String get resultBackHome => 'ഹോമിലേക്ക്';

  @override
  String get resultPlayAgain => 'വീണ്ടും കളിക്കുക';

  @override
  String resultExamScore(String score, int max) {
    return 'സ്കോർ: $score / $max';
  }

  @override
  String resultExamBreakdown(int correct, int wrong, int skipped) {
    return '$correct ശരി · $wrong തെറ്റ് · $skipped ഒഴിവാക്കി';
  }

  @override
  String get resultDuelWon => 'നിങ്ങൾ ഡ്യുവൽ ജയിച്ചു!';

  @override
  String get resultDuelLost => 'ഇഞ്ചോടിഞ്ച് പോരാട്ടം!';

  @override
  String get resultDuelDraw => 'സമനില!';

  @override
  String resultDuelPoints(int you, int them) {
    return '$you vs $them';
  }

  @override
  String get resultDocketShare => 'ഫലം പങ്കിടുക';

  @override
  String get resultYourAnswer => 'നിങ്ങളുടെ ഉത്തരം';

  @override
  String get resultCorrectAnswer => 'ശരിയായ ഉത്തരം';

  @override
  String get resultSkipped => 'ഒഴിവാക്കി';

  @override
  String get leaderboardTitle => 'ലീഡർബോർഡ്';

  @override
  String get leaderboardWeekly => 'ആഴ്ചതോറുമുള്ള ലീഗ്';

  @override
  String get leaderboardAllTime => 'എക്കാലത്തെയും';

  @override
  String get leaderboardPromotionZone => 'പ്രമോഷൻ മേഖല';

  @override
  String get leaderboardDemotionZone => 'ഡിമോഷൻ മേഖല';

  @override
  String leaderboardEndsIn(String time) {
    return 'ആഴ്ച $time-ൽ അവസാനിക്കും';
  }

  @override
  String leaderboardTopPromote(int count, String tier) {
    return 'ആദ്യ $count പേർ $tier-ലേക്ക് ഉയരും';
  }

  @override
  String get leaderboardNoDemotion => 'ഈ ലീഗിൽ ഡിമോഷനില്ല — പഠനം തുടരൂ!';

  @override
  String get leaderboardEarnToJoin =>
      'ലീഗിൽ ചേരാൻ ഈ ആഴ്ച ഒരു ക്വിസ് പൂർത്തിയാക്കൂ.';

  @override
  String leaderboardXp(int xp) {
    return '$xp XP';
  }

  @override
  String get leaderboardPractice => 'പരിശീലന കളിക്കാരൻ';

  @override
  String leaderboardLearners(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ബോർഡിൽ $count പഠിതാക്കൾ',
      one: 'ബോർഡിൽ 1 പഠിതാവ്',
    );
    return '$_temp0';
  }

  @override
  String get leaderboardAllTimeJoin =>
      'എക്കാലത്തെയും ബോർഡിൽ ഇടം നേടാൻ ഒരു ക്വിസ് പൂർത്തിയാക്കൂ.';

  @override
  String get leaderboardYou => 'നിങ്ങൾ';

  @override
  String get leaderboardTiers => 'ലീഗ് തലങ്ങൾ';

  @override
  String leagueOutcomePromoted(String tier) {
    return '$tier-ലേക്ക് പ്രമോഷൻ!';
  }

  @override
  String leagueOutcomeDemoted(String tier) {
    return '$tier-ലേക്ക് മാറ്റി';
  }

  @override
  String leagueOutcomeStayed(String tier) {
    return 'നിങ്ങൾ $tier-ൽ തുടരുന്നു';
  }

  @override
  String leagueOutcomeRank(int rank) {
    return 'കഴിഞ്ഞ ആഴ്ച നിങ്ങൾ #$rank സ്ഥാനത്തെത്തി.';
  }

  @override
  String get tier_nyayaPanchayat => 'ന്യായ പഞ്ചായത്ത്';

  @override
  String get tier_gramNyayalaya => 'ഗ്രാമ ന്യായാലയം';

  @override
  String get tier_munsiffCourt => 'മുൻസിഫ് കോടതി';

  @override
  String get tier_magistrateCourt => 'മജിസ്ട്രേറ്റ് കോടതി';

  @override
  String get tier_districtCourt => 'ജില്ലാ കോടതി';

  @override
  String get tier_sessionsCourt => 'സെഷൻസ് കോടതി';

  @override
  String get tier_highCourt => 'ഹൈക്കോടതി';

  @override
  String get tier_supremeCourt => 'സുപ്രീം കോടതി';

  @override
  String get chatTitle => 'Nyaya Kural AI';

  @override
  String get chatSubtitle => 'നിങ്ങളുടെ നിയമ വിവര സഹായി';

  @override
  String get chatDisclaimer =>
      'പൊതുവായ നിയമ വിവരം മാത്രം, നിയമോപദേശമല്ല. നിങ്ങളുടെ കേസിനായി ഒരു അഭിഭാഷകനെ കാണുക അല്ലെങ്കിൽ NALSA ഹെൽപ്‌ലൈൻ 15100-ൽ വിളിക്കുക.';

  @override
  String get chatHint => 'ഏത് ഇന്ത്യൻ നിയമത്തെക്കുറിച്ചും ചോദിക്കൂ…';

  @override
  String get chatWelcome =>
      'നമസ്കാരം! ഇന്ത്യൻ നിയമങ്ങൾ, നിങ്ങളുടെ അവകാശങ്ങൾ, നിയമ നടപടിക്രമങ്ങൾ, പുതിയ ക്രിമിനൽ നിയമങ്ങൾ (BNS, BNSS, BSA) എന്നിവ ഞാൻ വിശദീകരിക്കാം. നിങ്ങൾക്ക് എന്താണ് അറിയേണ്ടത്?';

  @override
  String get chatSuggest1 => 'എന്താണ് സീറോ FIR?';

  @override
  String get chatSuggest2 => 'അറസ്റ്റ് ചെയ്യപ്പെട്ടാൽ എന്റെ അവകാശങ്ങൾ';

  @override
  String get chatSuggest3 => 'RTI അപേക്ഷ എങ്ങനെ നൽകാം?';

  @override
  String get chatSuggest4 => 'ഉപഭോക്തൃ പരാതി എങ്ങനെ നൽകാം?';

  @override
  String get chatThinking => 'നിയമം പരിശോധിക്കുന്നു…';

  @override
  String chatLimitLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ഇന്ന് $count സൗജന്യ ചോദ്യങ്ങൾ ബാക്കി',
      one: 'ഇന്ന് 1 സൗജന്യ ചോദ്യം ബാക്കി',
    );
    return '$_temp0';
  }

  @override
  String get chatLimitReached =>
      'ഇന്നത്തെ സൗജന്യ ചോദ്യങ്ങൾ തീർന്നു. നാളെ വരൂ, അല്ലെങ്കിൽ കൂടുതൽ AI ചോദ്യങ്ങൾക്ക് Premium എടുക്കൂ.';

  @override
  String get chatLimitReachedToday =>
      'ഇന്നത്തെ ചോദ്യങ്ങൾ കഴിഞ്ഞു. നാളെ വീണ്ടും ചോദിക്കാം.';

  @override
  String get chatError =>
      'ഇപ്പോൾ AI-യുമായി ബന്ധപ്പെടാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get chatOfflineNote =>
      'ഓഫ്‌ലൈൻ മോഡ് — പൂർണ്ണ ഉത്തരങ്ങൾക്ക് ഒരു AI കീ ബന്ധിപ്പിക്കുക.';

  @override
  String get chatClear => 'ചാറ്റ് മായ്ക്കുക';

  @override
  String get chatCopy => 'പകർത്തി';

  @override
  String get updatesTitle => 'നിയമ വാർത്തകൾ';

  @override
  String get updatesSubtitle => 'വിധികൾ, പുതിയ നിയമങ്ങൾ, വിശദീകരണങ്ങൾ';

  @override
  String get updatesAll => 'എല്ലാം';

  @override
  String get updatesSupremeCourt => 'സുപ്രീം കോടതി';

  @override
  String get updatesHighCourts => 'ഹൈക്കോടതികൾ';

  @override
  String get updatesLegislation => 'നിയമനിർമ്മാണം';

  @override
  String get updatesExplainer => 'വിശദീകരണങ്ങൾ';

  @override
  String updatesReadTime(int minutes) {
    return '$minutes മിനിറ്റ് വായന';
  }

  @override
  String get updatesKeyPoints => 'പ്രധാന കാര്യങ്ങൾ';

  @override
  String get updatesWhyItMatters => 'എന്തുകൊണ്ട് പ്രധാനം';

  @override
  String get updatesSource => 'ഉറവിടം';

  @override
  String get updatesAskAi => 'ഇതിനെക്കുറിച്ച് AI-യോട് ചോദിക്കൂ';

  @override
  String get updatesSavedFilter => 'സേവ് ചെയ്തവ';

  @override
  String get updatesSavedEmpty =>
      'ഇതുവരെ ഒന്നും സേവ് ചെയ്തിട്ടില്ല. ഏതെങ്കിലും അപ്ഡേറ്റിലെ ബുക്ക്മാർക്ക് തൊട്ടാൽ അത് ഇവിടെ കാണാം.';

  @override
  String get updatesEmpty => 'ഈ വിഭാഗത്തിൽ ഇതുവരെ വാർത്തകളില്ല.';

  @override
  String get updatesSave => 'വാർത്ത സേവ് ചെയ്യുക';

  @override
  String get updatesUnsave => 'സേവ് ചെയ്തതിൽ നിന്ന് നീക്കുക';

  @override
  String get updatesInEnglish => 'ഇംഗ്ലീഷിൽ കാണിക്കുന്നു';

  @override
  String get settingsTitle => 'ക്രമീകരണങ്ങൾ';

  @override
  String get settingsProfile => 'പ്രൊഫൈൽ';

  @override
  String get settingsEditName => 'പേര് മാറ്റുക';

  @override
  String get settingsLearningAs => 'പഠിക്കുന്നത്';

  @override
  String get settingsLanguage => 'ഭാഷ';

  @override
  String get settingsDailyGoal => 'ദിവസേനയുള്ള ലക്ഷ്യം';

  @override
  String get settingsAppearance => 'രൂപം';

  @override
  String get settingsThemeSystem => 'സിസ്റ്റം';

  @override
  String get settingsThemeLight => 'ലൈറ്റ്';

  @override
  String get settingsThemeDark => 'ഡാർക്ക്';

  @override
  String get settingsSound => 'ശബ്ദ ഇഫക്റ്റുകൾ';

  @override
  String get settingsHaptics => 'ഹാപ്റ്റിക് ഫീഡ്‌ബാക്ക്';

  @override
  String get settingsReminders => 'ദിവസേനയുള്ള ഓർമ്മപ്പെടുത്തൽ';

  @override
  String get settingsRemindersSub =>
      'സ്ട്രീക്ക് നിലനിർത്താൻ ഒരു ഓർമ്മപ്പെടുത്തൽ';

  @override
  String get reminderTitle => 'ഇന്നത്തെ പരിശീലനത്തിനുള്ള സമയം';

  @override
  String reminderStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'നിങ്ങളുടെ $count ദിവസത്തെ സ്ട്രീക്ക് തുടരൂ: ഒരു ചെറിയ ക്വിസ് മതി.',
    );
    return '$_temp0';
  }

  @override
  String get reminderLearn =>
      'ദിവസവും ഒരു ചെറിയ ക്വിസ് യഥാർത്ഥ നിയമ അറിവ് വളർത്തുന്നു.';

  @override
  String get reminderJourney =>
      'നിങ്ങളുടെ പഠന പാത കാത്തിരിക്കുന്നു. അടുത്ത സ്റ്റോപ്പിന് തയ്യാറാണോ?';

  @override
  String get reminderRights =>
      'നിങ്ങളുടെ അവകാശങ്ങൾ അറിയൂ: രണ്ട് മിനിറ്റ് ക്വിസ് നിങ്ങൾക്കായി തയ്യാറാണ്.';

  @override
  String get settingsReminderTime => 'ഓർമ്മപ്പെടുത്തൽ സമയം';

  @override
  String get settingsRemindersBlocked =>
      'Nyaya Kural-യ്ക്ക് അറിയിപ്പുകൾ ഓഫാണ്. ഓർമ്മപ്പെടുത്തലുകൾ ലഭിക്കാൻ ഫോണിന്റെ ക്രമീകരണങ്ങളിൽ അവ ഓണാക്കൂ.';

  @override
  String get settingsStore => 'സ്റ്റോർ';

  @override
  String get settingsStreakFreeze => 'സ്ട്രീക്ക് ഫ്രീസ്';

  @override
  String settingsStreakFreezeSub(int owned, int max) {
    return 'ഒരു ദിവസം വിട്ടുപോയാൽ സ്ട്രീക്ക് സംരക്ഷിക്കും · $owned/$max സജ്ജം';
  }

  @override
  String settingsBuyFor(int coins) {
    return '$coins നാണയങ്ങൾ';
  }

  @override
  String get settingsFreezeBought => 'സ്ട്രീക്ക് ഫ്രീസ് സജ്ജമാക്കി!';

  @override
  String get settingsFreezeFull => 'നിങ്ങൾക്ക് പരമാവധി ഫ്രീസുകൾ ഇതിനകം ഉണ്ട്.';

  @override
  String get settingsPremium => 'Nyaya Kural Premium';

  @override
  String get settingsPremiumActive => 'Premium സജീവം';

  @override
  String get settingsPremiumUpgrade => 'Premium-ലേക്ക് മാറുക';

  @override
  String get settingsStats => 'നിങ്ങളുടെ കണക്കുകൾ';

  @override
  String get settingsTotalXp => 'ആകെ XP';

  @override
  String get settingsLongestStreak => 'ഏറ്റവും നീണ്ട സ്ട്രീക്ക്';

  @override
  String get settingsQuizzes => 'ക്വിസുകൾ';

  @override
  String get settingsAccuracy => 'കൃത്യത';

  @override
  String get settingsDuelRecord => 'വിജയങ്ങൾ';

  @override
  String get settingsAbout => 'കുറിച്ച്';

  @override
  String get settingsDisclaimer => 'നിയമപരമായ നിരാകരണം';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya Kural ഒരു വിദ്യാഭ്യാസ ആപ്പാണ്. ചോദ്യങ്ങൾ, വിശദീകരണങ്ങൾ, വാർത്തകൾ, AI ഉത്തരങ്ങൾ എന്നിവ പൊതുവായ വിവരങ്ങൾ മാത്രമാണ്, നിയമോപദേശമല്ല. നിയമങ്ങൾ മാറാം — എപ്പോഴും ഔദ്യോഗിക ഗസറ്റ് പരിശോധിക്കുക അല്ലെങ്കിൽ ഒരു അഭിഭാഷകനെ സമീപിക്കുക.';

  @override
  String get settingsPrivacy => 'സ്വകാര്യത';

  @override
  String get settingsPrivacyBody =>
      'നിങ്ങളുടെ പുരോഗതി നിങ്ങളുടെ അക്കൗണ്ടിൽ സൂക്ഷിക്കുന്നു, ഒപ്പം നിങ്ങൾ ആപ്പ് തുറക്കുന്ന ദിവസങ്ങളും, ആളുകൾ തിരികെ വരുന്നുണ്ടോ എന്ന് ഞങ്ങൾക്ക് അറിയാൻ. നിങ്ങൾ AI-യോട് ചോദിക്കുന്ന ചോദ്യങ്ങൾ ഉത്തരം എഴുതാൻ മാത്രം ഞങ്ങളുടെ AI ദാതാവിന് അയയ്ക്കുന്നു. ആപ്പ് ക്രാഷ് ആയാൽ, അത് പരിഹരിക്കാൻ സഹായിക്കുന്ന ഒരു ചെറിയ സാങ്കേതിക റിപ്പോർട്ട് (നിങ്ങളുടെ ഉത്തരങ്ങളോ വ്യക്തിഗത വിവരങ്ങളോ ഇല്ലാതെ) അയയ്ക്കുന്നു. ക്രമീകരണങ്ങളിൽ നിങ്ങളുടെ അക്കൗണ്ട് ഇല്ലാതാക്കാം.';

  @override
  String settingsVersion(String version) {
    return 'പതിപ്പ് $version';
  }

  @override
  String get settingsReset => 'ഈ ഫോൺ റീസെറ്റ് ചെയ്യുക';

  @override
  String get settingsResetConfirm =>
      'ഇത് സ്വാഗത ഘട്ടങ്ങൾ വീണ്ടും കാണിക്കുകയും ഈ ഫോണിലെ ക്രമീകരണങ്ങൾ മായ്ക്കുകയും ചെയ്യും. നിങ്ങളുടെ XP, നക്ഷത്രങ്ങൾ, നാണയങ്ങൾ, സ്ട്രീക്ക് എന്നിവ നിങ്ങളുടെ അക്കൗണ്ടിൽ സുരക്ഷിതമായിരിക്കും.';

  @override
  String get settingsResetAction => 'റീസെറ്റ് ചെയ്യുക';

  @override
  String get premiumTitle => 'Nyaya Kural Premium';

  @override
  String get premiumHeadline => 'ദിവസവും കൂടുതൽ പഠിക്കൂ';

  @override
  String get premiumBenefitEnergy => 'പരിധിയില്ലാത്ത എനർജി';

  @override
  String premiumBenefitEnergySub(int free) {
    return 'സൗജന്യം: ദിവസം $free എനർജി. Premium: ഇഷ്ടമുള്ളത്ര ക്വിസുകൾ കളിക്കൂ.';
  }

  @override
  String get premiumBenefitAi => 'കൂടുതൽ Nyaya Kural AI';

  @override
  String premiumBenefitAiSub(int free, int premium) {
    return 'സൗജന്യം: ദിവസം $free ചോദ്യങ്ങൾ. Premium: ദിവസം $premium.';
  }

  @override
  String get premiumFair =>
      'ന്യായമായ കളി: Premium ഒരിക്കലും ലീഗ് XP കൂട്ടില്ല.';

  @override
  String get premiumYearly => 'വാർഷികം';

  @override
  String get premiumMonthly => 'പ്രതിമാസം';

  @override
  String get premiumYearlyPrice => '₹999 / വർഷം';

  @override
  String get premiumMonthlyPrice => '₹149 / മാസം';

  @override
  String get premiumPerMonth => 'മാസം വെറും ₹83';

  @override
  String get premiumSave => '44% ലാഭിക്കൂ';

  @override
  String get premiumBestValue => 'മികച്ച മൂല്യം';

  @override
  String get premiumStartTrial => '7 ദിവസത്തെ സൗജന്യ ട്രയൽ തുടങ്ങൂ';

  @override
  String get premiumTrialNote =>
      'ട്രയൽ കഴിയുന്നതിന് മുമ്പ് എപ്പോൾ വേണമെങ്കിലും റദ്ദാക്കാം, പണം ഈടാക്കില്ല.';

  @override
  String get premiumRestore => 'വാങ്ങലുകൾ വീണ്ടെടുക്കുക';

  @override
  String get premiumActivated => 'Nyaya Kural Premium-ലേക്ക് സ്വാഗതം!';

  @override
  String get premiumAlready => 'നിങ്ങൾ ഒരു Premium അംഗമാണ്';

  @override
  String get premiumNothingToRestore => 'മുൻ വാങ്ങലുകളൊന്നും കണ്ടെത്തിയില്ല.';

  @override
  String get statXp => 'XP';

  @override
  String get statStreak => 'സ്ട്രീക്ക്';

  @override
  String get statCoins => 'നാണയങ്ങൾ';

  @override
  String get statEnergy => 'എനർജി';

  @override
  String get statStars => 'നക്ഷത്രങ്ങൾ';

  @override
  String get searchTitle => 'തിരയുക';

  @override
  String get searchHint => 'നിയമങ്ങൾ, വിഷയങ്ങൾ, അപ്ഡേറ്റുകൾ തിരയുക';

  @override
  String get searchTopics => 'വിഷയങ്ങൾ';

  @override
  String get searchLaws => 'നിയമങ്ങൾ';

  @override
  String get searchUpdates => 'അപ്ഡേറ്റുകൾ';

  @override
  String searchAskAi(String query) {
    return 'AI-യോട് ചോദിക്കൂ: “$query”';
  }

  @override
  String searchNoResults(String query) {
    return '“$query” എന്നതിന് ഇതുവരെ ഒന്നും ചേരുന്നില്ല. AI-യോട് ചോദിക്കൂ.';
  }

  @override
  String get exploreTitle => 'നിയമം അറിയാം';

  @override
  String get exploreSubtitle =>
      'ഇന്ത്യൻ നിയമത്തെക്കുറിച്ചുള്ള നിങ്ങളുടെ ധാരണ വളർത്തൂ';

  @override
  String get exploreStartHere => 'ഇവിടെ തുടങ്ങൂ';

  @override
  String get exploreFeatured => 'പ്രത്യേകം';

  @override
  String get exploreButton => 'കാണുക';

  @override
  String get exploreCoreLaws => 'പ്രധാന നിയമങ്ങൾ';

  @override
  String get exploreViewAll => 'എല്ലാം കാണുക';

  @override
  String get exploreLegacy => 'പഴയ നിയമങ്ങൾ';

  @override
  String get exploreAskAi => 'AI-യോട് ചോദിക്കൂ';

  @override
  String exploreAskPrompt(String law) {
    return '$law ലളിതമായി വിശദീകരിക്കൂ: അതിൽ എന്തെല്ലാം ഉൾപ്പെടുന്നു, ഞാൻ അറിയേണ്ട പ്രധാന വ്യവസ്ഥകൾ ഏതെല്ലാം.';
  }

  @override
  String get lawConstitutionTitle => 'ഇന്ത്യൻ ഭരണഘടന';

  @override
  String get lawConstitutionDesc =>
      'മൗലികാവകാശങ്ങൾ, നിർദ്ദേശക തത്വങ്ങൾ, കടമകൾ എന്നിവയും മറ്റും.';

  @override
  String get lawBnsTitle => 'ഭാരതീയ ന്യായ സംഹിത (BNS)';

  @override
  String get lawBnsShort => 'ഭാരതീയ ന്യായ സംഹിത';

  @override
  String get lawBnsDesc => 'കുറ്റകൃത്യങ്ങളെക്കുറിച്ചുള്ള അടിസ്ഥാന നിയമം';

  @override
  String get lawBnsFeatured =>
      'ഇന്ത്യയുടെ പുതിയ ക്രിമിനൽ നിയമത്തിലെ കുറ്റങ്ങളും ശിക്ഷകളും.';

  @override
  String get lawBnssTitle => 'ഭാരതീയ നാഗരിക സുരക്ഷാ സംഹിത (BNSS)';

  @override
  String get lawBnssDesc => 'ക്രിമിനൽ നടപടിക്രമ നിയമം';

  @override
  String get lawBsaTitle => 'ഭാരതീയ സാക്ഷ്യ അധിനിയം (BSA)';

  @override
  String get lawBsaDesc => 'തെളിവ് നിയമം';

  @override
  String get lawEverydayTitle => 'ദൈനംദിന നിയമം';

  @override
  String get lawEverydayDesc => 'നിത്യജീവിതത്തിലെ നിങ്ങളുടെ അവകാശങ്ങൾ അറിയൂ';

  @override
  String get lawEverydayFeatured =>
      'ഉപഭോക്താവ്, വാടക, ജോലിസ്ഥലം, കുടുംബം എന്നിവയിലെ അവകാശങ്ങൾ ലളിതമായി വിശദീകരിക്കുന്നു.';

  @override
  String get lawLegacyTitle => 'IPC & CrPC (പഴയ നിയമങ്ങൾ)';

  @override
  String get lawLegacyDesc =>
      '2024 ജൂലൈയിൽ മാറ്റിസ്ഥാപിച്ചു. റഫറൻസിനും താരതമ്യത്തിനുമായി സൂക്ഷിച്ചിരിക്കുന്നു.';

  @override
  String get chapterConstitutionTitle => 'ഭരണഘടനയുടെ അടിസ്ഥാനങ്ങൾ';

  @override
  String get chapterConstitutionSubtitle =>
      'ആമുഖം, പാർലമെന്റ്, കോടതികൾ, ഭേദഗതികൾ';

  @override
  String get chapterRightsTitle => 'അവകാശങ്ങളും കടമകളും';

  @override
  String get chapterRightsSubtitle =>
      'മൗലികാവകാശങ്ങൾ, നിർദ്ദേശക തത്വങ്ങൾ, റിട്ടുകൾ';

  @override
  String get chapterCriminalTitle => 'ക്രിമിനൽ നിയമം (BNS)';

  @override
  String get chapterCriminalSubtitle => 'പുതിയ സംഹിതയിലെ കുറ്റകൃത്യങ്ങൾ';

  @override
  String get chapterProcedureTitle => 'നടപടിക്രമവും തെളിവും';

  @override
  String get chapterProcedureSubtitle => 'BNSS, BSA, FIR, അറസ്റ്റ്, ജാമ്യം';

  @override
  String get chapterCivilTitle => 'കരാറുകളും ഉപഭോക്താക്കളും';

  @override
  String get chapterCivilSubtitle => 'കരാറുകൾ, ഉപഭോക്തൃ അവകാശങ്ങൾ, പരിഹാരങ്ങൾ';

  @override
  String get chapterEverydayTitle => 'ദൈനംദിന നിയമം';

  @override
  String get chapterEverydaySubtitle => 'നിത്യജീവിതത്തിലെ നിയമം';

  @override
  String get authCreateTitle => 'നിങ്ങളുടെ സൗജന്യ അക്കൗണ്ട് തുടങ്ങൂ';

  @override
  String get authCreateSubtitle =>
      'ചോദ്യങ്ങൾ Nyaya Kural-യുടെ പരിശോധിച്ച ശേഖരത്തിൽ നിന്നാണ്, നിങ്ങളുടെ ഫലങ്ങൾ അക്കൗണ്ടിൽ സൂക്ഷിക്കും.';

  @override
  String get authSignInTitle => 'വീണ്ടും സ്വാഗതം';

  @override
  String get authSignInSubtitle => 'പരിശീലനം തുടരാൻ സൈൻ ഇൻ ചെയ്യുക.';

  @override
  String get authName => 'നിങ്ങളുടെ പേര്';

  @override
  String get authEmail => 'ഇമെയിൽ';

  @override
  String get authPassword => 'പാസ്‌വേഡ്';

  @override
  String get authPasswordHint => 'കുറഞ്ഞത് 8 അക്ഷരങ്ങൾ';

  @override
  String get authCreate => 'അക്കൗണ്ട് ഉണ്ടാക്കുക';

  @override
  String get authSignIn => 'സൈൻ ഇൻ';

  @override
  String get authHaveAccount => 'എനിക്ക് ഇതിനകം അക്കൗണ്ട് ഉണ്ട്';

  @override
  String get authNeedAccount => 'പുതിയതാണോ? അക്കൗണ്ട് ഉണ്ടാക്കൂ';

  @override
  String get authErrorCredentials => 'ഇമെയിൽ അല്ലെങ്കിൽ പാസ്‌വേഡ് തെറ്റാണ്.';

  @override
  String get authErrorEmailTaken =>
      'ഈ ഇമെയിലിൽ ഇതിനകം ഒരു അക്കൗണ്ട് ഉണ്ട്. പകരം സൈൻ ഇൻ ചെയ്യുക.';

  @override
  String get authErrorNetwork =>
      'ഇപ്പോൾ Nyaya Kural-യുമായി ബന്ധപ്പെടാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get authErrorRateLimited =>
      'വളരെയധികം ശ്രമങ്ങൾ. കുറച്ച് മിനിറ്റ് കാത്തിരുന്ന് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get authErrorInvalid =>
      'ശരിയായ ഇമെയിലും കുറഞ്ഞത് 8 അക്ഷരങ്ങളുള്ള പാസ്‌വേഡും നൽകുക.';

  @override
  String get authErrorName => 'നിങ്ങളുടെ പേര് നൽകുക.';

  @override
  String get authForgot => 'പാസ്‌വേഡ് മറന്നോ?';

  @override
  String get authResetTitle => 'പാസ്‌വേഡ് മാറ്റൂ';

  @override
  String get authResetSubtitle =>
      'നിങ്ങളുടെ അക്കൗണ്ടിന്റെ ഇമെയിൽ നൽകൂ. ഞങ്ങൾ 6 അക്ക കോഡ് അയയ്ക്കും.';

  @override
  String get authResetSend => 'കോഡ് അയയ്ക്കൂ';

  @override
  String authResetSentTo(String email) {
    return '$email എന്ന വിലാസത്തിൽ അക്കൗണ്ട് ഉണ്ടെങ്കിൽ, അതിലേക്ക് 6 അക്ക കോഡ് അയച്ചിട്ടുണ്ട്. ഇത് 15 മിനിറ്റ് പ്രവർത്തിക്കും. കാണുന്നില്ലെങ്കിൽ സ്പാം ഫോൾഡർ നോക്കൂ.';
  }

  @override
  String get authResetCode => '6 അക്ക കോഡ്';

  @override
  String get authResetNewPassword => 'പുതിയ പാസ്‌വേഡ്';

  @override
  String get authResetSave => 'പുതിയ പാസ്‌വേഡ് സജ്ജമാക്കൂ';

  @override
  String get authResetResend => 'പുതിയ കോഡ് അയയ്ക്കൂ';

  @override
  String get authResetErrorCode =>
      'ഈ കോഡ് തെറ്റാണ് അല്ലെങ്കിൽ കാലാവധി കഴിഞ്ഞു. പുതിയ കോഡ് ചോദിക്കൂ.';

  @override
  String get authResetUnavailable =>
      'പാസ്‌വേഡ് മാറ്റൽ ഇപ്പോൾ ലഭ്യമല്ല. ദയവായി പിന്നീട് ശ്രമിക്കൂ.';

  @override
  String get authResetErrorInvalid =>
      '6 അക്ക കോഡും കുറഞ്ഞത് 8 അക്ഷരമുള്ള പുതിയ പാസ്‌വേഡും നൽകൂ.';

  @override
  String get authResetDone => 'നിങ്ങളുടെ പാസ്‌വേഡ് മാറ്റി.';

  @override
  String get settingsAccount => 'അക്കൗണ്ട്';

  @override
  String settingsSignedInAs(String email) {
    return '$email ആയി സൈൻ ഇൻ ചെയ്തു';
  }

  @override
  String get settingsSignIn => 'സൈൻ ഇൻ ചെയ്യുക അല്ലെങ്കിൽ അക്കൗണ്ട് ഉണ്ടാക്കുക';

  @override
  String get settingsSignOut => 'സൈൻ ഔട്ട്';

  @override
  String get updateRequiredTitle => 'ദയവായി Nyaya Kural അപ്ഡേറ്റ് ചെയ്യുക';

  @override
  String get updateRequiredBody =>
      'ആപ്പിന്റെ ഈ പതിപ്പ് വളരെ പഴയതാണ്, ഇനി പ്രവർത്തിക്കില്ല. തുടരാൻ അപ്ഡേറ്റ് ചെയ്യുക. നിങ്ങളുടെ പുരോഗതി അക്കൗണ്ടിൽ സൂക്ഷിച്ചിട്ടുണ്ട്, അതിനാൽ ഒന്നും നഷ്ടപ്പെടില്ല.';

  @override
  String get updateRequiredAction => 'അപ്ഡേറ്റ് ചെയ്യുക';

  @override
  String get settingsDeleteAccount => 'അക്കൗണ്ട് ഇല്ലാതാക്കുക';

  @override
  String get settingsDeleteAccountBody =>
      'ഇത് നിങ്ങളുടെ അക്കൗണ്ടും അതിലുള്ള എല്ലാം സ്ഥിരമായി ഇല്ലാതാക്കും: പുരോഗതി, XP, നാണയങ്ങൾ, സേവ് ചെയ്ത ചോദ്യങ്ങൾ, ലീഗ് സ്ഥാനം. ഇത് തിരികെ കൊണ്ടുവരാൻ കഴിയില്ല. സ്ഥിരീകരിക്കാൻ നിങ്ങളുടെ പാസ്‌വേഡ് നൽകുക.';

  @override
  String get settingsDeleteAccountPassword => 'പാസ്‌വേഡ്';

  @override
  String get settingsDeleteAccountAction => 'എന്റെ അക്കൗണ്ട് ഇല്ലാതാക്കുക';

  @override
  String get settingsDeleteAccountWrong => 'ആ പാസ്‌വേഡ് ശരിയല്ല.';

  @override
  String get settingsDeleteAccountFailed =>
      'അക്കൗണ്ട് ഇല്ലാതാക്കാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get quizSendFailed =>
      'നിങ്ങളുടെ ഉത്തരം അയയ്ക്കാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും അമർത്തുക.';

  @override
  String get quizSubmitFailed =>
      'നിങ്ങളുടെ ഫലം ലഭിച്ചില്ല. കണക്ഷൻ പരിശോധിക്കുക.';

  @override
  String get quizRetry => 'വീണ്ടും ശ്രമിക്കുക';

  @override
  String get quizScoring => 'നിങ്ങളുടെ കേസ് സ്കോർ ചെയ്യുന്നു…';

  @override
  String get quizOffline =>
      'Nyaya Kural-യുമായി ബന്ധപ്പെടാനായില്ല. കണക്ഷൻ പരിശോധിച്ച് വീണ്ടും ശ്രമിക്കുക.';

  @override
  String get quizSignedOut =>
      'നിങ്ങളുടെ സെഷൻ അവസാനിച്ചു. കളിക്കാൻ വീണ്ടും സൈൻ ഇൻ ചെയ്യുക.';
}
