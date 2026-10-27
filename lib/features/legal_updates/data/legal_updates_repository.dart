import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';

enum UpdateCategory { supremeCourt, highCourts, legislation, explainer }

@immutable
class LegalUpdate {
  const LegalUpdate({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.keyPoints,
    required this.whyItMatters,
    required this.source,
    required this.date,
    required this.readMinutes,
  });

  final String id;
  final UpdateCategory category;
  final String title;
  final String summary;
  final List<String> keyPoints;
  final String whyItMatters;
  final String source;
  final DateTime date;
  final int readMinutes;

  /// Card thumbnail; until it exists the card shows its category's painting.
  /// Prompts are in docs/UPDATES_ART.md.
  String get image => 'assets/images/update_${id.replaceAll('-', '_')}.webp';
}

final legalUpdatesRepositoryProvider = Provider<LegalUpdatesRepository>((ref) => const CuratedLegalUpdatesRepository());

final legalUpdatesProvider = FutureProvider<List<LegalUpdate>>(
  (ref) => ref.watch(legalUpdatesRepositoryProvider).fetch(),
);

final savedUpdatesProvider = NotifierProvider<SavedUpdatesController, Set<String>>(SavedUpdatesController.new);

/// Ids of updates the user bookmarked, kept on the device.
class SavedUpdatesController extends Notifier<Set<String>> {
  static const _key = 'saved_updates_v1';

  LocalStore get _store => ref.read(localStoreProvider);

  @override
  Set<String> build() => (_store.readJsonList(_key) ?? const []).cast<String>().toSet();

  void toggle(String id) {
    state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};
    _store.writeJson(_key, state.toList());
  }
}

abstract interface class LegalUpdatesRepository {
  Future<List<LegalUpdate>> fetch();
}

/// Editor-curated starter feed of landmark developments. Replace with a
/// CMS/API-backed implementation (same interface) for a live news feed.
class CuratedLegalUpdatesRepository implements LegalUpdatesRepository {
  const CuratedLegalUpdatesRepository();

  @override
  Future<List<LegalUpdate>> fetch() async {
    final list = [..._items]..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static final _items = <LegalUpdate>[
    LegalUpdate(
      id: 'tn-governor-assent',
      category: UpdateCategory.supremeCourt,
      title: 'Supreme Court sets timelines for Governors on State Bills',
      summary: 'In State of Tamil Nadu v. Governor of Tamil Nadu, the Supreme Court held that a Governor cannot sit indefinitely on Bills passed by a State legislature and laid down time limits for acting under Article 200.',
      keyPoints: [
        'A Governor must act on a Bill within a reasonable time — there is no "pocket veto".',
        'The Court indicated outer time limits for assent, withholding or reserving a Bill.',
        'Inaction beyond those limits can be challenged before constitutional courts.',
      ],
      whyItMatters:
          'It strengthens federalism by ensuring elected State legislatures are not stalled by delays at Raj Bhavan.',
      source: 'Supreme Court of India, 8 April 2025',
      date: DateTime(2025, 4, 8),
      readMinutes: 3,
    ),
    LegalUpdate(
      id: 'waqf-amendment-2025',
      category: UpdateCategory.legislation,
      title: 'Waqf (Amendment) Act, 2025 receives Presidential assent',
      summary: 'Parliament amended the Waqf Act, 1995, changing how waqf properties are registered, managed and adjudicated. The law received assent in April 2025 and its validity has been challenged before the Supreme Court.',
      keyPoints: [
        'Renames the law as the Unified Waqf Management, Empowerment, Efficiency and Development Act.',
        'Changes the composition of the Central Waqf Council and State Waqf Boards.',
        'Petitions challenging the amendments were taken up by the Supreme Court.',
      ],
      whyItMatters: 'Waqf boards manage significant land holdings; the changes affect property rights, administration and minority-rights debates.',
      source: 'Gazette of India, April 2025',
      date: DateTime(2025, 4, 5),
      readMinutes: 3,
    ),
    LegalUpdate(
      id: 'pocso-csam',
      category: UpdateCategory.supremeCourt,
      title: 'Storing or watching child sexual abuse material is an offence',
      summary: 'In Just Rights for Children Alliance v. S. Harish, the Supreme Court held that viewing, possessing or storing child sexual exploitative material can be an offence under the POCSO Act and the IT Act, overturning a Madras High Court ruling.',
      keyPoints: [
        'Mere possession with intent to share, or failure to delete/report, attracts POCSO Section 15.',
        'The Court urged Parliament to use the term "child sexual exploitative and abuse material".',
        'Courts should not use the phrase "child pornography".',
      ],
      whyItMatters: 'It closes a gap that treated private viewing as harmless and strengthens child protection online.',
      source: 'Supreme Court of India, 23 September 2024',
      date: DateTime(2024, 9, 23),
      readMinutes: 3,
    ),
    LegalUpdate(
      id: 'sc-subclassification',
      category: UpdateCategory.supremeCourt,
      title: 'States may sub-classify Scheduled Castes for reservation',
      summary: 'A seven-judge Constitution Bench in State of Punjab v. Davinder Singh held (6:1) that States can sub-classify Scheduled Castes to give more benefits to the most backward groups, overruling E.V. Chinnaiah (2004).',
      keyPoints: [
        'Sub-classification must be backed by empirical data on backwardness and representation.',
        'A State cannot reserve 100% of the SC quota for one sub-group.',
        'Several judges suggested a "creamy layer" test for SCs and STs.',
      ],
      whyItMatters: 'It reshapes how reservation benefits are distributed within Scheduled Castes across States.',
      source: 'Supreme Court of India, 1 August 2024',
      date: DateTime(2024, 8, 1),
      readMinutes: 4,
    ),
    LegalUpdate(
      id: 'new-criminal-laws',
      category: UpdateCategory.legislation,
      title: 'BNS, BNSS and BSA replace IPC, CrPC and Evidence Act',
      summary: 'From 1 July 2024, the Bharatiya Nyaya Sanhita, Bharatiya Nagarik Suraksha Sanhita and Bharatiya Sakshya Adhiniyam replaced the colonial-era IPC, CrPC and Indian Evidence Act for offences committed on or after that date.',
      keyPoints: [
        'Zero FIR and e-FIR are now expressly recognised (BNSS Section 173).',
        'Community service is introduced as a punishment for certain petty offences.',
        'Electronic records are treated as primary evidence in many cases (BSA).',
      ],
      whyItMatters: 'Every citizen, police officer and lawyer now works with new section numbers — older cases still run under the old codes.',
      source: 'Ministry of Home Affairs notification',
      date: DateTime(2024, 7, 1),
      readMinutes: 4,
    ),
    LegalUpdate(
      id: 'electoral-bonds',
      category: UpdateCategory.supremeCourt,
      title: 'Electoral Bonds Scheme struck down as unconstitutional',
      summary: 'In Association for Democratic Reforms v. Union of India, a five-judge bench unanimously held the Electoral Bonds Scheme violated voters\' right to information under Article 19(1)(a).',
      keyPoints: [
        'Anonymous political funding was held to violate the right to information.',
        'SBI was directed to stop issuing bonds and disclose details to the Election Commission.',
        'Related amendments to the Companies Act and RP Act were struck down.',
      ],
      whyItMatters: 'It strengthens transparency in political funding and voters\' informed choice.',
      source: 'Supreme Court of India, 15 February 2024',
      date: DateTime(2024, 2, 15),
      readMinutes: 3,
    ),
    LegalUpdate(
      id: 'dpdp-act',
      category: UpdateCategory.legislation,
      title: 'Digital Personal Data Protection Act, 2023 — what it means for you',
      summary: 'India\'s first comprehensive data protection law gives individuals ("Data Principals") rights over their personal data and places duties on companies ("Data Fiduciaries"). It is being operationalised in phases through Rules.',
      keyPoints: [
        'Consent must be free, specific, informed and withdrawable.',
        'You can seek access, correction and erasure of your personal data.',
        'A Data Protection Board adjudicates breaches; penalties can reach ₹250 crore.',
      ],
      whyItMatters: 'Apps and companies must now justify why they collect your data and protect it.',
      source: 'Act No. 22 of 2023',
      date: DateTime(2023, 8, 11),
      readMinutes: 4,
    ),
    LegalUpdate(
      id: 'explainer-zero-fir',
      category: UpdateCategory.explainer,
      title: 'Explainer: Zero FIR and e-FIR under BNSS',
      summary: 'You can report a cognizable offence at any police station, regardless of where it happened. The station must register a "Zero FIR" and transfer it to the station with jurisdiction.',
      keyPoints: [
        'Recognised in BNSS Section 173(1).',
        'Information can be given electronically; it must be signed within three days to be taken on record.',
        'You are entitled to a free copy of the FIR.',
      ],
      whyItMatters: 'Victims — especially of crimes against women — no longer get turned away over jurisdiction.',
      source: 'Bharatiya Nagarik Suraksha Sanhita, 2023',
      date: DateTime(2024, 7, 2),
      readMinutes: 2,
    ),
    LegalUpdate(
      id: 'explainer-legal-aid',
      category: UpdateCategory.explainer,
      title: 'Explainer: Who can get free legal aid?',
      summary: 'Under Section 12 of the Legal Services Authorities Act, 1987, women, children, SC/ST members, persons in custody, persons with disabilities, victims of disasters and people below the income limit are entitled to free legal services.',
      keyPoints: [
        'Apply at the District/Taluk Legal Services Authority or online via NALSA.',
        'Call the national legal aid helpline 15100.',
        'Free legal aid flows from Article 39A of the Constitution.',
      ],
      whyItMatters: 'Lack of money should never stop anyone from getting justice.',
      source: 'Legal Services Authorities Act, 1987',
      date: DateTime(2024, 6, 15),
      readMinutes: 2,
    ),
    LegalUpdate(
      id: 'mediation-act',
      category: UpdateCategory.legislation,
      title: 'Mediation Act, 2023 makes pre-litigation mediation mainstream',
      summary: 'The Mediation Act, 2023 creates a framework for institutional, online and community mediation, with mediated settlement agreements enforceable like court decrees.',
      keyPoints: [
        'Mediation should ordinarily conclude within 120 days, extendable by 60 days.',
        'Establishes the Mediation Council of India.',
        'Online mediation is expressly recognised.',
      ],
      whyItMatters: 'Faster, cheaper resolution of disputes and less burden on courts.',
      source: 'Act No. 32 of 2023',
      date: DateTime(2023, 9, 14),
      readMinutes: 3,
    ),
  ];
}
