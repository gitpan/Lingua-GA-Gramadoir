package Lingua::GA::Gramadoir::Languages::vi;
# Vietnamese Translation for gramadoir-0.5.
# Copyright (C) 2005 Kevin P. Scannell (msgid)
# Copyright (C) 2005 Free Software Foundation, Inc.
# Clytie Siddall <clytie@riverland.net.au>, 2005.
#
#msgid ""
#msgstr ""
#"Project-Id-Version: gramadoir 0.5\n"
#"Report-Msgid-Bugs-To: <scannell@slu.edu>\n"
#"POT-Creation-Date: 2005-03-02 22:40-0600\n"
#"PO-Revision-Date: 2005-02-04 17:24+1030\n"
#"Last-Translator: Clytie Siddall <clytie@riverland.net.au>\n"
#"Language-Team: Vietnamese <gnomevi-list@lists.sourceforge.net> \n"
#"MIME-Version: 1.0\n"
#"Content-Type: text/plain; charset=utf-8\n"
#"Content-Transfer-Encoding: 8bit\n"

use strict;
use warnings;
use utf8;
use base qw(Lingua::GA::Gramadoir::Languages);
use vars qw(%Lexicon);

%Lexicon = (
    "Line %d: [_1]\n"
 => "Dòng %d: [_1]\n",

    "unrecognized option [_1]"
 => "chưa chấp nhận tùy chọn [_1]",

    "option [_1] requires an argument"
 => "tùy chọn [_1] cần đến đối số",

    "option [_1] does not allow an argument"
 => "tùy chọn [_1] không cho phép đối số",

    "error parsing command-line options"
 => "gặp lỗi khi phân tách tùy chọn đường lệnh",

    "Unable to set output color to [_1]"
 => "Unable to set output color to [_1]",

    "Language [_1] is not supported."
 => "Chưa hỗ trợ ngôn ngữ [_1].",

    "An Gramadoir"
 => "An Gramadóir",

    "Try [_1] for more information."
 => "Thử lệnh [_1] để tìm thông tin thêm.",

    "version [_1]"
 => "phiên bản [_1]",

    "This is free software; see the source for copying conditions.  There is NO\nwarranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,\nto the extent permitted by law."
 => "Phần mềm này tự do; hãy xem nguồn để tìm điều kiện sao chép.\nKhông bảo đảm gì cả, dù khả năng bán hay khả năng làm việc dứt khoát,\ntrong phạm vi mà luật cho phép.",

    "Usage: [_1] ~[OPTIONS~] ~[FILES~]"
 => "Cách sử dụng: [_1] ~[TÙY_CHỌN~] ~[TẬP_TIN~]",

    "Options for end-users:"
 => "Tùy chọn cho người sử dụng cuối:",

    "    --iomlan       report all errors (i.e. do not use ~/.neamhshuim)"
 => "    --iomlan       thông báo tất cả lỗi (thì không sử dụng ~/.neamhshuim)",

    "    --ionchod=ENC  specify the character encoding of the text to be checked"
 => "    --ionchod=MÃ  ghi rõ mã chữ của văn bản để kiểm tra",

    "    --aschod=ENC   specify the character encoding for output"
 => "    --aschod=MÃ   ghi rõ mã chữ để xuất",

    "    --comheadan=xx choose the language for error messages"
 => "    --comheadan=xx chọn ngôn ngữ đối với thông điệp lỗi",

    "    --dath=COLOR   specify the color to use for highlighting errors"
 => "    --dath=MÀU   ghi rõ màu để nổi bật lỗi",

    "    --litriu       write misspelled words to standard output"
 => "    --litriu       ghi từ sai chính tả vào thiết bị xuất chuẩn",

    "    --aspell       suggest corrections for misspellings"
 => "    --aspell       đề nghị cách sửa từ sai chính tả",

    "    --aschur=FILE  write output to FILE"
 => "    --aschur=TẬP_TIN  ghi dữ liệu xuất TẬP TIN ấy",

    "    --help         display this help and exit"
 => "    --help         hiển thì _trợ giúp_ này rồi thoát",

    "    --version      output version information and exit"
 => "    --version      xuất thông tin _phiên bản_ rồi thoát",

    "Options for developers:"
 => "Tùy chọn cho lập trình viên:",

    "    --api          output a simple XML format for use with other applications"
 => "    --api          xuất khuôn dạng XML đơn giản để sử dụng với ứng dụng khác",

    "    --html         produce HTML output for viewing in a web browser"
 => "    --html         xuất bằng html để coi trong trình duyệt Mạng",

    "    --no-unigram   do not resolve ambiguous parts of speech by frequency"
 => "    --no-unigram   không giải quyết loại từ mơ hồ theo tần số",

    "    --xml          write tagged XML stream to standard output, for debugging"
 => "    --xml          ghi dòng XML có thẻ vào thiết bị xuất chuẩn để gỡ lỗi",

    "If no file is given, read from standard input."
 => "Nếu chưa chọn tập tin thì đọc dữ liệu nhập chuẩn.",

    "Send bug reports to <[_1]>."
 => "Hãy thông báo lỗi cho <[_1]>",

    "There is no such file."
 => "Không có tập tin như vậy.",

    "Is a directory"
 => "là thư mục",

    "Permission denied"
 => "Không cho phép",

    "[_1]: warning: problem closing [_2]\n"
 => "[_1]: cảnh báo: gặp khó đóng [_2]\n",

    "Currently checking [_1]"
 => "Hiện kiểm tra [_1]",

    "    --ilchiall     report unresolved ambiguities, sorted by frequency"
 => "    --ilchiall    thông báo các từ mơ hồ chưa giải quyết, sắp xếp theo tần số",

    "    --minic        output all tags, sorted by frequency (for unigram-xx.txt)"
 => "    --minic        xuất tất cả thẻ, sắp xếp theo tần số (đối với unigram-xx.txt)",

    "    --brill        find disambiguation rules via Brill's unsupervised algorithm"
 => "    --brill        tìm quy tắc giải quyết từ mơ hồ thông qua thuật toán không có giám sát của Brill",

    "[_1]: problem reading the database\n"
 => "[_1]: gặp khó đọc cơ sở dữ liệu\n",

    "[_1]: `[_2]' corrupted at [_3]\n"
 => "[_1]: `[_2]' bị hỏng tại [_3]\n",

    "conversion from [_1] is not supported"
 => "chưa hỗ trợ bản dịch sang [_1]",

    "[_1]: illegal grammatical code\n"
 => "[_1]: không cho phép mã ngữ pháp ấy\n",

    "[_1]: no grammar codes: [_2]\n"
 => "[_1]: không có mã ngữ pháp: [_2]\n",

    "[_1]: unrecognized error macro: [_2]\n"
 => "chưa chấp nhận tùy chọn [_1]",

    "Valid word but extremely rare in actual usage"
 => "Từ hợp lệ nhưng rất ít dụng",

    "Repeated word"
 => "Một từ hai lần",

    "Unusual combination of words"
 => "Phối hợp từ một cách không thường",

    "The plural form is required here"
 => "Ở đây thì cần đến cách sở hữu",

    "The singular form is required here"
 => "Ở đây thì cần đến cách sở hữu",

    "Comparative adjective required"
 => "Cần đến tính từ so sánh",

    "Definite article required"
 => "Definite article required",

    "Unnecessary use of the definite article"
 => "Không cần sử dụng mạo từ hạn định",

    "Unnecessary use of the genitive case"
 => "Không cần sử dụng mạo từ hạn định",

    "The genitive case is required here"
 => "Ở đây thì cần đến cách sở hữu",

    "It seems unlikely that you intended to use the subjunctive here"
 => "It seems unlikely that you intended to use the subjunctive here",

    "Usually used in the set phrase /[_1]/"
 => "Thường dụng trong cụm từ riêng /[_1]/",

    "You should use /[_1]/ here instead"
 => "Ở đây thì nên sử dụng /[_1]/ thay thế",

    "Non-standard form of /[_1]/"
 => "Hình thái không chuẩn của /[_1]/",

    "Derived from a non-standard form of /[_1]/"
 => "Gốc là hình thái không chuẩn của /[_1]/",

    "Derived incorrectly from the root /[_1]/"
 => "Gốc (không đúng) là /[_1]/",

    "Unknown word"
 => "Từ chưa biết",

    "Unknown word: /[_1]/?"
 => "Từ chưa biết",

    "Valid word but more often found in place of /[_1]/"
 => "Valid word but more often found in place of /[_1]/",

    "Not in database but apparently formed from the root /[_1]/"
 => "Không trong cơ sở dữ liệu nhưng hình như có gốc /[_1]/",

    "The word /[_1]/ is not needed"
 => "The word /[_1]/ is not needed",

    "Do you mean /[_1]/?"
 => "Ý kiến bạn là /[_1]/ không??",

    "Derived form of common misspelling /[_1]/?"
 => "Hình thái bắt nguồn từ sai chính tả /[_1]/ không?",

    "Not in database but may be a compound /[_1]/?"
 => "Không trong cơ sở dữ liệu nhưng có lẽ là /[_1]/ ghép không?",

    "Not in database but may be a non-standard compound /[_1]/?"
 => "Không trong cơ sở dữ liệu nhưng có lẽ là /[_1]/ ghép không chuẩn không?",

    "Possibly a foreign word (the sequence /[_1]/ is highly improbable)"
 => "Có lẽ từ nước ngoài (sắp xếp  /[_1]/ rất không chắc)",

    "Prefix /h/ missing"
 => "Thiếu tiền tố /h/",

    "Prefix /t/ missing"
 => "Thiếu tiền tố /t/",

    "Prefix /d'/ missing"
 => "Thiếu tiền tố /h/",

    "Unnecessary prefix /h/"
 => "Không cần tiền tố /h/",

    "Unnecessary prefix /t/"
 => "Không cần tiền tố /t/",

    "Unnecessary prefix /d'/"
 => "Không cần tiền tố /h/",

    "Unnecessary initial mutation"
 => "Không cần thêm chữ h để làm cho phụ âm đầu mềm hơn",

    "Initial mutation missing"
 => "Thiếu cách đổi phụ âm đầu",

    "Unnecessary lenition"
 => "Không cần thêm chữ h để làm cho phụ âm đầu mềm hơn",

    "Often the preposition /[_1]/ causes lenition, but this case is unclear"
 => "Often the preposition /[_1]/ causes lenition, but this case is unclear",

    "Lenition missing"
 => "Thiếu cách thêm chữ h để làm cho phụ âm đầu mềm hơn",

    "Unnecessary eclipsis"
 => "Không cần thêm chữ h để làm cho phụ âm đầu mềm hơn",

    "Eclipsis missing"
 => "Thiếu cách che phụ âm đầu",

    "The dative is used only in special phrases"
 => "The dative is used only in special phrases",

    "The dependent form of the verb is required here"
 => "Ở đây thì cần đến cách sở hữu",

    "Unnecessary use of the dependent form of the verb"
 => "Không cần sử dụng mạo từ hạn định",

    "The synthetic (combined) form, ending in /[_1]/, is often used here"
 => "The synthetic (combined) form, ending in /[_1]/, is often used here",

    "Second (soft) mutation missing"
 => "Thiếu cách đổi phụ âm đầu",

    "Third (breathed) mutation missing"
 => "Thiếu cách đổi phụ âm đầu",

    "Fourth (hard) mutation missing"
 => "Thiếu cách đổi phụ âm đầu",

    "Fifth (mixed) mutation missing"
 => "Thiếu cách đổi phụ âm đầu",

    "Fifth (mixed) mutation after 'th missing"
 => "Thiếu cách đổi phụ âm đầu",

);
1;
