package Lingua::GA::Gramadoir::Languages::sk;
# translation of gramadoir-0.4.po to Slovak
# Copyright (C) 2004 Kevin P. Scannell.
# This file is distributed under the same license as the gramadoir package.
# Andrej Kacian <andrej@kacian.sk>, 2004.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.4\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-01-10 23:04+0100\n"
#"Last-Translator: Andrej Kacian <andrej@kacian.sk>\n"
#"Language-Team: Slovak <sk-i18n@lists.linux.sk>\n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=UTF-8\n"
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
 => "Práve overujem [_1]",

    "There is no such file."
 => "Taký súbor neexistuje.",

    "Is a directory"
 => "Toto je priečinok",

    "Permission denied"
 => "Prístup nepovolený",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Použitie: [_1] ~[VOĽBY~] ~[SÚBORY~]",

    "Options for end-users:"
 => "Voľby pre koncových používateľov:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       hlásiť všetky chyby (teda nepoužívať ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  určenie kódovania overovaného textu",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       vypísať nesprávne slová na štandardný výstup",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       navrhnúť opravu nesprávnych slov (vyžaduje GNU aspell)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    určenie jazyku overovaného textu(prednastavené=ga)",

    "    --help         display this help and exit"
 => "    --help         zobrazí tento text a ukončí program",

    "    --version      output version information and exit"
 => "    --version      zobrazí informácie o verzii a ukončí program",

    "Options for developers:"
 => "Voľby pre vývojárov:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        nájsť pravidlá pre určenie významu slov pomocou Brillovho algoritmu",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         vytvorí HTML výstup pre prezeranie vo webovom prehliadači",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     vypísať slová s nenájdeným významom, zotriedené podľa počtu výskytu",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        vypíše všetky značky, zotriedené podľa počtu výskytu (pre unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   neurčovať význam slov podľa počtu výskytu",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          zapísať označkovaný XML stream na štandardný výstup, pre odlaďovanie",

    "If no file is given, read from standard input."
 => "Ak nie je zadaný žiadny súbor, čítaj zo štandardného vstupu",

    "Send bug reports to <[_1]>."
 => "Odosielať správy o chybe na <[_1]>.",

    "version [_1]"
 => "verzia [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Toto je voľne šíriteľný program, pozrite si zdrojové súbory. Neposkytuje sa\nžiadna záruka, dokonca ani záruka PREDAJNOSTI alebo VHODNOSTI PRE \nURČITÝ ÚČEL, v rozsahu povolenom zákonom.",

    "Try [_1] for more information."
 => "Skúste [_1] pre ďalšie informácie.",

    "unrecognized option [_1]"
 => "neznáma voľba [_1]",

    "option [_1] requires an argument"
 => "voľba [_1] vyžaduje parameter",

    "option [_1] does not allow an argument"
 => "voľba [_1] nepripúšta parameter",

    "Language [_1] is not supported."
 => "Jazyk [_1] nie je podporovaný.",

    "conversion from [_1] is not supported"
 => "konverzia z [_1] nie je podporovaná",

    "aspell-[_1] is not installed"
 => "aspell-[_1] nie je nainštalovaný",

    "Unknown word"
 => "Neznáme slovo",

    "Unknown word (ignoring remainder in this sentence)"
 => "Neznáme slovo (ignorujem zvyšok slov v tejto vete)",

    "Valid word but extremely rare in actual usage"
 => "Platné slovo, ale extrémne vzácne v bežnom použití",

    "Usually used in the set phrase /[_1]/"
 => "Väčšinou použité vo fráze /[_1]/",

    "You should use /[_1]/ here instead"
 => "Mali by ste tu radšej použiť /[_1]/",

    "Non-standard form of /[_1]/"
 => "Neštandardná forma: možno /[_1]/?",

    "Initial mutation missing"
 => "Počiatočná mutácia chýba",

    "Unnecessary lenition"
 => "Nepotrebná lenícia",

    "Prefix /h/ missing"
 => "Predpona /h/ chýba",

    "Prefix /t/ missing"
 => "Predpona /t/ chýba",

    "Lenition missing"
 => "Chýba eklipsa",

    "Eclipsis missing"
 => "Chýba eklipsa",

    "Repeated word"
 => "Opakované slovo",

    "Unusual combination of words"
 => "Nezvyklá kombinácia slov",

    "Comparative adjective required"
 => "Je potrebné porovnávacie prídavné meno",

    "Unnecessary prefix /h/"
 => "Nepotrebná predpona /h/",

    "Unnecessary prefix /t/"
 => "Nepotrebná predpona /t/",

    "Unnecessary use of the definite article"
 => "Nepotrebné použitie určitého člena",

    "The genitive case is required here"
 => "Je tu potrebný genitív",

    "[_1]: out of memory\n"
 => "[_1]: málo pamäti!\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' poškodené na %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: varovanie: overte veľkosť %s: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: varovanie: problém pri zatváraní %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: žiadne gramatické kódy: %s\n",

    "problem with the `cuardach' command\n"
 => "problém s príkazom `cuardach'\n",

    "[_1]: problem reading the database\n"
 => "[_1]: problém pri čítaní z databázy\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: neplatný gramatický kód\n",

    "Line %d: [_1]\n"
 => "Riadok %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       navrhnúť opravu nesprávnych slov",

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
