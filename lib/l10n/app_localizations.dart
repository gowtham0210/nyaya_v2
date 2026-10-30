import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('ta'),
    Locale('te'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Nyaya'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Learn Indian law, one case a day'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navJourney.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get navJourney;

  /// No description provided for @navAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get navAskAi;

  /// No description provided for @navUpdates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get navUpdates;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @reviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewTitle;

  /// No description provided for @reviewMistakesTab.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get reviewMistakesTab;

  /// No description provided for @reviewSavedTab.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get reviewSavedTab;

  /// No description provided for @reviewPractise.
  ///
  /// In en, this message translates to:
  /// **'Practise mistakes'**
  String get reviewPractise;

  /// No description provided for @reviewPractiseFree.
  ///
  /// In en, this message translates to:
  /// **'Free · up to 10 questions · earns XP'**
  String get reviewPractiseFree;

  /// No description provided for @reviewEmptyMistakes.
  ///
  /// In en, this message translates to:
  /// **'No mistakes to review. Questions you get wrong appear here until you answer them right.'**
  String get reviewEmptyMistakes;

  /// No description provided for @reviewEmptySaved.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet. After answering a question, tap Save to keep it here.'**
  String get reviewEmptySaved;

  /// No description provided for @reviewSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your mistakes and saved questions.'**
  String get reviewSignIn;

  /// No description provided for @reviewWrongTimes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Wrong once} other{Wrong {count} times}}'**
  String reviewWrongTimes(int count);

  /// No description provided for @reviewUpdatedSince.
  ///
  /// In en, this message translates to:
  /// **'Updated since you answered it. Shown as you saw it.'**
  String get reviewUpdatedSince;

  /// No description provided for @reviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This question is no longer available.'**
  String get reviewUnavailable;

  /// No description provided for @reviewCardBody.
  ///
  /// In en, this message translates to:
  /// **'{mistakes, plural, =1{1 mistake} other{{mistakes} mistakes}} · {saved} saved'**
  String reviewCardBody(int mistakes, int saved);

  /// No description provided for @questionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get questionSave;

  /// No description provided for @questionSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get questionSaved;

  /// No description provided for @questionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get questionReport;

  /// No description provided for @questionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Check your connection and try again.'**
  String get questionSaveFailed;

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportTitle;

  /// No description provided for @reportReasonWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'The answer is wrong'**
  String get reportReasonWrongAnswer;

  /// No description provided for @reportReasonUnclear.
  ///
  /// In en, this message translates to:
  /// **'The question is unclear'**
  String get reportReasonUnclear;

  /// No description provided for @reportReasonOutdatedLaw.
  ///
  /// In en, this message translates to:
  /// **'The law has changed'**
  String get reportReasonOutdatedLaw;

  /// No description provided for @reportReasonTypo.
  ///
  /// In en, this message translates to:
  /// **'Typo or wording'**
  String get reportReasonTypo;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reportReasonOther;

  /// No description provided for @reportComment.
  ///
  /// In en, this message translates to:
  /// **'Anything else? (optional)'**
  String get reportComment;

  /// No description provided for @reportSend.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportSend;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Our legal team will check this question.'**
  String get reportSent;

  /// No description provided for @reportAlready.
  ///
  /// In en, this message translates to:
  /// **'You already reported this question.'**
  String get reportAlready;

  /// No description provided for @reportLimit.
  ///
  /// In en, this message translates to:
  /// **'You\'ve sent many reports today. Please try again tomorrow.'**
  String get reportLimit;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// No description provided for @commonLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get commonLater;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWrong;

  /// No description provided for @onbChooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onbChooseLanguage;

  /// No description provided for @onbChooseLanguageSub.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings.'**
  String get onbChooseLanguageSub;

  /// No description provided for @onbSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Law, made simple'**
  String get onbSlide1Title;

  /// No description provided for @onbSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'Bite-sized quizzes on the Constitution, BNS, BNSS and the laws you meet every day.'**
  String get onbSlide1Body;

  /// No description provided for @onbSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Play the Case Path'**
  String get onbSlide2Title;

  /// No description provided for @onbSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'Climb level by level, earn stars, open chests and unlock new chapters.'**
  String get onbSlide2Body;

  /// No description provided for @onbSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Build a daily habit'**
  String get onbSlide3Title;

  /// No description provided for @onbSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'Keep your streak alive, climb weekly court leagues and ask our AI anything legal.'**
  String get onbSlide3Body;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onbGetStarted;

  /// No description provided for @onbBrandTagline.
  ///
  /// In en, this message translates to:
  /// **'Learn Law. Live It.'**
  String get onbBrandTagline;

  /// No description provided for @onbIntro1Title.
  ///
  /// In en, this message translates to:
  /// **'Your Guide to Indian Law'**
  String get onbIntro1Title;

  /// No description provided for @onbIntro1Body.
  ///
  /// In en, this message translates to:
  /// **'Learn with clarity, practise with purpose, and understand the law that shapes your everyday life.'**
  String get onbIntro1Body;

  /// No description provided for @onbIntro2Label.
  ///
  /// In en, this message translates to:
  /// **'Structured learning'**
  String get onbIntro2Label;

  /// No description provided for @onbIntro2Title.
  ///
  /// In en, this message translates to:
  /// **'Learn at Your Own Pace'**
  String get onbIntro2Title;

  /// No description provided for @onbIntro2Body.
  ///
  /// In en, this message translates to:
  /// **'Explore the Constitution, BNS, BNSS, BSA and more with structured lessons, notes and real-world examples.'**
  String get onbIntro2Body;

  /// No description provided for @onbIntro3Label.
  ///
  /// In en, this message translates to:
  /// **'Practice & apply'**
  String get onbIntro3Label;

  /// No description provided for @onbIntro3Title.
  ///
  /// In en, this message translates to:
  /// **'Build Real Understanding'**
  String get onbIntro3Title;

  /// No description provided for @onbIntro3Body.
  ///
  /// In en, this message translates to:
  /// **'Test your knowledge with quizzes, read the latest legal updates, and see how law applies in real life.'**
  String get onbIntro3Body;

  /// No description provided for @onbDemoChapter.
  ///
  /// In en, this message translates to:
  /// **'Fundamental Rights'**
  String get onbDemoChapter;

  /// No description provided for @onbDemoChapterSub.
  ///
  /// In en, this message translates to:
  /// **'Constitution of India · Chapter 3'**
  String get onbDemoChapterSub;

  /// No description provided for @onbDemoProgress.
  ///
  /// In en, this message translates to:
  /// **'5 of 8 lessons completed'**
  String get onbDemoProgress;

  /// No description provided for @onbDemoContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue Learning'**
  String get onbDemoContinue;

  /// No description provided for @onbDemoLesson1.
  ///
  /// In en, this message translates to:
  /// **'Introduction'**
  String get onbDemoLesson1;

  /// No description provided for @onbDemoLesson2.
  ///
  /// In en, this message translates to:
  /// **'Right to Equality'**
  String get onbDemoLesson2;

  /// No description provided for @onbDemoLesson3.
  ///
  /// In en, this message translates to:
  /// **'Right to Freedom'**
  String get onbDemoLesson3;

  /// No description provided for @onbDemoLesson4.
  ///
  /// In en, this message translates to:
  /// **'Right against Exploitation'**
  String get onbDemoLesson4;

  /// No description provided for @onbDemoQuiz.
  ///
  /// In en, this message translates to:
  /// **'Daily Quiz'**
  String get onbDemoQuiz;

  /// No description provided for @onbDemoQuizSub.
  ///
  /// In en, this message translates to:
  /// **'3 of 5 activities'**
  String get onbDemoQuizSub;

  /// No description provided for @onbDemoUpdates.
  ///
  /// In en, this message translates to:
  /// **'Legal Updates'**
  String get onbDemoUpdates;

  /// No description provided for @onbDemoUpdatesSub.
  ///
  /// In en, this message translates to:
  /// **'Stay informed with important judgments and developments.'**
  String get onbDemoUpdatesSub;

  /// No description provided for @onbDemoScenarios.
  ///
  /// In en, this message translates to:
  /// **'Real Life Scenarios'**
  String get onbDemoScenarios;

  /// No description provided for @onbDemoScenariosSub.
  ///
  /// In en, this message translates to:
  /// **'Understand how law works in everyday life.'**
  String get onbDemoScenariosSub;

  /// No description provided for @onbWhoAreYou.
  ///
  /// In en, this message translates to:
  /// **'Who are you learning as?'**
  String get onbWhoAreYou;

  /// No description provided for @onbWhoAreYouSub.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tune difficulty and suggestions for you.'**
  String get onbWhoAreYouSub;

  /// No description provided for @personaAdvocate.
  ///
  /// In en, this message translates to:
  /// **'Advocate'**
  String get personaAdvocate;

  /// No description provided for @personaAdvocateDesc.
  ///
  /// In en, this message translates to:
  /// **'Practising lawyer sharpening recall'**
  String get personaAdvocateDesc;

  /// No description provided for @personaAspirant.
  ///
  /// In en, this message translates to:
  /// **'Law aspirant'**
  String get personaAspirant;

  /// No description provided for @personaAspirantDesc.
  ///
  /// In en, this message translates to:
  /// **'CLAT, AIBE or judiciary prep'**
  String get personaAspirantDesc;

  /// No description provided for @personaCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get personaCitizen;

  /// No description provided for @personaCitizenDesc.
  ///
  /// In en, this message translates to:
  /// **'Know your rights and everyday law'**
  String get personaCitizenDesc;

  /// No description provided for @onbDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Pick a daily goal'**
  String get onbDailyGoal;

  /// No description provided for @onbDailyGoalSub.
  ///
  /// In en, this message translates to:
  /// **'Learners who set a goal are far more likely to stick with it.'**
  String get onbDailyGoalSub;

  /// No description provided for @goalCasual.
  ///
  /// In en, this message translates to:
  /// **'Casual'**
  String get goalCasual;

  /// No description provided for @goalRegular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get goalRegular;

  /// No description provided for @goalSerious.
  ///
  /// In en, this message translates to:
  /// **'Serious'**
  String get goalSerious;

  /// No description provided for @goalQuizzesPerDay.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 quiz a day} other{{count} quizzes a day}}'**
  String goalQuizzesPerDay(int count);

  /// No description provided for @onbYourName.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onbYourName;

  /// No description provided for @onbYourNameSub.
  ///
  /// In en, this message translates to:
  /// **'Shown on the leaderboard.'**
  String get onbYourNameSub;

  /// No description provided for @onbNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get onbNameHint;

  /// No description provided for @onbCommit.
  ///
  /// In en, this message translates to:
  /// **'Commit to my goal'**
  String get onbCommit;

  /// No description provided for @onbReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set, {name}!'**
  String onbReadyTitle(String name);

  /// No description provided for @onbReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Your first case is waiting on the Case Path.'**
  String get onbReadyBody;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @homeContinueJourney.
  ///
  /// In en, this message translates to:
  /// **'Continue your Case Path'**
  String get homeContinueJourney;

  /// No description provided for @homeContinueLeftOff.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off'**
  String get homeContinueLeftOff;

  /// No description provided for @homeChapterLevel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter} · Level {level}'**
  String homeChapterLevel(int chapter, int level);

  /// No description provided for @homeChestReady.
  ///
  /// In en, this message translates to:
  /// **'A chest is waiting for you!'**
  String get homeChestReady;

  /// No description provided for @homeAllDone.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed every chapter. New chapters are coming soon!'**
  String get homeAllDone;

  /// No description provided for @homePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get homePlay;

  /// No description provided for @homeDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get homeDailyGoal;

  /// No description provided for @homeGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {goal} quizzes'**
  String homeGoalProgress(int done, int goal);

  /// No description provided for @homeGoalDone.
  ///
  /// In en, this message translates to:
  /// **'Goal complete — great work!'**
  String get homeGoalDone;

  /// No description provided for @homeStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Start a streak today} =1{1 day streak} other{{count} day streak}}'**
  String homeStreakDays(int count);

  /// No description provided for @homeStreakAtRisk.
  ///
  /// In en, this message translates to:
  /// **'Play one quiz today to keep your streak!'**
  String get homeStreakAtRisk;

  /// No description provided for @homeStreakSafe.
  ///
  /// In en, this message translates to:
  /// **'Streak secured for today'**
  String get homeStreakSafe;

  /// No description provided for @homeModesTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz modes'**
  String get homeModesTitle;

  /// No description provided for @homeLeagueTitle.
  ///
  /// In en, this message translates to:
  /// **'This week\'s league'**
  String get homeLeagueTitle;

  /// No description provided for @homeLeagueRank.
  ///
  /// In en, this message translates to:
  /// **'You\'re #{rank} in {tier}'**
  String homeLeagueRank(int rank, String tier);

  /// No description provided for @homeLeagueEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends in {time}'**
  String homeLeagueEnds(String time);

  /// No description provided for @homeFactTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal fact of the day'**
  String get homeFactTitle;

  /// No description provided for @homeUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest legal updates'**
  String get homeUpdatesTitle;

  /// No description provided for @homeGoPremium.
  ///
  /// In en, this message translates to:
  /// **'Unlock unlimited energy'**
  String get homeGoPremium;

  /// No description provided for @homeGoPremiumSub.
  ///
  /// In en, this message translates to:
  /// **'Nyaya Premium · 7-day free trial'**
  String get homeGoPremiumSub;

  /// No description provided for @modeCasePath.
  ///
  /// In en, this message translates to:
  /// **'Case Path'**
  String get modeCasePath;

  /// No description provided for @modeCasePathDesc.
  ///
  /// In en, this message translates to:
  /// **'Level-by-level journey'**
  String get modeCasePathDesc;

  /// No description provided for @modeDailyDocket.
  ///
  /// In en, this message translates to:
  /// **'Daily Docket'**
  String get modeDailyDocket;

  /// No description provided for @modeDailyDocketDesc.
  ///
  /// In en, this message translates to:
  /// **'5 questions · same for everyone'**
  String get modeDailyDocketDesc;

  /// No description provided for @modeDuel.
  ///
  /// In en, this message translates to:
  /// **'Moot Court Duel'**
  String get modeDuel;

  /// No description provided for @modeDuelDesc.
  ///
  /// In en, this message translates to:
  /// **'1v1 · 7 questions · beat the clock'**
  String get modeDuelDesc;

  /// No description provided for @modeExam.
  ///
  /// In en, this message translates to:
  /// **'Exam Chamber'**
  String get modeExam;

  /// No description provided for @modeExamDesc.
  ///
  /// In en, this message translates to:
  /// **'20 questions · 20 min · negative marking'**
  String get modeExamDesc;

  /// No description provided for @modeExamDescCitizen.
  ///
  /// In en, this message translates to:
  /// **'20 questions · 20 min · know your rights'**
  String get modeExamDescCitizen;

  /// No description provided for @modeFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get modeFree;

  /// No description provided for @modeEnergyCost.
  ///
  /// In en, this message translates to:
  /// **'{count} ⚡'**
  String modeEnergyCost(int count);

  /// No description provided for @docketDoneToday.
  ///
  /// In en, this message translates to:
  /// **'Done for today'**
  String get docketDoneToday;

  /// No description provided for @docketNextIn.
  ///
  /// In en, this message translates to:
  /// **'Next docket in {time}'**
  String docketNextIn(String time);

  /// No description provided for @energyTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energyTitle;

  /// No description provided for @energyLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No energy left} =1{1 energy left} other{{count} energy left}}'**
  String energyLeft(int count);

  /// No description provided for @energyUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get energyUnlimited;

  /// No description provided for @energyOutTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re out of energy'**
  String get energyOutTitle;

  /// No description provided for @energyOutBody.
  ///
  /// In en, this message translates to:
  /// **'Energy refills at midnight — in {time}.'**
  String energyOutBody(String time);

  /// No description provided for @energyRefillCoins.
  ///
  /// In en, this message translates to:
  /// **'Refill 1 ⚡ for {coins} coins'**
  String energyRefillCoins(int coins);

  /// No description provided for @energyGoUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Get unlimited energy'**
  String get energyGoUnlimited;

  /// No description provided for @energyFreeOptions.
  ///
  /// In en, this message translates to:
  /// **'Free things you can still do'**
  String get energyFreeOptions;

  /// No description provided for @energyPlayDocket.
  ///
  /// In en, this message translates to:
  /// **'Play today\'s Daily Docket (free)'**
  String get energyPlayDocket;

  /// No description provided for @energyAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask the AI a legal question'**
  String get energyAskAi;

  /// No description provided for @energyReadUpdates.
  ///
  /// In en, this message translates to:
  /// **'Read legal updates'**
  String get energyReadUpdates;

  /// No description provided for @energyNotEnoughCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins yet — earn them from stars and chests.'**
  String get energyNotEnoughCoins;

  /// No description provided for @energyRefilled.
  ///
  /// In en, this message translates to:
  /// **'+1 energy!'**
  String get energyRefilled;

  /// No description provided for @journeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Case Path'**
  String get journeyTitle;

  /// No description provided for @journeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your journey through Indian law'**
  String get journeySubtitle;

  /// No description provided for @journeyKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going!'**
  String get journeyKeepGoing;

  /// No description provided for @journeyStars.
  ///
  /// In en, this message translates to:
  /// **'{count} ★'**
  String journeyStars(int count);

  /// No description provided for @journeyChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String journeyChapter(int number);

  /// No description provided for @journeyLevel.
  ///
  /// In en, this message translates to:
  /// **'Level {number}'**
  String journeyLevel(int number);

  /// No description provided for @journeyLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark level'**
  String get journeyLandmark;

  /// No description provided for @journeyLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get journeyLocked;

  /// No description provided for @journeyLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Clear the previous level to unlock this one.'**
  String get journeyLockedBody;

  /// No description provided for @journeyQuestions.
  ///
  /// In en, this message translates to:
  /// **'{count} questions'**
  String journeyQuestions(int count);

  /// No description provided for @journeyBestStars.
  ///
  /// In en, this message translates to:
  /// **'Your best'**
  String get journeyBestStars;

  /// No description provided for @journeyReplay.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get journeyReplay;

  /// No description provided for @journeyChest.
  ///
  /// In en, this message translates to:
  /// **'Chapter chest'**
  String get journeyChest;

  /// No description provided for @journeyChestBody.
  ///
  /// In en, this message translates to:
  /// **'You finished the chapter! Open the chest for bonus coins.'**
  String get journeyChestBody;

  /// No description provided for @journeyOpenChest.
  ///
  /// In en, this message translates to:
  /// **'Open chest'**
  String get journeyOpenChest;

  /// No description provided for @journeyChestOpened.
  ///
  /// In en, this message translates to:
  /// **'+{coins} coins!'**
  String journeyChestOpened(int coins);

  /// No description provided for @journeyChestLocked.
  ///
  /// In en, this message translates to:
  /// **'Finish every level in this chapter to open the chest.'**
  String get journeyChestLocked;

  /// No description provided for @journeyJumpToCurrent.
  ///
  /// In en, this message translates to:
  /// **'Jump to current level'**
  String get journeyJumpToCurrent;

  /// No description provided for @journeyYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get journeyYou;

  /// No description provided for @journeyPassHint.
  ///
  /// In en, this message translates to:
  /// **'Score 50% to pass · 80% for 2 stars · 100% for 3 stars'**
  String get journeyPassHint;

  /// No description provided for @quizQuestionOf.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String quizQuestionOf(int current, int total);

  /// No description provided for @quizCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizCorrect;

  /// No description provided for @quizWrong.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get quizWrong;

  /// No description provided for @quizTimeUp.
  ///
  /// In en, this message translates to:
  /// **'Time\'s up'**
  String get quizTimeUp;

  /// No description provided for @quizAnswerWas.
  ///
  /// In en, this message translates to:
  /// **'Answer: {answer}'**
  String quizAnswerWas(String answer);

  /// No description provided for @quizWhy.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get quizWhy;

  /// No description provided for @quizReference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get quizReference;

  /// No description provided for @quizOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Read the official text'**
  String get quizOpenSource;

  /// No description provided for @quizOpenSourceFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get quizOpenSourceFailed;

  /// No description provided for @quizCombo.
  ///
  /// In en, this message translates to:
  /// **'{count}× combo!'**
  String quizCombo(int count);

  /// No description provided for @quizFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get quizFinish;

  /// No description provided for @quizSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit exam'**
  String get quizSubmit;

  /// No description provided for @quizSkipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get quizSkipQuestion;

  /// No description provided for @quizSelectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Select an answer'**
  String get quizSelectAnswer;

  /// No description provided for @quizQuitTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this quiz?'**
  String get quizQuitTitle;

  /// No description provided for @quizQuitBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress in this quiz will be lost.'**
  String get quizQuitBody;

  /// No description provided for @quizQuitBodyRefund.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t answered yet, so your energy will be refunded.'**
  String get quizQuitBodyRefund;

  /// No description provided for @quizQuitStay.
  ///
  /// In en, this message translates to:
  /// **'Keep playing'**
  String get quizQuitStay;

  /// No description provided for @quizQuitLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get quizQuitLeave;

  /// No description provided for @quizLoading.
  ///
  /// In en, this message translates to:
  /// **'Preparing your case…'**
  String get quizLoading;

  /// No description provided for @quizEmpty.
  ///
  /// In en, this message translates to:
  /// **'No questions available here yet.'**
  String get quizEmpty;

  /// No description provided for @quizOpponent.
  ///
  /// In en, this message translates to:
  /// **'Opponent'**
  String get quizOpponent;

  /// No description provided for @quizOpponentAnswered.
  ///
  /// In en, this message translates to:
  /// **'{name} answered in {seconds}s'**
  String quizOpponentAnswered(String name, int seconds);

  /// No description provided for @quizVs.
  ///
  /// In en, this message translates to:
  /// **'VS'**
  String get quizVs;

  /// No description provided for @quizFindingOpponent.
  ///
  /// In en, this message translates to:
  /// **'Finding an opponent…'**
  String get quizFindingOpponent;

  /// No description provided for @quizMarkedAnswers.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String quizMarkedAnswers(int answered, int total);

  /// No description provided for @resultPerfect.
  ///
  /// In en, this message translates to:
  /// **'Perfect case!'**
  String get resultPerfect;

  /// No description provided for @resultGreat.
  ///
  /// In en, this message translates to:
  /// **'Excellent work!'**
  String get resultGreat;

  /// No description provided for @resultGood.
  ///
  /// In en, this message translates to:
  /// **'Level cleared!'**
  String get resultGood;

  /// No description provided for @resultTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get resultTryAgain;

  /// No description provided for @resultTryAgainBody.
  ///
  /// In en, this message translates to:
  /// **'Score at least 50% to clear this level. Review the explanations and try again.'**
  String get resultTryAgainBody;

  /// No description provided for @resultScore.
  ///
  /// In en, this message translates to:
  /// **'{correct}/{total} correct'**
  String resultScore(int correct, int total);

  /// No description provided for @resultAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get resultAccuracy;

  /// No description provided for @resultXp.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get resultXp;

  /// No description provided for @resultCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get resultCoins;

  /// No description provided for @resultTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get resultTime;

  /// No description provided for @resultStreakExtended.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Your streak has started — day 1!} other{Streak extended to {count} days!}}'**
  String resultStreakExtended(int count);

  /// No description provided for @resultMilestone.
  ///
  /// In en, this message translates to:
  /// **'{count}-day streak milestone!'**
  String resultMilestone(int count);

  /// No description provided for @resultGoalReached.
  ///
  /// In en, this message translates to:
  /// **'Daily goal reached!'**
  String get resultGoalReached;

  /// No description provided for @resultEnergyBonus.
  ///
  /// In en, this message translates to:
  /// **'3-star bonus: +{count} ⚡'**
  String resultEnergyBonus(int count);

  /// No description provided for @resultLeagueUp.
  ///
  /// In en, this message translates to:
  /// **'You climbed to #{rank} in your league'**
  String resultLeagueUp(int rank);

  /// No description provided for @resultReview.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get resultReview;

  /// No description provided for @resultNextLevel.
  ///
  /// In en, this message translates to:
  /// **'Next level'**
  String get resultNextLevel;

  /// No description provided for @resultBackToMap.
  ///
  /// In en, this message translates to:
  /// **'Back to map'**
  String get resultBackToMap;

  /// No description provided for @resultBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back home'**
  String get resultBackHome;

  /// No description provided for @resultPlayAgain.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get resultPlayAgain;

  /// No description provided for @resultExamScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score} / {max}'**
  String resultExamScore(String score, int max);

  /// No description provided for @resultExamBreakdown.
  ///
  /// In en, this message translates to:
  /// **'{correct} correct · {wrong} wrong · {skipped} skipped'**
  String resultExamBreakdown(int correct, int wrong, int skipped);

  /// No description provided for @resultDuelWon.
  ///
  /// In en, this message translates to:
  /// **'You won the duel!'**
  String get resultDuelWon;

  /// No description provided for @resultDuelLost.
  ///
  /// In en, this message translates to:
  /// **'Close fight!'**
  String get resultDuelLost;

  /// No description provided for @resultDuelDraw.
  ///
  /// In en, this message translates to:
  /// **'It\'s a draw!'**
  String get resultDuelDraw;

  /// No description provided for @resultDuelPoints.
  ///
  /// In en, this message translates to:
  /// **'{you} vs {them}'**
  String resultDuelPoints(int you, int them);

  /// No description provided for @resultDocketShare.
  ///
  /// In en, this message translates to:
  /// **'Share result'**
  String get resultDocketShare;

  /// No description provided for @resultYourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get resultYourAnswer;

  /// No description provided for @resultCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get resultCorrectAnswer;

  /// No description provided for @resultSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get resultSkipped;

  /// No description provided for @leaderboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly league'**
  String get leaderboardWeekly;

  /// No description provided for @leaderboardAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get leaderboardAllTime;

  /// No description provided for @leaderboardPromotionZone.
  ///
  /// In en, this message translates to:
  /// **'Promotion zone'**
  String get leaderboardPromotionZone;

  /// No description provided for @leaderboardDemotionZone.
  ///
  /// In en, this message translates to:
  /// **'Demotion zone'**
  String get leaderboardDemotionZone;

  /// No description provided for @leaderboardEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Week ends in {time}'**
  String leaderboardEndsIn(String time);

  /// No description provided for @leaderboardTopPromote.
  ///
  /// In en, this message translates to:
  /// **'Top {count} move up to {tier}'**
  String leaderboardTopPromote(int count, String tier);

  /// No description provided for @leaderboardNoDemotion.
  ///
  /// In en, this message translates to:
  /// **'No demotion in this league — just keep learning!'**
  String get leaderboardNoDemotion;

  /// No description provided for @leaderboardEarnToJoin.
  ///
  /// In en, this message translates to:
  /// **'Finish a quiz this week to join a league.'**
  String get leaderboardEarnToJoin;

  /// No description provided for @leaderboardXp.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP'**
  String leaderboardXp(int xp);

  /// League row label for a simulated player that tops up a small group
  ///
  /// In en, this message translates to:
  /// **'Practice player'**
  String get leaderboardPractice;

  /// No description provided for @leaderboardYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get leaderboardYou;

  /// No description provided for @leaderboardTiers.
  ///
  /// In en, this message translates to:
  /// **'League tiers'**
  String get leaderboardTiers;

  /// No description provided for @leagueOutcomePromoted.
  ///
  /// In en, this message translates to:
  /// **'Promoted to {tier}!'**
  String leagueOutcomePromoted(String tier);

  /// No description provided for @leagueOutcomeDemoted.
  ///
  /// In en, this message translates to:
  /// **'Moved to {tier}'**
  String leagueOutcomeDemoted(String tier);

  /// No description provided for @leagueOutcomeStayed.
  ///
  /// In en, this message translates to:
  /// **'You stayed in {tier}'**
  String leagueOutcomeStayed(String tier);

  /// No description provided for @leagueOutcomeRank.
  ///
  /// In en, this message translates to:
  /// **'You finished #{rank} last week.'**
  String leagueOutcomeRank(int rank);

  /// No description provided for @tier_nyayaPanchayat.
  ///
  /// In en, this message translates to:
  /// **'Nyaya Panchayat'**
  String get tier_nyayaPanchayat;

  /// No description provided for @tier_gramNyayalaya.
  ///
  /// In en, this message translates to:
  /// **'Gram Nyayalaya'**
  String get tier_gramNyayalaya;

  /// No description provided for @tier_munsiffCourt.
  ///
  /// In en, this message translates to:
  /// **'Munsiff Court'**
  String get tier_munsiffCourt;

  /// No description provided for @tier_magistrateCourt.
  ///
  /// In en, this message translates to:
  /// **'Magistrate Court'**
  String get tier_magistrateCourt;

  /// No description provided for @tier_districtCourt.
  ///
  /// In en, this message translates to:
  /// **'District Court'**
  String get tier_districtCourt;

  /// No description provided for @tier_sessionsCourt.
  ///
  /// In en, this message translates to:
  /// **'Sessions Court'**
  String get tier_sessionsCourt;

  /// No description provided for @tier_highCourt.
  ///
  /// In en, this message translates to:
  /// **'High Court'**
  String get tier_highCourt;

  /// No description provided for @tier_supremeCourt.
  ///
  /// In en, this message translates to:
  /// **'Supreme Court'**
  String get tier_supremeCourt;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Nyaya AI'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your legal information assistant'**
  String get chatSubtitle;

  /// No description provided for @chatDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'General legal information, not legal advice. For your specific case, consult an advocate or call NALSA\'s helpline 15100.'**
  String get chatDisclaimer;

  /// No description provided for @chatHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about any Indian law…'**
  String get chatHint;

  /// No description provided for @chatWelcome.
  ///
  /// In en, this message translates to:
  /// **'Namaste! I can explain Indian laws, your rights, legal procedures and the new criminal laws (BNS, BNSS, BSA). What would you like to know?'**
  String get chatWelcome;

  /// No description provided for @chatSuggest1.
  ///
  /// In en, this message translates to:
  /// **'What is a Zero FIR?'**
  String get chatSuggest1;

  /// No description provided for @chatSuggest2.
  ///
  /// In en, this message translates to:
  /// **'My rights if I am arrested'**
  String get chatSuggest2;

  /// No description provided for @chatSuggest3.
  ///
  /// In en, this message translates to:
  /// **'How do I file an RTI?'**
  String get chatSuggest3;

  /// No description provided for @chatSuggest4.
  ///
  /// In en, this message translates to:
  /// **'How to file a consumer complaint?'**
  String get chatSuggest4;

  /// No description provided for @chatThinking.
  ///
  /// In en, this message translates to:
  /// **'Researching the law…'**
  String get chatThinking;

  /// No description provided for @chatLimitLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 free question left today} other{{count} free questions left today}}'**
  String chatLimitLeft(int count);

  /// No description provided for @chatLimitReached.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s free questions. Come back tomorrow or go Premium for unlimited AI.'**
  String get chatLimitReached;

  /// No description provided for @chatLimitReachedToday.
  ///
  /// In en, this message translates to:
  /// **'You\'ve used today\'s questions. You can ask more tomorrow.'**
  String get chatLimitReachedToday;

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t reach the AI right now. Please check your connection and try again.'**
  String get chatError;

  /// No description provided for @chatOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'Offline mode — connect an AI key for full answers.'**
  String get chatOfflineNote;

  /// No description provided for @chatClear.
  ///
  /// In en, this message translates to:
  /// **'Clear chat'**
  String get chatClear;

  /// No description provided for @chatCopy.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chatCopy;

  /// No description provided for @updatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal Updates'**
  String get updatesTitle;

  /// No description provided for @updatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Judgments, new laws and explainers'**
  String get updatesSubtitle;

  /// No description provided for @updatesAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get updatesAll;

  /// No description provided for @updatesSupremeCourt.
  ///
  /// In en, this message translates to:
  /// **'Supreme Court'**
  String get updatesSupremeCourt;

  /// No description provided for @updatesHighCourts.
  ///
  /// In en, this message translates to:
  /// **'High Courts'**
  String get updatesHighCourts;

  /// No description provided for @updatesLegislation.
  ///
  /// In en, this message translates to:
  /// **'Legislation'**
  String get updatesLegislation;

  /// No description provided for @updatesExplainer.
  ///
  /// In en, this message translates to:
  /// **'Explainers'**
  String get updatesExplainer;

  /// No description provided for @updatesReadTime.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min read'**
  String updatesReadTime(int minutes);

  /// No description provided for @updatesKeyPoints.
  ///
  /// In en, this message translates to:
  /// **'Key points'**
  String get updatesKeyPoints;

  /// No description provided for @updatesWhyItMatters.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get updatesWhyItMatters;

  /// No description provided for @updatesSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get updatesSource;

  /// No description provided for @updatesAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI about this'**
  String get updatesAskAi;

  /// No description provided for @updatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No updates in this category yet.'**
  String get updatesEmpty;

  /// No description provided for @updatesSave.
  ///
  /// In en, this message translates to:
  /// **'Save update'**
  String get updatesSave;

  /// No description provided for @updatesUnsave.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get updatesUnsave;

  /// No description provided for @updatesInEnglish.
  ///
  /// In en, this message translates to:
  /// **'Shown in English'**
  String get updatesInEnglish;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get settingsEditName;

  /// No description provided for @settingsLearningAs.
  ///
  /// In en, this message translates to:
  /// **'Learning as'**
  String get settingsLearningAs;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get settingsDailyGoal;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSound;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get settingsReminders;

  /// No description provided for @settingsRemindersSub.
  ///
  /// In en, this message translates to:
  /// **'A nudge to keep your streak alive'**
  String get settingsRemindersSub;

  /// No description provided for @settingsStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get settingsStore;

  /// No description provided for @settingsStreakFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze'**
  String get settingsStreakFreeze;

  /// No description provided for @settingsStreakFreezeSub.
  ///
  /// In en, this message translates to:
  /// **'Protects your streak if you miss a day · {owned}/{max} equipped'**
  String settingsStreakFreezeSub(int owned, int max);

  /// No description provided for @settingsBuyFor.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String settingsBuyFor(int coins);

  /// No description provided for @settingsFreezeBought.
  ///
  /// In en, this message translates to:
  /// **'Streak freeze equipped!'**
  String get settingsFreezeBought;

  /// No description provided for @settingsFreezeFull.
  ///
  /// In en, this message translates to:
  /// **'You already have the maximum freezes equipped.'**
  String get settingsFreezeFull;

  /// No description provided for @settingsPremium.
  ///
  /// In en, this message translates to:
  /// **'Nyaya Premium'**
  String get settingsPremium;

  /// No description provided for @settingsPremiumActive.
  ///
  /// In en, this message translates to:
  /// **'Premium active'**
  String get settingsPremiumActive;

  /// No description provided for @settingsPremiumUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get settingsPremiumUpgrade;

  /// No description provided for @settingsStats.
  ///
  /// In en, this message translates to:
  /// **'Your stats'**
  String get settingsStats;

  /// No description provided for @settingsTotalXp.
  ///
  /// In en, this message translates to:
  /// **'Total XP'**
  String get settingsTotalXp;

  /// No description provided for @settingsLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get settingsLongestStreak;

  /// No description provided for @settingsQuizzes.
  ///
  /// In en, this message translates to:
  /// **'Quizzes'**
  String get settingsQuizzes;

  /// No description provided for @settingsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get settingsAccuracy;

  /// No description provided for @settingsDuelRecord.
  ///
  /// In en, this message translates to:
  /// **'Duels won'**
  String get settingsDuelRecord;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Legal disclaimer'**
  String get settingsDisclaimer;

  /// No description provided for @settingsDisclaimerBody.
  ///
  /// In en, this message translates to:
  /// **'Nyaya is an educational app. Questions, explanations, updates and AI answers are general information and are not legal advice. Laws change — always verify with the official Gazette or consult an advocate.'**
  String get settingsDisclaimerBody;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Your progress is saved to your account, along with the days you open the app, so we can see whether people come back. Questions you ask the AI are sent to our AI provider only to write the answer. If the app crashes, a short technical report (no answers or personal details) is sent to help us fix it. You can delete your account in Settings.'**
  String get settingsPrivacyBody;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get settingsReset;

  /// No description provided for @settingsResetConfirm.
  ///
  /// In en, this message translates to:
  /// **'This erases coins, energy and settings on this device. XP, stars and streaks are saved to your account and stay. This cannot be undone.'**
  String get settingsResetConfirm;

  /// No description provided for @settingsResetAction.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get settingsResetAction;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Nyaya Premium'**
  String get premiumTitle;

  /// No description provided for @premiumHeadline.
  ///
  /// In en, this message translates to:
  /// **'Learn without limits'**
  String get premiumHeadline;

  /// No description provided for @premiumBenefitEnergy.
  ///
  /// In en, this message translates to:
  /// **'Unlimited energy'**
  String get premiumBenefitEnergy;

  /// No description provided for @premiumBenefitEnergySub.
  ///
  /// In en, this message translates to:
  /// **'Play as many quizzes as you like'**
  String get premiumBenefitEnergySub;

  /// No description provided for @premiumBenefitAi.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Nyaya AI'**
  String get premiumBenefitAi;

  /// No description provided for @premiumBenefitAiSub.
  ///
  /// In en, this message translates to:
  /// **'Ask every legal question you have'**
  String get premiumBenefitAiSub;

  /// No description provided for @premiumBenefitFreeze.
  ///
  /// In en, this message translates to:
  /// **'Streak freezes included'**
  String get premiumBenefitFreeze;

  /// No description provided for @premiumBenefitFreezeSub.
  ///
  /// In en, this message translates to:
  /// **'Never lose your streak to a busy day'**
  String get premiumBenefitFreezeSub;

  /// No description provided for @premiumBenefitExam.
  ///
  /// In en, this message translates to:
  /// **'Full mock exams'**
  String get premiumBenefitExam;

  /// No description provided for @premiumBenefitExamSub.
  ///
  /// In en, this message translates to:
  /// **'CLAT, AIBE & judiciary-style practice'**
  String get premiumBenefitExamSub;

  /// No description provided for @premiumFair.
  ///
  /// In en, this message translates to:
  /// **'Fair play: Premium never boosts league XP.'**
  String get premiumFair;

  /// No description provided for @premiumYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get premiumYearly;

  /// No description provided for @premiumMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get premiumMonthly;

  /// No description provided for @premiumYearlyPrice.
  ///
  /// In en, this message translates to:
  /// **'₹999 / year'**
  String get premiumYearlyPrice;

  /// No description provided for @premiumMonthlyPrice.
  ///
  /// In en, this message translates to:
  /// **'₹149 / month'**
  String get premiumMonthlyPrice;

  /// No description provided for @premiumPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Just ₹83 / month'**
  String get premiumPerMonth;

  /// No description provided for @premiumSave.
  ///
  /// In en, this message translates to:
  /// **'Save 44%'**
  String get premiumSave;

  /// No description provided for @premiumBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get premiumBestValue;

  /// No description provided for @premiumStartTrial.
  ///
  /// In en, this message translates to:
  /// **'Start 7-day free trial'**
  String get premiumStartTrial;

  /// No description provided for @premiumTrialNote.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime before the trial ends and you won\'t be charged.'**
  String get premiumTrialNote;

  /// No description provided for @premiumRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get premiumRestore;

  /// No description provided for @premiumActivated.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Nyaya Premium!'**
  String get premiumActivated;

  /// No description provided for @premiumAlready.
  ///
  /// In en, this message translates to:
  /// **'You\'re a Premium member'**
  String get premiumAlready;

  /// No description provided for @premiumNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No previous purchase found.'**
  String get premiumNothingToRestore;

  /// No description provided for @statXp.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get statXp;

  /// No description provided for @statStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statStreak;

  /// No description provided for @statCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get statCoins;

  /// No description provided for @statEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get statEnergy;

  /// No description provided for @statStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get statStars;

  /// No description provided for @exploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore Law'**
  String get exploreTitle;

  /// No description provided for @exploreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Build your understanding of Indian law'**
  String get exploreSubtitle;

  /// No description provided for @exploreStartHere.
  ///
  /// In en, this message translates to:
  /// **'Start here'**
  String get exploreStartHere;

  /// No description provided for @exploreFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get exploreFeatured;

  /// No description provided for @exploreButton.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get exploreButton;

  /// No description provided for @exploreCoreLaws.
  ///
  /// In en, this message translates to:
  /// **'Core Laws'**
  String get exploreCoreLaws;

  /// No description provided for @exploreViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get exploreViewAll;

  /// No description provided for @exploreLegacy.
  ///
  /// In en, this message translates to:
  /// **'Legacy'**
  String get exploreLegacy;

  /// No description provided for @exploreAskAi.
  ///
  /// In en, this message translates to:
  /// **'Ask AI'**
  String get exploreAskAi;

  /// No description provided for @exploreAskPrompt.
  ///
  /// In en, this message translates to:
  /// **'Explain the {law} in simple terms: what it covers and the key provisions I should know.'**
  String exploreAskPrompt(String law);

  /// No description provided for @lawConstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Constitution of India'**
  String get lawConstitutionTitle;

  /// No description provided for @lawConstitutionDesc.
  ///
  /// In en, this message translates to:
  /// **'Fundamental rights, directive principles, duties and more.'**
  String get lawConstitutionDesc;

  /// No description provided for @lawBnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bharatiya Nyaya Sanhita (BNS)'**
  String get lawBnsTitle;

  /// No description provided for @lawBnsShort.
  ///
  /// In en, this message translates to:
  /// **'Bharatiya Nyaya Sanhita'**
  String get lawBnsShort;

  /// No description provided for @lawBnsDesc.
  ///
  /// In en, this message translates to:
  /// **'Substantive criminal law'**
  String get lawBnsDesc;

  /// No description provided for @lawBnsFeatured.
  ///
  /// In en, this message translates to:
  /// **'Offences and punishments under India\'s new criminal code.'**
  String get lawBnsFeatured;

  /// No description provided for @lawBnssTitle.
  ///
  /// In en, this message translates to:
  /// **'Bharatiya Nagarik Suraksha Sanhita (BNSS)'**
  String get lawBnssTitle;

  /// No description provided for @lawBnssDesc.
  ///
  /// In en, this message translates to:
  /// **'Criminal procedure law'**
  String get lawBnssDesc;

  /// No description provided for @lawBsaTitle.
  ///
  /// In en, this message translates to:
  /// **'Bharatiya Sakshya Adhiniyam (BSA)'**
  String get lawBsaTitle;

  /// No description provided for @lawBsaDesc.
  ///
  /// In en, this message translates to:
  /// **'Law of evidence'**
  String get lawBsaDesc;

  /// No description provided for @lawEverydayTitle.
  ///
  /// In en, this message translates to:
  /// **'Everyday Law'**
  String get lawEverydayTitle;

  /// No description provided for @lawEverydayDesc.
  ///
  /// In en, this message translates to:
  /// **'Know your rights in daily life'**
  String get lawEverydayDesc;

  /// No description provided for @lawEverydayFeatured.
  ///
  /// In en, this message translates to:
  /// **'Consumer, tenancy, workplace and family rights, explained simply.'**
  String get lawEverydayFeatured;

  /// No description provided for @lawLegacyTitle.
  ///
  /// In en, this message translates to:
  /// **'IPC & CrPC (Legacy)'**
  String get lawLegacyTitle;

  /// No description provided for @lawLegacyDesc.
  ///
  /// In en, this message translates to:
  /// **'Older laws for reference'**
  String get lawLegacyDesc;

  /// No description provided for @chapterConstitutionTitle.
  ///
  /// In en, this message translates to:
  /// **'Constitution Basics'**
  String get chapterConstitutionTitle;

  /// No description provided for @chapterConstitutionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Preamble, Parliament, courts, amendments'**
  String get chapterConstitutionSubtitle;

  /// No description provided for @chapterRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Rights & Duties'**
  String get chapterRightsTitle;

  /// No description provided for @chapterRightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fundamental Rights, DPSP and writs'**
  String get chapterRightsSubtitle;

  /// No description provided for @chapterCriminalTitle.
  ///
  /// In en, this message translates to:
  /// **'Criminal Law (BNS)'**
  String get chapterCriminalTitle;

  /// No description provided for @chapterCriminalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Offences under the new Sanhita'**
  String get chapterCriminalSubtitle;

  /// No description provided for @chapterProcedureTitle.
  ///
  /// In en, this message translates to:
  /// **'Procedure & Evidence'**
  String get chapterProcedureTitle;

  /// No description provided for @chapterProcedureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'BNSS, BSA, FIR, arrest, bail'**
  String get chapterProcedureSubtitle;

  /// No description provided for @chapterCivilTitle.
  ///
  /// In en, this message translates to:
  /// **'Contracts & Consumers'**
  String get chapterCivilTitle;

  /// No description provided for @chapterCivilSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contracts, consumer rights, remedies'**
  String get chapterCivilSubtitle;

  /// No description provided for @chapterEverydayTitle.
  ///
  /// In en, this message translates to:
  /// **'Everyday Law'**
  String get chapterEverydayTitle;

  /// No description provided for @chapterEverydaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Law for daily life'**
  String get chapterEverydaySubtitle;

  /// No description provided for @authCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your free account'**
  String get authCreateTitle;

  /// No description provided for @authCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Questions come from Nyaya\'s reviewed library, and your results are saved to your account.'**
  String get authCreateSubtitle;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep practising.'**
  String get authSignInSubtitle;

  /// No description provided for @authName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authName;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get authPasswordHint;

  /// No description provided for @authCreate.
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get authCreate;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get authSignIn;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get authHaveAccount;

  /// No description provided for @authNeedAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get authNeedAccount;

  /// No description provided for @authErrorCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authErrorCredentials;

  /// No description provided for @authErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. Sign in instead.'**
  String get authErrorEmailTaken;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Nyaya right now. Check your connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a minute and try again.'**
  String get authErrorRateLimited;

  /// No description provided for @authErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email and a password of at least 8 characters.'**
  String get authErrorInvalid;

  /// No description provided for @authErrorName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get authErrorName;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {email}'**
  String settingsSignedInAs(String email);

  /// No description provided for @settingsSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create an account'**
  String get settingsSignIn;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and everything on it: progress, XP, coins, saved questions and your league place. It cannot be undone. Enter your password to confirm.'**
  String get settingsDeleteAccountBody;

  /// No description provided for @settingsDeleteAccountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsDeleteAccountPassword;

  /// No description provided for @settingsDeleteAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get settingsDeleteAccountAction;

  /// No description provided for @settingsDeleteAccountWrong.
  ///
  /// In en, this message translates to:
  /// **'That password is not right.'**
  String get settingsDeleteAccountWrong;

  /// No description provided for @settingsDeleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the account. Check your connection and try again.'**
  String get settingsDeleteAccountFailed;

  /// No description provided for @quizSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your answer. Check your connection and tap again.'**
  String get quizSendFailed;

  /// No description provided for @quizSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your result. Check your connection.'**
  String get quizSubmitFailed;

  /// No description provided for @quizRetry.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get quizRetry;

  /// No description provided for @quizScoring.
  ///
  /// In en, this message translates to:
  /// **'Scoring your case…'**
  String get quizScoring;

  /// No description provided for @quizOffline.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach Nyaya. Check your connection and try again.'**
  String get quizOffline;

  /// No description provided for @quizSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Sign in again to play.'**
  String get quizSignedOut;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'hi',
    'kn',
    'ml',
    'ta',
    'te',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
