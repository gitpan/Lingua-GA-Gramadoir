package Lingua::GA::Gramadoir::Languages::de;
# Deutsche �bersetzungen f�r gramadoir
# Copyright (C) 2003 Free Software Foundation, Inc.
# This file is distributed under the same license as the gramadoir package.
# Karl Eichwalder <ke@gnu.franken.de>, 2003.
# Martin Gregory <martin.gregory@sas.com>, 2003.
# Roland Illig <roland.illig@gmx.de>, 2004.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.4\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-03-28 22:28+0100\n"
#"Last-Translator: Roland Illig <roland.illig@gmx.de>\n"
#"Language-Team: German <de@li.org>\n"
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
 => "[_1] wird gerade geprüft",

    "There is no such file."
 => "Datei nicht vorhanden.",

    "Is a directory"
 => "Ist ein Verzeichnis",

    "Permission denied"
 => "Zugriff nicht erlaubt",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Syntax: [_1] ~[OPTIONEN~] ~[DATEIEN~]",

    "Options for end-users:"
 => "Optionen für Endbenutzer:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       alle Fehler protokollieren; ~/.neamhshuim wird nicht gelesen",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  Zeichensatz des zu überprüfenden Textes",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       falsch geschriebene Wörter auf Standardausgabe ausgeben",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       Rechtschreibkorrekturen vorschlagen (benötigt GNU aspell)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    Sprache des zu überprüfenden Textes (Voreinstellung=ga)",

    "    --help         display this help and exit"
 => "    --help         diese Kurzanleitung anzeigen",

    "    --version      output version information and exit"
 => "    --version      Versionsnummer anzeigen",

    "Options for developers:"
 => "Optionen für Entwickler:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        Eindeutigkeitsregeln mit Brill's unbeaufsichtigtem Algorithmus finden",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         Ausgabe im HTML-Format erzeugen",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     Nicht aufgelöste Mehrdeutigkeiten berichten, nach Häufigkeit sortiert",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        Alle Tags nach Häufigkeit sortiert ausgeben (für unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   Mehrdeutige Satzteile nicht auflösen",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          Ausgabe im XML-Format zu Zwecken der Fehlersuche erzeugen",

    "If no file is given, read from standard input."
 => "Falls keine Datei angegeben wird, wird von der Standardeingabe gelesen.",

    "Send bug reports to <[_1]>."
 => "Fehlermeldungen an <[_1]> schicken.\nProbleme mit der Übersetzung an die Mailingliste de\@li.org melden.",

    "version [_1]"
 => "Version [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Dieses Programm ist freie Software; die Bedingungen, unter denen Sie es\nkopieren dürfen, finden Sie in dem Quellcode. Es ist OHNE IRGENDEINE GARANTIE,\nsogar ohne die implizite Garantie der MARKTREIFE oder der VERWENDBARKEIT FÜR\nEINEN BESTIMMTEN ZWECK.",

    "Try [_1] for more information."
 => "[_1] eingeben, um weitere Informationen zu erhalten.",

    "unrecognized option [_1]"
 => "unbekannte Option [_1]",

    "option [_1] requires an argument"
 => "Ein Argument ist bei der Option [_1] erforderlich",

    "option [_1] does not allow an argument"
 => "Ein Argument ist bei der Option [_1] nicht erlaubt",

    "Language [_1] is not supported."
 => "Die Sprache [_1] wird nicht unterstützt.",

    "conversion from [_1] is not supported"
 => "Umwandlung von [_1] wird nicht unterstützt.",

    "aspell-[_1] is not installed"
 => "aspell-[_1] ist nicht installiert",

    "Unknown word"
 => "Unbekanntes Wort",

    "Unknown word (ignoring remainder in this sentence)"
 => "Unbekanntes Wort (der Satz wird nicht weiter bearbeitet)",

    "Valid word but extremely rare in actual usage"
 => "Gültiges Wort, wird aber extrem selten wirklich benutzt",

    "Usually used in the set phrase /[_1]/"
 => "Normalerweise im Satz /[_1]/ benutzt",

    "You should use /[_1]/ here instead"
 => "An dieser Stelle besser /[_1]/ benutzen",

    "Non-standard form of /[_1]/"
 => "Nicht dem Standard entsprechende Form: vielleicht besser /[_1]/ benutzen?",

    "Initial mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Unnecessary lenition"
 => "Unnötige Lenierung",

    "Prefix /h/ missing"
 => "Präfix /h/ fehlt",

    "Prefix /t/ missing"
 => "Präfix /t/ fehlt",

    "Lenition missing"
 => "Lenierung fehlt",

    "Eclipsis missing"
 => "Eklipsis fehlt",

    "Repeated word"
 => "Wortwiederholung",

    "Unusual combination of words"
 => "Ungewöhnliche Wortkombination",

    "Comparative adjective required"
 => "Adjektiv im Komparativ benötigt",

    "Unnecessary prefix /h/"
 => "Unnötiges Präfix /h/",

    "Unnecessary prefix /t/"
 => "Unnötiges Präfix /t/",

    "Unnecessary use of the definite article"
 => "Unnötige Benutzung des bestimmten Artikels",

    "The genitive case is required here"
 => "Hier muss ein Genitiv stehen",

    "[_1]: out of memory\n"
 => "[_1]: Arbeitsspeicher erschöpft\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' beschädigt bei %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: Warnung: Größe von %s überprüfen: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: Warnung: Problem beim Schließen von %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: keine grammatischen Codes: %s\n",

    "problem with the `cuardach' command\n"
 => "Problem mit dem Befehl `cuardach'\n",

    "[_1]: problem reading the database\n"
 => "[_1]: Problem beim Lesen der Datenbank\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: ungültiger grammatische Code\n",

    "Line %d: [_1]\n"
 => "Zeile %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       Rechtschreibkorrekturen vorschlagen",

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
