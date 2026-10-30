// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malayalam (`ml`).
class AppLocalizationsMl extends AppLocalizations {
  AppLocalizationsMl([String locale = 'ml']) : super(locale);

  @override
  String get appName => 'Nyaya';

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
  String get onbSlide2Title => 'കേസ് പാത കളിക്കൂ';

  @override
  String get onbSlide2Body =>
      'ഓരോ ലെവലും കയറി, നക്ഷത്രങ്ങൾ നേടി, പെട്ടികൾ തുറന്ന് പുതിയ അധ്യായങ്ങൾ തുറക്കൂ.';

  @override
  String get onbSlide3Title => 'ദിവസേനയുള്ള ശീലം വളർത്തൂ';

  @override
  String get onbSlide3Body =>
      'സ്ട്രീക്ക് നിലനിർത്തൂ, ആഴ്ചതോറുമുള്ള കോടതി ലീഗുകളിൽ മുന്നേറൂ, നിയമപരമായ എന്തും ഞങ്ങളുടെ AI-യോട് ചോദിക്കൂ.';

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
  String get onbReadyBody =>
      'നിങ്ങളുടെ ആദ്യ കേസ് കേസ് പാതയിൽ കാത്തിരിക്കുന്നു.';

  @override
  String get greetingMorning => 'സുപ്രഭാതം';

  @override
  String get greetingAfternoon => 'ശുഭ ഉച്ച';

  @override
  String get greetingEvening => 'ശുഭ സന്ധ്യ';

  @override
  String get homeContinueJourney => 'കേസ് പാത തുടരുക';

  @override
  String get homeContinueLeftOff => 'Continue where you left off';

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
  String get homeGoPremiumSub => 'Nyaya Premium · 7 ദിവസം സൗജന്യ ട്രയൽ';

  @override
  String get modeCasePath => 'കേസ് പാത';

  @override
  String get modeCasePathDesc => 'ലെവൽ തോറുമുള്ള യാത്ര';

  @override
  String get modeDailyDocket => 'ഡെയ്‌ലി ഡോക്കറ്റ്';

  @override
  String get modeDailyDocketDesc => '5 ചോദ്യങ്ങൾ · എല്ലാവർക്കും ഒരേത്';

  @override
  String get modeDuel => 'മൂട്ട് കോർട്ട് ഡ്യുവൽ';

  @override
  String get modeDuelDesc => '1v1 · 7 ചോദ്യങ്ങൾ · സമയത്തെ തോൽപ്പിക്കൂ';

  @override
  String get modeExam => 'പരീക്ഷാ ചേംബർ';

  @override
  String get modeExamDesc => '20 ചോദ്യങ്ങൾ · 20 മിനിറ്റ് · നെഗറ്റീവ് മാർക്ക്';

  @override
  String get modeExamDescCitizen =>
      '20 ചോദ്യങ്ങൾ · 20 മിനിറ്റ് · അവകാശങ്ങൾ അറിയൂ';

  @override
  String get modeFree => 'സൗജന്യം';

  @override
  String modeEnergyCost(int count) {
    return '$count ⚡';
  }

  @override
  String get docketDoneToday => 'ഇന്നത്തേത് കഴിഞ്ഞു';

  @override
  String docketNextIn(String time) {
    return 'അടുത്ത ഡോക്കറ്റ് $time-ൽ';
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
    return '$coins നാണയങ്ങൾക്ക് 1 ⚡ നിറയ്ക്കുക';
  }

  @override
  String get energyGoUnlimited => 'പരിധിയില്ലാത്ത എനർജി നേടുക';

  @override
  String get energyFreeOptions => 'ഇപ്പോഴും സൗജന്യമായി ചെയ്യാവുന്നവ';

  @override
  String get energyPlayDocket => 'ഇന്നത്തെ ഡെയ്‌ലി ഡോക്കറ്റ് കളിക്കൂ (സൗജന്യം)';

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
  String get journeyTitle => 'കേസ് പാത';

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
  String get journeyLockedBody => 'ഇത് തുറക്കാൻ മുൻ ലെവൽ പൂർത്തിയാക്കുക.';

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
  String get journeyChestBody =>
      'നിങ്ങൾ അധ്യായം പൂർത്തിയാക്കി! ബോണസ് നാണയങ്ങൾക്കായി പെട്ടി തുറക്കൂ.';

  @override
  String get journeyOpenChest => 'പെട്ടി തുറക്കുക';

  @override
  String journeyChestOpened(int coins) {
    return '+$coins നാണയങ്ങൾ!';
  }

  @override
  String get journeyChestLocked =>
      'പെട്ടി തുറക്കാൻ ഈ അധ്യായത്തിലെ എല്ലാ ലെവലുകളും പൂർത്തിയാക്കുക.';

  @override
  String get journeyJumpToCurrent => 'ഇപ്പോഴത്തെ ലെവലിലേക്ക് പോകുക';

  @override
  String get journeyYou => 'നിങ്ങൾ';

  @override
  String get journeyPassHint =>
      'ജയിക്കാൻ 50% · 2 നക്ഷത്രത്തിന് 80% · 3 നക്ഷത്രത്തിന് 100%';

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
  String get quizQuitBody => 'ഈ ക്വിസിലെ നിങ്ങളുടെ പുരോഗതി നഷ്ടപ്പെടും.';

  @override
  String get quizQuitBodyRefund =>
      'നിങ്ങൾ ഇതുവരെ ഉത്തരം നൽകിയിട്ടില്ല, അതിനാൽ എനർജി തിരികെ ലഭിക്കും.';

  @override
  String get quizQuitStay => 'കളി തുടരുക';

  @override
  String get quizQuitLeave => 'ഉപേക്ഷിക്കുക';

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
    return '3 നക്ഷത്ര ബോണസ്: +$count ⚡';
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
  String get leaderboardPractice => 'Practice player';

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
  String get chatTitle => 'Nyaya AI';

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
      'ഇന്നത്തെ സൗജന്യ ചോദ്യങ്ങൾ തീർന്നു. നാളെ വരൂ, അല്ലെങ്കിൽ പരിധിയില്ലാത്ത AI-ക്ക് Premium എടുക്കൂ.';

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
  String get updatesEmpty => 'ഈ വിഭാഗത്തിൽ ഇതുവരെ വാർത്തകളില്ല.';

  @override
  String get updatesSave => 'Save update';

  @override
  String get updatesUnsave => 'Remove from saved';

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
  String get settingsPremium => 'Nyaya Premium';

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
  String get settingsDuelRecord => 'ജയിച്ച ഡ്യുവലുകൾ';

  @override
  String get settingsAbout => 'കുറിച്ച്';

  @override
  String get settingsDisclaimer => 'നിയമപരമായ നിരാകരണം';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya ഒരു വിദ്യാഭ്യാസ ആപ്പാണ്. ചോദ്യങ്ങൾ, വിശദീകരണങ്ങൾ, വാർത്തകൾ, AI ഉത്തരങ്ങൾ എന്നിവ പൊതുവായ വിവരങ്ങൾ മാത്രമാണ്, നിയമോപദേശമല്ല. നിയമങ്ങൾ മാറാം — എപ്പോഴും ഔദ്യോഗിക ഗസറ്റ് പരിശോധിക്കുക അല്ലെങ്കിൽ ഒരു അഭിഭാഷകനെ സമീപിക്കുക.';

  @override
  String get settingsPrivacy => 'സ്വകാര്യത';

  @override
  String get settingsPrivacyBody =>
      'നിങ്ങളുടെ പുരോഗതി ഈ ഉപകരണത്തിൽ സൂക്ഷിക്കുന്നു. ഉത്തരങ്ങൾ തയ്യാറാക്കാൻ മാത്രമായി AI ചോദ്യങ്ങൾ ഞങ്ങളുടെ AI ദാതാവിന് അയയ്ക്കുന്നു.';

  @override
  String settingsVersion(String version) {
    return 'പതിപ്പ് $version';
  }

  @override
  String get settingsReset => 'പുരോഗതി പുനഃസജ്ജമാക്കുക';

  @override
  String get settingsResetConfirm =>
      'ഈ ഉപകരണത്തിലെ എല്ലാ XP, നക്ഷത്രങ്ങൾ, സ്ട്രീക്കുകൾ, നാണയങ്ങൾ എന്നിവ മായ്ക്കും. ഇത് പഴയപടിയാക്കാനാവില്ല.';

  @override
  String get settingsResetAction => 'എല്ലാം മായ്ക്കുക';

  @override
  String get premiumTitle => 'Nyaya Premium';

  @override
  String get premiumHeadline => 'പരിധികളില്ലാതെ പഠിക്കൂ';

  @override
  String get premiumBenefitEnergy => 'പരിധിയില്ലാത്ത എനർജി';

  @override
  String get premiumBenefitEnergySub => 'ഇഷ്ടമുള്ളത്ര ക്വിസുകൾ കളിക്കൂ';

  @override
  String get premiumBenefitAi => 'പരിധിയില്ലാത്ത Nyaya AI';

  @override
  String get premiumBenefitAiSub => 'നിങ്ങളുടെ എല്ലാ നിയമ ചോദ്യങ്ങളും ചോദിക്കൂ';

  @override
  String get premiumBenefitFreeze => 'സ്ട്രീക്ക് ഫ്രീസുകൾ ഉൾപ്പെടെ';

  @override
  String get premiumBenefitFreezeSub =>
      'തിരക്കുള്ള ദിവസം കാരണം സ്ട്രീക്ക് നഷ്ടപ്പെടില്ല';

  @override
  String get premiumBenefitExam => 'പൂർണ്ണ മോക്ക് പരീക്ഷകൾ';

  @override
  String get premiumBenefitExamSub =>
      'CLAT, AIBE & ജുഡീഷ്യറി മാതൃകയിലുള്ള പരിശീലനം';

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
  String get premiumActivated => 'Nyaya Premium-ലേക്ക് സ്വാഗതം!';

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
