import 'package:material_ui/material_ui.dart';

import '../../features/gamification/domain/league.dart';
import '../../features/profile/domain/user_profile.dart';
import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppLocalizationsX on AppLocalizations {
  String tierName(LeagueTier t) => switch (t.key) {
        'nyayaPanchayat' => tier_nyayaPanchayat,
        'gramNyayalaya' => tier_gramNyayalaya,
        'munsiffCourt' => tier_munsiffCourt,
        'magistrateCourt' => tier_magistrateCourt,
        'districtCourt' => tier_districtCourt,
        'sessionsCourt' => tier_sessionsCourt,
        'highCourt' => tier_highCourt,
        _ => tier_supremeCourt,
      };

  String personaName(Persona p) => switch (p) {
        Persona.advocate => personaAdvocate,
        Persona.aspirant => personaAspirant,
        Persona.citizen => personaCitizen,
      };

  String personaDesc(Persona p) => switch (p) {
        Persona.advocate => personaAdvocateDesc,
        Persona.aspirant => personaAspirantDesc,
        Persona.citizen => personaCitizenDesc,
      };
}

/// Chapter names live in the app's translations; the server only knows the chapter id.
extension ChapterNamesX on AppLocalizations {
  String chapterTitle(String id) => switch (id) {
        'constitution' => chapterConstitutionTitle,
        'rights' => chapterRightsTitle,
        'criminal' => chapterCriminalTitle,
        'procedure' => chapterProcedureTitle,
        'civil' => chapterCivilTitle,
        'everyday' => chapterEverydayTitle,
        _ => '',
      };

  String chapterSubtitle(String id) => switch (id) {
        'constitution' => chapterConstitutionSubtitle,
        'rights' => chapterRightsSubtitle,
        'criminal' => chapterCriminalSubtitle,
        'procedure' => chapterProcedureSubtitle,
        'civil' => chapterCivilSubtitle,
        'everyday' => chapterEverydaySubtitle,
        _ => '',
      };
}
