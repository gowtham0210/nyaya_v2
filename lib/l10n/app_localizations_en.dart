// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nyaya';

  @override
  String get appTagline => 'Learn Indian law, one case a day';

  @override
  String get navHome => 'Home';

  @override
  String get navJourney => 'Journey';

  @override
  String get navAskAi => 'Ask AI';

  @override
  String get navUpdates => 'Updates';

  @override
  String get commonContinue => 'Continue';

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
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonClose => 'Close';

  @override
  String get commonStart => 'Start';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonLater => 'Maybe later';

  @override
  String get commonOk => 'OK';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonSomethingWrong => 'Something went wrong. Please try again.';

  @override
  String get onbChooseLanguage => 'Choose your language';

  @override
  String get onbChooseLanguageSub => 'You can change this anytime in Settings.';

  @override
  String get onbSlide1Title => 'Law, made simple';

  @override
  String get onbSlide1Body =>
      'Bite-sized quizzes on the Constitution, BNS, BNSS and the laws you meet every day.';

  @override
  String get onbSlide2Title => 'Play the Case Path';

  @override
  String get onbSlide2Body =>
      'Climb level by level, earn stars, open chests and unlock new chapters.';

  @override
  String get onbSlide3Title => 'Build a daily habit';

  @override
  String get onbSlide3Body =>
      'Keep your streak alive, climb weekly court leagues and ask our AI anything legal.';

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
  String get onbWhoAreYou => 'Who are you learning as?';

  @override
  String get onbWhoAreYouSub =>
      'We\'ll tune difficulty and suggestions for you.';

  @override
  String get personaAdvocate => 'Advocate';

  @override
  String get personaAdvocateDesc => 'Practising lawyer sharpening recall';

  @override
  String get personaAspirant => 'Law aspirant';

  @override
  String get personaAspirantDesc => 'CLAT, AIBE or judiciary prep';

  @override
  String get personaCitizen => 'Citizen';

  @override
  String get personaCitizenDesc => 'Know your rights and everyday law';

  @override
  String get onbDailyGoal => 'Pick a daily goal';

  @override
  String get onbDailyGoalSub =>
      'Learners who set a goal are far more likely to stick with it.';

  @override
  String get goalCasual => 'Casual';

  @override
  String get goalRegular => 'Regular';

  @override
  String get goalSerious => 'Serious';

  @override
  String goalQuizzesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count quizzes a day',
      one: '1 quiz a day',
    );
    return '$_temp0';
  }

  @override
  String get onbYourName => 'What should we call you?';

  @override
  String get onbYourNameSub => 'Shown on the leaderboard.';

  @override
  String get onbNameHint => 'Your name';

  @override
  String get onbCommit => 'Commit to my goal';

  @override
  String onbReadyTitle(String name) {
    return 'You\'re all set, $name!';
  }

  @override
  String get onbReadyBody => 'Your first case is waiting on the Case Path.';

  @override
  String get greetingMorning => 'Good morning';

  @override
  String get greetingAfternoon => 'Good afternoon';

  @override
  String get greetingEvening => 'Good evening';

  @override
  String get homeContinueJourney => 'Continue your Case Path';

  @override
  String get homeContinueLeftOff => 'Continue where you left off';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'Chapter $chapter · Level $level';
  }

  @override
  String get homeChestReady => 'A chest is waiting for you!';

  @override
  String get homeAllDone =>
      'You\'ve completed every chapter. New chapters are coming soon!';

  @override
  String get homePlay => 'Play';

  @override
  String get homeDailyGoal => 'Daily goal';

  @override
  String homeGoalProgress(int done, int goal) {
    return '$done of $goal quizzes';
  }

  @override
  String get homeGoalDone => 'Goal complete — great work!';

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
      zero: 'Start a streak today',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakAtRisk => 'Play one quiz today to keep your streak!';

  @override
  String get homeStreakSafe => 'Streak secured for today';

  @override
  String get homeModesTitle => 'Quiz modes';

  @override
  String get homeLeagueTitle => 'This week\'s league';

  @override
  String homeLeagueRank(int rank, String tier) {
    return 'You\'re #$rank in $tier';
  }

  @override
  String homeLeagueEnds(String time) {
    return 'Ends in $time';
  }

  @override
  String get homeFactTitle => 'Legal fact of the day';

  @override
  String get homeUpdatesTitle => 'Latest legal updates';

  @override
  String get homeGoPremium => 'Unlock unlimited energy';

  @override
  String get homeGoPremiumSub => 'Nyaya Premium · 7-day free trial';

  @override
  String get modeCasePath => 'Case Path';

  @override
  String get modeCasePathDesc => 'Level-by-level journey';

  @override
  String get modeDailyDocket => 'Daily Docket';

  @override
  String get modeDailyDocketDesc => '5 questions · same for everyone';

  @override
  String get modeDuel => 'Moot Court Duel';

  @override
  String get modeDuelDesc => '1v1 · 7 questions · beat the clock';

  @override
  String get modeExam => 'Exam Chamber';

  @override
  String get modeExamDesc => '20 questions · 20 min · negative marking';

  @override
  String get modeExamDescCitizen => '20 questions · 20 min · know your rights';

  @override
  String get modeFree => 'Free';

  @override
  String modeEnergyCost(int count) {
    return '$count ⚡';
  }

  @override
  String get docketDoneToday => 'Done for today';

  @override
  String docketNextIn(String time) {
    return 'Next docket in $time';
  }

  @override
  String get energyTitle => 'Energy';

  @override
  String energyLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count energy left',
      one: '1 energy left',
      zero: 'No energy left',
    );
    return '$_temp0';
  }

  @override
  String get energyUnlimited => 'Unlimited';

  @override
  String get energyOutTitle => 'You\'re out of energy';

  @override
  String energyOutBody(String time) {
    return 'Energy refills at midnight — in $time.';
  }

  @override
  String energyRefillCoins(int coins) {
    return 'Refill 1 ⚡ for $coins coins';
  }

  @override
  String get energyGoUnlimited => 'Get unlimited energy';

  @override
  String get energyFreeOptions => 'Free things you can still do';

  @override
  String get energyPlayDocket => 'Play today\'s Daily Docket (free)';

  @override
  String get energyAskAi => 'Ask the AI a legal question';

  @override
  String get energyReadUpdates => 'Read legal updates';

  @override
  String get energyNotEnoughCoins =>
      'Not enough coins yet — earn them from stars and chests.';

  @override
  String get energyRefilled => '+1 energy!';

  @override
  String get journeyTitle => 'Case Path';

  @override
  String get journeySubtitle => 'Your journey through Indian law';

  @override
  String get journeyKeepGoing => 'Keep going!';

  @override
  String get journeyQuote =>
      'Small steps build a stronger understanding of the law.';

  @override
  String journeyStars(int count) {
    return '$count ★';
  }

  @override
  String journeyChapter(int number) {
    return 'Chapter $number';
  }

  @override
  String journeyLevel(int number) {
    return 'Level $number';
  }

  @override
  String get journeyLandmark => 'Landmark level';

  @override
  String get journeyLocked => 'Locked';

  @override
  String get journeyLockedBody =>
      'Clear the previous level to unlock this one.';

  @override
  String journeyQuestions(int count) {
    return '$count questions';
  }

  @override
  String get journeyBestStars => 'Your best';

  @override
  String get journeyReplay => 'Replay';

  @override
  String get journeyChest => 'Chapter chest';

  @override
  String get journeyChestBody =>
      'You finished the chapter! Open the chest for bonus coins.';

  @override
  String get journeyOpenChest => 'Open chest';

  @override
  String journeyChestOpened(int coins) {
    return '+$coins coins!';
  }

  @override
  String get journeyChestLocked =>
      'Finish every level in this chapter to open the chest.';

  @override
  String get journeyJumpToCurrent => 'Jump to current level';

  @override
  String get journeyYou => 'You';

  @override
  String get journeyPassHint =>
      'Score 50% to pass · 80% for 2 stars · 100% for 3 stars';

  @override
  String quizQuestionOf(int current, int total) {
    return 'Question $current of $total';
  }

  @override
  String get quizCorrect => 'Correct!';

  @override
  String get quizWrong => 'Not quite';

  @override
  String get quizTimeUp => 'Time\'s up';

  @override
  String quizAnswerWas(String answer) {
    return 'Answer: $answer';
  }

  @override
  String get quizWhy => 'Why';

  @override
  String get quizReference => 'Reference';

  @override
  String get quizOpenSource => 'Read the official text';

  @override
  String get quizOpenSourceFailed => 'Couldn\'t open the link';

  @override
  String quizCombo(int count) {
    return '$count× combo!';
  }

  @override
  String get quizFinish => 'Finish';

  @override
  String get quizSubmit => 'Submit exam';

  @override
  String get quizSkipQuestion => 'Skip';

  @override
  String get quizSelectAnswer => 'Select an answer';

  @override
  String get quizQuitTitle => 'Leave this quiz?';

  @override
  String get quizQuitBody => 'Your progress in this quiz will be lost.';

  @override
  String get quizQuitBodyRefund =>
      'You haven\'t answered yet, so your energy will be refunded.';

  @override
  String get quizQuitStay => 'Keep playing';

  @override
  String get quizQuitLeave => 'Leave';

  @override
  String get quizLoading => 'Preparing your case…';

  @override
  String get quizEmpty => 'No questions available here yet.';

  @override
  String get quizOpponent => 'Opponent';

  @override
  String quizOpponentAnswered(String name, int seconds) {
    return '$name answered in ${seconds}s';
  }

  @override
  String get quizVs => 'VS';

  @override
  String get quizFindingOpponent => 'Finding an opponent…';

  @override
  String quizMarkedAnswers(int answered, int total) {
    return '$answered of $total answered';
  }

  @override
  String get resultPerfect => 'Perfect case!';

  @override
  String get resultGreat => 'Excellent work!';

  @override
  String get resultGood => 'Level cleared!';

  @override
  String get resultTryAgain => 'Almost there';

  @override
  String get resultTryAgainBody =>
      'Score at least 50% to clear this level. Review the explanations and try again.';

  @override
  String resultScore(int correct, int total) {
    return '$correct/$total correct';
  }

  @override
  String get resultAccuracy => 'Accuracy';

  @override
  String get resultXp => 'XP';

  @override
  String get resultCoins => 'Coins';

  @override
  String get resultTime => 'Time';

  @override
  String resultStreakExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Streak extended to $count days!',
      one: 'Your streak has started — day 1!',
    );
    return '$_temp0';
  }

  @override
  String resultMilestone(int count) {
    return '$count-day streak milestone!';
  }

  @override
  String get resultGoalReached => 'Daily goal reached!';

  @override
  String resultEnergyBonus(int count) {
    return '3-star bonus: +$count ⚡';
  }

  @override
  String resultLeagueUp(int rank) {
    return 'You climbed to #$rank in your league';
  }

  @override
  String get resultReview => 'Review answers';

  @override
  String get resultNextLevel => 'Next level';

  @override
  String get resultBackToMap => 'Back to map';

  @override
  String get resultBackHome => 'Back home';

  @override
  String get resultPlayAgain => 'Play again';

  @override
  String resultExamScore(String score, int max) {
    return 'Score: $score / $max';
  }

  @override
  String resultExamBreakdown(int correct, int wrong, int skipped) {
    return '$correct correct · $wrong wrong · $skipped skipped';
  }

  @override
  String get resultDuelWon => 'You won the duel!';

  @override
  String get resultDuelLost => 'Close fight!';

  @override
  String get resultDuelDraw => 'It\'s a draw!';

  @override
  String resultDuelPoints(int you, int them) {
    return '$you vs $them';
  }

  @override
  String get resultDocketShare => 'Share result';

  @override
  String get resultYourAnswer => 'Your answer';

  @override
  String get resultCorrectAnswer => 'Correct answer';

  @override
  String get resultSkipped => 'Skipped';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardWeekly => 'Weekly league';

  @override
  String get leaderboardAllTime => 'All time';

  @override
  String get leaderboardPromotionZone => 'Promotion zone';

  @override
  String get leaderboardDemotionZone => 'Demotion zone';

  @override
  String leaderboardEndsIn(String time) {
    return 'Week ends in $time';
  }

  @override
  String leaderboardTopPromote(int count, String tier) {
    return 'Top $count move up to $tier';
  }

  @override
  String get leaderboardNoDemotion =>
      'No demotion in this league — just keep learning!';

  @override
  String get leaderboardEarnToJoin =>
      'Finish a quiz this week to join a league.';

  @override
  String leaderboardXp(int xp) {
    return '$xp XP';
  }

  @override
  String get leaderboardPractice => 'Practice player';

  @override
  String get leaderboardYou => 'You';

  @override
  String get leaderboardTiers => 'League tiers';

  @override
  String leagueOutcomePromoted(String tier) {
    return 'Promoted to $tier!';
  }

  @override
  String leagueOutcomeDemoted(String tier) {
    return 'Moved to $tier';
  }

  @override
  String leagueOutcomeStayed(String tier) {
    return 'You stayed in $tier';
  }

  @override
  String leagueOutcomeRank(int rank) {
    return 'You finished #$rank last week.';
  }

  @override
  String get tier_nyayaPanchayat => 'Nyaya Panchayat';

  @override
  String get tier_gramNyayalaya => 'Gram Nyayalaya';

  @override
  String get tier_munsiffCourt => 'Munsiff Court';

  @override
  String get tier_magistrateCourt => 'Magistrate Court';

  @override
  String get tier_districtCourt => 'District Court';

  @override
  String get tier_sessionsCourt => 'Sessions Court';

  @override
  String get tier_highCourt => 'High Court';

  @override
  String get tier_supremeCourt => 'Supreme Court';

  @override
  String get chatTitle => 'Nyaya AI';

  @override
  String get chatSubtitle => 'Your legal information assistant';

  @override
  String get chatDisclaimer =>
      'General legal information, not legal advice. For your specific case, consult an advocate or call NALSA\'s helpline 15100.';

  @override
  String get chatHint => 'Ask about any Indian law…';

  @override
  String get chatWelcome =>
      'Namaste! I can explain Indian laws, your rights, legal procedures and the new criminal laws (BNS, BNSS, BSA). What would you like to know?';

  @override
  String get chatSuggest1 => 'What is a Zero FIR?';

  @override
  String get chatSuggest2 => 'My rights if I am arrested';

  @override
  String get chatSuggest3 => 'How do I file an RTI?';

  @override
  String get chatSuggest4 => 'How to file a consumer complaint?';

  @override
  String get chatThinking => 'Researching the law…';

  @override
  String chatLimitLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free questions left today',
      one: '1 free question left today',
    );
    return '$_temp0';
  }

  @override
  String get chatLimitReached =>
      'You\'ve used today\'s free questions. Come back tomorrow or go Premium for unlimited AI.';

  @override
  String get chatLimitReachedToday =>
      'You\'ve used today\'s questions. You can ask more tomorrow.';

  @override
  String get chatError =>
      'I couldn\'t reach the AI right now. Please check your connection and try again.';

  @override
  String get chatOfflineNote =>
      'Offline mode — connect an AI key for full answers.';

  @override
  String get chatClear => 'Clear chat';

  @override
  String get chatCopy => 'Copied';

  @override
  String get updatesTitle => 'Legal Updates';

  @override
  String get updatesSubtitle => 'Judgments, new laws and explainers';

  @override
  String get updatesAll => 'All';

  @override
  String get updatesSupremeCourt => 'Supreme Court';

  @override
  String get updatesHighCourts => 'High Courts';

  @override
  String get updatesLegislation => 'Legislation';

  @override
  String get updatesExplainer => 'Explainers';

  @override
  String updatesReadTime(int minutes) {
    return '$minutes min read';
  }

  @override
  String get updatesKeyPoints => 'Key points';

  @override
  String get updatesWhyItMatters => 'Why it matters';

  @override
  String get updatesSource => 'Source';

  @override
  String get updatesAskAi => 'Ask AI about this';

  @override
  String get updatesEmpty => 'No updates in this category yet.';

  @override
  String get updatesSave => 'Save update';

  @override
  String get updatesUnsave => 'Remove from saved';

  @override
  String get updatesInEnglish => 'Shown in English';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsProfile => 'Profile';

  @override
  String get settingsEditName => 'Edit name';

  @override
  String get settingsLearningAs => 'Learning as';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsDailyGoal => 'Daily goal';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsSound => 'Sound effects';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsReminders => 'Daily reminder';

  @override
  String get settingsRemindersSub => 'A nudge to keep your streak alive';

  @override
  String get settingsStore => 'Store';

  @override
  String get settingsStreakFreeze => 'Streak freeze';

  @override
  String settingsStreakFreezeSub(int owned, int max) {
    return 'Protects your streak if you miss a day · $owned/$max equipped';
  }

  @override
  String settingsBuyFor(int coins) {
    return '$coins coins';
  }

  @override
  String get settingsFreezeBought => 'Streak freeze equipped!';

  @override
  String get settingsFreezeFull =>
      'You already have the maximum freezes equipped.';

  @override
  String get settingsPremium => 'Nyaya Premium';

  @override
  String get settingsPremiumActive => 'Premium active';

  @override
  String get settingsPremiumUpgrade => 'Upgrade to Premium';

  @override
  String get settingsStats => 'Your stats';

  @override
  String get settingsTotalXp => 'Total XP';

  @override
  String get settingsLongestStreak => 'Longest streak';

  @override
  String get settingsQuizzes => 'Quizzes';

  @override
  String get settingsAccuracy => 'Accuracy';

  @override
  String get settingsDuelRecord => 'Duels won';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsDisclaimer => 'Legal disclaimer';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya is an educational app. Questions, explanations, updates and AI answers are general information and are not legal advice. Laws change — always verify with the official Gazette or consult an advocate.';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyBody =>
      'Your progress is saved to your account, along with the days you open the app, so we can see whether people come back. Questions you ask the AI are sent to our AI provider only to write the answer. If the app crashes, a short technical report (no answers or personal details) is sent to help us fix it. You can delete your account in Settings.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsReset => 'Reset progress';

  @override
  String get settingsResetConfirm =>
      'This erases coins, energy and settings on this device. XP, stars and streaks are saved to your account and stay. This cannot be undone.';

  @override
  String get settingsResetAction => 'Erase everything';

  @override
  String get premiumTitle => 'Nyaya Premium';

  @override
  String get premiumHeadline => 'Learn without limits';

  @override
  String get premiumBenefitEnergy => 'Unlimited energy';

  @override
  String get premiumBenefitEnergySub => 'Play as many quizzes as you like';

  @override
  String get premiumBenefitAi => 'Unlimited Nyaya AI';

  @override
  String get premiumBenefitAiSub => 'Ask every legal question you have';

  @override
  String get premiumBenefitFreeze => 'Streak freezes included';

  @override
  String get premiumBenefitFreezeSub => 'Never lose your streak to a busy day';

  @override
  String get premiumBenefitExam => 'Full mock exams';

  @override
  String get premiumBenefitExamSub => 'CLAT, AIBE & judiciary-style practice';

  @override
  String get premiumFair => 'Fair play: Premium never boosts league XP.';

  @override
  String get premiumYearly => 'Yearly';

  @override
  String get premiumMonthly => 'Monthly';

  @override
  String get premiumYearlyPrice => '₹999 / year';

  @override
  String get premiumMonthlyPrice => '₹149 / month';

  @override
  String get premiumPerMonth => 'Just ₹83 / month';

  @override
  String get premiumSave => 'Save 44%';

  @override
  String get premiumBestValue => 'Best value';

  @override
  String get premiumStartTrial => 'Start 7-day free trial';

  @override
  String get premiumTrialNote =>
      'Cancel anytime before the trial ends and you won\'t be charged.';

  @override
  String get premiumRestore => 'Restore purchases';

  @override
  String get premiumActivated => 'Welcome to Nyaya Premium!';

  @override
  String get premiumAlready => 'You\'re a Premium member';

  @override
  String get premiumNothingToRestore => 'No previous purchase found.';

  @override
  String get statXp => 'XP';

  @override
  String get statStreak => 'Streak';

  @override
  String get statCoins => 'Coins';

  @override
  String get statEnergy => 'Energy';

  @override
  String get statStars => 'Stars';

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
  String get chapterConstitutionTitle => 'Constitution Basics';

  @override
  String get chapterConstitutionSubtitle =>
      'Preamble, Parliament, courts, amendments';

  @override
  String get chapterRightsTitle => 'Rights & Duties';

  @override
  String get chapterRightsSubtitle => 'Fundamental Rights, DPSP and writs';

  @override
  String get chapterCriminalTitle => 'Criminal Law (BNS)';

  @override
  String get chapterCriminalSubtitle => 'Offences under the new Sanhita';

  @override
  String get chapterProcedureTitle => 'Procedure & Evidence';

  @override
  String get chapterProcedureSubtitle => 'BNSS, BSA, FIR, arrest, bail';

  @override
  String get chapterCivilTitle => 'Contracts & Consumers';

  @override
  String get chapterCivilSubtitle => 'Contracts, consumer rights, remedies';

  @override
  String get chapterEverydayTitle => 'Everyday Law';

  @override
  String get chapterEverydaySubtitle => 'Law for daily life';

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
      'Too many attempts. Wait a few minutes and try again.';

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
  String get updateRequiredTitle => 'Please update Nyaya';

  @override
  String get updateRequiredBody =>
      'This version of the app is too old to keep working. Update it to carry on. Your progress is saved on your account, so nothing will be lost.';

  @override
  String get updateRequiredAction => 'Update';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountBody =>
      'This permanently deletes your account and everything on it: progress, XP, coins, saved questions and your league place. It cannot be undone. Enter your password to confirm.';

  @override
  String get settingsDeleteAccountPassword => 'Password';

  @override
  String get settingsDeleteAccountAction => 'Delete my account';

  @override
  String get settingsDeleteAccountWrong => 'That password is not right.';

  @override
  String get settingsDeleteAccountFailed =>
      'Couldn\'t delete the account. Check your connection and try again.';

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
