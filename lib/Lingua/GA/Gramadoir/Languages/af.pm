package Lingua::GA::Gramadoir::Languages::af;
# An Gramad�ir - The Grammarian
# Copyright (C) 2004 Free Software Foundation, Inc.
# This file is distributed under the same license as the PACKAGE package.
# Petri Jooste <rkwjpj@puk.ac.za>, 2004.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.4\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-03-02 16:38+0200\n"
#"Last-Translator: Petri Jooste <rkwjpj@puk.ac.za>\n"
#"Language-Team: Afrikaans <i18n@af.org.za>\n"
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
 => "[_1] word tans nagegaan",

    "There is no such file."
 => "Daardie lêer bestaan nie.",

    "Is a directory"
 => "Dit is 'n lêergids",

    "Permission denied"
 => "Toegang geweier",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Gebruik so: [_1] ~[OPSIES~] ~[LÊERS~]",

    "Options for end-users:"
 => "Opsies vir eindgebruikers:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       wys alle foute (d.w.s. ignoreer die lêer ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  spesifiseer die karakterkodering van die teks wat nagegaan moet word",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       skryf spelfoute na standaardafvoer",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       maak suggesties vir spelfoute (benodig GNU aspell)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    spesifiseer die taal van die teks wat nagegaan moet word (verstek=ga)",

    "    --help         display this help and exit"
 => "    --help         wys hierdie hulpteks en stop",

    "    --version      output version information and exit"
 => "    --version      wys weergawe-inligting en stop",

    "Options for developers:"
 => "Opsies vir ontwikkelaars:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        bepaal reëls vir ondubbelsinnigmaking deur Brill se toesiglose algoritme",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         produseer HTML-afvoer wat met 'n webblaaier bekyk kan word",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     wys onopgeloste dubbelsinnighede, gesorteer volgens frekwensie",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        wys alle merkers, gesorteer volgens frekwensie (vir unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   moenie frekwensie gebruik om dubbelsinnige woordsoorte op te los nie",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          skryf die XML-stroom met merkers na standaardafvoer, vir ontfouting",

    "If no file is given, read from standard input."
 => "As geen lêer gegee is nie, lees van standaardtoevoer",

    "Send bug reports to <[_1]>."
 => "Stuur foutverslae aan <[_1]>.",

    "version [_1]"
 => "weergawe [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Hierdie is vry sagteware; sien die bronkode vir kopieervoorwaardes.  Daar is GEEN\nwaarborg nie; selfs nie eers vir MERCHANTABILITY of GESKIKTHEID VIR 'N SPESIFIEKE DOEL nie,\ntot die mate wat deur die wet toegelaat word.",

    "Try [_1] for more information."
 => "Probeer [_1] vir meer inligting.",

    "unrecognized option [_1]"
 => "onbekende opsie [_1]",

    "option [_1] requires an argument"
 => "opsie [_1]: benodig 'n parameter",

    "option [_1] does not allow an argument"
 => "opsie [_1] laat nie 'n parameter toe nie",

    "Language [_1] is not supported."
 => "Taal [_1] word nie ondersteun nie.",

    "conversion from [_1] is not supported"
 => "Omsetting van [_1] word nie ondersteun nie",

    "aspell-[_1] is not installed"
 => "aspell-[_1] is nie geïnstalleer nie",

    "Unknown word"
 => "Onbekende woord",

    "Unknown word (ignoring remainder in this sentence)"
 => "Onbekende woord (die res van die sin word geïgnoreer)",

    "Valid word but extremely rare in actual usage"
 => "Geldige woord, maar baie seldsaam",

    "Usually used in the set phrase /[_1]/"
 => "Word normaalweg gebruik in die vaste konstruksie /[_1]/",

    "You should use /[_1]/ here instead"
 => "U moet hier eerder /[_1]/ gebruik",

    "Non-standard form of /[_1]/"
 => "Nie-standaardvorm: gebruik miskien /[_1]/?",

    "Initial mutation missing"
 => "Aanvangsmutasie ontbreek",

    "Unnecessary lenition"
 => "Onnodige linisie",

    "Prefix /h/ missing"
 => "Voorvoegsel /h/ ontbreek",

    "Prefix /t/ missing"
 => "Voorvoegsel /t/ ontbreekkdesu is weg",

    "Lenition missing"
 => "Lenisie ontbreek",

    "Eclipsis missing"
 => "Eklips ontbreek",

    "Repeated word"
 => "Herhaalde woord",

    "Unusual combination of words"
 => "Ongewone kombinasie van woorde",

    "Comparative adjective required"
 => "Vergelykende adjektief benodig",

    "Unnecessary prefix /h/"
 => "Onnodige voorvoegsel /h/",

    "Unnecessary prefix /t/"
 => "Onnodige voorvoegsel /t/",

    "Unnecessary use of the definite article"
 => "Onnodige gebruik van die bepaalde lidwoord",

    "The genitive case is required here"
 => "Die genitief word hier benodig",

    "[_1]: out of memory\n"
 => "[_1]: te min geheue\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' is korrup by at %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: waarskuwing: gaan die groote na van %s: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: waarskuwing: problem met toemaak van %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: geen grammatika-kodes: %s\n",

    "problem with the `cuardach' command\n"
 => "probleem met die `cuardach' bevel\n",

    "[_1]: problem reading the database\n"
 => "[_1]: probleem met lees van databasis\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: ongeldige grammatika-kode\n",

    "Line %d: [_1]\n"
 => "Reël %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       maak suggesties vir spelfoute",

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
