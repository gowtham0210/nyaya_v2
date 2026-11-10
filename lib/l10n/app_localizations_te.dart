// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get appName => 'Nyaya Kural';

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
  String get reviewTitle => 'సమీక్ష';

  @override
  String get reviewMistakesTab => 'తప్పులు';

  @override
  String get reviewSavedTab => 'సేవ్ చేసినవి';

  @override
  String get reviewPractise => 'తప్పులను ప్రాక్టీస్ చేయండి';

  @override
  String get reviewPractiseFree => 'ఉచితం · 10 ప్రశ్నల వరకు · XP వస్తుంది';

  @override
  String get reviewEmptyMistakes =>
      'సమీక్షించడానికి తప్పులేవీ లేవు. మీరు తప్పుగా జవాబిచ్చిన ప్రశ్నలు, వాటికి సరైన జవాబు ఇచ్చే వరకు ఇక్కడ కనిపిస్తాయి.';

  @override
  String get reviewEmptySaved =>
      'ఇంకా ఏదీ సేవ్ చేయలేదు. ఒక ప్రశ్నకు జవాబిచ్చాక, సేవ్ నొక్కితే అది ఇక్కడ ఉంటుంది.';

  @override
  String get reviewSignIn =>
      'మీ తప్పులు, సేవ్ చేసిన ప్రశ్నలు చూడటానికి సైన్ ఇన్ చేయండి.';

  @override
  String reviewWrongTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సార్లు తప్పు',
      one: 'ఒకసారి తప్పు',
    );
    return '$_temp0';
  }

  @override
  String get reviewUpdatedSince =>
      'మీరు జవాబిచ్చిన తర్వాత ఇది మారింది. మీరు చూసినట్లే చూపిస్తున్నాం.';

  @override
  String get reviewUnavailable => 'ఈ ప్రశ్న ఇక అందుబాటులో లేదు.';

  @override
  String reviewCardBody(int mistakes, int saved) {
    String _temp0 = intl.Intl.pluralLogic(
      mistakes,
      locale: localeName,
      other: '$mistakes తప్పులు',
      one: '1 తప్పు',
    );
    return '$_temp0 · $saved సేవ్ చేసినవి';
  }

  @override
  String get questionSave => 'సేవ్';

  @override
  String get questionSaved => 'సేవ్ అయింది';

  @override
  String get questionReport => 'రిపోర్ట్';

  @override
  String get questionSaveFailed =>
      'సేవ్ చేయలేకపోయాం. కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get reportTitle => 'సమస్యను తెలియజేయండి';

  @override
  String get reportReasonWrongAnswer => 'జవాబు తప్పుగా ఉంది';

  @override
  String get reportReasonUnclear => 'ప్రశ్న స్పష్టంగా లేదు';

  @override
  String get reportReasonOutdatedLaw => 'చట్టం మారింది';

  @override
  String get reportReasonTypo => 'అక్షర దోషం లేదా పదాల సమస్య';

  @override
  String get reportReasonOther => 'ఇంకేదైనా';

  @override
  String get reportComment => 'ఇంకేమైనా చెప్పాలా? (ఐచ్ఛికం)';

  @override
  String get reportSend => 'రిపోర్ట్ పంపండి';

  @override
  String get reportSent =>
      'ధన్యవాదాలు. మా న్యాయ బృందం ఈ ప్రశ్నను పరిశీలిస్తుంది.';

  @override
  String get reportAlready => 'ఈ ప్రశ్నను మీరు ఇప్పటికే రిపోర్ట్ చేశారు.';

  @override
  String get reportLimit =>
      'ఈరోజు మీరు చాలా రిపోర్ట్‌లు పంపారు. దయచేసి రేపు మళ్లీ ప్రయత్నించండి.';

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
  String get onbSlide2Title => 'అభ్యాస మార్గంలో నడవండి';

  @override
  String get onbSlide2Body =>
      'లెవెల్ వారీగా ముందుకు సాగండి, స్టార్లు సంపాదించండి, చెస్ట్‌లు తెరవండి, కొత్త అధ్యాయాలు అన్‌లాక్ చేయండి.';

  @override
  String get onbSlide3Title => 'రోజువారీ అలవాటు చేసుకోండి';

  @override
  String get onbSlide3Body =>
      'మీ స్ట్రీక్‌ను కొనసాగించండి, వారపు కోర్టు లీగ్‌లలో పైకి ఎదగండి, చట్టపరమైన ఏ సందేహమైనా మా AIని అడగండి.';

  @override
  String get onbSkip => 'దాటవేయి';

  @override
  String onbSlidePosition(int current, int total) {
    return 'స్లైడ్ $current / $total';
  }

  @override
  String get onbGetStarted => 'ప్రారంభించండి';

  @override
  String get onbBrandTagline => 'చట్టం నేర్చుకోండి. జీవితంలో వాడండి.';

  @override
  String get onbIntro1Title => 'భారతీయ చట్టానికి మీ మార్గదర్శి';

  @override
  String get onbIntro1Body =>
      'స్పష్టంగా నేర్చుకోండి, లక్ష్యంతో ప్రాక్టీస్ చేయండి, మీ రోజువారీ జీవితాన్ని ప్రభావితం చేసే చట్టాన్ని అర్థం చేసుకోండి.';

  @override
  String get onbIntro2Label => 'క్రమబద్ధమైన అభ్యాసం';

  @override
  String get onbIntro2Title => 'మీ వేగంతో నేర్చుకోండి';

  @override
  String get onbIntro2Body =>
      'రాజ్యాంగం, BNS, BNSS, BSA మరియు మరిన్నింటిని క్రమపద్ధతిలో ఉన్న పాఠాలు, నోట్స్, నిజజీవిత ఉదాహరణలతో తెలుసుకోండి.';

  @override
  String get onbIntro3Label => 'ప్రాక్టీస్ & వాడకం';

  @override
  String get onbIntro3Title => 'నిజమైన అవగాహన పెంచుకోండి';

  @override
  String get onbIntro3Body =>
      'క్విజ్‌లతో మీ జ్ఞానాన్ని పరీక్షించుకోండి, తాజా న్యాయ అప్‌డేట్‌లు చదవండి, చట్టం నిజజీవితంలో ఎలా పనిచేస్తుందో చూడండి.';

  @override
  String get onbDemoChapter => 'ప్రాథమిక హక్కులు';

  @override
  String get onbDemoChapterSub => 'భారత రాజ్యాంగం · అధ్యాయం 3';

  @override
  String get onbDemoProgress => '8 పాఠాలలో 5 పూర్తయ్యాయి';

  @override
  String get onbDemoContinue => 'నేర్చుకోవడం కొనసాగించండి';

  @override
  String get onbDemoLesson1 => 'పరిచయం';

  @override
  String get onbDemoLesson2 => 'సమానత్వ హక్కు';

  @override
  String get onbDemoLesson3 => 'స్వేచ్ఛ హక్కు';

  @override
  String get onbDemoLesson4 => 'దోపిడీకి వ్యతిరేకంగా హక్కు';

  @override
  String get onbDemoQuiz => 'డైలీ క్విజ్';

  @override
  String get onbDemoQuizSub => '5 లో 3 కార్యకలాపాలు';

  @override
  String get onbDemoUpdates => 'న్యాయ అప్‌డేట్‌లు';

  @override
  String get onbDemoUpdatesSub =>
      'ముఖ్యమైన తీర్పులు, పరిణామాలతో తాజాగా ఉండండి.';

  @override
  String get onbDemoScenarios => 'నిజజీవిత సందర్భాలు';

  @override
  String get onbDemoScenariosSub =>
      'రోజువారీ జీవితంలో చట్టం ఎలా పనిచేస్తుందో అర్థం చేసుకోండి.';

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
  String get onbReadyBody => 'మీ మొదటి పాఠం అభ్యాస మార్గంలో ఎదురుచూస్తోంది.';

  @override
  String get greetingMorning => 'శుభోదయం';

  @override
  String get greetingAfternoon => 'శుభ మధ్యాహ్నం';

  @override
  String get greetingEvening => 'శుభ సాయంత్రం';

  @override
  String get homeContinueJourney => 'మీ అభ్యాస మార్గాన్ని కొనసాగించండి';

  @override
  String get homeContinueLeftOff => 'ఆపిన చోటు నుండి కొనసాగించండి';

  @override
  String get homeStartTitle => 'మీ అభ్యాస ప్రయాణం ప్రారంభించండి';

  @override
  String get homeStartBody => 'భారతీయ చట్టాన్ని ఒక్కో భావనగా అర్థం చేసుకోండి.';

  @override
  String get homeStartRecommended => 'ప్రారంభానికి సూచన';

  @override
  String get homeStartLawDesc =>
      'ప్రాథమిక హక్కులు, విధులు మరియు రాజ్యాంగ సూత్రాలను అర్థం చేసుకోండి.';

  @override
  String get homeStartLearning => 'నేర్చుకోవడం ప్రారంభించండి';

  @override
  String homeLevelsDone(int done, int total) {
    return '$total స్థాయిలలో $done పూర్తయ్యాయి';
  }

  @override
  String get homeFeatured => 'ప్రత్యేకం';

  @override
  String get homeViewOnMap => 'మ్యాప్‌లో చూడండి';

  @override
  String get homeReviewMistakes => 'మీ తప్పులను మళ్లీ చూడండి';

  @override
  String get homeReviewSaved => 'మీరు సేవ్ చేసిన ప్రశ్నలు';

  @override
  String get homeReviewNow => 'ఇప్పుడు చూడండి';

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
  String get homeGoPremiumSub => 'Nyaya Kural Premium · 7 రోజుల ఉచిత ట్రయల్';

  @override
  String get modeCasePath => 'అభ్యాస మార్గం';

  @override
  String get modeCasePathDesc => 'లెవెల్ వారీ ప్రయాణం';

  @override
  String get modeDailyDocket => 'నేటి ప్రశ్నలు';

  @override
  String get modeDailyDocketDesc => '5 ప్రశ్నలు · అందరికీ ఒకటే';

  @override
  String get modeDuel => 'క్విక్ క్విజ్';

  @override
  String get modeDuelDesc => '1v1 · 7 ప్రశ్నలు · సమయాన్ని ఓడించండి';

  @override
  String get modeExam => 'పరీక్ష సాధన';

  @override
  String get modeExamDesc => '20 ప్రశ్నలు · 20 నిమి · నెగటివ్ మార్కింగ్';

  @override
  String get modeExamDescCitizen =>
      '20 ప్రశ్నలు · 20 నిమి · మీ హక్కులు తెలుసుకోండి';

  @override
  String get modeFree => 'ఉచితం';

  @override
  String modeEnergyCost(int count) {
    return '$count ఎనర్జీ';
  }

  @override
  String get docketDoneToday => 'ఈరోజుకు పూర్తయింది';

  @override
  String docketNextIn(String time) {
    return 'కొత్త ప్రశ్నలు $timeలో';
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
    return '$coins కాయిన్‌లతో 1 ఎనర్జీ నింపండి';
  }

  @override
  String get energyGoUnlimited => 'అపరిమిత ఎనర్జీ పొందండి';

  @override
  String get energyFreeOptions => 'మీరు ఇప్పటికీ ఉచితంగా చేయగలిగేవి';

  @override
  String get energyPlayDocket => 'నేటి ప్రశ్నలు ఆడండి (ఉచితం)';

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
  String get journeyTitle => 'అభ్యాస మార్గం';

  @override
  String get journeySubtitle => 'భారతీయ చట్టంలో మీ ప్రయాణం';

  @override
  String get journeyKeepGoing => 'ఇలాగే కొనసాగించండి!';

  @override
  String get journeyQuote =>
      'చిన్న చిన్న అడుగులు చట్టంపై అవగాహనను మరింత బలపరుస్తాయి.';

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
  String get journeyOpenChest => 'చెస్ట్ తెరవండి';

  @override
  String get journeyJumpToCurrent => 'ప్రస్తుత లెవెల్‌కు వెళ్లండి';

  @override
  String get journeyYou => 'మీరు';

  @override
  String get journeyNext => 'తదుపరి అడుగు';

  @override
  String get journeyDone => 'పూర్తయింది';

  @override
  String journeyStarsOf(int count, int total) {
    return '$totalలో $count స్టార్లు';
  }

  @override
  String journeyLockedNext(String step) {
    return 'లెవెల్స్ వరుసగా తెరుచుకుంటాయి. మీ తదుపరి అడుగు $step.';
  }

  @override
  String get journeyGoToNext => 'నా తదుపరి అడుగు చూపించు';

  @override
  String journeyStartCost(int count) {
    return 'ప్రారంభించండి · $count ఎనర్జీ';
  }

  @override
  String journeyReplayCost(int count) {
    return 'మళ్లీ ఆడండి · $count ఎనర్జీ';
  }

  @override
  String get journeyNoTimer => 'సమయ పరిమితి లేదు';

  @override
  String get journeyStarsTitle => 'మీరు పొందగల స్టార్లు';

  @override
  String journeyPassMark(int percent) {
    return '$percent% · పాస్';
  }

  @override
  String journeyStarMark(int percent) {
    return '$percent%';
  }

  @override
  String get journeyHowScoring => 'స్కోర్ ఎలా లెక్కిస్తారు';

  @override
  String get journeyReplayFree => 'మళ్లీ ఆడండి · ఉచితం';

  @override
  String get journeyFreeReplay => 'ఉచిత రీప్లే';

  @override
  String get journeyRuleReplay =>
      'మీరు పూర్తి చేసిన లెవెల్‌ను మళ్లీ ఆడటం ఉచితం. మళ్లీ ఆడితే సగం XP వస్తుంది, అది మీ రోజువారీ లక్ష్యంలో లెక్కకు వస్తుంది.';

  @override
  String journeyRuleEnergy(int count) {
    return 'ప్రతి ప్రయత్నానికి $count ఎనర్జీ ఖర్చవుతుంది. మొదటి జవాబుకు ముందే వదిలేస్తే అది తిరిగి వస్తుంది.';
  }

  @override
  String get journeyRuleRetry =>
      'పాస్ కాలేదా? ఎన్నిసార్లైనా మళ్లీ ప్రయత్నించవచ్చు.';

  @override
  String get journeyRuleBest =>
      'మీ ఉత్తమ స్కోర్ ఉంచబడుతుంది. తక్కువ స్కోర్ స్టార్లను ఎప్పుడూ తగ్గించదు.';

  @override
  String get journeyRuleNoMinus => 'తప్పు జవాబులకు మార్కులు తగ్గవు.';

  @override
  String journeyRuleBonus(int count, int coins) {
    return 'ఒక లెవెల్‌లో మొదటిసారి 3 స్టార్లు పొందితే $count ఎనర్జీ తిరిగి వస్తుంది. ప్రతి కొత్త స్టార్‌కు $coins కాయిన్‌లు.';
  }

  @override
  String get journeyChestLockedTitle => 'అధ్యాయ చెస్ట్ లాక్ అయి ఉంది';

  @override
  String get journeyChestLockedText =>
      'మీ బహుమతి తెరవడానికి ఈ అధ్యాయంలోని అన్ని లెవెల్స్ పూర్తి చేయండి.';

  @override
  String get journeyChestReadyTitle => 'మీ అధ్యాయ బహుమతి సిద్ధంగా ఉంది';

  @override
  String get journeyChestReadyText =>
      'చాలా బాగుంది! మీరు ఈ అధ్యాయం పూర్తి చేశారు.';

  @override
  String journeyChestReward(int coins) {
    return 'బహుమతి: $coins కాయిన్‌లు';
  }

  @override
  String get journeyChestCollectedTitle => 'అధ్యాయ బహుమతి అందుకున్నారు';

  @override
  String journeyChestCollectedText(int coins) {
    return 'మీకు $coins కాయిన్‌లు వచ్చాయి.';
  }

  @override
  String get journeyChestFailed =>
      'చెస్ట్ తెరవలేకపోయాం. మీ కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి. మీ బహుమతి వేచి ఉంది.';

  @override
  String get journeyContinueLearning => 'నేర్చుకోవడం కొనసాగించండి';

  @override
  String get journeyBackToMap => 'మ్యాప్‌కు తిరిగి';

  @override
  String journeyChapterProgress(int number, int done, int total) {
    return 'అధ్యాయం $number · $done/$total పూర్తి';
  }

  @override
  String journeyStarsInfo(int one, int two) {
    return 'ప్రతి లెవెల్‌లో 3 స్టార్ల వరకు పొందండి: 1 స్టార్‌కు $one%, 2కు $two%, 3కు 100%. ప్రతి లెవెల్‌లో మీ ఉత్తమ స్కోర్ లెక్కలోకి వస్తుంది.';
  }

  @override
  String journeyEnergyInfo(int cost, int free, String time) {
    return 'అభ్యాస మార్గంలో ప్రతి లెవెల్‌కు $cost ఎనర్జీ ఖర్చవుతుంది. ప్రతిరోజూ $free ఎనర్జీ ఉచితం. అర్ధరాత్రి తిరిగి నిండుతుంది — $timeలో.';
  }

  @override
  String get journeyCoinsInfo =>
      'కొత్త స్టార్లు, అధ్యాయ చెస్ట్‌లు, నేటి ప్రశ్నలు, రోజువారీ లక్ష్యం, స్ట్రీక్ మైలురాళ్ల నుంచి కాయిన్‌లు సంపాదించండి. వాటిని స్టోర్‌లో ఎనర్జీ నింపడానికి, స్ట్రీక్ ఫ్రీజ్‌లకు ఖర్చు చేయండి.';

  @override
  String get journeyOpenStore => 'స్టోర్ తెరవండి';

  @override
  String get journeyListView => 'లెవెల్స్‌ను జాబితాగా చూపించు';

  @override
  String get journeyAllLevels => 'అన్ని లెవెల్స్';

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
  String get quizOpenSource => 'అధికారిక పాఠం చదవండి';

  @override
  String get quizOpenSourceFailed => 'లింక్ తెరవలేకపోయాం';

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
  String get quizQuitStay => 'ఆడుతూ ఉండండి';

  @override
  String get quizQuitLeave => 'బయటకు వెళ్లు';

  @override
  String get quizTapToCheck => 'తనిఖీ చేయడానికి ఒక జవాబును నొక్కండి.';

  @override
  String get quizChecking => 'మీ జవాబు తనిఖీ అవుతోంది…';

  @override
  String quizTimedHint(int seconds) {
    return '$seconds సెకన్లలో జవాబు ఇవ్వండి. సమయానికి జవాబు ఇవ్వకపోతే తప్పుగా లెక్కిస్తారు.';
  }

  @override
  String get quizDuelHint =>
      'సరైన జవాబుకు 1,000 పాయింట్ల వరకు — ఎంత వేగంగా ఇస్తే అంత ఎక్కువ. తప్పు జవాబుకు 0.';

  @override
  String get quizExamHint =>
      'ఒక జవాబు ఎంచుకుని ముందుకు వెళ్లండి. వెనక్కి వెళ్లి ప్రశ్న మార్చలేరు.';

  @override
  String quizSecondsLeft(int seconds) {
    return '$seconds సెకన్లు మిగిలాయి';
  }

  @override
  String quizTimeLeft(String time) {
    return 'మిగిలిన సమయం: $time';
  }

  @override
  String get quizNoExplanation => 'ఈ ప్రశ్నకు వివరణ ఇంకా అందుబాటులో లేదు.';

  @override
  String quizQuitRefund(int count) {
    return 'మీరు ఇంకా జవాబు ఇవ్వలేదు, కాబట్టి మీ $count ఎనర్జీ తిరిగి వస్తుంది.';
  }

  @override
  String get quizQuitFree =>
      'మీరు ఇంకా జవాబు ఇవ్వలేదు, కాబట్టి ఏమీ కోల్పోలేదు. తర్వాత మళ్లీ ప్రారంభించవచ్చు.';

  @override
  String get quizQuitAnswered =>
      'ఈ ప్రయత్నం ముగుస్తుంది, తర్వాత కొనసాగించలేరు. ఇప్పటివరకు ఇచ్చిన జవాబులు లెక్కలోకి రావు.';

  @override
  String quizQuitAnsweredEnergy(int count) {
    return 'ఈ ప్రయత్నం ముగుస్తుంది, తర్వాత కొనసాగించలేరు. ఇప్పటివరకు ఇచ్చిన జవాబులు లెక్కలోకి రావు, $count ఎనర్జీ తిరిగి రాదు.';
  }

  @override
  String get quizRefundFailed =>
      'Nyaya Kuralని చేరలేకపోయాం, కాబట్టి మీ ఎనర్జీ తిరిగి రాలేదు.';

  @override
  String get quizOptionCorrect => 'సరైన జవాబు';

  @override
  String get quizOptionWrong => 'మీ జవాబు, తప్పు';

  @override
  String get quizOptionSelected => 'ఎంచుకున్నారు';

  @override
  String get quizOptionChecking => 'తనిఖీ అవుతోంది';

  @override
  String get resultNoAnswer => 'జవాబు లేదు';

  @override
  String get resultHideReview => 'జవాబులు దాచు';

  @override
  String get reportSending => 'పంపుతోంది…';

  @override
  String get reportFailed =>
      'రిపోర్ట్ పంపలేకపోయాం. మీరు రాసింది ఉంది, మళ్లీ ప్రయత్నించండి.';

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
  String get resultKeepPractising => 'సాధన కొనసాగించండి';

  @override
  String get resultNewExam => 'కొత్త పరీక్ష';

  @override
  String get levelUpTitle => 'లెవెల్ అప్!';

  @override
  String levelUpCleared(int number) {
    return 'లెవెల్ $number పూర్తి';
  }

  @override
  String levelUpNextLevel(int number) {
    return 'లెవెల్ $number ఇప్పుడు తెరుచుకుంది';
  }

  @override
  String get levelUpChest => 'అధ్యాయ చెస్ట్ తెరవడానికి సిద్ధం';

  @override
  String levelUpNewChapter(String chapter) {
    return 'కొత్త అధ్యాయం: $chapter';
  }

  @override
  String levelUpRank(int before, int after) {
    return 'లీగ్ ర్యాంక్ #$before → #$after';
  }

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
    return '3 స్టార్ల బోనస్: +$count ఎనర్జీ';
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
  String get leaderboardPractice => 'ప్రాక్టీస్ ప్లేయర్';

  @override
  String leaderboardLearners(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'బోర్డులో $count మంది అభ్యాసకులు',
      one: 'బోర్డులో 1 అభ్యాసకుడు',
    );
    return '$_temp0';
  }

  @override
  String get leaderboardAllTimeJoin =>
      'ఆల్-టైమ్ బోర్డులో చేరడానికి ఒక క్విజ్ పూర్తి చేయండి.';

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
  String get chatTitle => 'Nyaya Kural AI';

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
      'ఈరోజు ఉచిత ప్రశ్నలు అయిపోయాయి. రేపు రండి లేదా మరిన్ని AI ప్రశ్నల కోసం Premium తీసుకోండి.';

  @override
  String get chatLimitReachedToday =>
      'ఈ రోజు ప్రశ్నలు అయిపోయాయి. రేపు మళ్ళీ అడగవచ్చు.';

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
  String get updatesSavedFilter => 'సేవ్ చేసినవి';

  @override
  String get updatesSavedEmpty =>
      'ఇంకా ఏమీ సేవ్ చేయలేదు. ఏ అప్‌డేట్‌పైనైనా బుక్‌మార్క్ నొక్కితే అది ఇక్కడ ఉంటుంది.';

  @override
  String get updatesEmpty => 'ఈ విభాగంలో ఇంకా అప్‌డేట్‌లు లేవు.';

  @override
  String get updatesSave => 'అప్‌డేట్ సేవ్ చేయండి';

  @override
  String get updatesUnsave => 'సేవ్ చేసిన వాటి నుండి తీసివేయండి';

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
  String get reminderTitle => 'నేటి సాధనకు సమయం';

  @override
  String reminderStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'మీ $count రోజుల స్ట్రీక్‌ను కొనసాగించండి: ఒక చిన్న క్విజ్ చాలు.',
    );
    return '$_temp0';
  }

  @override
  String get reminderLearn =>
      'రోజుకు ఒక చిన్న క్విజ్ నిజమైన న్యాయ అవగాహనను పెంచుతుంది.';

  @override
  String get reminderJourney =>
      'మీ అభ్యాస మార్గం ఎదురుచూస్తోంది. తదుపరి మజిలీకి సిద్ధమా?';

  @override
  String get reminderRights =>
      'మీ హక్కులు తెలుసుకోండి: రెండు నిమిషాల క్విజ్ మీ కోసం సిద్ధంగా ఉంది.';

  @override
  String get settingsReminderTime => 'రిమైండర్ సమయం';

  @override
  String get settingsRemindersBlocked =>
      'Nyaya Kuralకు నోటిఫికేషన్లు ఆఫ్‌లో ఉన్నాయి. రిమైండర్లు పొందడానికి ఫోన్ సెట్టింగ్స్‌లో వాటిని ఆన్ చేయండి.';

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
  String get settingsPremium => 'Nyaya Kural Premium';

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
  String get settingsDuelRecord => 'విజయాలు';

  @override
  String get settingsAbout => 'గురించి';

  @override
  String get settingsDisclaimer => 'న్యాయ నిరాకరణ';

  @override
  String get settingsDisclaimerBody =>
      'Nyaya Kural ఒక విద్యా యాప్. ప్రశ్నలు, వివరణలు, అప్‌డేట్‌లు, AI జవాబులు సాధారణ సమాచారం మాత్రమే, న్యాయ సలహా కాదు. చట్టాలు మారుతుంటాయి — ఎల్లప్పుడూ అధికారిక గెజిట్‌లో సరిచూసుకోండి లేదా న్యాయవాదిని సంప్రదించండి.';

  @override
  String get settingsPrivacy => 'గోప్యత';

  @override
  String get settingsPrivacyBody =>
      'మీ పురోగతి మీ ఖాతాలో నిల్వ అవుతుంది, అలాగే మీరు యాప్‌ను తెరిచే రోజులు కూడా, ప్రజలు తిరిగి వస్తున్నారో లేదో మేము తెలుసుకోవడానికి. మీరు AIని అడిగే ప్రశ్నలు జవాబు రాయడానికి మాత్రమే మా AI ప్రొవైడర్‌కు పంపబడతాయి. యాప్ క్రాష్ అయితే, దాన్ని సరిచేయడంలో సహాయపడే చిన్న సాంకేతిక నివేదిక (మీ జవాబులు లేదా వ్యక్తిగత వివరాలు లేకుండా) పంపబడుతుంది. సెట్టింగ్స్‌లో మీ ఖాతాను తొలగించవచ్చు.';

  @override
  String settingsVersion(String version) {
    return 'వెర్షన్ $version';
  }

  @override
  String get settingsReset => 'ఈ ఫోన్‌ను రీసెట్ చేయండి';

  @override
  String get settingsResetConfirm =>
      'ఇది స్వాగత దశలను మళ్లీ చూపించి, ఈ ఫోన్ సెట్టింగ్‌లను తొలగిస్తుంది. మీ XP, స్టార్లు, కాయిన్‌లు, స్ట్రీక్ మీ ఖాతాలో సురక్షితంగా ఉంటాయి.';

  @override
  String get settingsResetAction => 'రీసెట్ చేయండి';

  @override
  String get premiumTitle => 'Nyaya Kural Premium';

  @override
  String get premiumHeadline => 'ప్రతిరోజూ మరింత నేర్చుకోండి';

  @override
  String get premiumBenefitEnergy => 'అపరిమిత ఎనర్జీ';

  @override
  String premiumBenefitEnergySub(int free) {
    return 'ఉచితం: రోజుకు $free ఎనర్జీ. Premium: మీకు నచ్చినన్ని క్విజ్‌లు ఆడండి.';
  }

  @override
  String get premiumBenefitAi => 'మరింత Nyaya Kural AI';

  @override
  String premiumBenefitAiSub(int free, int premium) {
    return 'ఉచితం: రోజుకు $free ప్రశ్నలు. Premium: రోజుకు $premium.';
  }

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
  String get premiumActivated => 'Nyaya Kural Premiumకి స్వాగతం!';

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

  @override
  String get searchTitle => 'వెతకండి';

  @override
  String get searchHint => 'చట్టాలు, అంశాలు, అప్‌డేట్‌లు వెతకండి';

  @override
  String get searchTopics => 'అంశాలు';

  @override
  String get searchLaws => 'చట్టాలు';

  @override
  String get searchUpdates => 'అప్‌డేట్‌లు';

  @override
  String searchAskAi(String query) {
    return 'AIని అడగండి: “$query”';
  }

  @override
  String searchNoResults(String query) {
    return '“$query”కు ఇంకా ఏదీ సరిపోలలేదు. AIని అడగండి.';
  }

  @override
  String get exploreTitle => 'చట్టాన్ని తెలుసుకోండి';

  @override
  String get exploreSubtitle => 'భారతీయ చట్టంపై మీ అవగాహనను పెంచుకోండి';

  @override
  String get exploreStartHere => 'ఇక్కడ మొదలుపెట్టండి';

  @override
  String get exploreFeatured => 'ముఖ్యమైనవి';

  @override
  String get exploreButton => 'చూడండి';

  @override
  String get exploreCoreLaws => 'ప్రధాన చట్టాలు';

  @override
  String get exploreViewAll => 'అన్నీ చూడండి';

  @override
  String get exploreLegacy => 'పాత చట్టాలు';

  @override
  String get exploreAskAi => 'AIని అడగండి';

  @override
  String exploreAskPrompt(String law) {
    return '$lawను సులభమైన మాటల్లో వివరించండి: అది దేనికి వర్తిస్తుంది, నేను తెలుసుకోవాల్సిన ముఖ్య నిబంధనలు ఏమిటి.';
  }

  @override
  String get lawConstitutionTitle => 'భారత రాజ్యాంగం';

  @override
  String get lawConstitutionDesc =>
      'ప్రాథమిక హక్కులు, ఆదేశిక సూత్రాలు, విధులు మరియు మరిన్ని.';

  @override
  String get lawBnsTitle => 'భారతీయ న్యాయ సంహిత (BNS)';

  @override
  String get lawBnsShort => 'భారతీయ న్యాయ సంహిత';

  @override
  String get lawBnsDesc => 'నేరాలను నిర్వచించే చట్టం';

  @override
  String get lawBnsFeatured => 'భారతదేశ కొత్త నేర చట్టం కింద నేరాలు, శిక్షలు.';

  @override
  String get lawBnssTitle => 'భారతీయ నాగరిక సురక్షా సంహిత (BNSS)';

  @override
  String get lawBnssDesc => 'నేర ప్రక్రియ చట్టం';

  @override
  String get lawBsaTitle => 'భారతీయ సాక్ష్య అధినియం (BSA)';

  @override
  String get lawBsaDesc => 'సాక్ష్యాల చట్టం';

  @override
  String get lawEverydayTitle => 'నిత్యజీవిత చట్టం';

  @override
  String get lawEverydayDesc => 'రోజువారీ జీవితంలో మీ హక్కులు తెలుసుకోండి';

  @override
  String get lawEverydayFeatured =>
      'వినియోగదారు, అద్దె, పని ప్రదేశం, కుటుంబ హక్కులు, సులభంగా వివరించాం.';

  @override
  String get lawLegacyTitle => 'IPC & CrPC (పాత చట్టాలు)';

  @override
  String get lawLegacyDesc =>
      'జూలై 2024లో మార్చబడ్డాయి. సూచన మరియు పోలిక కోసం ఉంచబడ్డాయి.';

  @override
  String get chapterConstitutionTitle => 'రాజ్యాంగ ప్రాథమికాంశాలు';

  @override
  String get chapterConstitutionSubtitle =>
      'ప్రవేశిక, పార్లమెంటు, న్యాయస్థానాలు, సవరణలు';

  @override
  String get chapterRightsTitle => 'హక్కులు & విధులు';

  @override
  String get chapterRightsSubtitle =>
      'ప్రాథమిక హక్కులు, ఆదేశిక సూత్రాలు, రిట్‌లు';

  @override
  String get chapterCriminalTitle => 'నేర చట్టం (BNS)';

  @override
  String get chapterCriminalSubtitle => 'కొత్త సంహిత కింద నేరాలు';

  @override
  String get chapterProcedureTitle => 'విధానం & సాక్ష్యం';

  @override
  String get chapterProcedureSubtitle => 'BNSS, BSA, FIR, అరెస్టు, బెయిల్';

  @override
  String get chapterCivilTitle => 'ఒప్పందాలు & వినియోగదారులు';

  @override
  String get chapterCivilSubtitle =>
      'ఒప్పందాలు, వినియోగదారుల హక్కులు, పరిష్కారాలు';

  @override
  String get chapterEverydayTitle => 'నిత్యజీవిత చట్టం';

  @override
  String get chapterEverydaySubtitle => 'రోజువారీ జీవితానికి చట్టం';

  @override
  String get authCreateTitle => 'మీ ఉచిత ఖాతాను సృష్టించండి';

  @override
  String get authCreateSubtitle =>
      'ప్రశ్నలు Nyaya Kural సమీక్షించిన సేకరణ నుండి వస్తాయి, మీ ఫలితాలు మీ ఖాతాలో భద్రంగా ఉంటాయి.';

  @override
  String get authSignInTitle => 'మళ్లీ స్వాగతం';

  @override
  String get authSignInSubtitle =>
      'ప్రాక్టీస్ కొనసాగించడానికి సైన్ ఇన్ చేయండి.';

  @override
  String get authName => 'మీ పేరు';

  @override
  String get authEmail => 'ఇమెయిల్';

  @override
  String get authPassword => 'పాస్‌వర్డ్';

  @override
  String get authPasswordHint => 'కనీసం 8 అక్షరాలు';

  @override
  String get authCreate => 'ఖాతా సృష్టించండి';

  @override
  String get authSignIn => 'సైన్ ఇన్';

  @override
  String get authHaveAccount => 'నాకు ఇప్పటికే ఖాతా ఉంది';

  @override
  String get authNeedAccount => 'కొత్తవారా? ఖాతా సృష్టించండి';

  @override
  String get authErrorCredentials => 'ఇమెయిల్ లేదా పాస్‌వర్డ్ తప్పు.';

  @override
  String get authErrorEmailTaken =>
      'ఈ ఇమెయిల్‌తో ఖాతా ఇప్పటికే ఉంది. బదులుగా సైన్ ఇన్ చేయండి.';

  @override
  String get authErrorNetwork =>
      'ఇప్పుడు Nyaya Kural ను చేరుకోలేకపోతున్నాం. కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authErrorRateLimited =>
      'చాలాసార్లు ప్రయత్నించారు. కొన్ని నిమిషాలు ఆగి మళ్లీ ప్రయత్నించండి.';

  @override
  String get authErrorInvalid =>
      'సరైన ఇమెయిల్, కనీసం 8 అక్షరాల పాస్‌వర్డ్ ఇవ్వండి.';

  @override
  String get authErrorName => 'మీ పేరు ఇవ్వండి.';

  @override
  String get authForgot => 'పాస్‌వర్డ్ మర్చిపోయారా?';

  @override
  String get authResetTitle => 'మీ పాస్‌వర్డ్ మార్చండి';

  @override
  String get authResetSubtitle =>
      'మీ ఖాతా ఈమెయిల్ ఇవ్వండి. మేము 6 అంకెల కోడ్ పంపుతాము.';

  @override
  String get authResetSend => 'కోడ్ పంపండి';

  @override
  String authResetSentTo(String email) {
    return '$emailతో ఖాతా ఉంటే, దానికి 6 అంకెల కోడ్ పంపాము. ఇది 15 నిమిషాలు పనిచేస్తుంది. కనిపించకపోతే స్పామ్ ఫోల్డర్ చూడండి.';
  }

  @override
  String get authResetCode => '6 అంకెల కోడ్';

  @override
  String get authResetNewPassword => 'కొత్త పాస్‌వర్డ్';

  @override
  String get authResetSave => 'కొత్త పాస్‌వర్డ్ సెట్ చేయండి';

  @override
  String get authResetResend => 'కొత్త కోడ్ పంపండి';

  @override
  String get authResetErrorCode =>
      'ఈ కోడ్ తప్పు లేదా గడువు ముగిసింది. కొత్త కోడ్ అడగండి.';

  @override
  String get authResetUnavailable =>
      'పాస్‌వర్డ్ మార్చడం ఇప్పుడు అందుబాటులో లేదు. దయచేసి తర్వాత ప్రయత్నించండి.';

  @override
  String get authResetErrorInvalid =>
      '6 అంకెల కోడ్ మరియు కనీసం 8 అక్షరాల కొత్త పాస్‌వర్డ్ ఇవ్వండి.';

  @override
  String get authResetDone => 'మీ పాస్‌వర్డ్ మార్చబడింది.';

  @override
  String get settingsAccount => 'ఖాతా';

  @override
  String settingsSignedInAs(String email) {
    return '$emailగా సైన్ ఇన్ అయ్యారు';
  }

  @override
  String get settingsSignIn => 'సైన్ ఇన్ చేయండి లేదా ఖాతా సృష్టించండి';

  @override
  String get settingsSignOut => 'సైన్ అవుట్';

  @override
  String get updateRequiredTitle => 'దయచేసి Nyaya Kural ను అప్‌డేట్ చేయండి';

  @override
  String get updateRequiredBody =>
      'యాప్ ఈ వెర్షన్ చాలా పాతది, ఇక పని చేయదు. కొనసాగడానికి అప్‌డేట్ చేయండి. మీ పురోగతి మీ ఖాతాలో భద్రంగా ఉంది, కాబట్టి ఏదీ పోదు.';

  @override
  String get updateRequiredAction => 'అప్‌డేట్ చేయండి';

  @override
  String get settingsDeleteAccount => 'ఖాతాను తొలగించు';

  @override
  String get settingsDeleteAccountBody =>
      'ఇది మీ ఖాతాను మరియు దానిలోని ప్రతిదాన్ని శాశ్వతంగా తొలగిస్తుంది: పురోగతి, XP, నాణేలు, సేవ్ చేసిన ప్రశ్నలు, లీగ్ స్థానం. దీన్ని తిరిగి తీసుకురాలేరు. నిర్ధారించడానికి మీ పాస్‌వర్డ్ నమోదు చేయండి.';

  @override
  String get settingsDeleteAccountPassword => 'పాస్‌వర్డ్';

  @override
  String get settingsDeleteAccountAction => 'నా ఖాతాను తొలగించు';

  @override
  String get settingsDeleteAccountWrong => 'ఆ పాస్‌వర్డ్ సరైనది కాదు.';

  @override
  String get settingsDeleteAccountFailed =>
      'ఖాతాను తొలగించలేకపోయాం. కనెక్షన్ చూసి మళ్ళీ ప్రయత్నించండి.';

  @override
  String get quizSendFailed =>
      'మీ జవాబును పంపలేకపోయాం. కనెక్షన్ చూసి మళ్లీ నొక్కండి.';

  @override
  String get quizSubmitFailed => 'మీ ఫలితం తీసుకురాలేకపోయాం. కనెక్షన్ చూడండి.';

  @override
  String get quizRetry => 'మళ్లీ ప్రయత్నించు';

  @override
  String get quizScoring => 'మీ కేసుకు మార్కులు వేస్తున్నాం…';

  @override
  String get quizOffline =>
      'Nyaya Kural ను చేరుకోలేకపోతున్నాం. కనెక్షన్ చూసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get quizSignedOut =>
      'మీ సెషన్ ముగిసింది. ఆడటానికి మళ్లీ సైన్ ఇన్ చేయండి.';
}
