set EXE=convert-to-strip.exe
set APP=convert-to-strip.app

perlapp --trim JSON::PP58 --norunlib --gui --nologo --info "CompanyName=Zetetic LLC;FileVersion=1.0.1;InternalName=convert-to-strip;LegalCopyright=Copyright, 2013 all rights reserved;OriginalFilename=convert-to-strip;ProductName=Convert To Strip;ProductVersion=1.0.1" --exe %EXE% convert-to-strip.pl

perlapp --trim JSON::PP58 --norunlib --gui --nologo --target macosx-universal-32 --exe %APP% convert-to-strip.pl

set ZIP=tools\7za.exe

del /q %EXE%.zip
del /q %APP%.zip

%ZIP% a -tzip %EXE%.zip %EXE%
%ZIP% a -tzip %APP%.zip %APP%

del /q %EXE%
rmdir /s /q %APP%
