package Lingua::GA::Gramadoir::Languages::fr;
# Messages fran�ais pour GNU concernant gramadoir.
# Copyright � 2004 Free Software Foundation, Inc.
# This file is distributed under the same license as the PACKAGE package.
# Michel Robitaille <robitail@IRO.UMontreal.CA>, traducteur depuis/since 1996.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: GNU gramadoir 0.5\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2005-03-02 22:40-0600\n"
#"PO-Revision-Date: 2004-08-26 08:00-0500\n"
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
    "Line %d: [_1]\n"
 => "Ligne %d: [_1]\n",

    "unrecognized option [_1]"
 => "[_1] option non reconnue",

    "option [_1] requires an argument"
 => "option [_1] requiert un argument",

    "option [_1] does not allow an argument"
 => "option [_1] ne permet pas un argument",

    "error parsing command-line options"
 => "erreur d'analyse de syntaxe des options de la ligne de commande",

    "Unable to set output color to [_1]"
 => "Unable to set output color to [_1]",

    "Language [_1] is not supported."
 => "Le langage [_1] n'est pas supporté.",

    "An Gramadoir"
 => "Un Gramadoir",

    "Try [_1] for more information."
 => "Essayez [_1] pour plus d'informations.",

    "version [_1]"
 => "version [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Ce logiciel est libre; voir les sources pour les conditions de\nreproduction. AUCUNE garantie n'est donnée; tant pour des raisons\nCOMMERCIALES que pour RÉPONDRE À UN BESOIN PARTICULIER,\nselon que les lois le permettent",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Usage: [_1] ~[OPTIONS~] ~[FICHIERS~]",

    "Options for end-users:"
 => "Options les usagers:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       rapporter toutes les erreurs (i.e. ne pas utiliser ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  spécifier l'encodage des caractères du texte à vérifier",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   spécifier l'encodage des caractères pour la sortie",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choisir le langage pour les message d'erreur",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COULEUR spécifier la COULEUR à utiliser pour surligner les erreurs",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       écrire les mots mal orthographiés sur la sortie standard",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       suggérer des corrections pour les erreurs d'orhographe",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FICHIER  écrire la sortie dans le FICHIER",

    "    --help         display this help and exit"
 => "    --help         afficher l'aide-mémoire et quitter",

    "    --version      output version information and exit"
 => "    --version      afficher la version du logiciel et quitter",

    "Options for developers:"
 => "Options pour les développeurs:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          produire un format XML simple de sortie avec d'autres applications",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         produire une sortie HTML pour un logiciel de navigation Internet",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   ne pas résoudre les parties ambiguës de la langue selon la fréquence",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          écrire un flot XML étiqueté sur la sortie standard, pour mise au point (debug)",

    "If no file is given, read from standard input."
 => "Si aucun fichier n'est fourni, lire l'entrée standard",

    "Send bug reports to <[_1]>."
 => "Transmettre un rapport d'anomalies à <[_1]>.",

    "There is no such file."
 => "Il n'y a pas un tel fichier",

    "Is a directory"
 => "Est un répertoire",

    "Permission denied"
 => "Permission refusée",

    "[_1]: warning: problem closing [_2]\n"
 => "[_1]: AVERTISSEMENT: problème de fermeture de [_2]\n",

    "Currently checking [_1]"
 => "Vérification en cours [_1]",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     rapporter les ambiguïtés non résolues, triées selon la fréquence",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        afficher toutes les étiquettes,  triées selon la fréquence (pour unigram-xx.txt)",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        trouver des règle de clarification à l'aide de l'algorithme non supervisé de Brill",

    "[_1]: problem reading the database\n"
 => "[_1]: problème de lecture de la base de données\n",

    "[_1]: `[_2]' corrupted at [_3]\n"
 => "[_1]: « [_2] » corrompu à [_3]\n",

    "conversion from [_1] is not supported"
 => "la conversion 'a partir de [_1] n'est pas supportée",

    "[_1]: illegal grammatical code\n"
 => "[_1]: code grammatical illégal\n",

    "[_1]: no grammar codes: [_2]\n"
 => "[_1]: pas de codes de grammaire: [_2]\n",

    "[_1]: unrecognized error macro: [_2]\n"
 => "[_1] option non reconnue",

    "Valid word but extremely rare in actual usage"
 => "mot valide mais extrêmement rare selon l'usage actuel",

    "Repeated word"
 => "mot répété",

    "Unusual combination of words"
 => "combinaison de mots inusité",

    "The plural form is required here"
 => "le cas génitif est requis ici",

    "The singular form is required here"
 => "le cas génitif est requis ici",

    "Comparative adjective required"
 => "adjectif comparatif nécessaire",

    "Definite article required"
 => "Definite article required",

    "Unnecessary use of the definite article"
 => "usage non nécessaire de l'article défini",

    "Unnecessary use of the genitive case"
 => "usage non nécessaire de l'article défini",

    "The genitive case is required here"
 => "le cas génitif est requis ici",

    "It seems unlikely that you intended to use the subjunctive here"
 => "It seems unlikely that you intended to use the subjunctive here",

    "Usually used in the set phrase /[_1]/"
 => "habituellement utilisé dans le jeu de phrases /[_1]/",

    "You should use /[_1]/ here instead"
 => "Vous devriez utiliser /[_1]/ ici à la place",

    "Non-standard form of /[_1]/"
 => "Forme non standard de /[_1]/",

    "Derived from a non-standard form of /[_1]/"
 => "Dérivé d'une forme non standard de /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Dérivé incorrectement de la racine /[_1]/",

    "Unknown word"
 => "Mot inconnu",

    "Unknown word: /[_1]/?"
 => "Mot inconnu",

    "Valid word but more often found in place of /[_1]/"
 => "Valid word but more often found in place of /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "N'est pas dans la base de données mais apparemment formé à partir de la racine /[_1]/",

    "The word /[_1]/ is not needed"
 => "The word /[_1]/ is not needed",

    "Do you mean /[_1]/?"
 => "Entendez-vous /[_1]/?",

    "Derived form of common misspelling /[_1]/?"
 => "Forme dérivée d'une erreur d'orthographe commune /[_1]/?",

    "Not in database but may be a compound /[_1]/?"
 => "N'est pas dans la base de données mais peut être composé /[_1]/?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "N'est pas dans la base de données mais peut être composé de manière non standard /[_1]/?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Possiblement un mot étranger (la séquence /[_1]/ est hautement improbable)",

    "Prefix /h/ missing"
 => "Préfixe /h/ manquant",

    "Prefix /t/ missing"
 => "Préfixe /t/ manquant",

    "Prefix /d'/ missing"
 => "Préfixe /h/ manquant",

    "Unnecessary prefix /h/"
 => "préfixe non nécessaire /h/",

    "Unnecessary prefix /t/"
 => "préfixe non nécessaire /t/",

    "Unnecessary prefix /d'/"
 => "préfixe non nécessaire /h/",

    "Unnecessary initial mutation"
 => "Lénition non nécessaire",

    "Initial mutation missing"
 => "Mutation initiale manquante",

    "Unnecessary lenition"
 => "Lénition non nécessaire",

    "Often the preposition /[_1]/ causes lenition, but this case is unclear"
 => "Often the preposition /[_1]/ causes lenition, but this case is unclear",

    "Lenition missing"
 => "Lénition manquante",

    "Unnecessary eclipsis"
 => "Lénition non nécessaire",

    "Eclipsis missing"
 => "Éclipsis manquante",

    "The dative is used only in special phrases"
 => "The dative is used only in special phrases",

    "The dependent form of the verb is required here"
 => "le cas génitif est requis ici",

    "Unnecessary use of the dependent form of the verb"
 => "usage non nécessaire de l'article défini",

    "The synthetic (combined) form, ending in /[_1]/, is often used here"
 => "The synthetic (combined) form, ending in /[_1]/, is often used here",

    "Second (soft) mutation missing"
 => "Mutation initiale manquante",

    "Third (breathed) mutation missing"
 => "Mutation initiale manquante",

    "Fourth (hard) mutation missing"
 => "Mutation initiale manquante",

    "Fifth (mixed) mutation missing"
 => "Mutation initiale manquante",

    "Fifth (mixed) mutation after 'th missing"
 => "Mutation initiale manquante",

);
1;
