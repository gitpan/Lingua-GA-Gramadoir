package Lingua::GA::Gramadoir::Languages::ga;
# Irish translations for gramadoir.
# Copyright (C) 2003 Free Software Foundation, Inc.
# This file is distributed under the same license as the gramadoir package.
# Kevin Patrick Scannell <scannell@SLU.EDU>, 2003.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.5\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-07-28 15:58-0500\n"
#"Last-Translator: Kevin Patrick Scannell <scannell@SLU.EDU>\n"
#"Language-Team: Irish <ga@li.org>\n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=ISO-8859-1\n"
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
 => "Ag seiceáil [_1]",

    "There is no such file."
 => "Níl a leithéid de chomhad ann",

    "Is a directory"
 => "Is comhadlann é",

    "Permission denied"
 => "Cead diúltaithe",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Úsáid: [_1] ~[ROGHANNA~] ~[COMHAD~]",

    "Options for end-users:"
 => "Roghanna d'úsáideoirí:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       taispeáin gach earráid (.i. ná húsáid ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=CÓD  socraigh an t-ionchódú den téacs le seiceáil",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       scríobh focail mílitrithe chuig an aschur caighdeánach",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       mol ceartúcháin d'fhocail mílitrithe (is gá le GNU aspell)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=COMHAD scríobh aschur chuig COMHAD",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    socraigh an teanga den téacs le seiceáil (loicthe=ga)",

    "    --help         display this help and exit"
 => "    --help         taispeáin an chabhair seo agus éirigh as",

    "    --version      output version information and exit"
 => "    --version      taispeáin eolas faoin leagan agus éirigh as",

    "Options for developers:"
 => "Roghanna d'fhorbróirí:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          scríobh i bhformáid XML mar comhéadan le feidhmchláir eile",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        gin rialacha aonchiallacha le halgartam féinlathach de Brill",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         aschur i gcruth HTML chun féachaint le brabhsálaí",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     taispeáin focail ilchiallacha, de réir minicíochta",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        taispeáin gach clib de réir minicíochta (do unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   ná réitigh ranna cainte ilchiallacha de réir minicíochta",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          scríobh sruth XML chuig aschur caighdeánach, chun dífhabhtú",

    "If no file is given, read from standard input."
 => "Mura bhfuil comhad ann, léigh ón ionchur caighdeánach.",

    "Send bug reports to <[_1]>."
 => "Seol tuairiscí fabhtanna chuig <[_1]>.",

    "version [_1]"
 => "leagan [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Is saorbhogearra an ríomhchlár seo; féach ar an bhunchód le haghaidh\ncoinníollacha cóipeála.  Níl baránta AR BITH ann; go fiú níl baránta ann\nd'INDÍOLTACHT nó FEILIÚNACHT DO FHEIDHM AR LEITH, an oiread atá ceadaithe\nde réir dlí.",

    "Try [_1] for more information."
 => "Bain triail as [_1] chun tuilleadh eolais a fháil.",

    "unrecognized option [_1]"
 => "rogha anaithnid [_1]",

    "option [_1] requires an argument"
 => "ní foláir argóint don rogha [_1]",

    "option [_1] does not allow an argument"
 => "ní cheadaítear argóint i ndiaidh an rogha [_1]",

    "Language [_1] is not supported."
 => "Níl an teanga [_1] ar fáil.",

    "conversion from [_1] is not supported"
 => "níl aon fháil ar tiontú ón ionchódú [_1]",

    "aspell-[_1] is not installed"
 => "Níl aspell-[_1] ar fáil",

    "Unknown word"
 => "Focal anaithnid",

    "Unknown word (ignoring remainder in this sentence)"
 => "Focal anaithnid (scaoilfear an chuid eile san abairt seo)",

    "Valid word but extremely rare in actual usage"
 => "Focal ceart ach an-neamhchoitianta",

    "Usually used in the set phrase /[_1]/"
 => "Ní úsáidtear an focal seo ach san abairtín /[_1]/ de ghnáth",

    "You should use /[_1]/ here instead"
 => "Ba chóir duit /[_1]/ a úsáid anseo",

    "Non-standard form of /[_1]/"
 => "Foirm neamhchaighdeánach de /[_1]/",

    "Initial mutation missing"
 => "Urú nó séimhiú ar iarraidh",

    "Unnecessary lenition"
 => "Séimhiú gan ghá",

    "Prefix /h/ missing"
 => "Réamhlitir /h/ ar iarraidh",

    "Prefix /t/ missing"
 => "Réamhlitir /t/ ar iarraidh",

    "Lenition missing"
 => "Séimhiú ar iarraidh",

    "Eclipsis missing"
 => "Urú ar iarraidh",

    "Repeated word"
 => "Focal céanna faoi dhó",

    "Unusual combination of words"
 => "Cor cainte aisteach",

    "Comparative adjective required"
 => "Ba chóir duit an bhreischéim a úsáid anseo",

    "Unnecessary prefix /h/"
 => "Réamhlitir /h/ gan ghá",

    "Unnecessary prefix /t/"
 => "Réamhlitir /t/ gan ghá",

    "Unnecessary use of the definite article"
 => "Ní gá leis an alt cinnte anseo",

    "The genitive case is required here"
 => "Tá gá leis an leagan ginideach anseo",

    "[_1]: out of memory\n"
 => "[_1]: cuimhne ídithe\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' truaillithe ag %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: rabhadh: deimhnigh méid de %s: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: rabhadh: fadhb ag dúnadh %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: níl aon cód gramadaí ann: %s\n",

    "problem with the `cuardach' command\n"
 => "fadhb leis an ordú 'cuardach'\n",

    "[_1]: problem reading the database\n"
 => "[_1]: fadhb ag léamh an bhunachair sonraí\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: cód gramadach neamhcheadaithe\n",

    "Line %d: [_1]\n"
 => "Líne %d: [_1]\n",

    "error parsing command-line options"
 => "earráid agus roghanna líne na n-orduithe á miondealú",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=CÓD   socraigh an t-ionchódú le haschur",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx socraigh an teanga de na teachtaireachtaí",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=DATH    aibhsigh earráidí sa DHATH seo",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       mol ceartúcháin d'fhocail mílitrithe",

    "Derived from a non-standard form of /[_1]/"
 => "Bunaithe ar foirm neamhchaighdeánach de /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Bunaithe go mícheart ar an bhfréamh /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Focal anaithnid ach bunaithe ar /[_1]/ is dócha",

    "Do you mean /[_1]/?"
 => "An raibh /[_1]/ ar intinn agat?",

    "Derived form of common misspelling /[_1]/?"
 => "Bunaithe ar focal mílitrithe go coitianta /[_1]/?",

    "Not in database but may be a compound /[_1]/?"
 => "Focal anaithnid ach is féidir gur comhfhocal /[_1]/ é?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "Focal anaithnid ach is féidir gur comhfhocal neamhchaighdeánach /[_1]/ é?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Is féidir gur focal iasachta é seo (tá na litreacha /[_1]/ neamhdhóchúil)",

);
1;
