package Lingua::GA::Gramadoir::Languages::fr;
# Messages fran�ais pour GNU concernant gramadoir.
# Copyright � 2004 Free Software Foundation, Inc.
# This file is distributed under the same license as the PACKAGE package.
# Michel Robitaille <robitail@IRO.UMontreal.CA>, traducteur depuis/since 1996.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: GNU gramadoir 0.4\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-01-09 08:00-0500\n"
#"Last-Translator: Michel Robitaille <robitail@IRO.UMontreal.CA>\n"
#"Language-Team: French <traduc@traduc.org>\n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=ISO-8859-1\n"
#"Content-Transfer-Encoding: 8-bit\n"

use strict;
use warnings;
use utf8;
use base qw(Lingua::GA::Gramadoir::Languages);
use vars qw(%Lexicon);

%Lexicon = (
    "An Gramadoir"
 => "Un Gramadoir",

    "Currently checking [_1]"
 => "Vérification en cours [_1]",

    "There is no such file."
 => "Il n'y a pas un tel fichier",

    "Is a directory"
 => "Est un répertoire",

    "Permission denied"
 => "Permission refusée",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Usage: [_1] ~[OPTIONS~] ~[FICHIERS~]",

    "Options for end-users:"
 => "Options les usagers:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       rapporter toutes les erreurs (i.e. ne pas utiliser ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  spécifier l'encodage des caractères du texte à vérifier",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       écrire les mots mal orthographiés sur la sortie standard",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       suggérer des corrections pour les erreurs d'orhographe (GNU aspell requis)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    spécifier le langage du texte à vérifier (par défaut=ga)",

    "    --help         display this help and exit"
 => "    --help         afficher l'aide-mémoire et quitter",

    "    --version      output version information and exit"
 => "    --version      afficher la version du logiciel et quitter",

    "Options for developers:"
 => "Options pour les développeurs:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        trouver des règle de clarification à l'aide de l'algorithme non supervisé de Brill",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         produire une sortie HTML pour un logiciel de navigation Internet",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     rapporter les ambiguïtés non résolues, triées selon la fréquence",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        afficher toutes les étiquettes,  triées selon la fréquence (pour unigram-xx.txt)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   ne pas résoudre les parties ambiguës de la langue selon la fréquence",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          écrire un flot XML étiqueté sur la sortie standard, pour mise au point (debug)",

    "If no file is given, read from standard input."
 => "Si aucun fichier n'est fourni, lire l'entrée standard",

    "Send bug reports to <[_1]>."
 => "Transmettre un rapport d'anomalies à <[_1]>.",

    "version [_1]"
 => "version [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Ce logiciel est libre; voir les sources pour les conditions de\nreproduction. AUCUNE garantie n'est donnée; tant pour des raisons\nCOMMERCIALES que pour RÉPONDRE À UN BESOIN PARTICULIER,\nselon que les lois le permettent",

    "Try [_1] for more information."
 => "Essayez [_1] pour plus d'informations.",

    "unrecognized option [_1]"
 => "[_1] option non reconnue",

    "option [_1] requires an argument"
 => "option [_1] requiert un argument",

    "option [_1] does not allow an argument"
 => "option [_1] ne permet pas un argument",

    "Language [_1] is not supported."
 => "Le langage [_1] n'est pas supporté.",

    "conversion from [_1] is not supported"
 => "la conversion 'a partir de [_1] n'est pas supportée",

    "aspell-[_1] is not installed"
 => "aspell-[_1] n'est pas installé",

    "Unknown word"
 => "Mot inconnu",

    "Unknown word (ignoring remainder in this sentence)"
 => "Mot inconnu (le reste de la phrase est ignoré)",

    "Valid word but extremely rare in actual usage"
 => "mot valide mais extrêmement rare selon l'usage actuel",

    "Usually used in the set phrase /[_1]/"
 => "habituellement utilisé dans le jeu de phrases /[_1]/",

    "You should use /[_1]/ here instead"
 => "Vous devriez utiliser /[_1]/ ici à la place",

    "Non-standard form of /[_1]/"
 => "Forme non conforme: utiliser plutôt /[_1]/?",

    "Initial mutation missing"
 => "Mutation initiale manquante",

    "Unnecessary lenition"
 => "Lénition non nécessaire",

    "Prefix /h/ missing"
 => "Préfixe /h/ manquant",

    "Prefix /t/ missing"
 => "Préfixe /t/ manquant",

    "Lenition missing"
 => "Lénition manquante",

    "Eclipsis missing"
 => "Éclipsis manquante",

    "Repeated word"
 => "mot répété",

    "Unusual combination of words"
 => "combinaison de mots inusité",

    "Comparative adjective required"
 => "adjectif comparatif nécessaire",

    "Unnecessary prefix /h/"
 => "préfixe non nécessaire /h/",

    "Unnecessary prefix /t/"
 => "préfixe non nécessaire /t/",

    "Unnecessary use of the definite article"
 => "usage non nécessaire de l'article défini",

    "The genitive case is required here"
 => "le cas génitif est requis ici",

    "[_1]: out of memory\n"
 => "[_1]: mémoire épuisée\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: « %s » corrompu à %s\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: AVERTISSEMENT: vérifier la taille de %s: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: AVERTISSEMENT: problème de fermeture de %s\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: pas de codes de grammaire: %s\n",

    "problem with the `cuardach' command\n"
 => "problème avec la commande « cuardach »\n",

    "[_1]: problem reading the database\n"
 => "[_1]: problème de lecture de la base de données\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: code grammatical illégal\n",

    "Line %d: [_1]\n"
 => "Ligne %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       suggérer des corrections pour les erreurs d'orhographe",

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
