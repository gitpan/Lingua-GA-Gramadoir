package Lingua::GA::Gramadoir::Languages::mn;
# This file is distributed under the same license as the PACKAGE package.
# Copyright (C) 2004 Free Software Foundation, Inc.
# Sanlig Badral <badral@users.sourceforge.net>, 2004.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir-0.4\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2004-07-28 08:43-0500\n"
#"PO-Revision-Date: 2004-01-11 13:26+0100\n"
#"Last-Translator: Sanlig Badral <badral@users.sourceforge.net>\n"
#"Language-Team: Mongolian <openmn-translation@lists.sourceforge.net>\n"
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
 => "Грамадойр",

    "Currently checking [_1]"
 => "Одоо шалгаж байна [_1]",

    "There is no such file."
 => "Тийм файл алга.",

    "Is a directory"
 => "Энэ бол лавлах",

    "Permission denied"
 => "Хандалт хүчингүй",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Хэрэглээ: [_1] ~[СОНГОЛТ~] ~[ФАЙЛ~]",

    "Options for end-users:"
 => "Эцсийн хэрэглэгчдийн сонголт:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       бүх алдааг мэдээлэх (Ө.х. ~/.neamhshuim гэж хэрэглэхгүй)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=ENC  шалгагдах ёстой текстийн тэмдэгт кодчилолыг тодорхойлох",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       стандарт гаралт руу алдаатай үгсийг бичих",

    "    --aspell       suggest corrections for misspellings (requires GNU aspell)"
 => "    --aspell       зөв бичгийн алдаа засалт санал болгох (ГНУ aspell шаардлагатай)",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=FILE  write output to FILE",

    "    --teanga=XX    specify the language of the text to be checked (default=ga)"
 => "    --teanga=XX    шалгагдах текстийн хэлийг сонгоно (стандартаар=ga)",

    "    --help         display this help and exit"
 => "    --help         энэ тусламжийг үзүүлээд гарна",

    "    --version      output version information and exit"
 => "    --version      хувилбарын мэдээллийг үзүүлээд гарна",

    "Options for developers:"
 => "Хөгжүүлэгчдийн сонголт:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          output a simple XML format for use with other applications",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        ухагдахууны тодорхойлолтын дүрмийг Биллийн шалгалтгүй алгоритмаар олох",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         Вэб хөтөчид харуулахад зориулсан HTML -р гаргах",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall     шийдэгдээгүй ац утгыг хэлбэлзэлээр эрэмбэлэн тайлагнах",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        хэлбэлзэлээр эрэмбэлэн бүх тагийг гаргах (unigram-xx.txt -н хувьд)",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   хэллэгийн хэлбэлзэлээр ац утгат хэсгийг шийдвэрлэхгүй",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          Тагтай XML урсгал стандарт гаралт руу шинжлэн гаргах",

    "If no file is given, read from standard input."
 => "Хэрэв файл өгөгдөөгүй бол стандарт оролтоос уншина.",

    "Send bug reports to <[_1]>."
 => "<[_1]> рүү согогийн тайлан илгээх.",

    "version [_1]"
 => "хувилбар [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Энэ бол үнэгүй програм; эх код дах хуулах нөхцөлийн хар.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law.",

    "Try [_1] for more information."
 => "Илүү мэдээллийн хувьд [_1] гэж оролд.",

    "unrecognized option [_1]"
 => "танигдахгүй сонголт [_1]",

    "option [_1] requires an argument"
 => "[_1] сонголт аргумент шаардаж байна",

    "option [_1] does not allow an argument"
 => "[_1] сонголт аргумент зөвшөөрөхгүй",

    "Language [_1] is not supported."
 => "[_1] хэл дэмжигдээгүй байна.",

    "conversion from [_1] is not supported"
 => "[_1] -с хөрвүүлэх дэмжигдээгүй",

    "aspell-[_1] is not installed"
 => "aspell-[_1] суулгагдаагүй байна",

    "Unknown word"
 => "Мэдэгдэхүй үг",

    "Unknown word (ignoring remainder in this sentence)"
 => "Мэдэгдэхгүй үг (энэ өгүүлбэрийн үлдэгдлийг үл хэрэгсэх)",

    "Valid word but extremely rare in actual usage"
 => "Хүчинтэй үг гэхдээ идэвхитэй хэрэглээнд туйлын ховор",

    "Usually used in the set phrase /[_1]/"
 => " /[_1]/ хэллэгийн олонлогт үргэлж хэрэглэгддэг",

    "You should use /[_1]/ here instead"
 => "Та оронд нь /[_1]/ гэж хэрэглэх ёстой",

    "Non-standard form of /[_1]/"
 => "Стандарт бус хэлбэр: магад /[_1]/ байх?",

    "Initial mutation missing"
 => "Анхдагч өөрчлөлт дутуу",

    "Unnecessary lenition"
 => "шаардлагагүй зөөлрүүлэлт",

    "Prefix /h/ missing"
 => "Угтвар /h/ дутуу",

    "Prefix /t/ missing"
 => "Угтвар /t/ дутуу",

    "Lenition missing"
 => "Зөөлрүүлэлт дутуу",

    "Eclipsis missing"
 => "Eclipsis дутуу",

    "Repeated word"
 => "Давтагдсан үг",

    "Unusual combination of words"
 => "Сонин үгийн хослол байна даа",

    "Comparative adjective required"
 => "тэмдэг нэрийн харьцуулал шаардлагатай",

    "Unnecessary prefix /h/"
 => "Угтвар шаардлагагүй /h/",

    "Unnecessary prefix /t/"
 => "Угтвар шаардлагагүй /t/",

    "Unnecessary use of the definite article"
 => "Хүйс тодорхойлох шаардлагагүй хэрэглээ",

    "The genitive case is required here"
 => "Харъяалахын тийн ялгал энд шаардлагатай",

    "[_1]: out of memory\n"
 => "[_1]: санах ойгоос халилаа\n",

    "[_1]: `%s' corrupted at %s\n"
 => "[_1]: `%s' %s-д эвдэрчээ\n",

    "[_1]: warning: check size of %s: %d?\n"
 => "[_1]: сануулга: %s-н хэмжээг шалгах: %d?\n",

    "[_1]: warning: problem closing %s\n"
 => "[_1]: сануулга: %s асуудал хаагдав.\n",

    "[_1]: no grammar codes: %s\n"
 => "[_1]: дүрмийн код алга: %s\n",

    "problem with the `cuardach' command\n"
 => "`cuardach' тушаалд асуудал гарав\n",

    "[_1]: problem reading the database\n"
 => "[_1]: өгөгдлийн бааз уншиж байхад алдаа\n",

    "[_1]: illegal grammatical code\n"
 => "[_1]: хүчингүй дүрэмтэй код\n",

    "Line %d: [_1]\n"
 => "Мөр %d: [_1]\n",

    "error parsing command-line options"
 => "error parsing command-line options",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=ENC   specify the character encoding for output",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx choose the language for error messages",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=COLOR   specify the color to use for highlighting errors",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       зөв бичгийн алдаа засалт санал болгох",

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
