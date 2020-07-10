set EXE=convert-to-codebook.exe
set APP=convert-to-codebook.app
set LNX=convert-to-codebook-linux

perlapp --trim JSON::PP58 --norunlib --gui --nologo --target windows-x86-32 --info "CompanyName=Zetetic LLC;FileVersion=1.0.4;InternalName=convert-to-codebook;LegalCopyright=Copyright 2012-2013 All rights reserved;OriginalFilename=convert-to-codebook;ProductName=Convert to Codebook;ProductVersion=1.0.4" --exe %EXE% convert-to-codebook.pl

perlapp --trim JSON::PP58 --norunlib --gui --nologo --target macosx-universal-32 --exe %APP% convert-to-codebook.pl

set ZIP=tools\7za.exe

del /q %EXE%.zip
del /q %APP%.zip

%ZIP% a -tzip %EXE%.zip %EXE%
%ZIP% a -tzip %APP%.zip %APP%

del /q %EXE%
rmdir /s /q %APP%
