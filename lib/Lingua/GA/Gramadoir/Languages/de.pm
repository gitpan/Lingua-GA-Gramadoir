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
#"Project-Id-Version: gramadoir 0.5\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2005-03-02 22:40-0600\n"
#"PO-Revision-Date: 2004-10-16 08:54+0100\n"
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
    "Line %d: [_1]\n"
 => "Zeile %d: [_1]\n",

    "unrecognized option [_1]"
 => "unbekannte Option [_1]",

    "option [_1] requires an argument"
 => "Ein Argument ist bei der Option [_1] erforderlich",

    "option [_1] does not allow an argument"
 => "Ein Argument ist bei der Option [_1] nicht erlaubt",

    "error parsing command-line options"
 => "Fehler beim Interpretieren der Kommandozeilenoptionen",

    "Unable to set output color to [_1]"
 => "Unable to set output color to [_1]",

    "Language [_1] is not supported."
 => "Die Sprache [_1] wird nicht unterstützt.",

    "An Gramadoir"
 => "An Gramadóir",

    "Try [_1] for more information."
 => "[_1] eingeben, um weitere Informationen zu erhalten.",

    "version [_1]"
 => "Version [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Dieses Programm ist freie Software; die Bedingungen, unter denen Sie es\nkopieren dürfen, finden Sie in dem Quellcode. Es ist OHNE IRGENDEINE GARANTIE,\nsogar ohne die implizite Garantie der MARKTREIFE oder der VERWENDBARKEIT FÜR\nEINEN BESTIMMTEN ZWECK.",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Syntax: [_1] ~[OPTIONEN~] ~[DATEIEN~]",

    "Options for end-users:"
 => "Optionen für Endbenutzer:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       alle Fehler protokollieren; ~/.neamhshuim wird nicht gelesen",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  Zeichensatz des zu überprüfenden Textes",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   Zeichencodierung für die Ausgabe wählen",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx Sprache für Fehlermeldungen wählen",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=FARBE   Farbe zum Hervorheben von Fehlern wählen",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       falsch geschriebene Wörter auf Standardausgabe ausgeben",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       Rechtschreibkorrekturen vorschlagen",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=DATEI Ausgabe in DATEI schreiben",

    "    --help         display this help and exit"
 => "    --help         diese Kurzanleitung anzeigen",

    "    --version      output version information and exit"
 => "    --version      Versionsnummer anzeigen",

    "Options for developers:"
 => "Optionen für Entwickler:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          Einfaches XML-Dateiformat zur Benutzung in anderen Anwendungen ausgeben",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         Ausgabe im HTML-Format erzeugen",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   Mehrdeutige Satzteile nicht auflösen",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          Ausgabe im XML-Format zu Zwecken der Fehlersuche erzeugen",

    "If no file is given, read from standard input."
 => "Falls keine Datei angegeben wird, wird von der Standardeingabe gelesen.",

    "Send bug reports to <[_1]>."
 => "Fehlermeldungen an <[_1]> schicken.\nProbleme mit der Übersetzung an die Mailingliste de\@li.org melden.",

    "There is no such file."
 => "Datei nicht vorhanden.",

    "Is a directory"
 => "Ist ein Verzeichnis",

    "Permission denied"
 => "Zugriff nicht erlaubt",

    "[_1]: warning: problem closing [_2]\n"
 => "[_1]: Warnung: Problem beim Schließen von [_2]\n",

    "Currently checking [_1]"
 => "[_1] wird gerade geprüft",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     Nicht aufgelöste Mehrdeutigkeiten berichten, nach Häufigkeit sortiert",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        Alle Tags nach Häufigkeit sortiert ausgeben (für unigram-xx.txt)",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        Eindeutigkeitsregeln mit Brill's unbeaufsichtigtem Algorithmus finden",

    "[_1]: problem reading the database\n"
 => "[_1]: Problem beim Lesen der Datenbank\n",

    "[_1]: `[_2]' corrupted at [_3]\n"
 => "[_1]: `[_2]' beschädigt bei [_3]\n",

    "conversion from [_1] is not supported"
 => "Umwandlung von [_1] wird nicht unterstützt.",

    "[_1]: illegal grammatical code\n"
 => "[_1]: ungültiger grammatische Code\n",

    "[_1]: no grammar codes: [_2]\n"
 => "[_1]: keine grammatischen Codes: [_2]\n",

    "[_1]: unrecognized error macro: [_2]\n"
 => "unbekannte Option [_1]",

    "Valid word but extremely rare in actual usage"
 => "Gültiges Wort, wird aber extrem selten wirklich benutzt",

    "Repeated word"
 => "Wortwiederholung",

    "Unusual combination of words"
 => "Ungewöhnliche Wortkombination",

    "The plural form is required here"
 => "Hier muss ein Genitiv stehen",

    "The singular form is required here"
 => "Hier muss ein Genitiv stehen",

    "Comparative adjective required"
 => "Adjektiv im Komparativ benötigt",

    "Definite article required"
 => "Definite article required",

    "Unnecessary use of the definite article"
 => "Unnötige Benutzung des bestimmten Artikels",

    "Unnecessary use of the genitive case"
 => "Unnötige Benutzung des bestimmten Artikels",

    "The genitive case is required here"
 => "Hier muss ein Genitiv stehen",

    "It seems unlikely that you intended to use the subjunctive here"
 => "It seems unlikely that you intended to use the subjunctive here",

    "Usually used in the set phrase /[_1]/"
 => "Normalerweise im Satz /[_1]/ benutzt",

    "You should use /[_1]/ here instead"
 => "An dieser Stelle besser /[_1]/ benutzen",

    "Non-standard form of /[_1]/"
 => "Nicht dem Standard entsprechende Form von /[_1]/",

    "Derived from a non-standard form of /[_1]/"
 => "Abgeleitet von der nicht dem Standard entsprechenden Form /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Falsch abgeleitet von der Wurzel /[_1]/",

    "Unknown word"
 => "Unbekanntes Wort",

    "Unknown word: /[_1]/?"
 => "Unbekanntes Wort",

    "Valid word but more often found in place of /[_1]/"
 => "Valid word but more often found in place of /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Nicht in der Datenbank, aber anscheinend aus der Wurzel /[_1]/ gebildet",

    "The word /[_1]/ is not needed"
 => "The word /[_1]/ is not needed",

    "Do you mean /[_1]/?"
 => "Meinen Sie /[_1]/?",

    "Derived form of common misspelling /[_1]/?"
 => "Abgeleitete Form der beliebten Falschschreibung /[_1]/?",

    "Not in database but may be a compound /[_1]/?"
 => "Nicht in der Datenbank, aber könnte es ein zusammengesetztes /[_1]/ sein?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "Nicht in der Datenbank, aber könnte es ein ungewöhnliches zusammengesetztes /[_1]/ sein?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Wahrscheinlich ein Fremdwort (die Folge /[_1]/ ist sehr unwahrscheinlich)",

    "Prefix /h/ missing"
 => "Präfix /h/ fehlt",

    "Prefix /t/ missing"
 => "Präfix /t/ fehlt",

    "Prefix /d'/ missing"
 => "Präfix /h/ fehlt",

    "Unnecessary prefix /h/"
 => "Unnötiges Präfix /h/",

    "Unnecessary prefix /t/"
 => "Unnötiges Präfix /t/",

    "Unnecessary prefix /d'/"
 => "Unnötiges Präfix /h/",

    "Unnecessary initial mutation"
 => "Unnötige Lenierung",

    "Initial mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Unnecessary lenition"
 => "Unnötige Lenierung",

    "Often the preposition /[_1]/ causes lenition, but this case is unclear"
 => "Often the preposition /[_1]/ causes lenition, but this case is unclear",

    "Lenition missing"
 => "Lenierung fehlt",

    "Unnecessary eclipsis"
 => "Unnötige Lenierung",

    "Eclipsis missing"
 => "Eklipsis fehlt",

    "The dative is used only in special phrases"
 => "The dative is used only in special phrases",

    "The dependent form of the verb is required here"
 => "Hier muss ein Genitiv stehen",

    "Unnecessary use of the dependent form of the verb"
 => "Unnötige Benutzung des bestimmten Artikels",

    "The synthetic (combined) form, ending in /[_1]/, is often used here"
 => "The synthetic (combined) form, ending in /[_1]/, is often used here",

    "Second (soft) mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Third (breathed) mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Fourth (hard) mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Fifth (mixed) mutation missing"
 => "Veränderung am Anfang des Wortes fehlt",

    "Fifth (mixed) mutation after 'th missing"
 => "Veränderung am Anfang des Wortes fehlt",

);
1;
