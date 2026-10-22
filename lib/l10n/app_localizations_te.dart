// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appName => 'Nyaya';

  @override
  String get appTagline => 'రోజుకో కేసుతో భారతీయ చట్టం నేర్చుకోండి';

  @override
  String get navHome => 'హోమ్';

  @override
  String get navJourney => 'ప్రయాణం';

  @override
  String get navAskAi => 'AIని అడగండి';

  @override
  String get navUpdates => 'అప్‌డేట్‌లు';

  @override
  String get commonContinue => 'కొనసాగించు';

  @override
  String get commonBack => 'వెనుకకు';

  @override
  String get commonNext => 'తదుపరి';

  @override
  String get commonSkip => 'దాటవేయి';

  @override
  String get commonCancel => 'రద్దు';

  @override
  String get commonClose => 'మూసివేయి';

  @override
  String get commonStart => 'ప్రారంభించు';

  @override
  String get commonRetry => 'మళ్లీ ప్రయత్నించు';

  @override
  String get commonDone => 'పూర్తయింది';

  @override
  String get commonSeeAll => 'అన్నీ చూడండి';

  @override
  String get commonLater => 'తర్వాత చూద్దాం';

  @override
  String get commonOk => 'సరే';

  @override
  String get commonComingSoon => 'త్వరలో వస్తుంది';

  @override
  String get commonSomethingWrong =>
      'ఏదో పొరపాటు జరిగింది. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get onbChooseLanguage => 'మీ భాషను ఎంచుకోండి';

  @override
  String get onbChooseLanguageSub =>
      'దీన్ని సెట్టింగ్స్‌లో ఎప్పుడైనా మార్చుకోవచ్చు.';

  @override
  String get onbSlide1Title => 'చట్టం, సులభంగా';

  @override
  String get onbSlide1Body =>
      'రాజ్యాంగం, BNS, BNSS, మీకు రోజూ ఎదురయ్యే చట్టాలపై చిన్న చిన్న క్విజ్‌లు.';

  @override
  String get onbSlide2Title => 'కేస్ పాత్ ఆడండి';

  @override
  String get onbSlide2Body =>
      'లెవెల్ వారీగా ముందుకు సాగండి, స్టార్లు సంపాదించండి, చెస్ట్‌లు తెరవండి, కొత్త అధ్యాయాలు అన్‌లాక్ చేయండి.';

  @override
  String get onbSlide3Title => 'రోజువారీ అలవాటు చేసుకోండి';

  @override
  String get onbSlide3Body =>
      'మీ స్ట్రీక్‌ను కొనసాగించండి, వారపు కోర్టు లీగ్‌లలో పైకి ఎదగండి, చట్టపరమైన ఏ సందేహమైనా మా AIని అడగండి.';

  @override
  String get onbWhoAreYou => 'మీరు ఎవరిగా నేర్చుకుంటున్నారు?';

  @override
  String get onbWhoAreYouSub =>
      'మీకు తగ్గట్టు కష్టతనాన్ని, సూచనలను సర్దుబాటు చేస్తాం.';

  @override
  String get personaAdvocate => 'న్యాయవాది';

  @override
  String get personaAdvocateDesc =>
      'జ్ఞాపకశక్తిని పదును పెట్టుకునే ప్రాక్టీసింగ్ లాయర్';

  @override
  String get personaAspirant => 'న్యాయ విద్యార్థి / అభ్యర్థి';

  @override
  String get personaAspirantDesc => 'CLAT, AIBE లేదా జ్యుడీషియరీ ప్రిపరేషన్';

  @override
  String get personaCitizen => 'పౌరుడు';

  @override
  String get personaCitizenDesc => 'మీ హక్కులు, నిత్యజీవిత చట్టం తెలుసుకోండి';

  @override
  String get onbDailyGoal => 'రోజువారీ లక్ష్యాన్ని ఎంచుకోండి';

  @override
  String get onbDailyGoalSub =>
      'లక్ష్యం పెట్టుకున్నవారు నేర్చుకోవడాన్ని కొనసాగించే అవకాశం చాలా ఎక్కువ.';

  @override
  String get goalCasual => 'తేలికగా';

  @override
  String get goalRegular => 'క్రమంగా';

  @override
  String get goalSerious => 'సీరియస్‌గా';

  @override
  String goalQuizzesPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'రోజుకు $count క్విజ్‌లు',
      one: 'రోజుకు 1 క్విజ్',
    );
    return '$_temp0';
  }

  @override
  String get onbYourName => 'మిమ్మల్ని ఏమని పిలవాలి?';

  @override
  String get onbYourNameSub => 'లీడర్‌బోర్డ్‌లో కనిపిస్తుంది.';

  @override
  String get onbNameHint => 'మీ పేరు';

  @override
  String get onbCommit => 'నా లక్ష్యానికి కట్టుబడతాను';

  @override
  String onbReadyTitle(String name) {
    return 'అంతా సిద్ధం, $name!';
  }

  @override
  String get onbReadyBody => 'కేస్ పాత్‌లో మీ మొదటి కేసు ఎదురుచూస్తోంది.';

  @override
  String get greetingMorning => 'శుభోదయం';

  @override
  String get greetingAfternoon => 'శుభ మధ్యాహ్నం';

  @override
  String get greetingEvening => 'శుభ సాయంత్రం';

  @override
  String get homeContinueJourney => 'మీ కేస్ పాత్ కొనసాగించండి';

  @override
  String homeChapterLevel(int chapter, int level) {
    return 'అధ్యాయం $chapter · లెవెల్ $level';
  }

  @override
  String get homeChestReady => 'మీ కోసం ఒక చెస్ట్ ఎదురుచూస్తోంది!';

  @override
  String get homeAllDone =>
      'మీరు అన్ని అధ్యాయాలు పూర్తి చేశారు. కొత్త అధ్యాయాలు త్వరలో వస్తాయి!';

  @override
  String get homePlay => 'ఆడండి';

  @override
  String get homeDailyGoal => 'రోజువారీ లక్ష్యం';

  @override
  String homeGoalProgress(int done, int goal) {
    return '$goal క్విజ్‌లలో $done';
  }

  @override
  String get homeGoalDone => 'లక్ష్యం పూర్తయింది — చాలా బాగుంది!';

  @override
  String homeStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count రోజుల స్ట్రీక్',
      one: '1 రోజు స్ట్రీక్',
      zero: 'ఈరోజే స్ట్రీక్ ప్రారంభించండి',
    );
    return '$_temp0';
  }

  @override
  String get homeStreakAtRisk =>
      'మీ స్ట్రీక్ నిలవాలంటే ఈరోజు ఒక్క క్విజ్ ఆడండి!';

  @override
  String get homeStreakSafe => 'ఈరోజుకు స్ట్రీక్ సురక్షితం';

  @override
  String get homeModesTitle => 'క్విజ్ మోడ్‌లు';

  @override
  String get homeLeagueTitle => 'ఈ వారం లీగ్';

  @override
  String homeLeagueRank(int rank, String tier) {
    return '$tierలో మీరు #$rank';
  }

  @override
  String homeLeagueEnds(String time) {
    return '$timeలో ముగుస్తుంది';
  }

  @override
  String get homeFactTitle => 'నేటి న్యాయ వాస్తవం';

  @override
  String get homeUpdatesTitle => 'తాజా న్యాయ అప్‌డేట్‌లు';

  @override
  String get homeGoPremium => 'అపరిమిత ఎనర్జీ పొందండి';

  @override
  String get homeGoPremiumSub => 'Nyaya Premium · 7 రోజుల ఉచిత ట్రయల్';

  @override
  String get modeCasePath => 'కేస్ పాత్';

  @override
  String get modeCasePathDesc => 'లెవెల్ వారీ ప్రయాణం';

  @override
  String get modeDailyDocket => 'డైలీ డాకెట్';

  @override
  String get modeDailyDocketDesc => '5 ప్రశ్నలు · అందరికీ ఒకటే';

  @override
  String get modeDuel => 'మూట్ కోర్ట్ డ్యుయెల్';

  @override
  String get modeDuelDesc => '1v1 · 7 ప్రశ్నలు · సమయాన్ని ఓడించండి';

  @override
  String get modeExam => 'ఎగ్జామ్ ఛాంబర్';

  @override
  String get modeExamDesc => '20 ప్రశ్నలు · 20 నిమి · నెగటివ్ మార్కింగ్';

  @override
  String get modeExamDescCitizen =>
      '20 ప్రశ్నలు · 20 నిమి · మీ హక్కులు తెలుసుకోండి';

  @override
  String get modeFree => 'ఉచితం';

  @override
  String modeEnergyCost(int count) {
    return '$count ⚡';
  }

  @override
  String get docketDoneToday => 'ఈరోజుకు పూర్తయింది';

  @override
  String docketNextIn(String time) {
    return 'తదుపరి డాకెట్ $timeలో';
  }

  @override
  String get energyTitle => 'ఎనర్జీ';

  @override
  String energyLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఎనర్జీ మిగిలి ఉంది',
      one: '1 ఎనర్జీ మిగిలి ఉంది',
      zero: 'ఎనర్జీ అయిపోయింది',
    );
    return '$_temp0';
  }

  @override
  String get energyUnlimited => 'అపరిమితం';

  @override
  String get energyOutTitle => 'మీ ఎనర్జీ అయిపోయింది';

  @override
  String energyOutBody(String time) {
    return 'అర్ధరాత్రి ఎనర్జీ నిండుతుంది — ఇంకా $time.';
  }

  @override
  String energyRefillCoins(int coins) {
    return '$coins కాయిన్‌లతో 1 ⚡ నింపండి';
  }

  @override
  String get energyGoUnlimited => 'అపరిమిత ఎనర్జీ పొందండి';

  @override
  String get energyFreeOptions => 'మీరు ఇప్పటికీ ఉచితంగా చేయగలిగేవి';

  @override
  String get energyPlayDocket => 'నేటి డైలీ డాకెట్ ఆడండి (ఉచితం)';

  @override
  String get energyAskAi => 'AIని చట్టపరమైన ప్రశ్న అడగండి';

  @override
  String get energyReadUpdates => 'న్యాయ అప్‌డేట్‌లు చదవండి';

  @override
  String get energyNotEnoughCoins =>
      'ఇంకా తగినన్ని కాయిన్‌లు లేవు — స్టార్లు, చెస్ట్‌ల ద్వారా సంపాదించండి.';

  @override
  String get energyRefilled => '+1 ఎనర్జీ!';

  @override
  String get journeyTitle => 'కేస్ పాత్';

  @override
  String journeyStars(int count) {
    return '$count ★';
  }

  @override
  String journeyChapter(int number) {
    return 'అధ్యాయం $number';
  }

  @override
  String journeyLevel(int number) {
    return 'లెవెల్ $number';
  }

  @override
  String get journeyLandmark => 'ల్యాండ్‌మార్క్ లెవెల్';

  @override
  String get journeyLocked => 'లాక్ అయింది';

  @override
  String get journeyLockedBody =>
      'దీన్ని అన్‌లాక్ చేయడానికి ముందు లెవెల్ పూర్తి చేయండి.';

  @override
  String journeyQuestions(int count) {
    return '$count ప్రశ్నలు';
  }

  @override
  String get journeyBestStars => 'మీ ఉత్తమం';

  @override
  String get journeyReplay => 'మళ్లీ ఆడండి';

  @override
  String get journeyChest => 'అధ్యాయ చెస్ట్';

  @override
  String get journeyChestBody =>
      'మీరు అధ్యాయం పూర్తి చేశారు! బోనస్ కాయిన్‌ల కోసం చెస్ట్ తెరవండి.';

  @override
  String get journeyOpenChest => 'చెస్ట్ తెరవండి';

  @override
  String journeyChestOpened(int coins) {
    return '+$coins కాయిన్‌లు!';
  }

  @override
  String get journeyChestLocked =>
      'చెస్ట్ తెరవడానికి ఈ అధ్యాయంలోని అన్ని లెవెల్‌లు పూర్తి చేయండి.';

  @override
  String get journeyJumpToCurrent => 'ప్రస్తుత లెవెల్‌కు వెళ్లండి';

  @override
  String get journeyYou => 'మీరు';

  @override
  String get journeyPassHint =>
      'పాస్ కావడానికి 50% · 2 స్టార్లకు 80% · 3 స్టార్లకు 100%';

  @override
  String quizQuestionOf(int current, int total) {
    return 'ప్రశ్న $current / $total';
  }

  @override
  String get quizCorrect => 'సరైనది!';

  @override
  String get quizWrong => 'సరి కాదు';

  @override
  String get quizTimeUp => 'సమయం అయిపోయింది';

  @override
  String quizAnswerWas(String answer) {
    return 'జవాబు: $answer';
  }

  @override
  String get quizWhy => 'ఎందుకు';

  @override
  String get quizReference => 'ఆధారం';

  @override
  String quizCombo(int count) {
    return '$count× కాంబో!';
  }

  @override
  String get quizFinish => 'ముగించు';

  @override
  String get quizSubmit => 'పరీక్ష సమర్పించు';

  @override
  String get quizSkipQuestion => 'దాటవేయి';

  @override
  String get quizSelectAnswer => 'ఒక జవాబు ఎంచుకోండి';

  @override
  String get quizQuitTitle => 'ఈ క్విజ్ నుండి బయటకు వెళ్లాలా?';

  @override
  String get quizQuitBody => 'ఈ క్విజ్‌లో మీ పురోగతి పోతుంది.';

  @override
  String get quizQuitBodyRefund =>
      'మీరు ఇంకా జవాబు ఇవ్వలేదు, కాబట్టి మీ ఎనర్జీ తిరిగి వస్తుంది.';

  @override
  String get quizQuitStay => 'ఆడుతూ ఉండండి';

  @override
  String get quizQuitLeave => 'బయటకు వెళ్లు';

  @override
  String get quizLoading => 'మీ కేసును సిద్ధం చేస్తున్నాం…';

  @override
  String get quizEmpty => 'ఇక్కడ ఇంకా ప్రశ్నలు అందుబాటులో లేవు.';

  @override
  String get quizOpponent => 'ప్రత్యర్థి';

  @override
  String quizOpponentAnswered(String name, int seconds) {
    return '$name $seconds సెకన్లలో జవాబిచ్చారు';
  }

  @override
  String get quizVs => 'VS';

  @override
  String get quizFindingOpponent => 'ప్రత్యర్థిని వెతుకుతున్నాం…';

  @override
  String quizMarkedAnswers(int answered, int total) {
    return '$totalలో $answered జవాబిచ్చారు';
  }

  @override
  String get resultPerfect => 'పర్ఫెక్ట్ కేసు!';

  @override
  String get resultGreat => 'అద్భుతం!';

  @override
  String get resultGood => 'లెవెల్ పూర్తయింది!';

  @override
  String get resultTryAgain => 'దాదాపు చేరుకున్నారు';

  @override
  String get resultTryAgainBody =>
      'ఈ లెవెల్ పూర్తి చేయడానికి కనీసం 50% స్కోర్ చేయండి. వివరణలు చూసి మళ్లీ ప్రయత్నించండి.';

  @override
  String resultScore(int correct, int total) {
    return '$totalలో $correct సరైనవి';
  }

  @override
  String get resultAccuracy => 'ఖచ్చితత్వం';

  @override
  String get resultXp => 'XP';

  @override
  String get resultCoins => 'కాయిన్‌లు';

  @override
  String get resultTime => 'సమయం';

  @override
  String resultStreakExtended(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'స్ట్రీక్ $count రోజులకు పెరిగింది!',
      one: 'మీ స్ట్రీక్ మొదలైంది — 1వ రోజు!',
    );
    return '$_temp0';
  }

  @override
  String resultMilestone(int count) {
    return '$count రోజుల స్ట్రీక్ మైలురాయి!';
  }

  @override
  String get resultGoalReached => 'రోజువారీ లక్ష్యం చేరుకున్నారు!';

  @override
  String resultEnergyBonus(int count) {
    return '3 స్టార్ల బోనస్: +$count ⚡';
  }

  @override
  String resultLeagueUp(int rank) {
    return 'మీ లీగ్‌లో మీరు #$rankకి ఎదిగారు';
  }

  @override
  String get resultReview => 'జవాబులు సమీక్షించండి';

  @override
  String get resultNextLevel => 'తదుపరి లెవెల్';

  @override
  String get resultBackToMap => 'మ్యాప్‌కు వెళ్లు';

  @override
  String get resultBackHome => 'హోమ్‌కు వెళ్లు';

  @override
  String get resultPlayAgain => 'మళ్లీ ఆడండి';

  @override
  String resultExamScore(String score, int max) {
    return 'స్కోర్: $score / $max';
  }

  @override
  String resultExamBreakdown(int correct, int wrong, int skipped) {
    return '$correct సరైనవి · $wrong తప్పు · $skipped దాటవేసినవి';
  }

  @override
  String get resultDuelWon => 'మీరు డ్యుయెల్ గెలిచారు!';

  @override
  String get resultDuelLost => 'హోరాహోరీ పోరు!';

  @override
  String get resultDuelDraw => 'డ్రా అయింది!';

  @override
  String resultDuelPoints(int you, int them) {
    return '$you vs $them';
  }

  @override
  String get resultDocketShare => 'ఫలితం షేర్ చేయండి';

  @override
  String get resultYourAnswer => 'మీ జవాబు';

  @override
  String get resultCorrectAnswer => 'సరైన జవాబు';

  @override
  String get resultSkipped => 'దాటవేశారు';

  @override
  String get leaderboardTitle => 'లీడర్‌బోర్డ్';

  @override
  String get leaderboardWeekly => 'వారపు లీగ్';

  @override
  String get leaderboardAllTime => 'ఎప్పటికీ';

  @override
  String get leaderboardPromotionZone => 'ప్రమోషన్ జోన్';

  @override
  String get leaderboardDemotionZone => 'డిమోషన్ జోన్';

  @override
  String leaderboardEndsIn(String time) {
    return 'వారం $timeలో ముగుస్తుంది';
  }

  @override
  String leaderboardTopPromote(int count, String tier) {
    return 'టాప్ $count మంది $tierకి వెళ్తారు';
  }

  @override
  String get leaderboardNoDemotion =>
      'ఈ లీగ్‌లో డిమోషన్ లేదు — నేర్చుకుంటూ ఉండండి!';

  @override
  String get leaderboardEarnToJoin =>
      'లీగ్‌లో చేరడానికి ఈ వారం ఒక క్విజ్ పూర్తి చేయండి.';

  @override
  String leaderboardXp(int xp) {
    return '$xp XP';
  }

  @override
  String get leaderboardYou => 'మీరు';

  @override
  String get leaderboardTiers => 'లీగ్ స్థాయిలు';

  @override
  String leagueOutcomePromoted(String tier) {
    return '$tierకి ప్రమోషన్!';
  }

  @override
  String leagueOutcomeDemoted(String tier) {
    return '$tierకి మార్చబడ్డారు';
  }

  @override
  String leagueOutcomeStayed(String tier) {
    return 'మీరు $tierలోనే ఉన్నారు';
  }

  @override
  String leagueOutcomeRank(int rank) {
    return 'గత వారం మీరు #$rank స్థానంలో నిలిచారు.';
  }

  @override
  String get tier_nyayaPanchayat => 'న్యాయ పంచాయతీ';

  @override
  String get tier_gramNyayalaya => 'గ్రామ న్యాయాలయం';

  @override
  String get tier_munsiffCourt => 'మున్సిఫ్ కోర్టు';

  @override
  String get tier_magistrateCourt => 'మేజిస్ట్రేట్ కోర్టు';

  @override
  String get tier_districtCourt => 'జిల్లా కోర్టు';

  @override
  String get tier_sessionsCourt => 'సెషన్స్ కోర్టు';

  @override
  String get tier_highCourt => 'హైకోర్టు';

  @override
  String get tier_supremeCourt => 'సుప్రీంకోర్టు';

  @override
  String get chatTitle => 'Nyaya AI';

  @override
  String get chatSubtitle => 'మీ న్యాయ సమాచార సహాయకుడు';

  @override
  String get chatDisclaimer =>
      'ఇది సాధారణ న్యాయ సమాచారం మాత్రమే, న్యాయ సలహా కాదు. మీ కేసు కోసం న్యాయవాదిని సంప్రదించండి లేదా NALSA హెల్ప్‌లైన్ 15100కు కాల్ చేయండి.';

  @override
  String get chatHint => 'ఏ భారతీయ చట్టం గురించైనా అడగండి…';

  @override
  String get chatWelcome =>
      'నమస్తే! భారతీయ చట్టాలు, మీ హక్కులు, న్యాయ ప్రక్రియలు, కొత్త నేర చట్టాలు (BNS, BNSS, BSA) గురించి వివరించగలను. మీరు ఏమి తెలుసుకోవాలనుకుంటున్నారు?';

  @override
  String get chatSuggest1 => 'జీరో FIR అంటే ఏమిటి?';

  @override
  String get chatSuggest2 => 'నన్ను అరెస్టు చేస్తే నా హక్కులు';

  @override
  String get chatSuggest3 => 'RTI ఎలా దాఖలు చేయాలి?';

  @override
  String get chatSuggest4 => 'వినియోగదారుల ఫిర్యాదు ఎలా చేయాలి?';

  @override
  String get chatThinking => 'చట్టాన్ని పరిశీలిస్తున్నాం…';

  @override
  String chatLimitLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ఈరోజు $count ఉచిత ప్రశ్నలు మిగిలి ఉన్నాయి',
      one: 'ఈరోజు 1 ఉచిత ప్రశ్న మిగిలి ఉంది',
    );
    return '$_temp0';
  }

  @override
  String get chatLimitReached =>
      'ఈరోజు ఉచిత ప్రశ్నలు అయిపోయాయి. రేపు రండి లేదా అపరిమిత AI కోసం Premium తీసుకోండి.';

  @override
  String get chatError =>
      'ప్రస్తుతం AIని చేరుకోలేకపోయాను. మీ కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get chatOfflineNote =>
      'ఆఫ్‌లైన్ మోడ్ — పూర్తి జవాబుల కోసం AI కీని కనెక్ట్ చేయండి.';

  @override
  String get chatClear => 'చాట్ క్లియర్ చేయి';

  @override
  String get chatCopy => 'కాపీ అయింది';

  @override
  String get updatesTitle => 'న్యాయ అప్‌డేట్‌లు';

  @override
  String get updatesSubtitle => 'తీర్పులు, కొత్త చట్టాలు, వివరణలు';

  @override
  String get updatesAll => 'అన్నీ';

  @override
  String get updatesSupremeCourt => 'సుప్రీంకోర్టు';

  @override
  String get updatesHighCourts => 'హైకోర్టులు';

  @override
  String get updatesLegislation => 'చట్టాలు';

  @override
  String get updatesExplainer => 'వివరణలు';

  @override
  String updatesReadTime(int minutes) {
    return '$minutes నిమి చదవడం';
  }

  @override
  String get updatesKeyPoints => 'ముఖ్యాంశాలు';

  @override
  String get updatesWhyItMatters => 'ఇది ఎందుకు ముఖ్యం';

  @override
  String get updatesSource => 'మూలం';

  @override
  String get updatesAskAi => 'దీని గురించి AIని అడగండి';

  @override
  String get updatesEmpty => 'ఈ విభాగంలో ఇంకా అప్‌డేట్‌లు లేవు.';

  @override
  String get updatesInEnglish => 'ఆంగ్లంలో చూపబడుతోంది';

  @override
  String get settingsTitle => 'సెట్టింగ్స్';

  @override
  String get settingsProfile => 'ప్రొఫైల్';

  @override
  String get settingsEditName => 'పేరు మార్చండి';

  @override
  String get settingsLearningAs => 'నేర్చుకుంటున్నది';

  @override
  String get settingsLanguage => 'భాష';

  @override
  String get settingsDailyGoal => 'రోజువారీ లక్ష్యం';

  @override
  String get settingsAppearance => 'రూపం';

  @override
  String get settingsThemeSystem => 'సిస్టమ్';

  @override
  String get settingsThemeLight => 'లైట్';

  @override
  String get settingsThemeDark => 'డార్క్';

  @override
  String get settingsSound => 'సౌండ్ ఎఫెక్ట్స్';

  @override
  String get settingsHaptics => 'వైబ్రేషన్ ఫీడ్‌బ్యాక్';

  @override
  String get settingsReminders => 'రోజువారీ రిమైండర్';

  @override
  String get settingsRemindersSub => 'మీ స్ట్రీక్ కొనసాగడానికి ఒక చిన్న గుర్తు';

  @override
  String get settingsStore => 'స్టోర్';

  @override
  String get settingsStreakFreeze => 'స్ట్రీక్ ఫ్రీజ్';

  @override
  String settingsStreakFreezeSub(int owned, int max) {
    return 'ఒక రోజు మిస్ అయినా మీ స్ట్రీక్‌ను కాపాడుతుంది · $owned/$max సిద్ధంగా ఉన్నాయి';
  }

  @override
  String settingsBuyFor(int coins) {
    return '$coins కాయిన్‌లు';
  }

  @override
  String get settingsFreezeBought => 'స్ట్రీక్ ఫ్రీజ్ సిద్ధం!';

  @override
  String get settingsFreezeFull =>
      'మీ దగ్గర ఇప్పటికే గరిష్ఠ సంఖ్యలో ఫ్రీజ్‌లు ఉన్నాయి.';

  @override
  String get settingsPremium => 'Nyaya Premium';

  @override
  String get settingsPremiumActive => 'Premium యాక్టివ్‌గా ఉంది';

  @override
  String get settingsPremiumUpgrade => 'Premiumకి అప్‌గ్రేడ్ చేయండి';

  @override
  String get settingsStats => 'మీ గణాంకాలు';

  @override
  String get settingsTotalXp => 'మొత్తం XP';

  @override
  String get settingsLongestStreak => 'అత్యధిక స్ట్రీక్';

  @override
  String get settingsQuizzes => 'క్విజ్‌లు';

  @override
  String get settingsAccuracy => 'ఖచ్చితత్వం';

  @override
  String get settingsDuelRecord => 'గెలిచిన డ్యుయెల్స్';

  @override
  String get settingsAbout => 'గురించి';

  @override
  String get settingsDisclaimer => 'న్యాయ నిరాకరణ';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya ఒక విద్యా యాప్. ప్రశ్నలు, వివరణలు, అప్‌డేట్‌లు, AI జవాబులు సాధారణ సమాచారం మాత్రమే, న్యాయ సలహా కాదు. చట్టాలు మారుతుంటాయి — ఎల్లప్పుడూ అధికారిక గెజిట్‌లో సరిచూసుకోండి లేదా న్యాయవాదిని సంప్రదించండి.';

  @override
  String get settingsPrivacy => 'గోప్యత';

  @override
  String get settingsPrivacyBody =>
      'మీ పురోగతి ఈ పరికరంలోనే నిల్వ అవుతుంది. AI ప్రశ్నలు జవాబులు రూపొందించడానికి మాత్రమే మా AI ప్రొవైడర్‌కు పంపబడతాయి.';

  @override
  String settingsVersion(String version) {
    return 'వెర్షన్ $version';
  }

  @override
  String get settingsReset => 'పురోగతి రీసెట్ చేయండి';

  @override
  String get settingsResetConfirm =>
      'ఇది ఈ పరికరంలోని XP, స్టార్లు, స్ట్రీక్‌లు, కాయిన్‌లు అన్నింటినీ తొలగిస్తుంది. దీన్ని తిరిగి పొందలేరు.';

  @override
  String get settingsResetAction => 'అన్నీ తొలగించు';

  @override
  String get premiumTitle => 'Nyaya Premium';

  @override
  String get premiumHeadline => 'పరిమితులు లేకుండా నేర్చుకోండి';

  @override
  String get premiumBenefitEnergy => 'అపరిమిత ఎనర్జీ';

  @override
  String get premiumBenefitEnergySub => 'మీకు నచ్చినన్ని క్విజ్‌లు ఆడండి';

  @override
  String get premiumBenefitAi => 'అపరిమిత Nyaya AI';

  @override
  String get premiumBenefitAiSub => 'మీ ప్రతి న్యాయ సందేహాన్ని అడగండి';

  @override
  String get premiumBenefitFreeze => 'స్ట్రీక్ ఫ్రీజ్‌లు చేర్చబడ్డాయి';

  @override
  String get premiumBenefitFreezeSub =>
      'బిజీ రోజు వల్ల మీ స్ట్రీక్ ఎప్పటికీ కోల్పోరు';

  @override
  String get premiumBenefitExam => 'పూర్తి మాక్ పరీక్షలు';

  @override
  String get premiumBenefitExamSub =>
      'CLAT, AIBE & జ్యుడీషియరీ తరహా ప్రాక్టీస్';

  @override
  String get premiumFair => 'న్యాయమైన ఆట: Premium ఎప్పుడూ లీగ్ XPను పెంచదు.';

  @override
  String get premiumYearly => 'వార్షికం';

  @override
  String get premiumMonthly => 'నెలవారీ';

  @override
  String get premiumYearlyPrice => '₹999 / సంవత్సరం';

  @override
  String get premiumMonthlyPrice => '₹149 / నెల';

  @override
  String get premiumPerMonth => 'నెలకు కేవలం ₹83';

  @override
  String get premiumSave => '44% ఆదా';

  @override
  String get premiumBestValue => 'ఉత్తమ విలువ';

  @override
  String get premiumStartTrial => '7 రోజుల ఉచిత ట్రయల్ ప్రారంభించండి';

  @override
  String get premiumTrialNote =>
      'ట్రయల్ ముగిసేలోపు ఎప్పుడైనా రద్దు చేస్తే మీకు ఛార్జ్ పడదు.';

  @override
  String get premiumRestore => 'కొనుగోళ్లను పునరుద్ధరించండి';

  @override
  String get premiumActivated => 'Nyaya Premiumకి స్వాగతం!';

  @override
  String get premiumAlready => 'మీరు Premium సభ్యులు';

  @override
  String get premiumNothingToRestore => 'గతంలో చేసిన కొనుగోలు ఏదీ కనిపించలేదు.';

  @override
  String get statXp => 'XP';

  @override
  String get statStreak => 'స్ట్రీక్';

  @override
  String get statCoins => 'కాయిన్‌లు';

  @override
  String get statEnergy => 'ఎనర్జీ';

  @override
  String get statStars => 'స్టార్లు';
}
