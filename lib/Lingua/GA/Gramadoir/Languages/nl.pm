package Lingua::GA::Gramadoir::Languages::nl;
# Dutch translations for gramadoir.
# Copyright (C) 2003 Kevin P. Scannell
# This file is distributed under the same license as the gramadoir package.
# Anneke Bart <barta@slu.edu>, 2003.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.3\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2005-03-02 22:40-0600\n"
#"PO-Revision-Date: 2003-11-23 15:58-0600\n"
#"Last-Translator: Anneke Bart <barta@slu.edu>\n"
#"Language-Team: Dutch <vertaling@nl.linux.org>\n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=iso-8859-1\n"
#"Content-Transfer-Encoding: 8bit\n"

use strict;
use warnings;
use utf8;
use base qw(Lingua::GA::Gramadoir::Languages);
use vars qw(%Lexicon);

%Lexicon = (
    "Line %d: [_1]\n"
 => "Regel %d: [_1]\n",

    "unrecognized option [_1]"
 => "onbekende optie [_1]",

    "option [_1] requires an argument"
 => "optie [_1] vereist een argument",

    "option [_1] does not allow an argument"
 => "optie [_1] staat geen argumenten toe",

    "error parsing command-line options"
 => "error parsing command-line options",

    "Unable to set output color to [_1]"
 => "Unable to set output color to [_1]",

    "Language [_1] is not supported."
 => "Taal [_1] word niet ondersteund.",

    "An Gramadoir"
 => "An Gramadóir",

    "Try [_1] for more information."
 => "Probeer [_1] voor meer informatie.",

    "version [_1]"
 => "versie [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Dit is vrije programmatuur; zie de broncode voor distributie-\nvoorwaarden. Er is GEEN garantie; zelfs niet voor VERKOOPBAARHEID of\nGESCHIKTHEID VOOR EEN BEPAALD DOEL, zo ver als wettelijk mogelijk is.",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Gebruik: [_1] ~[OPTIE~] ~[BESTAND~]",

    "Options for end-users:"
 => "Options for end-users:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       geef alle fouten aan (m.a.w. gebruik niet ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  specificeer de character codering van de betreffende text",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       schrijf verkeerd gespelde woorden naar een standard output",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       suggest corrections for misspellings",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --help         display this help and exit"
 => "    --help         toon deze hulptekst en beëindig programma",

    "    --version      output version information and exit"
 => "    --version      toon versie-informatie en beëindig programma",

    "Options for developers:"
 => "Options for developers:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         creeer HTML output om te bekijken in een web browser",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   do not resolve ambiguous parts of speech by frequency",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          write tagged XML stream to standard output, for debugging",

    "If no file is given, read from standard input."
 => "Als geen bestand wordt gegeven, lees van standard invoering.",

    "Send bug reports to <[_1]>."
 => "Meld fouten in het programma aan <[_1]>.",

    "There is no such file."
 => "Dit bestand bestaat niet.",

    "Is a directory"
 => "Is een map",

    "Permission denied"
 => "Toegang geweigerd",

    "[_1]: warning: problem closing [_2]\n"
 => "[_1]: warning: problem closing [_2]\n",

    "Currently checking [_1]"
 => "Word momenteel nagekeken",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     report unresolved ambiguities, sorted by frequency",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        find disambiguation rules via Brill's unsupervised algorithm",

    "[_1]: problem reading the database\n"
 => "[_1]: Problemen met lezen van de databank\n",

    "[_1]: `[_2]' corrupted at [_3]\n"
 => "[_1]: `[_2]' corrupted at [_3]\n",

    "conversion from [_1] is not supported"
 => "Taal [_1] word niet ondersteund.",

    "[_1]: illegal grammatical code\n"
 => "[_1]: foutieve grammatica code\n",

    "[_1]: no grammar codes: [_2]\n"
 => "[_1]: no grammar codes: [_2]\n",

    "[_1]: unrecognized error macro: [_2]\n"
 => "onbekende optie [_1]",

    "Valid word but extremely rare in actual usage"
 => "Correct woord, maar erg zeldzaam in waarlijk gebruik",

    "Repeated word"
 => "Herhaald woord",

    "Unusual combination of words"
 => "Unusual combination of words",

    "The plural form is required here"
 => "The plural form is required here",

    "The singular form is required here"
 => "The singular form is required here",

    "Comparative adjective required"
 => "Comparative adjective required",

    "Definite article required"
 => "Definite article required",

    "Unnecessary use of the definite article"
 => "Unnecessary use of the definite article",

    "Unnecessary use of the genitive case"
 => "Onnodige lenitie",

    "The genitive case is required here"
 => "The genitive case is required here",

    "It seems unlikely that you intended to use the subjunctive here"
 => "It seems unlikely that you intended to use the subjunctive here",

    "Usually used in the set phrase /[_1]/"
 => "Usually used in the set phrase /[_1]/",

    "You should use /[_1]/ here instead"
 => "Gebruik /[_1]/ hier",

    "Non-standard form of /[_1]/"
 => "Geen standard vorm: gebruik misschien /[_1]/?",

    "Derived from a non-standard form of /[_1]/"
 => "Derived from a non-standard form of /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Derived incorrectly from the root /[_1]/",

    "Unknown word"
 => "Onbekend woord",

    "Unknown word: /[_1]/?"
 => "Onbekend woord",

    "Valid word but more often found in place of /[_1]/"
 => "Valid word but more often found in place of /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Not in database but apparently formed from the root /[_1]/",

    "The word /[_1]/ is not needed"
 => "The word /[_1]/ is not needed",

    "Do you mean /[_1]/?"
 => "Do you mean /[_1]/?",

    "Derived form of common misspelling /[_1]/?"
 => "Derived form of common misspelling /[_1]/?",

    "Not in database but may be a compound /[_1]/?"
 => "Not in database but may be a compound /[_1]/?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "Not in database but may be a non-standard compound /[_1]/?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Possibly a foreign word (the sequence /[_1]/ is highly improbable)",

    "Prefix /h/ missing"
 => "Voorvoegsel /h/ ontbreekt",

    "Prefix /t/ missing"
 => "Voorvoegsel /t/ ontbreekt",

    "Prefix /d'/ missing"
 => "Voorvoegsel /h/ ontbreekt",

    "Unnecessary prefix /h/"
 => "Unnecessary prefix /h/",

    "Unnecessary prefix /t/"
 => "Unnecessary prefix /t/",

    "Unnecessary prefix /d'/"
 => "Onnodige lenitie",

    "Unnecessary initial mutation"
 => "Onnodige lenitie",

    "Initial mutation missing"
 => "Begin mutatie ontbreekt",

    "Unnecessary lenition"
 => "Onnodige lenitie",

    "Often the preposition /[_1]/ causes lenition, but this case is unclear"
 => "Often the preposition /[_1]/ causes lenition, but this case is unclear",

    "Lenition missing"
 => "Lenitie (verzachting) ontbreekt",

    "Unnecessary eclipsis"
 => "Onnodige lenitie",

    "Eclipsis missing"
 => "Eclipsis ontbreekt",

    "The dative is used only in special phrases"
 => "The dative is used only in special phrases",

    "The dependent form of the verb is required here"
 => "The dependent form of the verb is required here",

    "Unnecessary use of the dependent form of the verb"
 => "Onnodige lenitie",

    "The synthetic (combined) form, ending in /[_1]/, is often used here"
 => "The synthetic (combined) form, ending in /[_1]/, is often used here",

    "Second (soft) mutation missing"
 => "Begin mutatie ontbreekt",

    "Third (breathed) mutation missing"
 => "Begin mutatie ontbreekt",

    "Fourth (hard) mutation missing"
 => "Begin mutatie ontbreekt",

    "Fifth (mixed) mutation missing"
 => "Begin mutatie ontbreekt",

    "Fifth (mixed) mutation after 'th missing"
 => "Begin mutatie ontbreekt",

);
1;
