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
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
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
    "An Gramadoir"
 => "An Gramadóir",

    "Currently checking [_1]"
 => "Word momenteel nagekeken",

    "There is no such file."
 => "Dit bestand bestaat niet.",

    "Is a directory"
 => "Is een map",

    "Permission denied"
 => "Toegang geweigerd",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Gebruik: [_1] ~[OPTIE~] ~[BESTAND~]",

    "Options for end-users:"
 => "Options for end-users:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       geef alle fouten aan (m.a.w. gebruik niet ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  specificeer de character codering van de betreffende text",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       schrijf verkeerd gespelde woorden naar een standard output",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       suggest corrections for misspellings (requires GNU aspell)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    Specificeer de taal van de betreffende text (default=ga)",

    "    --help         display this help and exit"
 => "    --help         toon deze hulptekst en beëindig programma",

    "    --version      output version information and exit"
 => "    --version      toon versie-informatie en beëindig programma",

    "Options for developers:"
 => "Options for developers:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        find disambiguation rules via Brill's unsupervised algorithm",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         creeer HTML output om te bekijken in een web browser",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     report unresolved ambiguities, sorted by frequency",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   do not resolve ambiguous parts of speech by frequency",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          write tagged XML stream to standard output, for debugging",

    "If no file is given, read from standard input."
 => "Als geen bestand wordt gegeven, lees van standard invoering.",

    "Send bug reports to <[_1]>."
 => "Meld fouten in het programma aan <[_1]>.",

    "version [_1]"
 => "versie [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Dit is vrije programmatuur; zie de broncode voor distributie-\nvoorwaarden. Er is GEEN garantie; zelfs niet voor VERKOOPBAARHEID of\nGESCHIKTHEID VOOR EEN BEPAALD DOEL, zo ver als wettelijk mogelijk is.",

    "Try [_1] for more information."
 => "Probeer [_1] voor meer informatie.",

    "unrecognized option [_1]"
 => "onbekende optie [_1]",

    "option [_1] requires an argument"
 => "optie [_1] vereist een argument",

    "option [_1] does not allow an argument"
 => "optie [_1] staat geen argumenten toe",

    "Language [_1] is not supported."
 => "Taal [_1] word niet ondersteund.",

    "conversion from [_1] is not supported"
 => "Taal [_1] word niet ondersteund.",

    "aspell-[_1] is not installed"
 => "aspell-[_1] is not installed",

    "Unknown word"
 => "Onbekend woord",

    "Unknown word (ignoring remainder in this sentence)"
 => "Onbekend word (de rest van deze zin word genegeerd)",

    "Valid word but extremely rare in actual usage"
 => "Correct woord, maar erg zeldzaam in waarlijk gebruik",

    "Usually used in the set phrase /[_1]/"
 => "Usually used in the set phrase /[_1]/",

    "You should use /[_1]/ here instead"
 => "Gebruik /[_1]/ hier",

    "Non-standard form of /[_1]/"
 => "Geen standard vorm: gebruik misschien /[_1]/?",

    "Initial mutation missing"
 => "Begin mutatie ontbreekt",

    "Unnecessary lenition"
 => "Onnodige lenitie",

    "Prefix /h/ missing"
 => "Voorvoegsel /h/ ontbreekt",

    "Prefix /t/ missing"
 => "Voorvoegsel /t/ ontbreekt",

    "Lenition missing"
 => "Lenitie (verzachting) ontbreekt",

    "Eclipsis missing"
 => "Eclipsis ontbreekt",

    "Repeated word"
 => "Herhaald woord",

    "Unusual combination of words"
 => "Unusual combination of words",

    "Comparative adjective required"
 => "Comparative adjective required",

    "Unnecessary prefix /h/"
 => "Unnecessary prefix /h/",

    "Unnecessary prefix /t/"
 => "Unnecessary prefix /t/",

    "Unnecessary use of the definite article"
 => "Unnecessary use of the definite article",

    "The genitive case is required here"
 => "The genitive case is required here",

    "[_1]: out of memory\n"
 => "[_1]: geen geheugen meer beschikbaar\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' corrupted at %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: warning: check size of %s: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: warning: problem closing %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: no grammar codes: %s\n",

    "problem with the `cuardach' command\n"
 => "problem with the `cuardach' command\n",

    "[_1]: problem reading the database\n"
 => "[_1]: Problemen met lezen van de databank\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: foutieve grammatica code\n",

    "Line %d: [_1]\n"
 => "Regel %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       suggest corrections for misspellings",

    "Derived from a non-standard form of /[_1]/"
 => "Derived from a non-standard form of /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Derived incorrectly from the root /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Not in database but apparently formed from the root /[_1]/",

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

);
1;
