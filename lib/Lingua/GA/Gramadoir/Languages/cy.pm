package Lingua::GA::Gramadoir::Languages::cy;
# translation of cy.po to Cymraeg
# translation of gramadoir.po to Cymraeg
# This file is distributed under the same license as the PACKAGE package.
# Copyright (C) YEAR Kevin P. Scannell.
# Kyfieithu <kyfieithu@dotmon.com>, 2004.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.5\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2005-03-02 22:40-0600\n"
#"PO-Revision-Date: 2004-09-19 11:43+0100\n"
#"Last-Translator: Kyfieithu <kyfieithu@dotmon.com>\n"
#"Language-Team: Cymraeg <cy@li.org>\n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=UTF-8\n"
#"Content-Transfer-Encoding: 8bit\n"

use strict;
use warnings;
use utf8;
use base qw(Lingua::GA::Gramadoir::Languages);
use vars qw(%Lexicon);

%Lexicon = (
    "Line %d: [_1]\n"
 => "Llinell %d: [_1]\n",

    "unrecognized option [_1]"
 => "dewisiad anadnabyddus [_1]",

    "option [_1] requires an argument"
 => "mae ymresymiad yn gofynnol ar gyfer dewisiad [_1]",

    "option [_1] does not allow an argument"
 => "nid yw'r dewisiad [_1] yn caniatáu ymresymiad",

    "error parsing command-line options"
 => "gwall wrth ddosrannu'r dewisiadau llinell orchymyn",

    "Unable to set output color to [_1]"
 => "Methu gosod y lliw allbwn i [_1]",

    "Language [_1] is not supported."
 => "Ni chynhelir yr iaith [_1]",

    "An Gramadoir"
 => "An Gramadóir",

    "Try [_1] for more information."
 => "Ceisiwch [_1] am ragor o wybodaeth.",

    "version [_1]"
 => "fersiwn [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Meddalwedd rhydd yw hwn; gweler y tarddiad ar gyfer amodau copïo.  Nid oes DIM\ngwarant; nid hyd yn oed ar gyfer MASNACHEIDDRWYDD neu ADDASRWYDD AR GYFER PWRPAS PENODOL, \nhyd yr eithaf a ganiateir gan y gyfraith.",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Defnydd: [_1] ~[DEWISIADAU~]~[FFEILIAU~]",

    "Options for end-users:"
 => "Dewisiadau ar gyfer defnyddwyr:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       adrodd pob gwall (h.y. peidiwch â defnyddio ~/.neamhshuim - ffeil anwybyddu)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=AMG  penodi'r amgodiad nodau o'r testun i'w gywiro",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=AMG   penodi'r amgodiad nodau ar gyfer allbwn",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx dewis yr iaith ar gyfer negeseuon gwall",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=LLIW   penodi'r lliw i'w ddefnyddio ar gyfer amlygu gwallau",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       ysgrifennu geiriau a gamsillafwyd i allbwn safonol",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       awgrymu cywiriadau ar gyfer camsillafiadau",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FFEIL ysgrifennu allbwn i FFEIL",

    "    --help         display this help and exit"
 => "    --help         dangos y cymorth yma a terfynu",

    "    --version      output version information and exit"
 => "    --version      dangos gwybodaeth am y fersiwn a terfynu",

    "Options for developers:"
 => "Dewisiadau ar gyfer datblygwyr:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          allbynnu fformat XML syml i'w defnyddio efo cymhwysiadau eraill",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         cynhyrchu allbwn HTML i'w weld mewn porydd gwe",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   peidio â datrys rhannau ymadrodd amwys gan amlder",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          ysgrifennu llif XML wedi'i dagio i allbwn safonol, ar gyfer dadnamu",

    "If no file is given, read from standard input."
 => "Os ni roddir ffeil, darllenir o fewnbwn safonol.",

    "Send bug reports to <[_1]>."
 => "Anfonwch adroddiadau nam i <[_1]>",

    "There is no such file."
 => "Nid oes y math ffeil.",

    "Is a directory"
 => "Yn gyfeiriadur",

    "Permission denied"
 => "Gwrthodwyd caniatâd",

    "[_1]: warning: problem closing [_2]\n"
 => "[_1]: rhybudd: problem wrth gau [_2]\n",

    "Currently checking [_1]"
 => "Gwirio [_1] ar hyn o bryd",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     adrodd amwyseddau annatrys, wedi eu trefnu gan amlder",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        allbynnu pob tag, wedi'u trefnu gan amlder (ar gyfer unigram-xx.txt)",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        canfod rheolau dileu amwysedd gan ddefnyddio algorithm diarolygiaeth Brill",

    "[_1]: problem reading the database\n"
 => "[_1]: problem wrth ddarllen y gronfa ddata\n",

    "[_1]: `[_2]' corrupted at [_3]\n"
 => "[_1]: `[_2]' wedi ei lygru wrth [_3]\n",

    "conversion from [_1] is not supported"
 => "ni chynhelir trosi o [_1]",

    "[_1]: illegal grammatical code\n"
 => "[_1]: côd gramadegol anghyfreithlon\n",

    "[_1]: no grammar codes: [_2]\n"
 => "[_1]: dim codau gramadeg: [_2]\n",

    "[_1]: unrecognized error macro: [_2]\n"
 => "dewisiad anadnabyddus [_1]",

    "Valid word but extremely rare in actual usage"
 => "Gair dilys, ond eithriadol o brin mewn defnydd gwirioneddol",

    "Repeated word"
 => "Gair wedi'i ailadrodd",

    "Unusual combination of words"
 => "Cyfuniad anarferol o eiriau",

    "The plural form is required here"
 => "Mae'r cyflwr genidol yn ofynnol yma",

    "The singular form is required here"
 => "Mae'r cyflwr genidol yn ofynnol yma",

    "Comparative adjective required"
 => "Mae ansoddair cymharol yn ofynnol",

    "Definite article required"
 => "Definite article required",

    "Unnecessary use of the definite article"
 => "Defnydd diangen o'r fannod benodol",

    "Unnecessary use of the genitive case"
 => "Defnydd diangen o'r fannod benodol",

    "The genitive case is required here"
 => "Mae'r cyflwr genidol yn ofynnol yma",

    "It seems unlikely that you intended to use the subjunctive here"
 => "It seems unlikely that you intended to use the subjunctive here",

    "Usually used in the set phrase /[_1]/"
 => "Defnyddir fel rheol yn yr ymadrodd sefydlog /[_1]/",

    "You should use /[_1]/ here instead"
 => "Dylech ddefnyddio /[_1]/ yma yn lle",

    "Non-standard form of /[_1]/"
 => "Ffurf ansafonol o /[_1]/",

    "Derived from a non-standard form of /[_1]/"
 => "Deilliwyd o ffurf ansafonol o /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Deilliwyd yn anghywir o'r gwreiddyn /[_1]/",

    "Unknown word"
 => "Gair anhysbys",

    "Unknown word: /[_1]/?"
 => "Gair anhysbys",

    "Valid word but more often found in place of /[_1]/"
 => "Valid word but more often found in place of /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Dim yn y gronfa ddata, ond yn ôl pob golwg deilliwyd o'r gwreiddyn /[_1]/",

    "The word /[_1]/ is not needed"
 => "The word /[_1]/ is not needed",

    "Do you mean /[_1]/?"
 => "Ydych yn golygu /[_1]/?",

    "Derived form of common misspelling /[_1]/?"
 => "Ffurf ddeilliedig o'r camsillafiad cyffredin /[_1]/?",

    "Not in database but may be a compound /[_1]/?"
 => "Dim yn y gronfa ddata ond efallai cyfansoddair o /[_1]/?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "Dim yn y gronfa ddata ond efallai cyfansoddair ansafonol o /[_1]/?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Efallai gair dieithr (mae'r dilyniant /[_1]/ yn annhebygol iawn)",

    "Prefix /h/ missing"
 => "Rhagddodiad /h/ ar goll",

    "Prefix /t/ missing"
 => "Rhagddodiad /t/ ar goll",

    "Prefix /d'/ missing"
 => "Rhagddodiad /h/ ar goll",

    "Unnecessary prefix /h/"
 => "Rhagddodiad diangen /h/",

    "Unnecessary prefix /t/"
 => "Rhagddodiad diangen /t/",

    "Unnecessary prefix /d'/"
 => "Rhagddodiad diangen /h/",

    "Unnecessary initial mutation"
 => "Treiglad meddal diangen",

    "Initial mutation missing"
 => "Treiglad cychwynnol ar goll",

    "Unnecessary lenition"
 => "Treiglad meddal diangen",

    "Often the preposition /[_1]/ causes lenition, but this case is unclear"
 => "Often the preposition /[_1]/ causes lenition, but this case is unclear",

    "Lenition missing"
 => "Treiglad meddal ar goll",

    "Unnecessary eclipsis"
 => "Treiglad meddal diangen",

    "Eclipsis missing"
 => "Treiglad trwynol ar goll",

    "The dative is used only in special phrases"
 => "The dative is used only in special phrases",

    "The dependent form of the verb is required here"
 => "Mae'r cyflwr genidol yn ofynnol yma",

    "Unnecessary use of the dependent form of the verb"
 => "Defnydd diangen o'r fannod benodol",

    "The synthetic (combined) form, ending in /[_1]/, is often used here"
 => "The synthetic (combined) form, ending in /[_1]/, is often used here",

    "Second (soft) mutation missing"
 => "Treiglad cychwynnol ar goll",

    "Third (breathed) mutation missing"
 => "Treiglad cychwynnol ar goll",

    "Fourth (hard) mutation missing"
 => "Treiglad cychwynnol ar goll",

    "Fifth (mixed) mutation missing"
 => "Treiglad cychwynnol ar goll",

    "Fifth (mixed) mutation after 'th missing"
 => "Treiglad cychwynnol ar goll",

);
1;
