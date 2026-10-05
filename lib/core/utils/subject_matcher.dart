import 'dart:math' as math;

/// Represents the hierarchy tier that satisfied the subject match.
enum MatchTier {
  none,
  emptyListAllowed, // Rule 1: Empty "Can Teach" list means eligible for all subjects
  subjectIdExact,   // Tier 1: Exact Subject ID match
  subjectCodeExact, // Tier 1: Exact Subject Code match (normalized)
  fullNameExact,    // Tier 2: Exact normalized full subject-name match
  exactToken,       // Tier 3: Exact normalized TOKEN/WORD match
  stemToken,        // Tier 3: Stemmed token match (e.g. systems -> system, arts -> art)
  multiTokenPhrase, // Tier 4: Partial multi-token phrase match
  acronym,          // Tier 4: Acronym match (e.g. SEPM, DBMS, OS, AI)
  abbreviation,     // Tier 4: Standard abbreviation expansion (e.g. mgmt -> management)
  fuzzyToken,       // Tier 5: Conservative fuzzy token match for spelling mistakes
}

/// Detailed result of evaluating a professor-subject match.
class MatchResult {
  final bool isEligible;
  final MatchTier tier;
  final String? matchedProfessorEntry;
  final String? matchedSubjectToken;
  final String? matchedProfessorToken;
  final String explanation;

  const MatchResult({
    required this.isEligible,
    required this.tier,
    this.matchedProfessorEntry,
    this.matchedSubjectToken,
    this.matchedProfessorToken,
    required this.explanation,
  });

  @override
  String toString() =>
      'MatchResult(eligible: $isEligible, tier: $tier, explanation: "$explanation")';
}

/// Centralized, reusable utility for professor-subject eligibility matching across TimePilot.
///
/// Implements the 5-tier matching hierarchy:
/// 1. Subject ID / Code exact match
/// 2. Exact normalized full subject-name match
/// 3. Exact normalized TOKEN/WORD match
/// 4. Partial multi-token match & standard abbreviations/acronyms
/// 5. Conservative fuzzy token matching for spelling mistakes (e.g. softwre -> software)
///
/// NOTE: Unrestricted substring matching is strictly prohibited to avoid false positives
/// (e.g., "art" will NEVER match "Smart Systems" or "Earth Sciences").
class SubjectMatcher {
  SubjectMatcher._();

  /// Stop words that are ignored when matching individual tokens.
  /// These common prepositions, conjunctions, and articles cannot trigger eligibility alone.
  static const Set<String> stopWords = {
    'and',
    'or',
    'of',
    'in',
    'to',
    'for',
    'the',
    'a',
    'an',
    'on',
    'at',
    'by',
    'with',
    'as',
    'is',
    'from',
    'into',
    'through',
    'during',
    'including',
    'against',
    'among',
    'throughout',
    'despite',
    'towards',
    'upon',
    'concerning',
    'about',
    'like',
    'over',
    'before',
    'between',
    'after',
    'since',
    'without',
    'under',
    'within',
    'along',
    'following',
    'across',
    'behind',
    'beyond',
    'plus',
    'except',
    'but',
    'up',
    'out',
    'around',
    'down',
    'off',
    'above',
    'near',
    // Roman numerals often attached to subject names (e.g. Physics I, Calculus II)
    'i',
    'ii',
    'iii',
    'iv',
    'v',
    'vi',
    'vii',
    'viii',
    'ix',
    'x',
  };

  /// Common academic & technical abbreviation expansions.
  static const Map<String, List<String>> abbreviationMap = {
    'ai': ['artificial intelligence'],
    'ml': ['machine learning'],
    'dl': ['deep learning'],
    'ds': ['data structures'],
    'dsa': ['data structures and algorithms'],
    'dbms': ['database management systems', 'database management system'],
    'db': ['database', 'databases'],
    'os': ['operating systems', 'operating system'],
    'se': ['software engineering'],
    'pm': ['project management'],
    'spm': ['software project management'],
    'cn': ['computer networks', 'computer network'],
    'nw': ['networks', 'network'],
    'net': ['networks', 'network'],
    'coa': [
      'computer organization and architecture',
      'computer organization and design'
    ],
    'co': ['computer organization'],
    'ca': ['computer architecture'],
    'toc': ['theory of computation'],
    'cd': ['compiler design'],
    'daa': ['design and analysis of algorithms'],
    'ada': ['analysis and design of algorithms'],
    'wt': ['web technologies', 'web technology'],
    'iot': ['internet of things'],
    'oop': ['object oriented programming'],
    'oops': [
      'object oriented programming systems',
      'object oriented programming'
    ],
    'crypto': ['cryptography'],
    'cns': ['cryptography and network security'],
    'cyber': ['cybersecurity', 'cyber security'],
    'nlp': ['natural language processing'],
    'cv': ['computer vision'],
    'math': ['mathematics'],
    'maths': ['mathematics'],
    'phy': ['physics'],
    'phys': ['physics'],
    'chem': ['chemistry'],
    'bio': ['biology'],
    'stat': ['statistics'],
    'stats': ['statistics'],
    'mgmt': ['management'],
    'mgt': ['management'],
    'prog': ['programming'],
    'algo': ['algorithm', 'algorithms'],
    'algos': ['algorithms'],
    'sys': ['systems', 'system'],
    'env': ['environmental'],
    'sw': ['software'],
    'hw': ['hardware'],
    'intro': ['introduction'],
    'lab': ['laboratory'],
  };

  /// Normalizes a subject or query string:
  /// - converts to lowercase
  /// - replaces '&' with ' and '
  /// - preserves special language identifiers (c++, c#, .net)
  /// - replaces punctuation with spaces
  /// - collapses multiple whitespace into single spaces and trims
  static String normalize(String input) {
    if (input.isEmpty) return '';
    var text = input.toLowerCase();

    // Replace '&' with ' and '
    text = text.replaceAll('&', ' and ');

    // Normalize specific programming terms before stripping punctuation
    text = text.replaceAll(RegExp(r'\bc\+\+\b'), 'cpp');
    text = text.replaceAll(RegExp(r'\bc#\b'), 'csharp');
    text = text.replaceAll(RegExp(r'\b\.net\b'), 'dotnet');

    // Replace all other punctuation with spaces
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    // Collapse multiple whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Normalizes subject codes by lowercasing and stripping all non-alphanumeric characters.
  /// E.g. "CS-301", "cs 301", "CS301" -> "cs301".
  static String normalizeCode(String input) {
    if (input.isEmpty) return '';
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Extracts individual tokens from normalized string.
  static List<String> extractTokens(String input) {
    final norm = normalize(input);
    if (norm.isEmpty) return const [];
    return norm.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Extracts meaningful tokens, filtering out stop words.
  static List<String> extractMeaningfulTokens(String input) {
    final tokens = extractTokens(input);
    return tokens.where((t) => isMeaningfulToken(t)).toList();
  }

  /// Checks if a single token is meaningful.
  static bool isMeaningfulToken(String token) {
    if (token.isEmpty) return false;
    if (stopWords.contains(token)) return false;

    // Single-character tokens are not meaningful on their own, except recognized languages ('c', 'r')
    if (token.length == 1) {
      return token == 'c' || token == 'r';
    }

    // 2-character tokens are meaningful if they are recognized abbreviations
    if (token.length == 2) {
      return abbreviationMap.containsKey(token) || _isKnownReverseAbbreviation(token);
    }

    return true;
  }

  /// Simple stemmer to equate singular and plural forms without over-stemming.
  /// E.g.: "systems" -> "system", "networks" -> "network", "arts" -> "art".
  static String stemWord(String word) {
    if (word.length <= 3) return word;
    if (word.endsWith('ies') && word.length > 4) {
      return '${word.substring(0, word.length - 3)}y'; // technologies -> technology
    }
    if (word.endsWith('ses') ||
        word.endsWith('zes') ||
        word.endsWith('ches') ||
        word.endsWith('shes')) {
      return word.substring(0, word.length - 2); // classes -> class
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 3) {
      return word.substring(0, word.length - 1); // systems -> system, arts -> art
    }
    return word;
  }

  /// Computes the Damerau-Levenshtein distance between two strings,
  /// accounting for insertions, deletions, substitutions, and adjacent transpositions.
  static int damerauLevenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final n = s.length;
    final m = t.length;
    final d = List.generate(n + 1, (_) => List.filled(m + 1, 0));

    for (int i = 0; i <= n; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= m; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= n; i++) {
      for (int j = 1; j <= m; j++) {
        final cost = (s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1)) ? 0 : 1;
        var minVal = math.min(
          d[i - 1][j] + 1, // deletion
          math.min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost), // insertion / substitution
        );

        // Transposition
        if (i > 1 &&
            j > 1 &&
            s.codeUnitAt(i - 1) == t.codeUnitAt(j - 2) &&
            s.codeUnitAt(i - 2) == t.codeUnitAt(j - 1)) {
          minVal = math.min(minVal, d[i - 2][j - 2] + 1);
        }

        d[i][j] = minVal;
      }
    }
    return d[n][m];
  }

  /// Conservative fuzzy match for spelling mistakes.
  ///
  /// Constraints to strictly avoid false positives:
  /// 1. Both tokens must have length >= 4 (short words like 'art', 'net', 'os' NEVER fuzzy match).
  /// 2. First characters must match (typing errors rarely change the starting letter).
  /// 3. Length difference must be <= 2.
  /// 4. Damerau-Levenshtein distance & similarity threshold:
  ///    - max length <= 5: distance <= 1, similarity >= 0.8
  ///    - max length 6..8: distance <= 1, similarity >= 0.8 (prevents "computer" matching "compiler")
  ///    - max length >= 9: distance <= 2, similarity >= 0.8 (e.g. "enginering" -> "engineering", "managment" -> "management")
  static bool isConservativeFuzzyMatch(String a, String b) {
    if (a == b) return true;
    if (a.length < 4 || b.length < 4) return false;

    // Do NOT fuzzy match tokens that contain numbers (e.g. "cs301" vs "cs302")
    // Different numbers represent different course codes / levels, not spelling errors!
    if (RegExp(r'\d').hasMatch(a) || RegExp(r'\d').hasMatch(b)) {
      return false;
    }

    // Starting character must agree
    if (a[0] != b[0]) return false;

    final lenDiff = (a.length - b.length).abs();
    if (lenDiff > 2) return false;

    final maxLen = math.max(a.length, b.length);
    final dist = damerauLevenshtein(a, b);
    final similarity = 1.0 - (dist / maxLen);

    if (maxLen <= 5) {
      return dist <= 1 && similarity >= 0.8;
    } else if (maxLen <= 8) {
      return dist <= 1 && similarity >= 0.8;
    } else {
      return dist <= 2 && similarity >= 0.8;
    }
  }

  /// Generates the acronym formed by the first letters of meaningful tokens.
  /// E.g. ["software", "engineering", "project", "management"] -> "sepm".
  static String generateAcronym(List<String> meaningfulTokens) {
    if (meaningfulTokens.isEmpty) return '';
    return meaningfulTokens.map((t) => t[0]).join('');
  }

  /// Generates sub-acronyms for 2 or more contiguous tokens.
  /// E.g. "Software Engineering & Project Management" yields ["se", "pm", "sep", "epm", "sepm"].
  static Set<String> generateSubAcronyms(List<String> meaningfulTokens) {
    final results = <String>{};
    final n = meaningfulTokens.length;
    for (int start = 0; start < n; start++) {
      for (int end = start + 2; end <= n; end++) {
        final sub = meaningfulTokens.sublist(start, end);
        results.add(generateAcronym(sub));
      }
    }
    return results;
  }

  /// Checks if an entry or token matches via abbreviation dictionary or acronyms.
  static bool matchesAbbreviation({
    required String profTokenOrPhrase,
    required List<String> subjMeaningfulTokens,
    required String normSubjectName,
  }) {
    final normProf = normalize(profTokenOrPhrase);
    if (normProf.isEmpty) return false;

    // Direct acronym match (e.g. "sepm" -> "software engineering and project management")
    final fullAcronym = generateAcronym(subjMeaningfulTokens);
    if (normProf.length >= 2 && normProf == fullAcronym) {
      return true;
    }

    // Sub-phrase acronym match (e.g. "se" -> "software engineering", "pm" -> "project management")
    final subAcronyms = generateSubAcronyms(subjMeaningfulTokens);
    if (subAcronyms.contains(normProf)) {
      return true;
    }

    // Abbreviation dictionary lookup:
    // Does the professor's abbreviation expand to a phrase contained in the subject?
    final expansions = abbreviationMap[normProf];
    if (expansions != null) {
      for (final exp in expansions) {
        final normExp = normalize(exp);
        if (normSubjectName.contains(normExp)) {
          return true;
        }
        final expTokens = extractMeaningfulTokens(normExp);
        if (expTokens.every((et) => subjMeaningfulTokens.any((st) => st == et || stemWord(st) == stemWord(et)))) {
          return true;
        }
      }
    }

    // Reverse abbreviation lookup: e.g. prof entered full phrase, subject is abbreviation
    for (final entry in abbreviationMap.entries) {
      if (entry.value.any((exp) => normalize(exp) == normProf)) {
        if (subjMeaningfulTokens.contains(entry.key) || normSubjectName.contains(entry.key)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _isKnownReverseAbbreviation(String token) {
    return abbreviationMap.containsKey(token);
  }

  /// Evaluates whether a staff member with [subjectsCanTeach] is eligible to teach
  /// a subject identified by [subjectName], [subjectCode], and optional [subjectId].
  ///
  /// Evaluates whether a staff member with [subjectsCanTeach] is eligible to teach
  /// a subject identified by [subjectName], [subjectCode], optional [courseShortName], and optional [subjectId].
  ///
  /// Rule 1: If [subjectsCanTeach] is empty (or contains only blank entries),
  /// the professor is universally eligible for any subject.
  ///
  /// Rule 2: If [subjectsCanTeach] is non-empty, the professor is eligible if ANY
  /// meaningful professor-entered subject token matches a meaningful token in the
  /// actual subject name under the 5-tier matching hierarchy.
  static bool isStaffEligible({
    required List<String> subjectsCanTeach,
    required String subjectName,
    required String subjectCode,
    String? courseShortName,
    String? subjectId,
  }) {
    return evaluateStaffEligibility(
      subjectsCanTeach: subjectsCanTeach,
      subjectName: subjectName,
      subjectCode: subjectCode,
      courseShortName: courseShortName,
      subjectId: subjectId,
    ).isEligible;
  }

  /// Evaluates staff eligibility and returns a structured [MatchResult] detailing
  /// whether the staff is eligible and which hierarchy tier was satisfied.
  static MatchResult evaluateStaffEligibility({
    required List<String> subjectsCanTeach,
    required String subjectName,
    required String subjectCode,
    String? courseShortName,
    String? subjectId,
  }) {
    // 1. If subjectsCanTeach is empty, universally eligible (Rule 1)
    if (subjectsCanTeach.isEmpty) {
      return const MatchResult(
        isEligible: true,
        tier: MatchTier.emptyListAllowed,
        explanation: 'Eligible for all subjects (empty "Can Teach" list).',
      );
    }

    // Flatten and clean professor entries (handling comma, semicolon, newline separated inputs)
    final entries = <String>[];
    for (final raw in subjectsCanTeach) {
      if (raw.contains(',') || raw.contains(';') || raw.contains('\n')) {
        for (final item in raw.split(RegExp(r'[,;\n]'))) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) entries.add(trimmed);
        }
      } else {
        final trimmed = raw.trim();
        if (trimmed.isNotEmpty) entries.add(trimmed);
      }
    }

    // If all entries were blank, treat as empty (universal eligibility)
    if (entries.isEmpty) {
      return const MatchResult(
        isEligible: true,
        tier: MatchTier.emptyListAllowed,
        explanation: 'Eligible for all subjects (empty "Can Teach" list).',
      );
    }

    // 2. Evaluate each entry against the subject
    for (final entry in entries) {
      final result = evaluateEntry(
        profEntry: entry,
        subjectName: subjectName,
        subjectCode: subjectCode,
        courseShortName: courseShortName,
        subjectId: subjectId,
      );
      if (result.isEligible) {
        return result;
      }
    }

    return MatchResult(
      isEligible: false,
      tier: MatchTier.none,
      explanation:
          'No matching subject ID, code, name, token, abbreviation, or spelling match for entries: ${entries.join(", ")}.',
    );
  }

  /// Evaluates a single professor entry against a target subject using the 5-tier hierarchy:
  /// 1. Subject ID / Code exact match
  /// 2. Exact normalized full subject-name match
  /// 3. Exact normalized TOKEN / WORD match
  /// 4. Partial multi-token match & Abbreviations
  /// 5. Conservative fuzzy token matching for spelling mistakes
  static MatchResult evaluateEntry({
    required String profEntry,
    required String subjectName,
    required String subjectCode,
    String? courseShortName,
    String? subjectId,
  }) {
    final trimmedProf = profEntry.trim();
    if (trimmedProf.isEmpty) {
      return const MatchResult(
        isEligible: false,
        tier: MatchTier.none,
        explanation: 'Empty professor entry.',
      );
    }

    // =========================================================================
    // Tier 1: Subject ID / Code exact match
    // =========================================================================
    if (subjectId != null && subjectId.trim().isNotEmpty) {
      if (trimmedProf.toLowerCase() == subjectId.trim().toLowerCase()) {
        return MatchResult(
          isEligible: true,
          tier: MatchTier.subjectIdExact,
          matchedProfessorEntry: trimmedProf,
          explanation: 'Exact match on Subject ID: "$subjectId".',
        );
      }
    }

    final normSubjectCode = normalizeCode(subjectCode);
    final normProfCode = normalizeCode(trimmedProf);
    if (normSubjectCode.isNotEmpty && normProfCode == normSubjectCode) {
      return MatchResult(
        isEligible: true,
        tier: MatchTier.subjectCodeExact,
        matchedProfessorEntry: trimmedProf,
        explanation: 'Exact match on Subject Code: "$subjectCode".',
      );
    }

    final normShortName = courseShortName != null ? normalizeCode(courseShortName) : '';
    if (normShortName.isNotEmpty && normProfCode == normShortName) {
      return MatchResult(
        isEligible: true,
        tier: MatchTier.subjectCodeExact,
        matchedProfessorEntry: trimmedProf,
        explanation: 'Exact match on Course Short Name: "$courseShortName".',
      );
    }

    // =========================================================================
    // Tier 2: Exact normalized full subject-name match
    // =========================================================================
    final normSubjectName = normalize(subjectName);
    final normProf = normalize(trimmedProf);

    if (normSubjectName.isNotEmpty && normProf == normSubjectName) {
      return MatchResult(
        isEligible: true,
        tier: MatchTier.fullNameExact,
        matchedProfessorEntry: trimmedProf,
        explanation: 'Exact match on normalized full subject name: "$subjectName".',
      );
    }

    final normFullShort = courseShortName != null ? normalize(courseShortName) : '';
    if (normFullShort.isNotEmpty && normProf == normFullShort) {
      return MatchResult(
        isEligible: true,
        tier: MatchTier.fullNameExact,
        matchedProfessorEntry: trimmedProf,
        explanation: 'Exact match on normalized course short name: "$courseShortName".',
      );
    }

    // Extract meaningful tokens from combined subject text (name, shortName, code)
    final profMeaningfulTokens = extractMeaningfulTokens(trimmedProf);
    final combinedSubjectText = '$subjectName ${courseShortName ?? ''} $subjectCode';
    final subjMeaningfulTokens = extractMeaningfulTokens(combinedSubjectText);

    if (profMeaningfulTokens.isEmpty || subjMeaningfulTokens.isEmpty) {
      // If no meaningful tokens exist (e.g. only stop words), do not match
      return MatchResult(
        isEligible: false,
        tier: MatchTier.none,
        matchedProfessorEntry: trimmedProf,
        explanation: 'No meaningful tokens to compare.',
      );
    }

    // =========================================================================
    // Tier 3: Exact normalized TOKEN / WORD match
    // "If ANY meaningful professor-entered subject token matches a meaningful
    // token in the actual subject name, the professor should be eligible."
    // =========================================================================
    for (final pToken in profMeaningfulTokens) {
      for (final sToken in subjMeaningfulTokens) {
        if (pToken == sToken) {
          return MatchResult(
            isEligible: true,
            tier: MatchTier.exactToken,
            matchedProfessorEntry: trimmedProf,
            matchedProfessorToken: pToken,
            matchedSubjectToken: sToken,
            explanation:
                'Meaningful token exact match: "$pToken" matches "$sToken" in "$subjectName".',
          );
        }
        if (stemWord(pToken) == stemWord(sToken)) {
          return MatchResult(
            isEligible: true,
            tier: MatchTier.stemToken,
            matchedProfessorEntry: trimmedProf,
            matchedProfessorToken: pToken,
            matchedSubjectToken: sToken,
            explanation:
                'Stemmed token match: "$pToken" matches "$sToken" in "$subjectName".',
          );
        }
      }
    }

    // =========================================================================
    // Tier 4: Partial multi-token match & Abbreviations / Acronyms
    // =========================================================================
    // Multi-token phrase sub-sequence matching
    if (profMeaningfulTokens.length > 1) {
      // Check if all professor tokens appear in order in the subject tokens
      if (_isSubsequence(profMeaningfulTokens, subjMeaningfulTokens)) {
        return MatchResult(
          isEligible: true,
          tier: MatchTier.multiTokenPhrase,
          matchedProfessorEntry: trimmedProf,
          explanation:
              'Multi-token phrase match: "${profMeaningfulTokens.join(" ")}" occurs in "$subjectName".',
        );
      }
    }

    // Abbreviation & Acronym matching
    final targetNormSubject = normSubjectName.isNotEmpty ? normSubjectName : normalize(combinedSubjectText);
    if (matchesAbbreviation(
      profTokenOrPhrase: trimmedProf,
      subjMeaningfulTokens: subjMeaningfulTokens,
      normSubjectName: targetNormSubject,
    )) {
      return MatchResult(
        isEligible: true,
        tier: MatchTier.abbreviation,
        matchedProfessorEntry: trimmedProf,
        explanation:
            'Abbreviation or acronym match between "$trimmedProf" and "$subjectName".',
      );
    }

    // Also check individual professor tokens against subject abbreviations
    for (final pToken in profMeaningfulTokens) {
      if (matchesAbbreviation(
        profTokenOrPhrase: pToken,
        subjMeaningfulTokens: subjMeaningfulTokens,
        normSubjectName: targetNormSubject,
      )) {
        return MatchResult(
          isEligible: true,
          tier: MatchTier.abbreviation,
          matchedProfessorEntry: trimmedProf,
          matchedProfessorToken: pToken,
          explanation:
              'Abbreviation match for token "$pToken" in "$subjectName".',
        );
      }
    }

    // =========================================================================
    // Tier 5: Conservative fuzzy token matching for spelling mistakes
    // =========================================================================
    for (final pToken in profMeaningfulTokens) {
      for (final sToken in subjMeaningfulTokens) {
        if (isConservativeFuzzyMatch(pToken, sToken)) {
          return MatchResult(
            isEligible: true,
            tier: MatchTier.fuzzyToken,
            matchedProfessorEntry: trimmedProf,
            matchedProfessorToken: pToken,
            matchedSubjectToken: sToken,
            explanation:
                'Conservative fuzzy token match (spelling mistake): "$pToken" -> "$sToken" in "$subjectName".',
          );
        }
      }
    }

    return MatchResult(
      isEligible: false,
      tier: MatchTier.none,
      matchedProfessorEntry: trimmedProf,
      explanation: 'No match found for "$trimmedProf" in "$subjectName".',
    );
  }

  /// Checks if [sub] is a contiguous or ordered sub-sequence of [target].
  static bool _isSubsequence(List<String> sub, List<String> target) {
    if (sub.length > target.length) return false;
    for (int i = 0; i <= target.length - sub.length; i++) {
      bool allMatch = true;
      for (int j = 0; j < sub.length; j++) {
        final p = sub[j];
        final t = target[i + j];
        if (p != t && stemWord(p) != stemWord(t)) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return true;
    }
    return false;
  }
}
