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
      'Your progress is stored on this device. AI questions are sent to our AI provider only to generate answers.';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsReset => 'Reset progress';

  @override
  String get settingsResetConfirm =>
      'This erases all XP, stars, streaks and coins on this device. This cannot be undone.';

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
}
