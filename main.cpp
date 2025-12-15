
// https://www.youtube.com/watch?v=DMWD7wfhgNY
// https://code.visualstudio.com/docs/cpp/config-mingw

#include <iostream>
#include <vector>
#include <string>
#include <cstdio>
#include "stdio.h"

using namespace std;

std::vector<std::string> split(std::string s, std::string delimiter) {
    size_t pos_start = 0, pos_end, delim_len = delimiter.length();
    std::string token;
    std::vector<std::string> res;

    while ((pos_end = s.find(delimiter, pos_start)) != std::string::npos) {
        token = s.substr (pos_start, pos_end - pos_start);
        pos_start = pos_end + delim_len;
        res.push_back (token);
    }

    res.push_back (s.substr (pos_start));
    return res;
}

#include <stdarg.h>  // For va_start, etc.

std::string string_format(const std::string fmt, ...) {
    int size = ((int)fmt.size()) * 2 + 50;   // Use a rubric appropriate for your code
    std::string str;
    va_list ap;
    while (1) {     // Maximum two passes on a POSIX system...
        str.resize(size);
        va_start(ap, fmt);
        int n = vsnprintf((char *)str.data(), size, fmt.c_str(), ap);
        va_end(ap);
        if (n > -1 && n < size) {  // Everything worked
            str.resize(n);
            return str;
        }
        if (n > -1)  // Needed size returned
            size = n + 1;   // For null char
        else
            size *= 2;      // Guess at a larger size (OS specific)
    }
    return str;
}

typedef unsigned char u8;
typedef unsigned short u16;

const u8 HexTable[16]={'0','1','2','3','4','5','6','7','8','9','a','b','c','d','e','f'};
const u8* ToHex(u8 a)
{
	return HexTable+a;
}

struct FS_FILE
{
	string _sName;
	vector<u8> _Data;
};

struct FS_PACK
{
	void AddFile(string sFile);
	
	void Out(string sFile);

	vector<FS_FILE *> _aFiles;
};

#define MAX_LENGTH 256

void FS_PACK::AddFile(string sFile)
{
	FILE *f = fopen(("C:\\Git\\TICFS\\" + sFile).c_str(), "r");
	if (f)
	{
		FS_FILE* pFsFile = new FS_FILE;

		char szBuffer[MAX_LENGTH];
		while (!feof(f))
		{
			fgets(szBuffer, MAX_LENGTH, f);
			if (ferror(f))
			{
				fprintf(stderr, "Reading error with code %d\n", errno);
				break;
			}
			string s=szBuffer;
			vector<string> sSplit=split(s, " ");
			if (sSplit.size()>0)
			{
				if (sSplit[0]=="line")
				{
					pFsFile->_Data.push_back('l');
					pFsFile->_Data.push_back((u8)std::stoi(sSplit[1]));
					pFsFile->_Data.push_back((u8)std::stoi(sSplit[2]));
					pFsFile->_Data.push_back((u8)std::stoi(sSplit[3]));
					pFsFile->_Data.push_back((u8)std::stoi(sSplit[4]));
					pFsFile->_Data.push_back((u8)std::stoi(sSplit[5]));
				}

			}

			printf(szBuffer);
		}

		if (pFsFile->_Data.size()!=0)
		{
			pFsFile->_Data.push_back((u8)0);		// add zero at end of file for conveniance
			pFsFile->_sName=sFile;
			_aFiles.push_back(pFsFile);
		}

		fclose(f);
	}
}

void FS_PACK::Out(string sFile)
{
	FILE *f = fopen(("C:\\Git\\TICFS\\" + sFile).c_str(), "w");
	if (f)
	{
		const string sHeader = "-- <MAP>";
		const string sFooter = "\n-- </MAP>\n";
		fwrite(sHeader.c_str(), sHeader.size(), 1, f);

		// FS Format :
		// XX filecount 1 byte
		// for each file
		// >	filename (zero term)
		// >	XX XX filesize 2 bytes (+1 byte '0' terminal)
		// ===> RawStreamStart
		// for each file
		// >	Stream

		vector<u8> aOut;
		aOut.push_back((u8)_aFiles.size());
		for (FS_FILE* pFile:_aFiles)
		{
			for (size_t i=0; i<pFile->_sName.size(); i++)
			{
				aOut.push_back(pFile->_sName[i]);
			}
			aOut.push_back(0);
			u16 filesize16 =(u16)pFile->_Data.size();
			aOut.push_back(u8(filesize16&0xFF));
			aOut.push_back(u8(filesize16>>8));
		}

		for (FS_FILE* pFile:_aFiles)
		{
			for (u8 c:pFile->_Data)
			{
				aOut.push_back(c);
			}
		}

		int iCurrentRow=-1;
		size_t i;
		for (i=0; i<aOut.size(); i++)
		{
			if (i%240==0)
			{
				iCurrentRow++;
				//"-- 001:"
				string sRow=string_format("\n-- %03d:", iCurrentRow);
				fwrite(sRow.c_str(), sRow.size(), 1, f);
			}
//			string sbyte=string_format("%02x", aOut[i]);
			u8 hi=aOut[i]>>4;
			u8 lo=aOut[i]&0x0F;
			fwrite(ToHex(lo), 1, 1, f);
			fwrite(ToHex(hi), 1, 1, f);
		}

		//trailing zeros
		while (i%240!=0)
		{
			fwrite("00", 2, 1, f);
			++i;
		}
		
		fwrite(sFooter.c_str(), sFooter.size(), 1, f);
		fclose(f);
	}
}

int main()
{
	FS_PACK pack;
	pack.AddFile("abc.txt");
	pack.AddFile("test.txt");
	pack.AddFile("scene.txt");

	pack.Out("out.lua");
}
