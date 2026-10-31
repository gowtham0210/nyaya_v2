// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kannada (`kn`).
class AppLocalizationsKn extends AppLocalizations {
  AppLocalizationsKn([String locale = 'kn']) : super(locale);

  @override
  String get appName => 'Nyaya';

  @override
  String get appTagline => 'ದಿನಕ್ಕೊಂದು ಪ್ರಕರಣ, ಭಾರತೀಯ ಕಾನೂನು ಕಲಿಯಿರಿ';

  @override
  String get navHome => 'ಮುಖಪುಟ';

  @override
  String get navJourney => 'ಪಯಣ';

  @override
  String get navAskAi => 'AI ಕೇಳಿ';

  @override
  String get navUpdates => 'ಸುದ್ದಿಗಳು';

  @override
  String get commonContinue => 'ಮುಂದುವರಿಸಿ';

  @override
  String get reviewTitle => 'ಪರಿಶೀಲನೆ';

  @override
  String get reviewMistakesTab => 'ತಪ್ಪುಗಳು';

  @override
  String get reviewSavedTab => 'ಉಳಿಸಿದವು';

  @override
  String get reviewPractise => 'ತಪ್ಪುಗಳನ್ನು ಅಭ್ಯಾಸ ಮಾಡಿ';

  @override
  String get reviewPractiseFree => 'ಉಚಿತ · ಗರಿಷ್ಠ 10 ಪ್ರಶ್ನೆಗಳು · XP ಗಳಿಸಿ';

  @override
  String get reviewEmptyMistakes =>
      'ಪರಿಶೀಲಿಸಲು ತಪ್ಪುಗಳಿಲ್ಲ. ನೀವು ತಪ್ಪಾಗಿ ಉತ್ತರಿಸಿದ ಪ್ರಶ್ನೆಗಳು, ಸರಿಯಾಗಿ ಉತ್ತರಿಸುವವರೆಗೆ ಇಲ್ಲಿ ಕಾಣಿಸುತ್ತವೆ.';

  @override
  String get reviewEmptySaved =>
      'ಇನ್ನೂ ಏನೂ ಉಳಿಸಿಲ್ಲ. ಪ್ರಶ್ನೆಗೆ ಉತ್ತರಿಸಿದ ನಂತರ ‘ಉಳಿಸಿ’ ಒತ್ತಿದರೆ ಅದು ಇಲ್ಲಿ ಇರುತ್ತದೆ.';

  @override
  String get reviewSignIn =>
      'ನಿಮ್ಮ ತಪ್ಪುಗಳು ಮತ್ತು ಉಳಿಸಿದ ಪ್ರಶ್ನೆಗಳನ್ನು ನೋಡಲು ಸೈನ್ ಇನ್ ಮಾಡಿ.';

  @override
  String reviewWrongTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ಬಾರಿ ತಪ್ಪಾಗಿದೆ',
      one: 'ಒಮ್ಮೆ ತಪ್ಪಾಗಿದೆ',
    );
    return '$_temp0';
  }

  @override
  String get reviewUpdatedSince =>
      'ನೀವು ಉತ್ತರಿಸಿದ ನಂತರ ಇದನ್ನು ಬದಲಾಯಿಸಲಾಗಿದೆ. ನೀವು ನೋಡಿದಂತೆಯೇ ತೋರಿಸಲಾಗಿದೆ.';

  @override
  String get reviewUnavailable => 'ಈ ಪ್ರಶ್ನೆ ಈಗ ಲಭ್ಯವಿಲ್ಲ.';

  @override
  String reviewCardBody(int mistakes, int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      mistakes,
      locale: localeName,
      other: '$mistakes ತಪ್ಪುಗಳು',
      one: '1 ತಪ್ಪು',
    );
    return '$_temp0 · $saved ಉಳಿಸಿದವು';
  }

  @override
  String get questionSave => 'ಉಳಿಸಿ';

  @override
  String get questionSaved => 'ಉಳಿಸಲಾಗಿದೆ';

  @override
  String get questionReport => 'ವರದಿ ಮಾಡಿ';

  @override
  String get questionSaveFailed =>
      'ಉಳಿಸಲು ಆಗಲಿಲ್ಲ. ನಿಮ್ಮ ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get reportTitle => 'ಸಮಸ್ಯೆಯನ್ನು ವರದಿ ಮಾಡಿ';

  @override
  String get reportReasonWrongAnswer => 'ಉತ್ತರ ತಪ್ಪಾಗಿದೆ';

  @override
  String get reportReasonUnclear => 'ಪ್ರಶ್ನೆ ಸ್ಪಷ್ಟವಾಗಿಲ್ಲ';

  @override
  String get reportReasonOutdatedLaw => 'ಕಾನೂನು ಬದಲಾಗಿದೆ';

  @override
  String get reportReasonTypo => 'ಕಾಗುಣಿತ ಅಥವಾ ಪದಬಳಕೆ ತಪ್ಪು';

  @override
  String get reportReasonOther => 'ಬೇರೆ ಏನೋ';

  @override
  String get reportComment => 'ಇನ್ನೇನಾದರೂ ಇದೆಯೇ? (ಐಚ್ಛಿಕ)';

  @override
  String get reportSend => 'ವರದಿ ಕಳುಹಿಸಿ';

  @override
  String get reportSent =>
      'ಧನ್ಯವಾದಗಳು. ನಮ್ಮ ಕಾನೂನು ತಂಡ ಈ ಪ್ರಶ್ನೆಯನ್ನು ಪರಿಶೀಲಿಸುತ್ತದೆ.';

  @override
  String get reportAlready => 'ನೀವು ಈ ಪ್ರಶ್ನೆಯನ್ನು ಈಗಾಗಲೇ ವರದಿ ಮಾಡಿದ್ದೀರಿ.';

  @override
  String get reportLimit =>
      'ನೀವು ಇಂದು ಹಲವು ವರದಿಗಳನ್ನು ಕಳುಹಿಸಿದ್ದೀರಿ. ದಯವಿಟ್ಟು ನಾಳೆ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get commonBack => 'ಹಿಂದೆ';

  @override
  String get commonNext => 'ಮುಂದೆ';

  @override
  String get commonSkip => 'ಬಿಟ್ಟುಬಿಡಿ';

  @override
  String get commonCancel => 'ರದ್ದುಮಾಡಿ';

  @override
  String get commonClose => 'ಮುಚ್ಚಿ';

  @override
  String get commonStart => 'ಪ್ರಾರಂಭಿಸಿ';

  @override
  String get commonRetry => 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ';

  @override
  String get commonDone => 'ಮುಗಿದಿದೆ';

  @override
  String get commonSeeAll => 'ಎಲ್ಲಾ ನೋಡಿ';

  @override
  String get commonLater => 'ನಂತರ';

  @override
  String get commonOk => 'ಸರಿ';

  @override
  String get commonComingSoon => 'ಶೀಘ್ರದಲ್ಲೇ ಬರಲಿದೆ';

  @override
  String get commonSomethingWrong =>
      'ಏನೋ ತಪ್ಪಾಗಿದೆ. ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get onbChooseLanguage => 'ನಿಮ್ಮ ಭಾಷೆಯನ್ನು ಆಯ್ಕೆಮಾಡಿ';

  @override
  String get onbChooseLanguageSub =>
      'ಇದನ್ನು ಸೆಟ್ಟಿಂಗ್ಸ್‌ನಲ್ಲಿ ಯಾವಾಗ ಬೇಕಾದರೂ ಬದಲಾಯಿಸಬಹುದು.';

  @override
  String get onbSlide1Title => 'ಕಾನೂನು, ಸರಳವಾಗಿ';

  @override
  String get onbSlide1Body =>
      'ಸಂವಿಧಾನ, BNS, BNSS ಮತ್ತು ನೀವು ದಿನನಿತ್ಯ ಎದುರಿಸುವ ಕಾನೂನುಗಳ ಬಗ್ಗೆ ಚಿಕ್ಕ ಚಿಕ್ಕ ರಸಪ್ರಶ್ನೆಗಳು.';

  @override
  String get onbSlide2Title => 'ಕೇಸ್ ಪಾತ್ ಆಡಿ';

  @override
  String get onbSlide2Body =>
      'ಹಂತ ಹಂತವಾಗಿ ಏರಿ, ನಕ್ಷತ್ರಗಳನ್ನು ಗಳಿಸಿ, ಪೆಟ್ಟಿಗೆಗಳನ್ನು ತೆರೆಯಿರಿ ಮತ್ತು ಹೊಸ ಅಧ್ಯಾಯಗಳನ್ನು ಅನ್‌ಲಾಕ್ ಮಾಡಿ.';

  @override
  String get onbSlide3Title => 'ದೈನಂದಿನ ಅಭ್ಯಾಸ ಬೆಳೆಸಿ';

  @override
  String get onbSlide3Body =>
      'ನಿಮ್ಮ ಸ್ಟ್ರೀಕ್ ಉಳಿಸಿಕೊಳ್ಳಿ, ವಾರದ ನ್ಯಾಯಾಲಯ ಲೀಗ್‌ಗಳಲ್ಲಿ ಮೇಲೇರಿ ಮತ್ತು ಕಾನೂನಿನ ಬಗ್ಗೆ ಏನನ್ನಾದರೂ ನಮ್ಮ AI ಗೆ ಕೇಳಿ.';

  @override
  String get onbSkip => 'ಬಿಟ್ಟುಬಿಡಿ';

  @override
  String get onbGetStarted => 'ಪ್ರಾರಂಭಿಸಿ';

  @override
  String get onbBrandTagline => 'ಕಾನೂನು ಕಲಿಯಿರಿ. ಬದುಕಿನಲ್ಲಿ ಬಳಸಿ.';

  @override
  String get onbIntro1Title => 'ಭಾರತೀಯ ಕಾನೂನಿಗೆ ನಿಮ್ಮ ಮಾರ್ಗದರ್ಶಿ';

  @override
  String get onbIntro1Body =>
      'ಸ್ಪಷ್ಟವಾಗಿ ಕಲಿಯಿರಿ, ಉದ್ದೇಶದಿಂದ ಅಭ್ಯಾಸ ಮಾಡಿ, ನಿಮ್ಮ ದೈನಂದಿನ ಜೀವನವನ್ನು ರೂಪಿಸುವ ಕಾನೂನನ್ನು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಿ.';

  @override
  String get onbIntro2Label => 'ಕ್ರಮಬದ್ಧ ಕಲಿಕೆ';

  @override
  String get onbIntro2Title => 'ನಿಮ್ಮ ವೇಗದಲ್ಲಿ ಕಲಿಯಿರಿ';

  @override
  String get onbIntro2Body =>
      'ಸಂವಿಧಾನ, BNS, BNSS, BSA ಮತ್ತು ಇನ್ನಷ್ಟನ್ನು ಹಂತಹಂತದ ಪಾಠಗಳು, ಟಿಪ್ಪಣಿಗಳು ಮತ್ತು ನಿಜ ಜೀವನದ ಉದಾಹರಣೆಗಳೊಂದಿಗೆ ತಿಳಿಯಿರಿ.';

  @override
  String get onbIntro3Label => 'ಅಭ್ಯಾಸ ಮತ್ತು ಬಳಕೆ';

  @override
  String get onbIntro3Title => 'ನಿಜವಾದ ತಿಳುವಳಿಕೆ ಬೆಳೆಸಿ';

  @override
  String get onbIntro3Body =>
      'ರಸಪ್ರಶ್ನೆಗಳಲ್ಲಿ ನಿಮ್ಮ ಜ್ಞಾನ ಪರೀಕ್ಷಿಸಿ, ಇತ್ತೀಚಿನ ಕಾನೂನು ಸುದ್ದಿಗಳನ್ನು ಓದಿ, ಕಾನೂನು ನಿಜ ಜೀವನದಲ್ಲಿ ಹೇಗೆ ಅನ್ವಯಿಸುತ್ತದೆ ಎಂದು ನೋಡಿ.';

  @override
  String get onbDemoChapter => 'ಮೂಲಭೂತ ಹಕ್ಕುಗಳು';

  @override
  String get onbDemoChapterSub => 'ಭಾರತದ ಸಂವಿಧಾನ · ಅಧ್ಯಾಯ 3';

  @override
  String get onbDemoProgress => '8 ಪಾಠಗಳಲ್ಲಿ 5 ಪೂರ್ಣ';

  @override
  String get onbDemoContinue => 'ಕಲಿಕೆ ಮುಂದುವರಿಸಿ';

  @override
  String get onbDemoLesson1 => 'ಪರಿಚಯ';

  @override
  String get onbDemoLesson2 => 'ಸಮಾನತೆಯ ಹಕ್ಕು';

  @override
  String get onbDemoLesson3 => 'ಸ್ವಾತಂತ್ರ್ಯದ ಹಕ್ಕು';

  @override
  String get onbDemoLesson4 => 'ಶೋಷಣೆ ವಿರುದ್ಧದ ಹಕ್ಕು';

  @override
  String get onbDemoQuiz => 'ದೈನಂದಿನ ರಸಪ್ರಶ್ನೆ';

  @override
  String get onbDemoQuizSub => '5 ಚಟುವಟಿಕೆಗಳಲ್ಲಿ 3';

  @override
  String get onbDemoUpdates => 'ಕಾನೂನು ಸುದ್ದಿಗಳು';

  @override
  String get onbDemoUpdatesSub =>
      'ಮುಖ್ಯ ತೀರ್ಪುಗಳು ಮತ್ತು ಬೆಳವಣಿಗೆಗಳ ಬಗ್ಗೆ ತಿಳಿದಿರಿ.';

  @override
  String get onbDemoScenarios => 'ನಿಜ ಜೀವನದ ಸನ್ನಿವೇಶಗಳು';

  @override
  String get onbDemoScenariosSub =>
      'ಕಾನೂನು ದಿನನಿತ್ಯದ ಜೀವನದಲ್ಲಿ ಹೇಗೆ ಕೆಲಸ ಮಾಡುತ್ತದೆ ಎಂದು ಅರ್ಥಮಾಡಿಕೊಳ್ಳಿ.';

  @override
  String get onbWhoAreYou => 'ನೀವು ಯಾರಾಗಿ ಕಲಿಯುತ್ತಿದ್ದೀರಿ?';

  @override
  String get onbWhoAreYouSub =>
      'ನಿಮಗೆ ತಕ್ಕಂತೆ ಕಠಿಣತೆ ಮತ್ತು ಸಲಹೆಗಳನ್ನು ಹೊಂದಿಸುತ್ತೇವೆ.';

  @override
  String get personaAdvocate => 'ವಕೀಲರು';

  @override
  String get personaAdvocateDesc =>
      'ನೆನಪನ್ನು ಚುರುಕುಗೊಳಿಸುತ್ತಿರುವ ವೃತ್ತಿನಿರತ ವಕೀಲರು';

  @override
  String get personaAspirant => 'ಕಾನೂನು ಆಕಾಂಕ್ಷಿ';

  @override
  String get personaAspirantDesc => 'CLAT, AIBE ಅಥವಾ ನ್ಯಾಯಾಂಗ ಪರೀಕ್ಷೆ ತಯಾರಿ';

  @override
  String get personaCitizen => 'ನಾಗರಿಕ';

  @override
  String get personaCitizenDesc =>
      'ನಿಮ್ಮ ಹಕ್ಕುಗಳು ಮತ್ತು ದೈನಂದಿನ ಕಾನೂನು ತಿಳಿಯಿರಿ';

  @override
  String get onbDailyGoal => 'ದೈನಂದಿನ ಗುರಿ ಆಯ್ಕೆಮಾಡಿ';

  @override
  String get onbDailyGoalSub =>
      'ಗುರಿ ಇಟ್ಟುಕೊಳ್ಳುವವರು ಕಲಿಕೆಯನ್ನು ಮುಂದುವರಿಸುವ ಸಾಧ್ಯತೆ ಹೆಚ್ಚು.';

  @override
  String get goalCasual => 'ಸಾಧಾರಣ';

  @override
  String get goalRegular => 'ನಿಯಮಿತ';

  @override
  String get goalSerious => 'ಗಂಭೀರ';

  @override
  String goalQuizzesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ದಿನಕ್ಕೆ $count ರಸಪ್ರಶ್ನೆಗಳು',
      one: 'ದಿನಕ್ಕೆ 1 ರಸಪ್ರಶ್ನೆ',
    );
    return '$_temp0';
  }

  @override
  String get onbYourName => 'ನಿಮ್ಮನ್ನು ಏನೆಂದು ಕರೆಯಲಿ?';

  @override
  String get onbYourNameSub => 'ಲೀಡರ್‌ಬೋರ್ಡ್‌ನಲ್ಲಿ ತೋರಿಸಲಾಗುತ್ತದೆ.';

  @override
  String get onbNameHint => 'ನಿಮ್ಮ ಹೆಸರು';

  @override
  String get onbCommit => 'ನನ್ನ ಗುರಿಗೆ ಬದ್ಧನಾಗಿದ್ದೇನೆ';

  @override
  String onbReadyTitle(String name) {
    return 'ಎಲ್ಲವೂ ಸಿದ್ಧ, $name!';
  }

  @override
  String get onbReadyBody => 'ನಿಮ್ಮ ಮೊದಲ ಪ್ರಕರಣ ಕೇಸ್ ಪಾತ್‌ನಲ್ಲಿ ಕಾಯುತ್ತಿದೆ.';

  @override
  String get greetingMorning => 'ಶುಭೋದಯ';

  @override
  String get greetingAfternoon => 'ಶುಭ ಮಧ್ಯಾಹ್ನ';

  @override
  String get greetingEvening => 'ಶುಭ ಸಂಜೆ';

  @override
  String get homeContinueJourney => 'ನಿಮ್ಮ ಕೇಸ್ ಪಾತ್ ಮುಂದುವರಿಸಿ';

  @override
  String get homeContinueLeftOff => 'ನಿಲ್ಲಿಸಿದ ಜಾಗದಿಂದ ಮುಂದುವರಿಸಿ';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'ಅಧ್ಯಾಯ $chapter · ಹಂತ $level';
  }

  @override
  String get homeChestReady => 'ನಿಮಗಾಗಿ ಒಂದು ಪೆಟ್ಟಿಗೆ ಕಾಯುತ್ತಿದೆ!';

  @override
  String get homeAllDone =>
      'ನೀವು ಎಲ್ಲಾ ಅಧ್ಯಾಯಗಳನ್ನು ಮುಗಿಸಿದ್ದೀರಿ. ಹೊಸ ಅಧ್ಯಾಯಗಳು ಶೀಘ್ರದಲ್ಲೇ ಬರಲಿವೆ!';

  @override
  String get homePlay => 'ಆಡಿ';

  @override
  String get homeDailyGoal => 'ದೈನಂದಿನ ಗುರಿ';

  @override
  String homeGoalProgress(int done, int goal) {
    return '$goal ರಲ್ಲಿ $done ರಸಪ್ರಶ್ನೆಗಳು';
  }

  @override
  String get homeGoalDone => 'ಗುರಿ ಪೂರ್ಣ — ಅದ್ಭುತ ಕೆಲಸ!';

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ದಿನಗಳ ಸ್ಟ್ರೀಕ್',
      one: '1 ದಿನದ ಸ್ಟ್ರೀಕ್',
      zero: 'ಇಂದೇ ಸ್ಟ್ರೀಕ್ ಆರಂಭಿಸಿ',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakAtRisk =>
      'ನಿಮ್ಮ ಸ್ಟ್ರೀಕ್ ಉಳಿಸಲು ಇಂದು ಒಂದು ರಸಪ್ರಶ್ನೆ ಆಡಿ!';

  @override
  String get homeStreakSafe => 'ಇಂದಿನ ಸ್ಟ್ರೀಕ್ ಸುರಕ್ಷಿತ';

  @override
  String get homeModesTitle => 'ರಸಪ್ರಶ್ನೆ ವಿಧಗಳು';

  @override
  String get homeLeagueTitle => 'ಈ ವಾರದ ಲೀಗ್';

  @override
  String homeLeagueRank(int rank, String tier) {
    return '$tier ನಲ್ಲಿ ನೀವು #$rank';
  }

  @override
  String homeLeagueEnds(String time) {
    return '$time ರಲ್ಲಿ ಮುಕ್ತಾಯ';
  }

  @override
  String get homeFactTitle => 'ಇಂದಿನ ಕಾನೂನು ಸಂಗತಿ';

  @override
  String get homeUpdatesTitle => 'ಇತ್ತೀಚಿನ ಕಾನೂನು ಸುದ್ದಿಗಳು';

  @override
  String get homeGoPremium => 'ಅಮಿತ ಶಕ್ತಿ ಅನ್‌ಲಾಕ್ ಮಾಡಿ';

  @override
  String get homeGoPremiumSub => 'Nyaya ಪ್ರೀಮಿಯಂ · 7 ದಿನಗಳ ಉಚಿತ ಪ್ರಯೋಗ';

  @override
  String get modeCasePath => 'ಕೇಸ್ ಪಾತ್';

  @override
  String get modeCasePathDesc => 'ಹಂತ ಹಂತದ ಪಯಣ';

  @override
  String get modeDailyDocket => 'ದೈನಂದಿನ ಡಾಕೆಟ್';

  @override
  String get modeDailyDocketDesc => '5 ಪ್ರಶ್ನೆಗಳು · ಎಲ್ಲರಿಗೂ ಒಂದೇ';

  @override
  String get modeDuel => 'ಮೂಟ್ ಕೋರ್ಟ್ ಸವಾಲು';

  @override
  String get modeDuelDesc => '1v1 · 7 ಪ್ರಶ್ನೆಗಳು · ಸಮಯವನ್ನು ಸೋಲಿಸಿ';

  @override
  String get modeExam => 'ಪರೀಕ್ಷಾ ಕೊಠಡಿ';

  @override
  String get modeExamDesc => '20 ಪ್ರಶ್ನೆಗಳು · 20 ನಿಮಿಷ · ಋಣಾತ್ಮಕ ಅಂಕ';

  @override
  String get modeExamDescCitizen =>
      '20 ಪ್ರಶ್ನೆಗಳು · 20 ನಿಮಿಷ · ನಿಮ್ಮ ಹಕ್ಕುಗಳನ್ನು ತಿಳಿಯಿರಿ';

  @override
  String get modeFree => 'ಉಚಿತ';

  @override
  String modeEnergyCost(int count) {
    return '$count ⚡';
  }

  @override
  String get docketDoneToday => 'ಇಂದಿಗೆ ಮುಗಿದಿದೆ';

  @override
  String docketNextIn(String time) {
    return 'ಮುಂದಿನ ಡಾಕೆಟ್ $time ರಲ್ಲಿ';
  }

  @override
  String get energyTitle => 'ಶಕ್ತಿ';

  @override
  String energyLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ಶಕ್ತಿ ಉಳಿದಿದೆ',
      one: '1 ಶಕ್ತಿ ಉಳಿದಿದೆ',
      zero: 'ಶಕ್ತಿ ಉಳಿದಿಲ್ಲ',
    );
    return '$_temp0';
  }

  @override
  String get energyUnlimited => 'ಅಮಿತ';

  @override
  String get energyOutTitle => 'ನಿಮ್ಮ ಶಕ್ತಿ ಖಾಲಿಯಾಗಿದೆ';

  @override
  String energyOutBody(String time) {
    return 'ಮಧ್ಯರಾತ್ರಿ ಶಕ್ತಿ ಮರುಭರ್ತಿಯಾಗುತ್ತದೆ — $time ರಲ್ಲಿ.';
  }

  @override
  String energyRefillCoins(int coins) {
    return '$coins ನಾಣ್ಯಗಳಿಗೆ 1 ⚡ ಮರುಭರ್ತಿ';
  }

  @override
  String get energyGoUnlimited => 'ಅಮಿತ ಶಕ್ತಿ ಪಡೆಯಿರಿ';

  @override
  String get energyFreeOptions => 'ನೀವು ಈಗಲೂ ಮಾಡಬಹುದಾದ ಉಚಿತ ಕೆಲಸಗಳು';

  @override
  String get energyPlayDocket => 'ಇಂದಿನ ದೈನಂದಿನ ಡಾಕೆಟ್ ಆಡಿ (ಉಚಿತ)';

  @override
  String get energyAskAi => 'AI ಗೆ ಕಾನೂನು ಪ್ರಶ್ನೆ ಕೇಳಿ';

  @override
  String get energyReadUpdates => 'ಕಾನೂನು ಸುದ್ದಿಗಳನ್ನು ಓದಿ';

  @override
  String get energyNotEnoughCoins =>
      'ಇನ್ನೂ ಸಾಕಷ್ಟು ನಾಣ್ಯಗಳಿಲ್ಲ — ನಕ್ಷತ್ರಗಳು ಮತ್ತು ಪೆಟ್ಟಿಗೆಗಳಿಂದ ಗಳಿಸಿ.';

  @override
  String get energyRefilled => '+1 ಶಕ್ತಿ!';

  @override
  String get journeyTitle => 'ಕೇಸ್ ಪಾತ್';

  @override
  String get journeySubtitle => 'ಭಾರತೀಯ ಕಾನೂನಿನ ಮೂಲಕ ನಿಮ್ಮ ಪಯಣ';

  @override
  String get journeyKeepGoing => 'ಮುಂದುವರಿಸಿ!';

  @override
  String get journeyQuote =>
      'ಸಣ್ಣ ಸಣ್ಣ ಹೆಜ್ಜೆಗಳು ಕಾನೂನಿನ ತಿಳುವಳಿಕೆಯನ್ನು ಇನ್ನಷ್ಟು ಬಲಪಡಿಸುತ್ತವೆ.';

  @override
  String journeyStars(int count) {
    return '$count ★';
  }

  @override
  String journeyChapter(int number) {
    return 'ಅಧ್ಯಾಯ $number';
  }

  @override
  String journeyLevel(int number) {
    return 'ಹಂತ $number';
  }

  @override
  String get journeyLandmark => 'ಮೈಲಿಗಲ್ಲು ಹಂತ';

  @override
  String get journeyLocked => 'ಲಾಕ್ ಆಗಿದೆ';

  @override
  String get journeyLockedBody =>
      'ಇದನ್ನು ಅನ್‌ಲಾಕ್ ಮಾಡಲು ಹಿಂದಿನ ಹಂತವನ್ನು ಪೂರ್ಣಗೊಳಿಸಿ.';

  @override
  String journeyQuestions(int count) {
    return '$count ಪ್ರಶ್ನೆಗಳು';
  }

  @override
  String get journeyBestStars => 'ನಿಮ್ಮ ಉತ್ತಮ ಸಾಧನೆ';

  @override
  String get journeyReplay => 'ಮತ್ತೆ ಆಡಿ';

  @override
  String get journeyChest => 'ಅಧ್ಯಾಯದ ಪೆಟ್ಟಿಗೆ';

  @override
  String get journeyChestBody =>
      'ನೀವು ಅಧ್ಯಾಯ ಮುಗಿಸಿದ್ದೀರಿ! ಬೋನಸ್ ನಾಣ್ಯಗಳಿಗಾಗಿ ಪೆಟ್ಟಿಗೆ ತೆರೆಯಿರಿ.';

  @override
  String get journeyOpenChest => 'ಪೆಟ್ಟಿಗೆ ತೆರೆಯಿರಿ';

  @override
  String journeyChestOpened(int coins) {
    return '+$coins ನಾಣ್ಯಗಳು!';
  }

  @override
  String get journeyChestLocked =>
      'ಪೆಟ್ಟಿಗೆ ತೆರೆಯಲು ಈ ಅಧ್ಯಾಯದ ಎಲ್ಲಾ ಹಂತಗಳನ್ನು ಮುಗಿಸಿ.';

  @override
  String get journeyJumpToCurrent => 'ಪ್ರಸ್ತುತ ಹಂತಕ್ಕೆ ಹೋಗಿ';

  @override
  String get journeyYou => 'ನೀವು';

  @override
  String get journeyPassHint =>
      'ಉತ್ತೀರ್ಣರಾಗಲು 50% · 2 ನಕ್ಷತ್ರಕ್ಕೆ 80% · 3 ನಕ್ಷತ್ರಕ್ಕೆ 100%';

  @override
  String quizQuestionOf(int current, int total) {
    return '$total ರಲ್ಲಿ ಪ್ರಶ್ನೆ $current';
  }

  @override
  String get quizCorrect => 'ಸರಿ ಉತ್ತರ!';

  @override
  String get quizWrong => 'ಸ್ವಲ್ಪ ತಪ್ಪಾಯಿತು';

  @override
  String get quizTimeUp => 'ಸಮಯ ಮುಗಿಯಿತು';

  @override
  String quizAnswerWas(String answer) {
    return 'ಉತ್ತರ: $answer';
  }

  @override
  String get quizWhy => 'ಏಕೆ';

  @override
  String get quizReference => 'ಆಧಾರ';

  @override
  String get quizOpenSource => 'ಅಧಿಕೃತ ಪಠ್ಯವನ್ನು ಓದಿ';

  @override
  String get quizOpenSourceFailed => 'ಲಿಂಕ್ ತೆರೆಯಲು ಆಗಲಿಲ್ಲ';

  @override
  String quizCombo(int count) {
    return '$count× ಕಾಂಬೊ!';
  }

  @override
  String get quizFinish => 'ಮುಗಿಸಿ';

  @override
  String get quizSubmit => 'ಪರೀಕ್ಷೆ ಸಲ್ಲಿಸಿ';

  @override
  String get quizSkipQuestion => 'ಬಿಟ್ಟುಬಿಡಿ';

  @override
  String get quizSelectAnswer => 'ಉತ್ತರ ಆಯ್ಕೆಮಾಡಿ';

  @override
  String get quizQuitTitle => 'ಈ ರಸಪ್ರಶ್ನೆಯಿಂದ ಹೊರಹೋಗುವಿರಾ?';

  @override
  String get quizQuitBody => 'ಈ ರಸಪ್ರಶ್ನೆಯಲ್ಲಿನ ನಿಮ್ಮ ಪ್ರಗತಿ ಕಳೆದುಹೋಗುತ್ತದೆ.';

  @override
  String get quizQuitBodyRefund =>
      'ನೀವು ಇನ್ನೂ ಉತ್ತರಿಸಿಲ್ಲ, ಆದ್ದರಿಂದ ನಿಮ್ಮ ಶಕ್ತಿ ಮರಳಿ ಸಿಗುತ್ತದೆ.';

  @override
  String get quizQuitStay => 'ಆಡುತ್ತಿರಿ';

  @override
  String get quizQuitLeave => 'ಹೊರಹೋಗಿ';

  @override
  String get quizLoading => 'ನಿಮ್ಮ ಪ್ರಕರಣ ಸಿದ್ಧವಾಗುತ್ತಿದೆ…';

  @override
  String get quizEmpty => 'ಇಲ್ಲಿ ಇನ್ನೂ ಯಾವುದೇ ಪ್ರಶ್ನೆಗಳಿಲ್ಲ.';

  @override
  String get quizOpponent => 'ಎದುರಾಳಿ';

  @override
  String quizOpponentAnswered(String name, int seconds) {
    return '$name ${seconds}s ನಲ್ಲಿ ಉತ್ತರಿಸಿದರು';
  }

  @override
  String get quizVs => 'VS';

  @override
  String get quizFindingOpponent => 'ಎದುರಾಳಿಯನ್ನು ಹುಡುಕಲಾಗುತ್ತಿದೆ…';

  @override
  String quizMarkedAnswers(int answered, int total) {
    return '$total ರಲ್ಲಿ $answered ಉತ್ತರಿಸಲಾಗಿದೆ';
  }

  @override
  String get resultPerfect => 'ಪರಿಪೂರ್ಣ ಪ್ರಕರಣ!';

  @override
  String get resultGreat => 'ಅತ್ಯುತ್ತಮ ಕೆಲಸ!';

  @override
  String get resultGood => 'ಹಂತ ಪೂರ್ಣಗೊಂಡಿದೆ!';

  @override
  String get resultTryAgain => 'ಸ್ವಲ್ಪದರಲ್ಲೇ ತಪ್ಪಿತು';

  @override
  String get resultTryAgainBody =>
      'ಈ ಹಂತ ದಾಟಲು ಕನಿಷ್ಠ 50% ಅಂಕ ಗಳಿಸಿ. ವಿವರಣೆಗಳನ್ನು ಓದಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String resultScore(int correct, int total) {
    return '$correct/$total ಸರಿ';
  }

  @override
  String get resultAccuracy => 'ನಿಖರತೆ';

  @override
  String get resultXp => 'XP';

  @override
  String get resultCoins => 'ನಾಣ್ಯಗಳು';

  @override
  String get resultTime => 'ಸಮಯ';

  @override
  String resultStreakExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ಸ್ಟ್ರೀಕ್ $count ದಿನಗಳಿಗೆ ವಿಸ್ತರಿಸಿದೆ!',
      one: 'ನಿಮ್ಮ ಸ್ಟ್ರೀಕ್ ಆರಂಭವಾಯಿತು — ದಿನ 1!',
    );
    return '$_temp0';
  }

  @override
  String resultMilestone(int count) {
    return '$count-ದಿನಗಳ ಸ್ಟ್ರೀಕ್ ಮೈಲಿಗಲ್ಲು!';
  }

  @override
  String get resultGoalReached => 'ದೈನಂದಿನ ಗುರಿ ತಲುಪಿದೆ!';

  @override
  String resultEnergyBonus(int count) {
    return '3-ನಕ್ಷತ್ರ ಬೋನಸ್: +$count ⚡';
  }

  @override
  String resultLeagueUp(int rank) {
    return 'ನಿಮ್ಮ ಲೀಗ್‌ನಲ್ಲಿ ನೀವು #$rank ಕ್ಕೆ ಏರಿದ್ದೀರಿ';
  }

  @override
  String get resultReview => 'ಉತ್ತರಗಳನ್ನು ಪರಿಶೀಲಿಸಿ';

  @override
  String get resultNextLevel => 'ಮುಂದಿನ ಹಂತ';

  @override
  String get resultBackToMap => 'ನಕ್ಷೆಗೆ ಹಿಂತಿರುಗಿ';

  @override
  String get resultBackHome => 'ಮುಖಪುಟಕ್ಕೆ';

  @override
  String get resultPlayAgain => 'ಮತ್ತೆ ಆಡಿ';

  @override
  String resultExamScore(String score, int max) {
    return 'ಅಂಕ: $score / $max';
  }

  @override
  String resultExamBreakdown(int correct, int wrong, int skipped) {
    return '$correct ಸರಿ · $wrong ತಪ್ಪು · $skipped ಬಿಟ್ಟಿದ್ದು';
  }

  @override
  String get resultDuelWon => 'ನೀವು ಸವಾಲು ಗೆದ್ದಿರಿ!';

  @override
  String get resultDuelLost => 'ತೀವ್ರ ಪೈಪೋಟಿ!';

  @override
  String get resultDuelDraw => 'ಸಮಬಲ!';

  @override
  String resultDuelPoints(int you, int them) {
    return '$you vs $them';
  }

  @override
  String get resultDocketShare => 'ಫಲಿತಾಂಶ ಹಂಚಿಕೊಳ್ಳಿ';

  @override
  String get resultYourAnswer => 'ನಿಮ್ಮ ಉತ್ತರ';

  @override
  String get resultCorrectAnswer => 'ಸರಿಯಾದ ಉತ್ತರ';

  @override
  String get resultSkipped => 'ಬಿಟ್ಟಿದ್ದು';

  @override
  String get leaderboardTitle => 'ಲೀಡರ್‌ಬೋರ್ಡ್';

  @override
  String get leaderboardWeekly => 'ವಾರದ ಲೀಗ್';

  @override
  String get leaderboardAllTime => 'ಸಾರ್ವಕಾಲಿಕ';

  @override
  String get leaderboardPromotionZone => 'ಬಡ್ತಿ ವಲಯ';

  @override
  String get leaderboardDemotionZone => 'ಹಿಂಬಡ್ತಿ ವಲಯ';

  @override
  String leaderboardEndsIn(String time) {
    return 'ವಾರ $time ರಲ್ಲಿ ಮುಗಿಯುತ್ತದೆ';
  }

  @override
  String leaderboardTopPromote(int count, String tier) {
    return 'ಅಗ್ರ $count ಜನರು $tier ಗೆ ಏರುತ್ತಾರೆ';
  }

  @override
  String get leaderboardNoDemotion =>
      'ಈ ಲೀಗ್‌ನಲ್ಲಿ ಹಿಂಬಡ್ತಿ ಇಲ್ಲ — ಕಲಿಯುತ್ತಲೇ ಇರಿ!';

  @override
  String get leaderboardEarnToJoin => 'ಲೀಗ್ ಸೇರಲು ಈ ವಾರ ಒಂದು ರಸಪ್ರಶ್ನೆ ಮುಗಿಸಿ.';

  @override
  String leaderboardXp(int xp) {
    return '$xp XP';
  }

  @override
  String get leaderboardPractice => 'ಅಭ್ಯಾಸ ಆಟಗಾರ';

  @override
  String get leaderboardYou => 'ನೀವು';

  @override
  String get leaderboardTiers => 'ಲೀಗ್ ಶ್ರೇಣಿಗಳು';

  @override
  String leagueOutcomePromoted(String tier) {
    return '$tier ಗೆ ಬಡ್ತಿ!';
  }

  @override
  String leagueOutcomeDemoted(String tier) {
    return '$tier ಗೆ ವರ್ಗಾಯಿಸಲಾಗಿದೆ';
  }

  @override
  String leagueOutcomeStayed(String tier) {
    return 'ನೀವು $tier ನಲ್ಲೇ ಉಳಿದಿದ್ದೀರಿ';
  }

  @override
  String leagueOutcomeRank(int rank) {
    return 'ಕಳೆದ ವಾರ ನೀವು #$rank ಸ್ಥಾನ ಪಡೆದಿರಿ.';
  }

  @override
  String get tier_nyayaPanchayat => 'ನ್ಯಾಯ ಪಂಚಾಯತ್';

  @override
  String get tier_gramNyayalaya => 'ಗ್ರಾಮ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_munsiffCourt => 'ಮುನ್ಸಿಫ್ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_magistrateCourt => 'ಮ್ಯಾಜಿಸ್ಟ್ರೇಟ್ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_districtCourt => 'ಜಿಲ್ಲಾ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_sessionsCourt => 'ಸೆಷನ್ಸ್ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_highCourt => 'ಉಚ್ಚ ನ್ಯಾಯಾಲಯ';

  @override
  String get tier_supremeCourt => 'ಸರ್ವೋಚ್ಚ ನ್ಯಾಯಾಲಯ';

  @override
  String get chatTitle => 'Nyaya AI';

  @override
  String get chatSubtitle => 'ನಿಮ್ಮ ಕಾನೂನು ಮಾಹಿತಿ ಸಹಾಯಕ';

  @override
  String get chatDisclaimer =>
      'ಇದು ಸಾಮಾನ್ಯ ಕಾನೂನು ಮಾಹಿತಿ, ಕಾನೂನು ಸಲಹೆಯಲ್ಲ. ನಿಮ್ಮ ನಿರ್ದಿಷ್ಟ ಪ್ರಕರಣಕ್ಕೆ ವಕೀಲರನ್ನು ಸಂಪರ್ಕಿಸಿ ಅಥವಾ NALSA ಸಹಾಯವಾಣಿ 15100 ಗೆ ಕರೆ ಮಾಡಿ.';

  @override
  String get chatHint => 'ಯಾವುದೇ ಭಾರತೀಯ ಕಾನೂನಿನ ಬಗ್ಗೆ ಕೇಳಿ…';

  @override
  String get chatWelcome =>
      'ನಮಸ್ಕಾರ! ಭಾರತೀಯ ಕಾನೂನುಗಳು, ನಿಮ್ಮ ಹಕ್ಕುಗಳು, ಕಾನೂನು ಪ್ರಕ್ರಿಯೆಗಳು ಮತ್ತು ಹೊಸ ಕ್ರಿಮಿನಲ್ ಕಾನೂನುಗಳನ್ನು (BNS, BNSS, BSA) ನಾನು ವಿವರಿಸಬಲ್ಲೆ. ನೀವು ಏನು ತಿಳಿಯಲು ಬಯಸುತ್ತೀರಿ?';

  @override
  String get chatSuggest1 => 'ಶೂನ್ಯ FIR (Zero FIR) ಎಂದರೇನು?';

  @override
  String get chatSuggest2 => 'ನನ್ನನ್ನು ಬಂಧಿಸಿದರೆ ನನ್ನ ಹಕ್ಕುಗಳೇನು?';

  @override
  String get chatSuggest3 => 'RTI ಅರ್ಜಿ ಹೇಗೆ ಸಲ್ಲಿಸುವುದು?';

  @override
  String get chatSuggest4 => 'ಗ್ರಾಹಕ ದೂರು ಹೇಗೆ ಸಲ್ಲಿಸುವುದು?';

  @override
  String get chatThinking => 'ಕಾನೂನನ್ನು ಪರಿಶೀಲಿಸಲಾಗುತ್ತಿದೆ…';

  @override
  String chatLimitLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ಇಂದು $count ಉಚಿತ ಪ್ರಶ್ನೆಗಳು ಉಳಿದಿವೆ',
      one: 'ಇಂದು 1 ಉಚಿತ ಪ್ರಶ್ನೆ ಉಳಿದಿದೆ',
    );
    return '$_temp0';
  }

  @override
  String get chatLimitReached =>
      'ಇಂದಿನ ಉಚಿತ ಪ್ರಶ್ನೆಗಳು ಮುಗಿದಿವೆ. ನಾಳೆ ಬನ್ನಿ ಅಥವಾ ಅಮಿತ AI ಗಾಗಿ ಪ್ರೀಮಿಯಂ ಪಡೆಯಿರಿ.';

  @override
  String get chatLimitReachedToday =>
      'ಇಂದಿನ ಪ್ರಶ್ನೆಗಳು ಮುಗಿದಿವೆ. ನಾಳೆ ಮತ್ತೆ ಕೇಳಬಹುದು.';

  @override
  String get chatError =>
      'ಈಗ AI ಅನ್ನು ಸಂಪರ್ಕಿಸಲು ಆಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get chatOfflineNote =>
      'ಆಫ್‌ಲೈನ್ ಮೋಡ್ — ಪೂರ್ಣ ಉತ್ತರಗಳಿಗಾಗಿ AI ಕೀ ಸಂಪರ್ಕಿಸಿ.';

  @override
  String get chatClear => 'ಚಾಟ್ ಅಳಿಸಿ';

  @override
  String get chatCopy => 'ನಕಲಿಸಲಾಗಿದೆ';

  @override
  String get updatesTitle => 'ಕಾನೂನು ಸುದ್ದಿಗಳು';

  @override
  String get updatesSubtitle => 'ತೀರ್ಪುಗಳು, ಹೊಸ ಕಾನೂನುಗಳು ಮತ್ತು ವಿವರಣೆಗಳು';

  @override
  String get updatesAll => 'ಎಲ್ಲಾ';

  @override
  String get updatesSupremeCourt => 'ಸುಪ್ರೀಂ ಕೋರ್ಟ್';

  @override
  String get updatesHighCourts => 'ಹೈಕೋರ್ಟ್‌ಗಳು';

  @override
  String get updatesLegislation => 'ಶಾಸನ';

  @override
  String get updatesExplainer => 'ವಿವರಣೆಗಳು';

  @override
  String updatesReadTime(int minutes) {
    return '$minutes ನಿಮಿಷದ ಓದು';
  }

  @override
  String get updatesKeyPoints => 'ಮುಖ್ಯ ಅಂಶಗಳು';

  @override
  String get updatesWhyItMatters => 'ಇದು ಏಕೆ ಮುಖ್ಯ';

  @override
  String get updatesSource => 'ಮೂಲ';

  @override
  String get updatesAskAi => 'ಇದರ ಬಗ್ಗೆ AI ಕೇಳಿ';

  @override
  String get updatesEmpty => 'ಈ ವರ್ಗದಲ್ಲಿ ಇನ್ನೂ ಯಾವುದೇ ಸುದ್ದಿಗಳಿಲ್ಲ.';

  @override
  String get updatesSave => 'ಸುದ್ದಿ ಉಳಿಸಿ';

  @override
  String get updatesUnsave => 'ಉಳಿಸಿದವುಗಳಿಂದ ತೆಗೆಯಿರಿ';

  @override
  String get updatesInEnglish => 'ಇಂಗ್ಲಿಷ್‌ನಲ್ಲಿ ತೋರಿಸಲಾಗಿದೆ';

  @override
  String get settingsTitle => 'ಸೆಟ್ಟಿಂಗ್ಸ್';

  @override
  String get settingsProfile => 'ಪ್ರೊಫೈಲ್';

  @override
  String get settingsEditName => 'ಹೆಸರು ಬದಲಿಸಿ';

  @override
  String get settingsLearningAs => 'ಯಾರಾಗಿ ಕಲಿಕೆ';

  @override
  String get settingsLanguage => 'ಭಾಷೆ';

  @override
  String get settingsDailyGoal => 'ದೈನಂದಿನ ಗುರಿ';

  @override
  String get settingsAppearance => 'ನೋಟ';

  @override
  String get settingsThemeSystem => 'ಸಿಸ್ಟಮ್';

  @override
  String get settingsThemeLight => 'ಲೈಟ್';

  @override
  String get settingsThemeDark => 'ಡಾರ್ಕ್';

  @override
  String get settingsSound => 'ಧ್ವನಿ ಪರಿಣಾಮಗಳು';

  @override
  String get settingsHaptics => 'ಕಂಪನ ಪ್ರತಿಕ್ರಿಯೆ';

  @override
  String get settingsReminders => 'ದೈನಂದಿನ ಜ್ಞಾಪನೆ';

  @override
  String get settingsRemindersSub => 'ನಿಮ್ಮ ಸ್ಟ್ರೀಕ್ ಉಳಿಸಿಕೊಳ್ಳಲು ಒಂದು ನೆನಪು';

  @override
  String get settingsStore => 'ಅಂಗಡಿ';

  @override
  String get settingsStreakFreeze => 'ಸ್ಟ್ರೀಕ್ ಫ್ರೀಜ್';

  @override
  String settingsStreakFreezeSub(int owned, int max) {
    return 'ಒಂದು ದಿನ ತಪ್ಪಿದರೆ ನಿಮ್ಮ ಸ್ಟ್ರೀಕ್ ರಕ್ಷಿಸುತ್ತದೆ · $owned/$max ಸಜ್ಜಾಗಿದೆ';
  }

  @override
  String settingsBuyFor(int coins) {
    return '$coins ನಾಣ್ಯಗಳು';
  }

  @override
  String get settingsFreezeBought => 'ಸ್ಟ್ರೀಕ್ ಫ್ರೀಜ್ ಸಜ್ಜಾಗಿದೆ!';

  @override
  String get settingsFreezeFull =>
      'ನೀವು ಈಗಾಗಲೇ ಗರಿಷ್ಠ ಫ್ರೀಜ್‌ಗಳನ್ನು ಹೊಂದಿದ್ದೀರಿ.';

  @override
  String get settingsPremium => 'Nyaya ಪ್ರೀಮಿಯಂ';

  @override
  String get settingsPremiumActive => 'ಪ್ರೀಮಿಯಂ ಸಕ್ರಿಯವಾಗಿದೆ';

  @override
  String get settingsPremiumUpgrade => 'ಪ್ರೀಮಿಯಂಗೆ ಅಪ್‌ಗ್ರೇಡ್ ಮಾಡಿ';

  @override
  String get settingsStats => 'ನಿಮ್ಮ ಅಂಕಿಅಂಶಗಳು';

  @override
  String get settingsTotalXp => 'ಒಟ್ಟು XP';

  @override
  String get settingsLongestStreak => 'ಅತಿ ದೀರ್ಘ ಸ್ಟ್ರೀಕ್';

  @override
  String get settingsQuizzes => 'ರಸಪ್ರಶ್ನೆಗಳು';

  @override
  String get settingsAccuracy => 'ನಿಖರತೆ';

  @override
  String get settingsDuelRecord => 'ಗೆದ್ದ ಸವಾಲುಗಳು';

  @override
  String get settingsAbout => 'ಕುರಿತು';

  @override
  String get settingsDisclaimer => 'ಕಾನೂನು ಹಕ್ಕು ನಿರಾಕರಣೆ';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya ಒಂದು ಶೈಕ್ಷಣಿಕ ಆ್ಯಪ್. ಪ್ರಶ್ನೆಗಳು, ವಿವರಣೆಗಳು, ಸುದ್ದಿಗಳು ಮತ್ತು AI ಉತ್ತರಗಳು ಸಾಮಾನ್ಯ ಮಾಹಿತಿಯಾಗಿದ್ದು, ಕಾನೂನು ಸಲಹೆಯಲ್ಲ. ಕಾನೂನುಗಳು ಬದಲಾಗುತ್ತವೆ — ಯಾವಾಗಲೂ ಅಧಿಕೃತ ರಾಜ್ಯಪತ್ರ (ಗೆಜೆಟ್) ಪರಿಶೀಲಿಸಿ ಅಥವಾ ವಕೀಲರನ್ನು ಸಂಪರ್ಕಿಸಿ.';

  @override
  String get settingsPrivacy => 'ಗೌಪ್ಯತೆ';

  @override
  String get settingsPrivacyBody =>
      'ನಿಮ್ಮ ಪ್ರಗತಿ ನಿಮ್ಮ ಖಾತೆಯಲ್ಲಿ ಉಳಿಸಲಾಗುತ್ತದೆ, ಜೊತೆಗೆ ನೀವು ಆ್ಯಪ್ ತೆರೆಯುವ ದಿನಗಳೂ, ಜನರು ಮತ್ತೆ ಬರುತ್ತಿದ್ದಾರೆಯೇ ಎಂದು ನಾವು ತಿಳಿಯಲು. ನೀವು AI ಗೆ ಕೇಳುವ ಪ್ರಶ್ನೆಗಳನ್ನು ಉತ್ತರ ಬರೆಯಲು ಮಾತ್ರ ನಮ್ಮ AI ಪೂರೈಕೆದಾರರಿಗೆ ಕಳುಹಿಸಲಾಗುತ್ತದೆ. ಆ್ಯಪ್ ಕ್ರ್ಯಾಶ್ ಆದರೆ, ಅದನ್ನು ಸರಿಪಡಿಸಲು ಸಹಾಯ ಮಾಡುವ ಸಣ್ಣ ತಾಂತ್ರಿಕ ವರದಿ (ನಿಮ್ಮ ಉತ್ತರಗಳು ಅಥವಾ ವೈಯಕ್ತಿಕ ವಿವರಗಳಿಲ್ಲದೆ) ಕಳುಹಿಸಲಾಗುತ್ತದೆ. ಸೆಟ್ಟಿಂಗ್ಸ್‌ನಲ್ಲಿ ನಿಮ್ಮ ಖಾತೆಯನ್ನು ಅಳಿಸಬಹುದು.';

  @override
  String settingsVersion(String version) {
    return 'ಆವೃತ್ತಿ $version';
  }

  @override
  String get settingsReset => 'ಪ್ರಗತಿ ಮರುಹೊಂದಿಸಿ';

  @override
  String get settingsResetConfirm =>
      'ಇದು ಈ ಸಾಧನದಲ್ಲಿನ ಎಲ್ಲಾ XP, ನಕ್ಷತ್ರಗಳು, ಸ್ಟ್ರೀಕ್‌ಗಳು ಮತ್ತು ನಾಣ್ಯಗಳನ್ನು ಅಳಿಸುತ್ತದೆ. ಇದನ್ನು ಹಿಂಪಡೆಯಲು ಸಾಧ್ಯವಿಲ್ಲ.';

  @override
  String get settingsResetAction => 'ಎಲ್ಲವನ್ನೂ ಅಳಿಸಿ';

  @override
  String get premiumTitle => 'Nyaya ಪ್ರೀಮಿಯಂ';

  @override
  String get premiumHeadline => 'ಮಿತಿಯಿಲ್ಲದೆ ಕಲಿಯಿರಿ';

  @override
  String get premiumBenefitEnergy => 'ಅಮಿತ ಶಕ್ತಿ';

  @override
  String get premiumBenefitEnergySub => 'ಬೇಕಾದಷ್ಟು ರಸಪ್ರಶ್ನೆಗಳನ್ನು ಆಡಿ';

  @override
  String get premiumBenefitAi => 'ಅಮಿತ Nyaya AI';

  @override
  String get premiumBenefitAiSub => 'ನಿಮ್ಮ ಪ್ರತಿಯೊಂದು ಕಾನೂನು ಪ್ರಶ್ನೆಯನ್ನೂ ಕೇಳಿ';

  @override
  String get premiumBenefitFreeze => 'ಸ್ಟ್ರೀಕ್ ಫ್ರೀಜ್‌ಗಳು ಸೇರಿವೆ';

  @override
  String get premiumBenefitFreezeSub =>
      'ಬಿಡುವಿಲ್ಲದ ದಿನದಿಂದ ಸ್ಟ್ರೀಕ್ ಎಂದಿಗೂ ಕಳೆದುಕೊಳ್ಳಬೇಡಿ';

  @override
  String get premiumBenefitExam => 'ಪೂರ್ಣ ಅಣಕು ಪರೀಕ್ಷೆಗಳು';

  @override
  String get premiumBenefitExamSub => 'CLAT, AIBE ಮತ್ತು ನ್ಯಾಯಾಂಗ ಮಾದರಿ ಅಭ್ಯಾಸ';

  @override
  String get premiumFair =>
      'ನ್ಯಾಯಯುತ ಆಟ: ಪ್ರೀಮಿಯಂ ಎಂದಿಗೂ ಲೀಗ್ XP ಹೆಚ್ಚಿಸುವುದಿಲ್ಲ.';

  @override
  String get premiumYearly => 'ವಾರ್ಷಿಕ';

  @override
  String get premiumMonthly => 'ಮಾಸಿಕ';

  @override
  String get premiumYearlyPrice => '₹999 / ವರ್ಷ';

  @override
  String get premiumMonthlyPrice => '₹149 / ತಿಂಗಳು';

  @override
  String get premiumPerMonth => 'ಕೇವಲ ₹83 / ತಿಂಗಳು';

  @override
  String get premiumSave => '44% ಉಳಿಸಿ';

  @override
  String get premiumBestValue => 'ಅತ್ಯುತ್ತಮ ಮೌಲ್ಯ';

  @override
  String get premiumStartTrial => '7 ದಿನಗಳ ಉಚಿತ ಪ್ರಯೋಗ ಆರಂಭಿಸಿ';

  @override
  String get premiumTrialNote =>
      'ಪ್ರಯೋಗ ಮುಗಿಯುವ ಮೊದಲು ಯಾವಾಗ ಬೇಕಾದರೂ ರದ್ದುಮಾಡಿ, ನಿಮಗೆ ಶುಲ್ಕ ವಿಧಿಸಲಾಗುವುದಿಲ್ಲ.';

  @override
  String get premiumRestore => 'ಖರೀದಿಗಳನ್ನು ಮರುಸ್ಥಾಪಿಸಿ';

  @override
  String get premiumActivated => 'Nyaya ಪ್ರೀಮಿಯಂಗೆ ಸ್ವಾಗತ!';

  @override
  String get premiumAlready => 'ನೀವು ಪ್ರೀಮಿಯಂ ಸದಸ್ಯರು';

  @override
  String get premiumNothingToRestore => 'ಹಿಂದಿನ ಯಾವುದೇ ಖರೀದಿ ಕಂಡುಬಂದಿಲ್ಲ.';

  @override
  String get statXp => 'XP';

  @override
  String get statStreak => 'ಸ್ಟ್ರೀಕ್';

  @override
  String get statCoins => 'ನಾಣ್ಯಗಳು';

  @override
  String get statEnergy => 'ಶಕ್ತಿ';

  @override
  String get statStars => 'ನಕ್ಷತ್ರಗಳು';

  @override
  String get exploreTitle => 'ಕಾನೂನು ಅನ್ವೇಷಿಸಿ';

  @override
  String get exploreSubtitle => 'ಭಾರತೀಯ ಕಾನೂನಿನ ಬಗ್ಗೆ ನಿಮ್ಮ ತಿಳುವಳಿಕೆ ಬೆಳೆಸಿ';

  @override
  String get exploreStartHere => 'ಇಲ್ಲಿಂದ ಪ್ರಾರಂಭಿಸಿ';

  @override
  String get exploreFeatured => 'ವಿಶೇಷ';

  @override
  String get exploreButton => 'ಅನ್ವೇಷಿಸಿ';

  @override
  String get exploreCoreLaws => 'ಪ್ರಮುಖ ಕಾನೂನುಗಳು';

  @override
  String get exploreViewAll => 'ಎಲ್ಲಾ ನೋಡಿ';

  @override
  String get exploreLegacy => 'ಹಳೆಯವು';

  @override
  String get exploreAskAi => 'AI ಕೇಳಿ';

  @override
  String exploreAskPrompt(String law) {
    return '$law ಅನ್ನು ಸರಳ ಮಾತುಗಳಲ್ಲಿ ವಿವರಿಸಿ: ಇದು ಯಾವುದನ್ನು ಒಳಗೊಂಡಿದೆ ಮತ್ತು ನಾನು ತಿಳಿಯಬೇಕಾದ ಮುಖ್ಯ ನಿಬಂಧನೆಗಳೇನು.';
  }

  @override
  String get lawConstitutionTitle => 'ಭಾರತದ ಸಂವಿಧಾನ';

  @override
  String get lawConstitutionDesc =>
      'ಮೂಲಭೂತ ಹಕ್ಕುಗಳು, ನಿರ್ದೇಶಕ ತತ್ವಗಳು, ಕರ್ತವ್ಯಗಳು ಮತ್ತು ಇನ್ನಷ್ಟು.';

  @override
  String get lawBnsTitle => 'ಭಾರತೀಯ ನ್ಯಾಯ ಸಂಹಿತೆ (BNS)';

  @override
  String get lawBnsShort => 'ಭಾರತೀಯ ನ್ಯಾಯ ಸಂಹಿತೆ';

  @override
  String get lawBnsDesc => 'ಮೂಲ ಕ್ರಿಮಿನಲ್ ಕಾನೂನು';

  @override
  String get lawBnsFeatured =>
      'ಭಾರತದ ಹೊಸ ಕ್ರಿಮಿನಲ್ ಸಂಹಿತೆಯಡಿ ಅಪರಾಧಗಳು ಮತ್ತು ಶಿಕ್ಷೆಗಳು.';

  @override
  String get lawBnssTitle => 'ಭಾರತೀಯ ನಾಗರಿಕ ಸುರಕ್ಷಾ ಸಂಹಿತೆ (BNSS)';

  @override
  String get lawBnssDesc => 'ಕ್ರಿಮಿನಲ್ ಪ್ರಕ್ರಿಯಾ ಕಾನೂನು';

  @override
  String get lawBsaTitle => 'ಭಾರತೀಯ ಸಾಕ್ಷ್ಯ ಅಧಿನಿಯಮ (BSA)';

  @override
  String get lawBsaDesc => 'ಸಾಕ್ಷ್ಯ ಕಾನೂನು';

  @override
  String get lawEverydayTitle => 'ದೈನಂದಿನ ಕಾನೂನು';

  @override
  String get lawEverydayDesc =>
      'ದಿನನಿತ್ಯದ ಜೀವನದಲ್ಲಿ ನಿಮ್ಮ ಹಕ್ಕುಗಳನ್ನು ತಿಳಿಯಿರಿ';

  @override
  String get lawEverydayFeatured =>
      'ಗ್ರಾಹಕ, ಬಾಡಿಗೆ, ಕೆಲಸದ ಸ್ಥಳ ಮತ್ತು ಕುಟುಂಬದ ಹಕ್ಕುಗಳು, ಸರಳವಾಗಿ ವಿವರಿಸಲಾಗಿದೆ.';

  @override
  String get lawLegacyTitle => 'IPC ಮತ್ತು CrPC (ಹಳೆಯವು)';

  @override
  String get lawLegacyDesc => 'ಉಲ್ಲೇಖಕ್ಕಾಗಿ ಹಳೆಯ ಕಾನೂನುಗಳು';

  @override
  String get chapterConstitutionTitle => 'ಸಂವಿಧಾನದ ಮೂಲಾಂಶಗಳು';

  @override
  String get chapterConstitutionSubtitle =>
      'ಪ್ರಸ್ತಾವನೆ, ಸಂಸತ್ತು, ನ್ಯಾಯಾಲಯಗಳು, ತಿದ್ದುಪಡಿಗಳು';

  @override
  String get chapterRightsTitle => 'ಹಕ್ಕುಗಳು ಮತ್ತು ಕರ್ತವ್ಯಗಳು';

  @override
  String get chapterRightsSubtitle =>
      'ಮೂಲಭೂತ ಹಕ್ಕುಗಳು, ನಿರ್ದೇಶಕ ತತ್ವಗಳು ಮತ್ತು ರಿಟ್‌ಗಳು';

  @override
  String get chapterCriminalTitle => 'ಕ್ರಿಮಿನಲ್ ಕಾನೂನು (BNS)';

  @override
  String get chapterCriminalSubtitle => 'ಹೊಸ ಸಂಹಿತೆಯಡಿ ಅಪರಾಧಗಳು';

  @override
  String get chapterProcedureTitle => 'ಪ್ರಕ್ರಿಯೆ ಮತ್ತು ಸಾಕ್ಷ್ಯ';

  @override
  String get chapterProcedureSubtitle => 'BNSS, BSA, FIR, ಬಂಧನ, ಜಾಮೀನು';

  @override
  String get chapterCivilTitle => 'ಒಪ್ಪಂದಗಳು ಮತ್ತು ಗ್ರಾಹಕರು';

  @override
  String get chapterCivilSubtitle => 'ಒಪ್ಪಂದಗಳು, ಗ್ರಾಹಕ ಹಕ್ಕುಗಳು, ಪರಿಹಾರಗಳು';

  @override
  String get chapterEverydayTitle => 'ದೈನಂದಿನ ಕಾನೂನು';

  @override
  String get chapterEverydaySubtitle => 'ದಿನನಿತ್ಯದ ಜೀವನಕ್ಕೆ ಕಾನೂನು';

  @override
  String get authCreateTitle => 'ನಿಮ್ಮ ಉಚಿತ ಖಾತೆ ತೆರೆಯಿರಿ';

  @override
  String get authCreateSubtitle =>
      'ಪ್ರಶ್ನೆಗಳು Nyaya ಪರಿಶೀಲಿಸಿದ ಸಂಗ್ರಹದಿಂದ ಬರುತ್ತವೆ, ಮತ್ತು ನಿಮ್ಮ ಫಲಿತಾಂಶಗಳನ್ನು ನಿಮ್ಮ ಖಾತೆಯಲ್ಲಿ ಉಳಿಸಲಾಗುತ್ತದೆ.';

  @override
  String get authSignInTitle => 'ಮತ್ತೆ ಸ್ವಾಗತ';

  @override
  String get authSignInSubtitle => 'ಅಭ್ಯಾಸ ಮುಂದುವರಿಸಲು ಸೈನ್ ಇನ್ ಮಾಡಿ.';

  @override
  String get authName => 'ನಿಮ್ಮ ಹೆಸರು';

  @override
  String get authEmail => 'ಇಮೇಲ್';

  @override
  String get authPassword => 'ಪಾಸ್‌ವರ್ಡ್';

  @override
  String get authPasswordHint => 'ಕನಿಷ್ಠ 8 ಅಕ್ಷರಗಳು';

  @override
  String get authCreate => 'ಖಾತೆ ತೆರೆಯಿರಿ';

  @override
  String get authSignIn => 'ಸೈನ್ ಇನ್';

  @override
  String get authHaveAccount => 'ನನಗೆ ಈಗಾಗಲೇ ಖಾತೆ ಇದೆ';

  @override
  String get authNeedAccount => 'ಹೊಸಬರೇ? ಖಾತೆ ತೆರೆಯಿರಿ';

  @override
  String get authErrorCredentials => 'ಇಮೇಲ್ ಅಥವಾ ಪಾಸ್‌ವರ್ಡ್ ಸರಿಯಿಲ್ಲ.';

  @override
  String get authErrorEmailTaken =>
      'ಈ ಇಮೇಲ್‌ನ ಖಾತೆ ಈಗಾಗಲೇ ಇದೆ. ಬದಲಿಗೆ ಸೈನ್ ಇನ್ ಮಾಡಿ.';

  @override
  String get authErrorNetwork =>
      'ಈಗ Nyaya ಅನ್ನು ತಲುಪಲು ಆಗುತ್ತಿಲ್ಲ. ನಿಮ್ಮ ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get authErrorRateLimited =>
      'ತುಂಬಾ ಪ್ರಯತ್ನಗಳಾಗಿವೆ. ಕೆಲವು ನಿಮಿಷ ಕಾದು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get authErrorInvalid =>
      'ಸರಿಯಾದ ಇಮೇಲ್ ಮತ್ತು ಕನಿಷ್ಠ 8 ಅಕ್ಷರಗಳ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ.';

  @override
  String get authErrorName => 'ನಿಮ್ಮ ಹೆಸರನ್ನು ನಮೂದಿಸಿ.';

  @override
  String get settingsAccount => 'ಖಾತೆ';

  @override
  String settingsSignedInAs(String email) {
    return '$email ಆಗಿ ಸೈನ್ ಇನ್ ಆಗಿದ್ದೀರಿ';
  }

  @override
  String get settingsSignIn => 'ಸೈನ್ ಇನ್ ಮಾಡಿ ಅಥವಾ ಖಾತೆ ತೆರೆಯಿರಿ';

  @override
  String get settingsSignOut => 'ಸೈನ್ ಔಟ್';

  @override
  String get updateRequiredTitle => 'ದಯವಿಟ್ಟು Nyaya ಅನ್ನು ಅಪ್‌ಡೇಟ್ ಮಾಡಿ';

  @override
  String get updateRequiredBody =>
      'ಆ್ಯಪ್‌ನ ಈ ಆವೃತ್ತಿ ತುಂಬಾ ಹಳೆಯದಾಗಿದ್ದು ಇನ್ನು ಮುಂದೆ ಕೆಲಸ ಮಾಡುವುದಿಲ್ಲ. ಮುಂದುವರಿಸಲು ಅಪ್‌ಡೇಟ್ ಮಾಡಿ. ನಿಮ್ಮ ಪ್ರಗತಿ ನಿಮ್ಮ ಖಾತೆಯಲ್ಲಿ ಉಳಿದಿದೆ, ಆದ್ದರಿಂದ ಏನೂ ಕಳೆದುಹೋಗುವುದಿಲ್ಲ.';

  @override
  String get updateRequiredAction => 'ಅಪ್‌ಡೇಟ್ ಮಾಡಿ';

  @override
  String get settingsDeleteAccount => 'ಖಾತೆಯನ್ನು ಅಳಿಸಿ';

  @override
  String get settingsDeleteAccountBody =>
      'ಇದು ನಿಮ್ಮ ಖಾತೆಯನ್ನು ಮತ್ತು ಅದರಲ್ಲಿರುವ ಎಲ್ಲವನ್ನೂ ಶಾಶ್ವತವಾಗಿ ಅಳಿಸುತ್ತದೆ: ಪ್ರಗತಿ, XP, ನಾಣ್ಯಗಳು, ಉಳಿಸಿದ ಪ್ರಶ್ನೆಗಳು, ಲೀಗ್ ಸ್ಥಾನ. ಇದನ್ನು ಹಿಂತಿರುಗಿಸಲು ಸಾಧ್ಯವಿಲ್ಲ. ಖಚಿತಪಡಿಸಲು ನಿಮ್ಮ ಪಾಸ್‌ವರ್ಡ್ ನಮೂದಿಸಿ.';

  @override
  String get settingsDeleteAccountPassword => 'ಪಾಸ್‌ವರ್ಡ್';

  @override
  String get settingsDeleteAccountAction => 'ನನ್ನ ಖಾತೆಯನ್ನು ಅಳಿಸಿ';

  @override
  String get settingsDeleteAccountWrong => 'ಆ ಪಾಸ್‌ವರ್ಡ್ ಸರಿಯಿಲ್ಲ.';

  @override
  String get settingsDeleteAccountFailed =>
      'ಖಾತೆಯನ್ನು ಅಳಿಸಲಾಗಲಿಲ್ಲ. ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get quizSendFailed =>
      'ನಿಮ್ಮ ಉತ್ತರ ಕಳುಹಿಸಲು ಆಗಲಿಲ್ಲ. ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಒತ್ತಿ.';

  @override
  String get quizSubmitFailed =>
      'ನಿಮ್ಮ ಫಲಿತಾಂಶ ಪಡೆಯಲು ಆಗಲಿಲ್ಲ. ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ.';

  @override
  String get quizRetry => 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ';

  @override
  String get quizScoring => 'ನಿಮ್ಮ ಪ್ರಕರಣಕ್ಕೆ ಅಂಕ ನೀಡಲಾಗುತ್ತಿದೆ…';

  @override
  String get quizOffline =>
      'Nyaya ಅನ್ನು ತಲುಪಲು ಆಗುತ್ತಿಲ್ಲ. ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.';

  @override
  String get quizSignedOut => 'ನಿಮ್ಮ ಸೆಷನ್ ಮುಗಿದಿದೆ. ಆಡಲು ಮತ್ತೆ ಸೈನ್ ಇನ್ ಮಾಡಿ.';
}
