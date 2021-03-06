unit RSLod;
{ *********************************************************************** }
{ Copyright (c) Sergey Rozhenko                                           }
{ http://sites.google.com/site/sergroj/                                   }
{ sergroj@mail.ru                                                         }
{ *********************************************************************** }
{$I RSPak.inc}

interface

uses
  Windows, Classes, Messages, SysUtils, RSSysUtils, RSQ, Consts, Graphics,
  {ZLib}dzlib, Math, RSDefLod, RSGraphics, RSStrUtils;

type
(*
Lod format:
 <Header> { <DirItem> }   <Data...>
*)
  ERSLodException = class(Exception)
  end;
  ERSLodWrongFileName = class(ERSLodException)
  end; // too long file name
  ERSLodBitmapException = class(ERSLodException)
  end; // error in bitmap palette or dimensions

  TRSLodVersion = (RSLodHeroes, RSLodBitmaps, RSLodIcons, RSLodSprites,
    RSLodGames, RSLodGames7, RSLodChapter, RSLodChapter7, RSLodMM8);

  TRSLodHeroesHeader = packed record
    Signature: array[0..3] of char;
    Version: DWord;
    Count: DWord;
    Unknown: array[0..79] of char;
  end;
  PRSLodHeroesHeader = ^TRSLodHeroesHeader;

  TRSLodMMHeader = packed record
    Signature: array[0..3] of char;
    Version: array[0..79] of char; 
    Description: array[0..79] of char;
    Unk1: int; // 100 (version)
    Unk2: int; // 0
    Unk3: int; // 1 (archives count)
    Unknown: array[0..79] of char;
    LodType: array[0..15] of char;
    ArchiveStart: DWord;
    ArchiveSize: DWord;
    Unk5: int; // 0 (bits)
    Count: uint2;
    Unk6: uint2; // 0 (type of data)
  end;
  PRSLodMMHeader = ^TRSLodMMHeader;


  TRSMMFilesOptions = record
    // Lod Entry properties
    NameSize: int;
    AddrOffset: int;
    SizeOffset: int;
    UnpackedSizeOffset: int;
    PackedSizeOffset: int;
    ItemSize: int;

    // Lod properties
    DataStart: int;
    AddrStart: int;
    MinFileSize: int;
  end;

type
  TRSMMFiles = class;

  TRSMMFilesReadHeaderEvent = procedure(Sender: TRSMMFiles; Stream: TStream;
     var Options: TRSMMFilesOptions; var FilesCount: int) of object;
  TRSMMFilesWriteHeaderEvent = procedure(Sender: TRSMMFiles; Stream: TStream) of object;
  TRSMMFilesProcessEvent = procedure(Sender: TRSMMFiles; FileName: string;
     var Stream: TStream; var Size: int) of object;
  TRSMMFilesGetFileSizeEvent = procedure(Sender: TRSMMFiles; Index: int;
     var Size: int) of object;
  TRSMMFilesFileEvent = procedure(Sender: TRSMMFiles; Index: int) of object;

// !!! Add 'Processing' exceptions for all public members
  TRSMMFiles = class(TObject)
  private
    FOnReadHeader: TRSMMFilesReadHeaderEvent;
    FOnWriteHeader: TRSMMFilesWriteHeaderEvent;
    FOnGetFileSize: TRSMMFilesGetFileSizeEvent;
    FOnBeforeReplaceFile: TRSMMFilesFileEvent;
    FIgnoreUnzipErrors: Boolean;
    procedure SetWriteOnDemand(v: Boolean);
    function GetUserData(i: int): ptr;
    procedure SetUserDataSize(v: int);
    function GetAddress(i: int): int;
    function GetIsPacked(i: int): Boolean;
    function GetName(i: int): PChar;
    function GetSize(i: int): int;
    function GetUnpackedSize(i: int): int;
  protected
    FOptions: TRSMMFilesOptions;

    // Files
    FInFile: string;
    FOutFile: string;
    FWriteStream: TStream;
    FWritesCount: int;
    FBlockStream: TStream;

    // Files properties
    FBlockInFile: Boolean;
    FWriteOnDemand: Boolean;

    // Fields
    FData: TRSByteArray;
    FCount: int;
    FFileSize: int;
    FFileBuffers: array of TMemoryStream;
    FSorted: Boolean;
    FGamesLod: Boolean; // new files must be added to the end of games.lod

    FUserData: TRSByteArray;
    FUserDataSize: int;

    procedure DoDelete(i: int; NoWrite: Boolean = false);
    function GetFileSpace(Index: int): int;
    function CanExpand(Index, aSize: uint): Boolean;
    procedure ReadHeader;
    procedure WriteHeader;
    procedure DoWriteFile(Index:int; Data:TStream; Size:int; Addr:int;
       ForceWrite: Boolean = false);
    procedure DoMoveFile(Index:int; Addr:int);
    function BeginRead: TStream;
    procedure EndRead(Stream: TStream);
    function BeginWrite: TStream;
    procedure EndWrite;
    procedure InsertData(var Data:TRSByteArray; Index, ItemSize:int);
    procedure RemoveData(var Data:TRSByteArray; Index, ItemSize:int);
    procedure CalculateFileSize;
    procedure SaveAsNoBlock(const FileName: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure New(const FileName: string; const Options: TRSMMFilesOptions);
    procedure Load(const FileName: string);
    procedure Save;
    procedure SaveAs(const FileName: string);
    procedure Rebuild;
    procedure Close;
    function CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMFiles;
    procedure MergeTo(Files: TRSMMFiles);

    function Add(const Name: string; Data: TStream; Size: int = -1;
       Compression: TCompressionLevel = clDefault; UnpackedSize: int = -1): int;
    procedure Delete(i:int); overload;
    procedure Delete(const Name: string); overload;
    procedure Delete(const Name: PChar); overload;
    procedure CheckName(const Name: string);
    function FindFile(const Name: string; var Index: int): Boolean; overload;
    function FindFile(const Name: PChar; var Index: int): Boolean; overload;
    function GetAsIsFileStream(Index: int; IgnoreWrite: Boolean = false): TStream;
    procedure FreeAsIsFileStream(Index: int; Stream: TStream);
    procedure RawExtract(i: int; a: TStream);
    procedure ReserveFilesCount(n: int);

    property Name[i: int]: PChar read GetName;
    property Address[i: int]: int read GetAddress;
    property Size[i: int]: int read GetSize;
    property UnpackedSize[i: int]: int read GetUnpackedSize;
    property IsPacked[i: int]: Boolean read GetIsPacked;
    property UserData[i: int]: ptr read GetUserData;
    property Count: int read FCount;
    property ArchiveSize: int read FFileSize;
    property Options: TRSMMFilesOptions read FOptions;
    property UserDataSize: int read FUserDataSize write SetUserDataSize;
    property WriteOnDemand: Boolean read FWriteOnDemand write SetWriteOnDemand;
    property FileName: string read FOutFile;
    property Sorted: Boolean read FSorted;
    property IgnoreUnzipErrors: Boolean read FIgnoreUnzipErrors write FIgnoreUnzipErrors;

    property OnReadHeader: TRSMMFilesReadHeaderEvent read FOnReadHeader write FOnReadHeader;
    property OnWriteHeader: TRSMMFilesWriteHeaderEvent read FOnWriteHeader write FOnWriteHeader;
    property OnGetFileSize: TRSMMFilesGetFileSizeEvent read FOnGetFileSize write FOnGetFileSize;
    property OnBeforeReplaceFile: TRSMMFilesFileEvent read FOnBeforeReplaceFile write FOnBeforeReplaceFile;
  end;

  TRSArchive = class(TObject)
  protected
    function GetCount: int; virtual; abstract;
    function GetFileName(i: int): PChar; virtual; abstract;
  public
    constructor Create; overload; virtual; abstract;
    constructor Create(const FileName: string); overload;
    procedure Load(const FileName: string); virtual; abstract;
    procedure SaveAs(const FileName: string); virtual; abstract;

    property Count: int read GetCount;
    property Names[i: int]: PChar read GetFileName;
  end;


  TRSMMArchive = class(TRSArchive)
  private
    FBackupOnAdd: Boolean;
    FBackupOnAddOverwrite: Boolean;
    procedure BeforeReplaceFile(Sender: TRSMMFiles; Index: int);
  protected
    FFiles: TRSMMFiles;
    FTagSize: int;

    constructor CreateInternal(Files: TRSMMFiles); virtual;

    function GetCount: int; override;
    function GetFileName(i: int): PChar; override;
    procedure ReadHeader(Sender: TRSMMFiles; Stream: TStream;
       var Options: TRSMMFilesOptions; var FilesCount: int); virtual; abstract;
    procedure WriteHeader(Sender: TRSMMFiles; Stream: TStream); virtual; abstract;
    function DoExtract(Index: int; const FileName: string; Overwrite: Boolean = true): string;
    function MakeBackupDir: string;
    procedure DoBackupFile(Index: int; Overwrite:Boolean); virtual;
  public
    constructor Create; override;
    destructor Destroy; override;

    function Add(const Name: string; Data: TStream; Size: int = -1; pal: int = 0): int; overload; virtual;
    function Add(const Name: string; Data: TRSByteArray; pal: int = 0): int; overload; // virtual;
    function Add(const FileName: string; pal: int = 0): int; overload; // virtual;
    function Extract(Index: int; const Dir: string; Overwrite: Boolean = true): string; overload; virtual;
    function Extract(Index: int; Output: TStream): string; overload; virtual;
    function Extract(Index: int): TObject; overload; virtual;
    function ExtractArrayOrBmp(Index: int; var Arr: TRSByteArray): TBitmap; virtual;
    function ExtractArray(Index: int): TRSByteArray;
    function ExtractString(Index: int): string;
    function GetExtractName(Index: int): string; virtual;
    function BackupFile(Index: int; Overwrite:Boolean): Boolean;
    function CloneForProcessing(const NewFile: string; FilesCount: int = 0): TRSMMArchive; virtual;
    procedure Load(const FileName: string); override;
    procedure SaveAs(const FileName: string); override;

    property RawFiles: TRSMMFiles read FFiles;
    property BackupOnAdd: Boolean read FBackupOnAdd write FBackupOnAdd;
    property BackupOnAddOverwrite: Boolean read FBackupOnAddOverwrite write FBackupOnAddOverwrite;
  end;


  TRSLodBase = class(TRSMMArchive)
  private
    FAnyHeader: array[0..SizeOf(TRSLodMMHeader)-1] of byte;
  protected
    FMMHeader: PRSLodMMHeader;
    FHeroesHeader: PRSLodHeroesHeader;
    FAdditionalData: TRSByteArray;
    FVersion: TRSLodVersion;

    constructor CreateInternal(Files: TRSMMFiles); override;
    procedure InitOptions(var Options: TRSMMFilesOptions);
    procedure ReadHeader(Sender: TRSMMFiles; Stream: TStream;
       var Options: TRSMMFilesOptions; var FilesCount: int); override;
    procedure WriteHeader(Sender: TRSMMFiles; Stream: TStream); override;
  public
    function GetExtractName(Index: int): string; override;
    function CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive; override;
    procedure New(const FileName: string; AVersion: TRSLodVersion);
    procedure Load(const FileName: string); override;

    property Version: TRSLodVersion read FVersion write FVersion;  // !!! setting it may be dangerous
  end;


  TRSLod = class;

  TRSLodSpritePaletteEvent = procedure(Sender: TRSLod; Name: string; var pal: int2; var Data) of object;
  TRSLodNeedPaletteEvent = procedure(Sender: TRSLod; Bitmap: TBitmap; var Palette: int) of object;

  TRSLod = class(TRSLodBase)
  private
    FBitmapsLod: TRSLod;
    FOwnBitmapsLod: Boolean;
    FOnNeedBitmapsLod: TNotifyEvent;
    FOnNeedPalette: TRSLodNeedPaletteEvent;
    FOnSpritePalette: TRSLodSpritePaletteEvent;
    FLastPalette: int;
  protected
    function GetIntAt(i: int; o: int): int;
    procedure PackSprite(b: TBitmap; m: TMemoryStream; pal: int);
    procedure PackBitmap(b: TBitmap; m: TMemoryStream; pal, ABits: int; Keep: Boolean);
    procedure PackStr(m: TMemoryStream; Data: TStream; Size: int); // STR converted by mm8leveleditor
    function PackPcx(b: TBitmap; m: TMemoryStream; KeepBmp: Boolean): int;
    procedure Zip(output:TMemoryStream; buf:TStream; size: int; pk, unp: int); overload;
    procedure Zip(output:TMemoryStream; buf:TStream; size: int;
       DataSize, UnpackedSize: ptr); overload;

    procedure Unzip(input, output: TStream; size, unp: int; noless: Boolean);
    procedure UnpackPcx(data: TMemoryStream; b: TBitmap);
    procedure UnpackBitmap(data: TStream; b: TBitmap; const FileHeader);
    procedure UnpackSprite(const name: string; data: TStream; b: TBitmap; size: int);
    procedure UnpackStr(a, Output:TStream; const FileHeader);

    function AddBitmap(const Name: string; b: TBitmap; pal: int; Keep: Boolean;
      Bits: int = -1): int;
    function DoExtract(i: int; Output: TStream = nil; Arr: PRSByteArray = nil;
      FileName: PStr = nil; CheckNameKind: int = 0):TObject; overload;
    procedure DoBackupFile(Index: int; Overwrite: Boolean); override;
  public
    destructor Destroy; override;
    function Add(const Name: string; Data: TStream; Size: int = -1; pal: int = 0): int; override;
    function Add(const Name: string; b: TBitmap; pal: int = 0): int; overload;
    function Extract(Index: int; const Dir: string; Overwrite: Boolean = true): string; override;
    function Extract(Index: int; Output: TStream): string; override;
    function Extract(Index: int): TObject; override;
    function ExtractArrayOrBmp(Index: int; var Arr: TRSByteArray): TBitmap; override;
    function GetExtractName(Index: int): string; override;
    function CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive; override;
    function FindSamePalette(const PalEntries; var pal: int): Boolean;

    property BitmapsLod: TRSLod read FBitmapsLod write FBitmapsLod;
    property LastPalette: int read FLastPalette;
    property OwnBitmapsLod: Boolean read FOwnBitmapsLod write FOwnBitmapsLod;
    property OnNeedBitmapsLod: TNotifyEvent read FOnNeedBitmapsLod write FOnNeedBitmapsLod;
    property OnNeedPalette: TRSLodNeedPaletteEvent read FOnNeedPalette write FOnNeedPalette;
    property OnSpritePalette: TRSLodSpritePaletteEvent read FOnSpritePalette write FOnSpritePalette;
  end;


  TRSSnd = class(TRSMMArchive)
  protected
    FMM: Boolean;

    procedure InitOptions(var Options: TRSMMFilesOptions);
    procedure ReadHeader(Sender: TRSMMFiles; Stream: TStream;
       var Options: TRSMMFilesOptions; var FilesCount: int); override;
    procedure WriteHeader(Sender: TRSMMFiles; Stream: TStream); override;
  public
    procedure New(const FileName: string; MightAndMagic: Boolean);
    function Add(const Name: string; Data: TStream; Size: int = -1; pal: int = 0): int; override;
    function GetExtractName(Index: int): string; override;
    function CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive; override;
  end;


  TRSVid = class(TRSMMArchive)
  protected
    FNoExtension: Boolean;

    constructor CreateInternal(Files: TRSMMFiles); override;

    function DoGetFileSize(Stream: TStream; sz: uint): uint;

    procedure InitOptions(var Options: TRSMMFilesOptions);
    procedure ReadHeader(Sender: TRSMMFiles; Stream: TStream;
       var Options: TRSMMFilesOptions; var FilesCount: int); override;
    procedure WriteHeader(Sender: TRSMMFiles; Stream: TStream); override;
    procedure GetFileSize(Sender: TRSMMFiles; Index: int; var Size: int);
  public
    procedure New(const FileName: string; NoExtension: Boolean);
    function Add(const Name: string; Data: TStream; Size: int = -1; pal: int = 0): int; override;
    function GetExtractName(Index: int): string; override;
    function CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive; override;
    procedure Load(const FileName: string); override;
  end;


procedure RSMMFilesOptionsInitialize(var Options: TRSMMFilesOptions);
function RSLoadMMArchive(const FileName: string): TRSMMArchive;

// _stricmp comparsion. AnsiCompareText returns a different result.
function RSLodCompareStr(s1, s2: PChar): int; overload;
function RSLodCompareStr(s1, s2: PChar; var SameCount: int): int; overload;

resourcestring
  SRSLodCorrupt = 'File invalid or corrupt';
  SRSLodLongName = 'File name (%s) length exceeds %d symbols';
  SRSLodUnknown = 'Unknown LOD version';
  SRSLodUnknownSnd = 'Unknown SND format';
  SRSLodSpriteMustPal = 'Palette index for sprite must be specified';
  SRSLodSpriteMust256 = 'Sprites must be in 256 colors format';
  SRSLodNoBitmaps = 'This LOD type doesn''t support bitmaps';
  SRSLodSpriteMustBmp = 'Cannot add files other than bitmap into sprites.lod';
  SRSLodActPalMust768 = 'ACT palette size must be 768 bytes';
  SRSLodSpriteExtractNeedLods = 'BitmapsLod and TextsLod must be specified to extract images from sprites.lod';
  SRSLodPalNotFound = 'File "PAL%.3d" referred to by sprite "%s" not found in BitmapsLod';
  SRSLodMustPowerOf2 = 'Bitmap %s must be a power of 2 and can''t be less than 4';

implementation

uses Types;

const
  HeroesId=#$C8; MM6Id='MMVI'; MM8Id='MMVIII';

const
  SReadFailed = 'Failed to read %d bytes at offset %d';

type
  TMyReadStream = class(TMemoryStream)
  protected
    FPtr: pptr;
    function Realloc(var NewCapacity: Longint): Pointer; override;
  public
    constructor Create(var p: ptr);
    destructor Destroy; override;
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

{ TMyReadStream }

constructor TMyReadStream.Create(var p: ptr);
begin
  FPtr:= @p;
end;

destructor TMyReadStream.Destroy;
var
  p: pint;
begin
  p:= FPtr^;
  if (p <> nil) and (InterlockedDecrement(p^) = 0) then
  begin
    FPtr^:= nil;
    FreeMem(p, Capacity + sizeof(int));
  end;
  FPtr:= nil;
  SetPointer(nil, 0);
  inherited;
end;

function TMyReadStream.Realloc(var NewCapacity: Integer): Pointer;
var
  p: pint;
begin
  Assert(Memory = nil, 'Attempt to set size of read-only stream');
  Result:= nil;
  if FPtr <> nil then
  begin
    p:= AllocMem(NewCapacity + sizeof(int));
    FPtr^:= p;
    p^:= 1;
    inc(p);
    Result:= p;
  end;
end;

function TMyReadStream.Write(const Buffer; Count: Integer): Longint;
begin
  Assert(false, 'Attempt to write to read-only stream');
  Result:= 0;
end;




function RSLodCompareStr(s1, s2: PChar): int; overload;
var
  a,b:int;
begin
  while true do
  begin
    a:= ord(s1^);
    if a in [ord('A')..ord('Z')] then
      inc(a, ord('a') - ord('A'));
    b:= ord(s2^);
    if b in [ord('A')..ord('Z')] then
      inc(b, ord('a') - ord('A'));
    Result:= a - b;
    if (Result <> 0) or (a = 0) or (b = 0) then
      exit;

    inc(s1);
    inc(s2);
  end;
end;

function RSLodCompareStr(s1, s2: PChar; var SameCount: int): int; overload;
var
  a,b:int; baseS1: PChar;
begin
  baseS1:= s1;
  while true do
  begin
    a:= ord(s1^);
    if a in [ord('A')..ord('Z')] then
      inc(a, ord('a') - ord('A'));
    b:= ord(s2^);
    if b in [ord('A')..ord('Z')] then
      inc(b, ord('a') - ord('A'));
    Result:= a - b;
    if (Result <> 0) or (a = 0) or (b = 0) then
    begin
      SameCount:= s1 - baseS1;
      exit;
    end;
    inc(s1);
    inc(s2);
  end;
end;

procedure UnzipIgnoreErrors(output, input: TStream; unp: uint; noless: Boolean);
var
  c: TDecompressionStream;
  oldPos, oldPosI: int64;
  i, ReadOk, oldSize: uint;
begin
  oldPos:= output.Position;
  oldPosI:= input.Position;
  oldSize:= uint(-1);
  c:= TDecompressionStream.Create(input);
  try
    if output is TMemoryStream then
    begin
      oldSize:= uint(output.Size);
      i:= uint(oldPos) + unp;
      if oldSize < i then
        TMemoryStream(output).SetSize(i)
      else
        oldSize:= uint(-1);
    end;
    try
      output.CopyFrom(c, unp);
    except
      FreeAndNil(c);
      input.Position:= oldPosI;
      c:= TDecompressionStream.Create(input);
      try
        ReadOk:= uint(output.Position - oldPos);
        if ReadOk <> 0 then
          c.Seek(ReadOk, soFromBeginning);
        for i := 1 to unp - ReadOk do
          output.CopyFrom(c, 1);
      except
      end;
      if noless then
      begin
        ReadOk:= uint(output.Position - oldPos);
        oldPos:= 0;
        for i := 1 to unp - ReadOk do
          output.WriteBuffer(oldPos, 1);
      end else
        if oldSize <> uint(-1) then
          output.Size:= max(oldSize, output.Position);
    end;
  finally
    c.Free;
  end;
end;


{ TRSMMFiles }

procedure MyReadBuffer(a: TStream; var data; size: int);
begin
  if a is TMemoryStream then
    a.ReadBuffer(data, size) // don't mistake it for the lod file
  else
    Assert(a.Read(data, size) = size, Format(SReadFailed, [size, a.Position]));
end;

function TRSMMFiles.Add(const Name: string; Data: TStream; Size: int = -1;
   Compression: TCompressionLevel = clDefault; UnpackedSize: int = -1): int;
var
  NewData, fs, Compr: TStream;
  Found: Boolean;
  i, addr, UnpSize, PkSize: int;
begin
  if Size < 0 then
    Size:= Data.Size - Data.Position;
  UnpSize:= Size;
  PkSize:= 0;
  NewData:= nil;
  fs:= nil;
  with FOptions do
    try
      // Pack file
      if UnpackedSize >= 0 then // Already packed
      begin
        UnpSize:= UnpackedSize;
        PkSize:= Size;
      end else
        if (Compression <> clNone) and (Data.Size > 256) and
           ((PackedSizeOffset >= 0) or (UnpackedSizeOffset >= 0)) then
        begin
          NewData:= TMemoryStream.Create;
          Compr:= TCompressionStream.Create(Compression, NewData);
          try
            RSCopyStream(Compr, Data, UnpSize);
          finally
            Compr.Free;
          end;
          if NewData.Size < Size then
          begin
            Data:= NewData;
            Data.Seek(0, 0);
            Size:= Data.Size;
            PkSize:= Size;
          end else
            Data.Seek(-UnpSize, soCurrent);
        end;

      Found:= FindFile(Name, Result);
      if Found and Assigned(OnBeforeReplaceFile) then
        OnBeforeReplaceFile(self, Result);

      BeginWrite;
      try
        if Found then  // Replace existing
        begin
          if CanExpand(Result, Size) then
            DoWriteFile(Result, Data, Size, Address[Result])
          else
            DoWriteFile(Result, Data, Size, FFileSize);
          // !!! update data
          FillChar(FUserData[Result*FUserDataSize], FUserDataSize, 0);
        end else                        // Add new
        begin
          if FGamesLod then
            Result:= FCount;
          addr:= DataStart + (FCount + 1)*ItemSize;
          //if uint(addr) > uint(FOptions.MinFileSize) then
            for i := 0 to FCount - 1 do
              if uint(Address[i]) < uint(addr) then
                if FCount = 1 then
                  DoMoveFile(i, addr)
                else
                  DoMoveFile(i, FFileSize);

          inc(FCount);
          InsertData(FData, Result, ItemSize);
          InsertData(FUserData, Result, FUserDataSize);
          SetLength(FFileBuffers, FCount);
          ArrayInsert(FFileBuffers, Result, sizeof(ptr));
          FFileSize:= max(FFileSize, FOptions.DataStart + length(FData));
          DoWriteFile(Result, Data, Size, FFileSize);
        end;
        i:= Result;

        
        // Write file name
        FillChar(FData[i*ItemSize], 0, NameSize);
        if Name <> '' then
          Move(Name[1], FData[i*ItemSize], length(Name));
        // Write file size
        if SizeOffset >= 0 then
          pint(@FData[i*ItemSize + SizeOffset])^:= Size;
        if UnpackedSizeOffset >= 0 then
          pint(@FData[i*ItemSize + UnpackedSizeOffset])^:= UnpSize;
        if PackedSizeOffset >= 0 then
          pint(@FData[i*ItemSize + PackedSizeOffset])^:= PkSize;

        if not FWriteOnDemand then
          WriteHeader;
      finally
        EndWrite;
      end;

    finally
      NewData.Free;
      fs.Free;
    end;
end;

function TRSMMFiles.BeginRead: TStream;
var h: HFILE;
begin
  if (FWriteStream = nil) or not SameText(FInFile, FOutFile) then
  begin
    h:= RSCreateFile(FInFile, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING);
    if h = INVALID_HANDLE_VALUE then  RSRaiseLastOSError;
    Result:= TFileStream.Create(h);
  end else
    Result:= BeginWrite;
end;

function TRSMMFiles.BeginWrite: TStream;
var h: HFILE;
begin
  Result:= FWriteStream;
  if Result = nil then
  begin
    if (FBlockStream <> nil) and SameText(FInFile, FOutFile) then
      FreeAndNil(FBlockStream);

    h:= RSCreateFile(FOutFile, GENERIC_READ or GENERIC_WRITE, FILE_SHARE_READ, nil, OPEN_ALWAYS); //OPEN_EXISTING);
    if h = INVALID_HANDLE_VALUE then  RSRaiseLastOSError;
    Result:= TFileStream.Create(h);
    FWriteStream:= Result;
  end;
  Result.Seek(0, 0);
  inc(FWritesCount);
end;

procedure TRSMMFiles.CalculateFileSize;
var i, sz:int;
begin
  sz:= max(FOptions.DataStart, FOptions.MinFileSize);
  for i := 0 to Count - 1 do
    sz:= max(sz, Address[i] + Size[i]);
  FFileSize:= sz;  
end;

function TRSMMFiles.CanExpand(Index, aSize: uint): Boolean;
var addr, sz, i, j: uint;
begin
  addr:= uint(Address[Index]);
  sz:= uint(Size[Index]);
  Result:= (aSize <= sz) or (addr + sz >= uint(FFileSize));
  if Result then  exit;

  j:= uint(Address[Index + 1]) - addr;
  Result:= (j >= aSize);
  if not Result then  exit;

  for i := 0 to Count - 1 do
  begin
    j:= uint(Address[i]) - addr;
    Result:= (j >= aSize);
    if not Result then  exit;
  end;
end;

procedure TRSMMFiles.CheckName(const Name: string);
begin
  if length(Name) >= FOptions.NameSize then
    raise ERSLodWrongFileName.CreateFmt(SRSLodLongName, [Name, FOptions.NameSize]);
end;

function TRSMMFiles.CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMFiles;
begin
  Result:= TRSMMFiles.Create;
  with Result do
  begin
    FOptions:= self.FOptions;
    FInFile:= NewFile;
    FOutFile:= NewFile;
    FUserDataSize:= self.FUserDataSize;
    FFileSize:= max(FOptions.DataStart + FilesCount*FOptions.ItemSize, FOptions.MinFileSize); // !!! wrong?
    FGamesLod:= self.FGamesLod;
    FSorted:= self.FSorted;
  end;
end;

procedure TRSMMFiles.Close;
var i:int;
begin
  for i := 0 to length(FFileBuffers) - 1 do
    FFileBuffers[i].Free;
  FFileBuffers:= nil;
  FreeAndNil(FBlockStream);
  FCount:= 0;
  RSMMFilesOptionsInitialize(FOptions);
  FData:= nil;
  FInFile:= '';
  FOutFile:= '';
  FSorted:= true;
  // !!! Finalize UserData
  FUserData:= nil;
end;

constructor TRSMMFiles.Create;
begin
  RSMMFilesOptionsInitialize(FOptions);
end;

procedure TRSMMFiles.Delete(i: int);
begin
  DoDelete(i);
end;

procedure TRSMMFiles.Delete(const Name: string);
var i:int;
begin
  if FindFile(ptr(Name), i) then
    Delete(i);
end;

procedure TRSMMFiles.Delete(const Name: PChar);
var i:int;
begin
  if FindFile(Name, i) then
    Delete(i);
end;

destructor TRSMMFiles.Destroy;
begin
  Close;
  inherited;
end;

procedure TRSMMFiles.DoDelete(i: int; NoWrite: Boolean = false);
begin
  dec(FCount);
  RemoveData(FData, i, FOptions.ItemSize);
  // !!! Finalize UserData
  RemoveData(FUserData, i, FUserDataSize);
  if length(FFileBuffers) > i then
  begin
    FFileBuffers[i].Free;
    ArrayDelete(FFileBuffers, i, sizeof(ptr));
    SetLength(FFileBuffers, length(FFileBuffers) - 1);
  end;
  if not FWriteOnDemand then
    WriteHeader;
end;

procedure TRSMMFiles.DoMoveFile(Index, Addr: int);
var
  r:TStream;
begin
  if (length(FFileBuffers) > Index) and (FFileBuffers[Index] <> nil) then
  begin
    FFileBuffers[Index].Seek(0, 0);
    DoWriteFile(Index, FFileBuffers[Index], FFileBuffers[Index].Size, Addr);
    exit;
  end;

  r:= GetAsIsFileStream(Index);
  try
    DoWriteFile(Index, r, Size[Index], Addr);
  finally
    FreeAsIsFileStream(Index, r);
  end;
end;

procedure TRSMMFiles.DoWriteFile(Index: int; Data: TStream; Size, Addr: int;
   ForceWrite: Boolean = false);
var
  w: TStream;
begin
  if FWriteOnDemand and not ForceWrite then
  begin
    if Index >= length(FFileBuffers) then
      SetLength(FFileBuffers, Index + 1);
    if Data <> FFileBuffers[Index] then
    begin
      FFileBuffers[Index].Free;
      FFileBuffers[Index]:= TMemoryStream.Create;
      FFileBuffers[Index].SetSize(Size);
      MyReadBuffer(Data, FFileBuffers[Index].Memory^, Size);
    end;
  end else
  begin
    w:= BeginWrite;
    try
      w.Seek(Addr, 0);
      Assert(Data.Size - Data.Position >= Size, Format(SReadFailed, [Size, Data.Position]));
      RSCopyStream(w, Data, Size);
    finally
      EndWrite;
    end;
  end;

  with FOptions do
    pint(@FData[Index*ItemSize + AddrOffset])^:= Addr - AddrStart;
  inc(Addr, Size);
  if Addr > FFileSize then
    FFileSize:= Addr;
end;

procedure TRSMMFiles.EndRead(Stream: TStream);
begin
  if Stream <> nil then
    if Stream = FWriteStream then
      EndWrite
    else
      if Stream <> FBlockStream then
        Stream.Free;
end;

procedure TRSMMFiles.EndWrite;
var i:int;
begin
  i:= FWritesCount - 1;
  Assert(i >= 0);
  FWritesCount:= i;
  if i = 0 then  FreeAndNil(FWriteStream);
  if FBlockInFile and SameText(FInFile, FOutFile) and (FBlockStream = nil) then
    FBlockStream:= BeginRead;
end;

function TRSMMFiles.FindFile(const Name: PChar; var Index: int): Boolean;
var
  L, H, i, C, same, bestSame: int;
begin
  if not FSorted then
  begin
    bestSame:= 0;
    L:= 0;
    H:= 1; // best C
    for i := 0 to FCount - 1 do
    begin
      C:= RSLodCompareStr(Name, self.Name[i], same);
      if C = 0 then
      begin
        Index:= i;
        Result:= true;
        exit;
      end else
        if (same > bestSame) or (same = bestSame) and (H > 0) then
        begin
          L:= i;
          if C > 0 then
            inc(L);
          bestSame:= same;
          H:= C;
        end;
    end;

  end else
  begin
    L:= 0;
    H:= FCount - 1;
    while L <= H do
    begin
      i:= (L + H) shr 1;

      C:= RSLodCompareStr(Name, self.Name[i]);
      if C <= 0 then
      begin
        if C = 0 then
        begin
          Index:= i;
          Result:= True;
          exit;
        end;
        H:= i - 1;
      end else
        L:= i + 1;
    end;
  end;
  Index:= L;
  Result:= false;
end;

function TRSMMFiles.FindFile(const Name: string; var Index: int): Boolean;
begin
  Result:= FindFile(ptr(Name), Index);
end;

procedure TRSMMFiles.FreeAsIsFileStream(Index: int; Stream: TStream);
begin
  if (Index >= length(FFileBuffers)) or (FFileBuffers[Index] <> Stream) then
    EndRead(Stream);
end;

function TRSMMFiles.GetAddress(i: int): int;
begin
  with FOptions do
    if i < Count then
      Result:= pint(@FData[i*ItemSize + AddrOffset])^ + AddrStart
    else
      Result:= FFileSize;
end;

function TRSMMFiles.GetFileSpace(Index: int): int;
var addr, i, j: int;
begin
  Result:= MaxInt;
  addr:= Address[Index];
  j:= Address[Index + 1] - addr;
  if j > 0 then  Result:= j;

  for i := 0 to Count - 1 do
  begin
    j:= Address[i] - addr;
    if (j > 0) and (j < Result) then  Result:= j;
  end;
end;

function TRSMMFiles.GetAsIsFileStream(Index: int; IgnoreWrite: Boolean = false): TStream;
begin
  if (Index < length(FFileBuffers)) and (FFileBuffers[Index] <> nil) then
  begin
    Result:= FFileBuffers[Index];
    Result.Seek(0, 0);
    exit;
  end;

  Result:= BeginRead;
  Result.Seek(Address[Index], 0);
  if (Result = FWriteStream) and not IgnoreWrite then
  begin
    Result:= TMemoryStream.Create;
    with TMemoryStream(Result) do
    begin
      SetSize(self.Size[Index]);
      MyReadBuffer(FWriteStream, Memory^, Size);
      Seek(0, 0);
    end;
    EndWrite;
  end;
end;

function TRSMMFiles.GetIsPacked(i: int): Boolean;
begin
  with FOptions do
    if PackedSizeOffset >= 0 then
      Result:= (pint(@FData[i*ItemSize + PackedSizeOffset])^ <> 0)
    else
      if (SizeOffset >= 0) and (UnpackedSizeOffset >= 0) then
        Result:= (pint(@FData[i*ItemSize + SizeOffset])^ <>
                    pint(@FData[i*ItemSize + UnpackedSizeOffset])^)
      else
        Result:= false;
end;

function TRSMMFiles.GetName(i: int): PChar;
begin
  Result:= @FData[i*FOptions.ItemSize];
end;

function TRSMMFiles.GetSize(i: int): int;
begin
  if (i < length(FFileBuffers)) and (FFileBuffers[i] <> nil) then
  begin
    Result:= FFileBuffers[i].Size;
    exit;
  end;

  Result:= 0;
  with FOptions do
    if SizeOffset < 0 then
    begin
      if (Result = 0) and (PackedSizeOffset >= 0) then
        Result:= pint(@FData[i*ItemSize + PackedSizeOffset])^;
      if (Result = 0) and (UnpackedSizeOffset >= 0) then
        Result:= pint(@FData[i*ItemSize + UnpackedSizeOffset])^;
    end else
      Result:= pint(@FData[i*ItemSize + SizeOffset])^;

  if Assigned(OnGetFileSize) then
    OnGetFileSize(self, i, Result);
end;

function TRSMMFiles.GetUnpackedSize(i: int): int;
begin
  if FOptions.UnpackedSizeOffset < 0 then
  begin
    Assert(FOptions.PackedSizeOffset < 0); // !!! ??
    Result:= GetSize(i);
  end else
    Result:= pint(@FData[i*FOptions.ItemSize + FOptions.UnpackedSizeOffset])^;
end;

function TRSMMFiles.GetUserData(i: int): ptr;
begin
  Result:= @FUserData[i*FUserDataSize];
end;

procedure TRSMMFiles.InsertData(var Data: TRSByteArray; Index, ItemSize: int);
var i,j: int;
begin
  SetLength(Data, length(Data) + ItemSize);
  i:= Index*ItemSize;
  j:= i + ItemSize;
  Move(Data[i], Data[j], length(Data) - j);
  FillChar(Data[i], ItemSize, 0);
end;

procedure TRSMMFiles.Load(const FileName: string);
begin
  Close;
  FInFile:= FileName;
  FOutFile:= FileName;
  ReadHeader;
end;

procedure TRSMMFiles.MergeTo(Files: TRSMMFiles);
var
  r: TStream;
  i: int;
begin
  Files.BeginWrite;
  try
    for i := 0 to Count - 1 do
    begin
      r:= GetAsIsFileStream(i);
      try
        if IsPacked[i] then
          Files.Add(Name[i], r, Size[i], clNone, UnpackedSize[i])
        else
          Files.Add(Name[i], r, Size[i], clNone);
      finally
        FreeAsIsFileStream(i, r);
      end;
    end;
  finally
    Files.EndWrite;
  end;
end;

procedure TRSMMFiles.New(const FileName: string;
  const Options: TRSMMFilesOptions);
begin
  Close;
  FOptions:= Options;
  FInFile:= FileName;
  FOutFile:= FileName;
  FFileSize:= max(FOptions.DataStart, FOptions.MinFileSize);
  Save;
end;

(*
procedure TRSMMFiles.Process(OutputFile: string;
   ProcessProc: TRSMMFilesProcessEvent);
var
  i, sz: int;
  r, Stream: TStream;
begin
  FOutFile:= OutputFile;
  try
    BeginWrite;
  except
    FOutFile:= FInFile;
    raise;
  end;
  FProcessing:= true;
  try
    i:= 0;
    while i < FCount do
    begin
      r:= BeginRead;
      Stream:= r;
      sz:= Size[i];
      try
        ProcessProc(self, Name[i], Stream, sz);
        if Stream = nil then
        begin
          DoDelete(i);
        end else
        begin
          DoWriteFile(i, Stream, sz);
          inc(i);
        end;

      finally
        EndRead(r);
        if Stream<>r then
          Stream.Free;
      end;
    end;
    FInFile:= OutputFile;
  finally
    FProcessing:= false;
    EndWrite;
    FOutFile:= FInFile;
  end;
end;
*)

procedure TRSMMFiles.RawExtract(i: int; a: TStream);
var
  b, c: TStream;
begin
  b:= GetAsIsFileStream(i, true);
  c:= nil;
  try
    if IsPacked[i] then
      if not IgnoreUnzipErrors then
      begin
        c:= TDecompressionStream.Create(b);
        RSCopyStream(a, c, UnpackedSize[i]);
      end else
        UnzipIgnoreErrors(a, b, UnpackedSize[i], true)
    else
      RSCopyStream(a, b, Size[i]);
  finally
    c.Free;
    FreeAsIsFileStream(i, b);
  end;
end;

procedure TRSMMFiles.ReadHeader;
var
  r: TStream;
  i: int;
begin
  r:= BeginRead;
  if FBlockInFile then
    FBlockStream:= r;

  with r do
    try
      OnReadHeader(self, r, FOptions, FCount);

      SetLength(FData, FCount*FOptions.ItemSize);
      SetLength(FUserData, FCount*FUserDataSize);
      if FCount = 0 then  exit;
      Seek(FOptions.DataStart, 0);
      MyReadBuffer(r, FData[0], length(FData));
    finally
      EndRead(r);
    end;

  CalculateFileSize;
  FSorted:= false;
  for i := 0 to Count - 2 do
    if RSLodCompareStr(Name[i], Name[i+1]) > 0 then
      exit;
  FSorted:= true;
end;

procedure TRSMMFiles.Rebuild;
var
  name, s: string;
begin
  name:= FOutFile;
  s:= name + '.tmp';
  while FileExists(s) do
    s:= name + '.' + IntToHex(Random($1000), 3);
  try
    SaveAsNoBlock(s);
    RSWin32Check(RSMoveFile(s, name, false));
  finally
    if FileExists(name) then
      DeleteFile(s)
    else
      name:= s;
    FOutFile:= name;
    FInFile:= name;
  end;
  if FBlockInFile then
    FBlockStream:= BeginRead;
end;

procedure TRSMMFiles.RemoveData(var Data: TRSByteArray; Index, ItemSize: int);
var i,j: int;
begin
  i:= Index*ItemSize;
  j:= i + ItemSize;
  Move(Data[j], Data[i], length(Data) - j);
  SetLength(Data, length(Data) - ItemSize);
end;

procedure TRSMMFiles.ReserveFilesCount(n: int);
begin
  FFileSize:= max(FFileSize, FOptions.DataStart + n*FOptions.ItemSize);
end;

procedure TRSMMFiles.Save;
var i:int;
begin
  if length(FFileBuffers) = 0 then
    exit;
    
  BeginWrite;
  try
    for i := 0 to length(FFileBuffers) - 1 do
      if FFileBuffers[i] <> nil then
      begin
        FFileBuffers[i].Seek(0, 0);
        DoWriteFile(i, FFileBuffers[i], FFileBuffers[i].Size, Address[i], true);
        FreeAndNil(FFileBuffers[i]);
      end;
    FFileBuffers:= nil;  
    WriteHeader;
  finally
    EndWrite;
  end;
end;

procedure TRSMMFiles.SaveAs(const FileName:string);
begin
  SaveAsNoBlock(FileName);
  if FBlockInFile then
    FBlockStream:= BeginRead;
end;

procedure TRSMMFiles.SaveAsNoBlock(const FileName: string);
var
  i, oldSize: int;
  f: TStream;
  ok: Boolean;
  oldData: TRSByteArray;
begin
  FOutFile:= FileName;
  oldSize:= FFileSize;
  FFileSize:= max(FOptions.MinFileSize, FOptions.DataStart + length(FData));
  SetLength(oldData, length(FData));
  Move(FData[0], oldData[0], length(FData));
  DeleteFile(FileName);
  BeginWrite;
  ok:= false;
  try
    for i := 0 to FCount - 1 do
    begin
      f:= GetAsIsFileStream(i);
      Assert(f.Size - f.Position >= Size[i], Format('Failed to read %d bytes at offset %d (file %d address %d)', [Size[i], f.Position, i, Address[i]]));
      try
        DoWriteFile(i, f, Size[i], FFileSize, true);
      finally
        FreeAsIsFileStream(i, f);
      end;
    end;
    ok:= true;
    WriteHeader;
  finally
    EndWrite;
    if not ok then
    begin
      FData:= oldData;
      FFileSize:= oldSize;
    end;
  end;

  for i := 0 to length(FFileBuffers) - 1 do
    FreeAndNil(FFileBuffers[i]);
  FreeAndNil(FBlockStream);
  FInFile:= FOutFile;
end;

procedure TRSMMFiles.SetUserDataSize(v: int);
begin
  if v = FUserDataSize then  exit;
  
  FUserData:= nil;
  FUserDataSize:= v;
  SetLength(FUserData, FUserDataSize*FCount);
end;

procedure TRSMMFiles.SetWriteOnDemand(v: Boolean);
begin
  if FWriteOnDemand = v then  exit;

  if not v then
    Save;
  FWriteOnDemand:= v;
end;

procedure TRSMMFiles.WriteHeader;
var
  w: TStream;
begin
  w:= BeginWrite;
  with w do
    try
      OnWriteHeader(self, w);

      if FCount = 0 then  exit;
      Seek(FOptions.DataStart, 0);
      WriteBuffer(FData[0], length(FData));
    finally
      EndWrite;
    end;
end;

{ TRSArchive }

constructor TRSArchive.Create(const FileName: string);
begin
  Create;
  Load(FileName);
end;

{ TRSMMArchive }

function TRSMMArchive.Add(const Name: string; Data: TStream;
  Size: int = -1; pal: int = 0): int;
begin
  Result:= FFiles.Add(Name, Data, Size, clNone);
end;

function TRSMMArchive.Add(const Name: string; Data: TRSByteArray;
  pal: int = 0): int;
var
  a: TStream;
begin
  a:= TRSArrayStream.Create(Data);
  try
    Result:= Add(Name, a, -1, pal);
  finally
    a.Free;
  end;
end;

function TRSMMArchive.Add(const FileName: string; pal: int = 0): int;
var
  a: TStream;
begin
  a:= TFileStream.Create(FileName, fmOpenRead);
  try
    Result:= Add(ExtractFileName(FileName), a, -1, pal);
  finally
    a.Free;
  end;
end;

function TRSMMArchive.BackupFile(Index: int; Overwrite: Boolean): Boolean;
var
  old: Boolean;
begin
  old:= FFiles.IgnoreUnzipErrors;
  FFiles.IgnoreUnzipErrors:= true;
  try
    DoBackupFile(Index, Overwrite);
    Result:= true;
  except
    Result:= false;
  end;
  FFiles.IgnoreUnzipErrors:= old;
end;

procedure TRSMMArchive.BeforeReplaceFile(Sender: TRSMMFiles; Index: int);
begin
  if FBackupOnAdd then
    BackupFile(Index, FBackupOnAddOverwrite);
end;

function TRSMMArchive.CloneForProcessing(const NewFile: string;
  FilesCount: int): TRSMMArchive;
begin
  Result:= TRSMMArchive(self.NewInstance);
  Result.CreateInternal(FFiles.CloneForProcessing(NewFile, FilesCount));
end;

constructor TRSMMArchive.Create;
begin
  CreateInternal(TRSMMFiles.Create);
end;

constructor TRSMMArchive.CreateInternal(Files: TRSMMFiles);
begin
  FFiles:= Files;
  Files.OnReadHeader:= ReadHeader;
  Files.OnWriteHeader:= WriteHeader;
  Files.UserDataSize:= FTagSize;
  Files.OnBeforeReplaceFile:= BeforeReplaceFile; 
end;

destructor TRSMMArchive.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TRSMMArchive.DoBackupFile(Index: int; Overwrite: Boolean);
begin
  Extract(Index, MakeBackupDir, Overwrite);
end;

function TRSMMArchive.DoExtract(Index: int; const FileName: string; Overwrite: Boolean): string;
var
  a: TMemoryStream;
begin
  Result:= '';
  if not Overwrite and FileExists(FileName) then  exit;
  Result:= FileName;
  a:= TMemoryStream.Create;
  try
    Extract(Index, a);
    RSSaveFile(Result, a);
  finally
    a.Free;
  end;
end;

function TRSMMArchive.Extract(Index: int): TObject;
begin
  Result:= TMemoryStream.Create;
  try
    Extract(Index, TStream(Result));
  except
    Result.Free;
    raise;
  end;
end;

function TRSMMArchive.ExtractArray(Index: int): TRSByteArray;
var
  a: TStream;
begin
  Result:= nil;
  a:= TRSArrayStream.Create(Result);
  try
    Extract(Index, a);
  finally
    a.Free;
  end;
end;

function TRSMMArchive.ExtractArrayOrBmp(Index: int; var Arr: TRSByteArray): TBitmap;
begin
  Arr:= nil;
  Arr:= ExtractArray(Index);
  Result:= nil;
end;

function TRSMMArchive.ExtractString(Index: int): string;
var
  a: TStream;
begin
  Result:= '';
  a:= TRSStringStream.Create(Result);
  try
    Extract(Index, a);
  finally
    a.Free;
  end;
end;

function TRSMMArchive.Extract(Index: int; Output: TStream): string;
begin
  FFiles.RawExtract(Index, Output);
  Result:= GetExtractName(Index);
end;

function TRSMMArchive.Extract(Index: int; const Dir: string; Overwrite: Boolean = true): string;
begin
  Result:= DoExtract(Index, IncludeTrailingPathDelimiter(Dir) + GetExtractName(Index), Overwrite);
end;

function TRSMMArchive.GetCount: int;
begin
  Result:= FFiles.Count;
end;

function TRSMMArchive.GetExtractName(Index: int): string;
begin
  Result:= FFiles.Name[Index];
end;

function TRSMMArchive.GetFileName(i: int): PChar;
begin
  Result:= FFiles.Name[i];
end;

procedure TRSMMArchive.Load(const FileName: string);
begin
  FFiles.Load(FileName);
end;

function TRSMMArchive.MakeBackupDir: string;
begin
  Result:= FFiles.FileName + ' Backup';
  RSCreateDir(Result);
  Result:= Result + '\';
end;

procedure TRSMMArchive.SaveAs(const FileName: string);
begin
  FFiles.SaveAs(FileName);
end;

{ TRSLodBase }

type
  TLodType = record
    Version: string;
    LodType: string;
  end;

const
  LodTypes: array[TRSLodVersion] of TLodType =
  (
    (Version: ''; LodType: ''),              // RSLodHeroes
    (Version: 'MMVI'; LodType: 'bitmaps'),   // RSLodBitmaps
    (Version: 'MMVI'; LodType: 'icons'),     // RSLodIcons
    (Version: 'MMVI'; LodType: 'sprites08'), // RSLodSprites
    (Version: 'GameMMVI'; LodType: 'maps'),  // RSLodGames
    (Version: 'GameMMVI'; LodType: 'maps'),  // RSLodGames7
    (Version: 'MMVI'; LodType: 'chapter'),   // RSLodChapter
    (Version: 'MMVII'; LodType: 'chapter'),  // RSLodChapter7
    (Version: 'MMVIII'; LodType: 'language') // RSLodMM8
  );

  LodDescriptions: array[TRSLodVersion] of string =
  (
    '',                                      // RSLodHeroes
    'Bitmaps for MMVI.',                     // RSLodBitmaps
    'Icons for MMVI.',                       // RSLodIcons
    'Sprites for MMVI.',                     // RSLodSprites
    'Maps for MMVI',                         // RSLodGames
    'Maps for MMVI',                         // RSLodGames7
    'newmaps for MMVI',                      // RSLodChapter
    'newmaps for MMVII',                     // RSLodChapter7
    'Language for MMVIII.'                   // RSLodMM8
  );

function TRSLodBase.CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive;
begin
  Result:= inherited CloneForProcessing(NewFile, FilesCount);
  with TRSLodBase(Result) do
  begin
    FAnyHeader:= self.FAnyHeader;
    FVersion:= self.FVersion;
    SetLength(FAdditionalData, length(self.FAdditionalData));
    if FAdditionalData <> nil then
      Move(self.FAdditionalData[0], FAdditionalData[0], length(FAdditionalData));

    if FVersion = RSLodHeroes then
    begin
      FHeroesHeader^.Count:= 0;
    end else
      with FMMHeader^ do
      begin
        Count:= 0;
        ArchiveSize:= FFiles.ArchiveSize - FFiles.Options.DataStart;
      end;

    if FVersion in [RSLodGames, RSLodGames7, RSLodChapter, RSLodChapter7] then
      RawFiles.FSorted:= self.RawFiles.FSorted;
  end;
end;

constructor TRSLodBase.CreateInternal(Files: TRSMMFiles);
begin
  inherited;
  FHeroesHeader:= @FAnyHeader;
  FMMHeader:= @FAnyHeader;
end;

function TRSLodBase.GetExtractName(Index: int): string;
begin
  Result:= FFiles.Name[Index] + '.mmrawdata';
end;

procedure TRSLodBase.InitOptions(var Options: TRSMMFilesOptions);
begin
  with Options do
  begin
    if Version <> RSLodHeroes then
    begin
      if FVersion = RSLodMM8 then
      begin
        NameSize:= $40;
        AddrOffset:= $40;
        UnpackedSizeOffset:= $44;
        ItemSize:= $4C;
      end else
      begin
        NameSize:= $10;
        AddrOffset:= $10;
        UnpackedSizeOffset:= $14;
        ItemSize:= $20;
      end;
      PackedSizeOffset:= -1;

      AddrStart:= FMMHeader^.ArchiveStart;
      DataStart:= FMMHeader^.ArchiveStart;
      MinFileSize:= 0;
    end else
      with Options do
      begin
        NameSize:= $10;
        AddrOffset:= $10;
        UnpackedSizeOffset:= $14;
        PackedSizeOffset:= $1C;
        ItemSize:= $20;

        AddrStart:= 0;
        DataStart:= SizeOf(TRSLodHeroesHeader);
        MinFileSize:= 320092;
      end
  end;
end;

procedure TRSLodBase.Load(const FileName: string);
var
  sig: array[1..2] of int;
  a: TStream;
  ext: string;
  i: int;
begin
  inherited;
  if FVersion = RSLodGames then
    for i := 0 to FFiles.Count - 1 do
    begin
      ext:= LowerCase(ExtractFileExt(FFiles.Name[i]));
      if (ext = '.blv') or (ext = '.dlv') or (ext = '.odm') or (ext = '.ddm') then
      begin
        if FFiles.Size[i] < 16 then  exit;
        a:= FFiles.GetAsIsFileStream(i, true);
        try
          MyReadBuffer(a, sig, 8);
        finally
          FFiles.FreeAsIsFileStream(i, a);
        end;
        if (sig[1] = $16741) and (sig[2] = $6969766D) then
          FVersion:= RSLodGames7;
        exit;
      end;
    end;
end;

procedure TRSLodBase.New(const FileName: string; AVersion: TRSLodVersion);
var
  o: TRSMMFilesOptions;
begin
  FVersion:= AVersion;
  ZeroMemory(@FAnyHeader, SizeOf(FAnyHeader));
  FAdditionalData:= nil;
  FMMHeader^.Signature:= 'LOD';
  if AVersion <> RSLodHeroes then
    with FMMHeader^ do
    begin
      StrCopy(Version, ptr(LodTypes[AVersion].Version));
      StrCopy(LodType, ptr(LodTypes[AVersion].LodType));
      StrCopy(Description, ptr(LodDescriptions[AVersion]));
      Unk1:= 100;
      Unk2:= 0;
      Unk3:= 1;
      ArchiveStart:= $120;
    end
  else
    FHeroesHeader^.Version:= 200;
  RSMMFilesOptionsInitialize(o);
  InitOptions(o);
  FFiles.New(FileName, o);
end;

procedure TRSLodBase.ReadHeader(Sender: TRSMMFiles; Stream: TStream;
   var Options: TRSMMFilesOptions; var FilesCount: int);
var
  ver: TRSLodVersion;
begin
  with Stream do
  begin
    MyReadBuffer(Stream, FHeroesHeader^, SizeOf(TRSLodHeroesHeader));
    FVersion:= RSLodHeroes;
    if FHeroesHeader^.Version > $FFFF then
    begin
      MyReadBuffer(Stream, (PChar(FMMHeader) + SizeOf(TRSLodHeroesHeader))^,
        SizeOf(TRSLodMMHeader) - SizeOf(TRSLodHeroesHeader));

      for ver := RSLodBitmaps to RSlodMM8 do
        if (FMMHeader^.Version = LodTypes[ver].Version) and
           (FMMHeader^.LodType = LodTypes[ver].LodType) then
        begin
          FVersion:= ver;
          break;
        end;

      if FVersion = RSLodHeroes then
        raise ERSLodException.Create(SRSLodUnknown);
      if FVersion in [RSLodGames, RSLodGames7] then
        FFiles.FGamesLod:= true;

      FilesCount:= FMMHeader^.Count;
      InitOptions(Options);
      SetLength(FAdditionalData, FMMHeader^.ArchiveStart - SizeOf(TRSLodMMHeader));
      if FAdditionalData <> nil then
        MyReadBuffer(Stream, FAdditionalData[0], length(FAdditionalData));

    end else
    begin
      FVersion:= RSLodHeroes;
      FilesCount:= FHeroesHeader^.Count;
      InitOptions(Options);
    end;
  end;
end;

procedure TRSLodBase.WriteHeader(Sender: TRSMMFiles; Stream: TStream);
begin
  with Stream do
  begin
    if FVersion = RSLodHeroes then
    begin
      FHeroesHeader^.Count:= FFiles.Count;

      WriteBuffer(FHeroesHeader^, SizeOf(TRSLodHeroesHeader));
    end else
    begin
      FMMHeader^.Count:= FFiles.Count;
      FMMHeader^.ArchiveSize:= FFiles.ArchiveSize - FFiles.Options.DataStart;

      WriteBuffer(FMMHeader^, SizeOf(TRSLodMMHeader));
      if FAdditionalData <> nil then
        WriteBuffer(FAdditionalData[0], length(FAdditionalData));
    end;
  end;
end;

{ TRSLod }

type
  PMMLodFile = ^TMMLodFile;
  TMMLodFile = packed record
    BmpSize: int;
    DataSize: int;
    BmpWidth: int2;
    BmpHeight: int2;
    BmpWidthLn2: int2;  // textures: log2(BmpWidth)
    BmpHeightLn2: int2;  // textures: log2(BmpHeight)
    BmpWidthMinus1: int2;  // textures: BmpWidth - 1
    BmpHeightMinus1: int2;  // textures: BmpHeight - 1
    Palette: int;
    UnpSize: int;
    Bits: int;  // Bits:  2 - multitexture, $10 - something important too 
    // Data...
    // Palette...
  end;

  TSpriteLine = packed record
    a1: int2;
    a2: int2;
    pos: int4;
  end;
  TSprite = packed record
    Size: int;
    w: int2;
    h: int2;
    Palette: int2;
    unk_1: int2;
    yskip: int2; // number of clear lines at bottom
    unk_2: int2; // used in runtime only, for bits
    UnpSize: int;
  end;
  TSpriteEx = packed record
    Sprite: TSprite;
    Lines: array[0..(MaxInt div SizeOf(TSpriteLine) div 2)] of TSpriteLine;
    // Data...
  end;

  TPCXFileHeader = packed record
    ImageSize: longint;
    Width: longint;
    Height: longint;
    // Data...
    // Palette...
  end;
  PPCXFileHeader = ^TPCXFileHeader;
   // Pcx Format: <Header> <Picture> <Palette>
   // The format is far form PCX in fact
   // Palette exists only if biSizeImage/(biWidth*biHeight) = 1

  TMM6GamesFile = packed record
    DataSize: int;
    UnpackedSize: int;
  end;

  TMM7GamesFile = packed record
    Sig1: int; // $16741
    Sig2: int; // $6969766D (mvii)
    DataSize: int;
    UnpackedSize: int;
  end;

const
  cnkNone = 0;
  cnkExist = 1;
  cnkGetName = 2;

function TRSLod.Add(const Name: string; b: TBitmap; pal: int = 0): int;
begin
  Result:= AddBitmap(Name, b, pal, true);
end;

function TRSLod.Add(const Name: string; Data: TStream; Size: int = -1; pal: int = 0): int;
var
  ext, s: string;
  sz: int;
  m: TMemoryStream;
  act: Boolean;
  b: TBitmap;
begin
  Result:= -1;
  ext:= LowerCase(ExtractFileExt(Name));
  if ext = '.mmrawdata' then
  begin
    Result:= inherited Add(ChangeFileExt(Name, ''), Data, Size, pal);
    exit;
  end;
  if ext = '.bmp' then
  begin
    Result:= AddBitmap(Name, RSLoadBitmap(Data), pal, false);
    exit;
  end;
  if Size < 0 then
    Size:= Data.Size - Data.Position;
  act:= false;
  if (ext = '') and (FVersion = RSLodBitmaps) and (LowerCase(Copy(Name, 1, 3)) = 'pal') then
    if Size <> 768 then
    begin
      b:= RSLoadBitmap(Data);
      b.Width:= 0;
      b.Height:= 0;
      Result:= AddBitmap(Name, b, 0, false, 0);
      exit;
    end else
      act:= true;

  m:= nil;
  try
    case FVersion of
      RSLodHeroes:
        Result:= FFiles.Add(Name, Data, Size);
      RSLodBitmaps, RSLodIcons, RSLodMM8:
      begin
        if ext = '.act' then
        begin
          act:= true;
          if Size <> 768 then
            raise ERSLodException.Create(SRSLodActPalMust768);
          s:= copy(Name, 1, length(Name) - 4);
        end else
          s:= Name;
        FFiles.CheckName(s);
        sz:= FFiles.Options.NameSize;
        m:= TMemoryStream.Create;
        m.SetSize(sz + SizeOf(TMMLodFile));
        ZeroMemory(m.Memory, sz + SizeOf(TMMLodFile));
        if s <> '' then
          Move(s[1], m.Memory^, length(s));

        if act then
          Zip(m, Data, Size, -1, int(@PMMLodFile(sz).UnpSize))
        else if ext = '.str' then
          PackStr(m, Data, Size)
        else
          Zip(m, Data, Size, int(@PMMLodFile(sz).DataSize), int(@PMMLodFile(sz).UnpSize));
        m.Seek(0, 0);
        Result:= FFiles.Add(s, m, -1, clNone);
      end;
      RSLodSprites:
        raise ERSLodException.Create(SRSLodSpriteMustBmp);
      RSLodGames, RSLodGames7, RSLodChapter, RSLodChapter7:
        if (ext = '.blv') or (ext = '.dlv') or (ext = '.odm') or (ext = '.ddm') then
        begin
          m:= TMemoryStream.Create;
          sz:= 8;
          if FVersion in [RSLodGames7, RSLodChapter7] then
            sz:= 16;
          m.SetSize(sz);
          if sz = 16 then
            with TMM7GamesFile(m.Memory^) do
            begin
              Sig1:= $16741;
              Sig2:= $6969766D;
            end;
          Zip(m, Data, Size, sz - 8, sz - 4);
          m.Seek(0, 0);
          Result:= FFiles.Add(Name, m, -1, clNone);
        end else
          Result:= FFiles.Add(Name, Data, Size, clNone);
    end;
  finally
    m.Free;
  end;
end;

destructor TRSLod.Destroy;
begin
  if OwnBitmapsLod then
    BitmapsLod.Free;
  inherited;
end;

function TRSLod.DoExtract(i: int; Output: TStream = nil; Arr: PRSByteArray = nil;
   FileName: PStr = nil; CheckNameKind: int = 0): TObject;
// Output <> nil    =>  fills Output
// Arr <> nil       =>  fills Arr
// else creates a bitmap or memory stream and returns it as Result
var
  outnew: TStream;
  Dummy: string;

  function CheckName: Boolean;
  begin
    Result:= (CheckNameKind = 0) or (CheckNameKind = cnkExist) and not FileExists(FileName^);
    CheckNameKind:= 0;
  end;

  function SetName(const s: string): Boolean;
  begin
    FileName^:= s;
    Result:= CheckName;
  end;

  function NeedOutput: Boolean;
  begin
    if (Output = nil) and CheckName then
    begin
      if Arr <> nil then
        outnew:= TRSArrayStream.Create(Arr^)
      else
        outnew:= TMemoryStream.Create;
      Output:= outnew;
    end;
    Result:= Output<>nil;
  end;

var
  a: TStream;
  games: TMM7GamesFile;
  regular: TMMLodFile;
  sz: int;
  b: TBitmap;
  name, ext: string;
begin
  FLastPalette:= 0;
  Result:= nil;
  b:= nil;
  a:= nil;
  outnew:= nil;
  Dummy:= '';
  if FileName = nil then
    FileName:= @Dummy;
  name:= FFiles.Name[i];
  ext:= LowerCase(ExtractFileExt(name));
  try
    if FVersion <> RSLodHeroes then
      a:= FFiles.GetAsIsFileStream(i, true);

    case FVersion of
      RSLodHeroes:
        if ext = '.pcx' then
        begin
          if not SetName(ChangeFileExt(FileName^, '.bmp')) then  exit;
          a:= TMemoryStream.Create;
          FFiles.RawExtract(i, a);
          b:= TBitmap.Create;
          UnpackPcx(TMemoryStream(a), b);
        end else
        begin
          if not NeedOutput then  exit;
          FFiles.RawExtract(i, Output);
        end;

      RSLodSprites:
      begin
        if not SetName(FileName^ + '.bmp') then  exit;
        a.Seek(FFiles.Options.NameSize - 4, soCurrent);
        b:= TBitmap.Create;
        UnpackSprite(name, a, b, FFiles.Size[i] - FFiles.Options.NameSize + 4);
      end;

      RSLodBitmaps, RSLodIcons, RSLodMM8:
      begin
        a.Seek(FFiles.Options.NameSize, soCurrent);
        a.ReadBuffer(regular, SizeOf(regular));
        if regular.BmpSize <> 0 then
        begin
          if not SetName(FileName^ + '.bmp') then  exit;
          b:= TBitmap.Create;
          UnpackBitmap(a, b, regular);
        end else
          if (regular.DataSize = 0) and (FFiles.Size[i] >= 768 + SizeOf(regular) + FFiles.Options.NameSize) then
          begin
            if not SetName(FileName^ + '.act') or not NeedOutput then  exit;
            RSCopyStream(Output, a, 768);
          end else
          begin
            if not NeedOutput then  exit;
            if ext = '.str' then
              UnpackStr(a, Output, regular)
            else
              Unzip(a, Output, regular.DataSize, regular.UnpSize, ext <> '.txt');
          end;
      end;
      
      RSLodGames, RSLodGames7, RSLodChapter, RSLodChapter7:
      begin
        if not NeedOutput then  exit;
        if (ext = '.blv') or (ext = '.dlv') or (ext = '.odm') or (ext = '.ddm') then
        begin
          if FVersion in [RSLodGames7, RSLodChapter7] then
          begin
            sz:= 16;
            a.ReadBuffer(games, 16)
          end else
          begin
            sz:= 8;
            a.ReadBuffer(games.DataSize, 8);
          end;
          Unzip(a, Output, FFiles.Size[i] - sz, games.UnpackedSize, true);
        end else
          FFiles.RawExtract(i, Output);
      end;
    end;

    if Output <> nil then
    begin
      if b <> nil then
        b.SaveToStream(Output);

      if (outnew = Output) and (Arr = nil) then
      begin
        Result:= outnew;
        outnew:= nil;
      end;
    end else
      Result:= b;
  finally
    if a <> nil then
      FFiles.FreeAsIsFileStream(i, a);
    outnew.Free;
    if b <> Result then
      b.Free;
  end;
end;

function TRSLod.Extract(Index: int; const Dir: string; Overwrite: Boolean): string;
var
  a: TObject;
begin
  Result:= IncludeTrailingPathDelimiter(Dir) + FFiles.Name[Index];
  a:= nil;
  try
    a:= DoExtract(Index, nil, nil, @Result, IfThen(Overwrite, 0, cnkExist));
    if a = nil then
      Result:= ''
    else
      if a is TBitmap then
        TBitmap(a).SaveToFile(Result)
      else
        RSSaveFile(Result, a as TMemoryStream);
  finally
    a.Free;
  end
end;

function TRSLod.Extract(Index: int; Output: TStream): string;
begin
  Result:= FFiles.Name[Index];
  DoExtract(Index, Output, nil, @Result);
end;

function TRSLod.Extract(Index: int): TObject;
begin
  Result:= DoExtract(Index);
end;

function TRSLod.ExtractArrayOrBmp(Index: int; var Arr: TRSByteArray): TBitmap;
begin
  Result:= TBitmap(DoExtract(Index, nil, @Arr));
end;

function PalVal(p: PChar): uint;
label
  bad;
var
  i: uint;
begin
  // Don't know why I optimized it...
  // '0' - '9'  =  $30 - $39
  inc(p, 3);
  i:= pint(p + 1)^;
  if ((i and $C0F0F0) <> $3030) or ((ord(p^) and $F0) <> $30) then  goto bad;
  Result:= (ord(p^) and $F)*100 + (i and $F)*10 + (i shr 8) and $F;
  i:= i shr 16;
  if byte(i) = 0 then  exit;
  if (byte(i) < $30) or (Result < 100) then  goto bad;
  Result:= Result*10 + byte(i) - $30;
  i:= i shr 8;
  if i = 0 then  exit;
  if (byte(i) < $30) or (byte(i) > $39) then  goto bad;
  Result:= Result*10 + byte(i) - $30;
  if (p + 5)^ = #0 then  exit;
bad:
  Result:= 0;
end;

function TRSLod.FindSamePalette(const PalEntries; var pal: int): Boolean;
const
  ReadOff = 16;
  FileSize = SizeOf(TMMLodFile) + ReadOff + 768;
var
  PalFile: array[0..SizeOf(TMMLodFile) + 768 - 1] of byte;
  a: TStream;
  i, j, m1, m2, fr3, fr4, fr5: int;
begin
  Result:= false;
  if FVersion <> RSLodBitmaps then  exit;
  FFiles.FindFile('pal', m1);
  FFiles.FindFile('pam', m2);
  fr3:= 1;  // to find a free palette index
  fr4:= 1000;  // for numbers consisting of 3, 4 and 5 digits
  fr5:= 10000;  // in these categories lexicographical sorting works
  for i := m1 to m2 - 1 do
  begin
    j:= PalVal(FFiles.Name[i]);
    if j = 0 then  continue;
    if j <= fr3 then
      inc(fr3)
    else if j <= fr4 then
      inc(fr4)
    else if j <= fr5 then
      inc(fr5);
    if (FFiles.Size[i] <> FileSize) then  continue;
    a:= FFiles.GetAsIsFileStream(i);
    try
      a.Seek(ReadOff, soCurrent);
      a.ReadBuffer(PalFile, SizeOf(PalFile));
    finally
      FFiles.FreeAsIsFileStream(i, a);
    end;

    with PMMLodFile(@PalFile)^ do
      if (BmpSize or DataSize or pint(@BmpWidth)^ = 0) and
         CompareMem(@PalFile[SizeOf(TMMLodFile)], @PalEntries, 768) then
      begin
        pal:= j;  // found identical palette
        Result:= true;
        exit;
      end;
  end;

  if fr3 < 1000 then
    pal:= fr3
  else if fr4 < 10000 then
    pal:= fr4
  else
    pal:= fr5;
end;

function TRSLod.GetExtractName(Index: int): string;
begin
  Result:= FFiles.Name[Index];
  DoExtract(Index, nil, nil, @Result, cnkGetName);
end;

function TRSLod.GetIntAt(i, o: int): int;
var
  a: TStream;
begin
  a:= FFiles.GetAsIsFileStream(i);
  try
    a.Seek(o + FFiles.Options.NameSize, soCurrent);
    MyReadBuffer(a, Result, 4);
  finally
    FFiles.FreeAsIsFileStream(i, a);
  end;
end;

function TRSLod.AddBitmap(const Name: string; b: TBitmap; pal: int;
  Keep: Boolean; Bits: int = -1): int;
var
  nam: string;
  m: TMemoryStream;
  NoPal: Boolean;
  i: int;
begin
  Result:= -1;
  if FVersion = RSLodHeroes then
    nam:= '.pcx'
  else
    nam:= '';
  nam:= ChangeFileExt(Name, nam);
  m:= nil;
  try
    if FVersion <> RSLodSprites then
      FFiles.CheckName(nam)
    else
      if length(nam) >= 12 then
        raise ERSLodWrongFileName.CreateFmt(SRSLodLongName, [nam, 12]);

    m:= TMemoryStream.Create;
    if FVersion <> RSLodHeroes then
    begin
      m.SetSize(FFiles.Options.NameSize);
      ZeroMemory(m.Memory, m.Size);
      if nam <> '' then
        Move(nam[1], m.Memory^, length(nam));
    end;
    case FVersion of
      RSLodHeroes:
        PackPcx(b, m, Keep);  // Result?
      RSLodSprites:
      begin
        if pal <= 0 then
        begin
          if FFiles.FindFile(nam, i) then
            pal:= GetIntAt(i, 4);
          if Assigned(OnNeedPalette) then
            OnNeedPalette(self, b, pal);
        end;
        PackSprite(b, m, pal);
      end;
      RSLodBitmaps, RSLodIcons, RSLodMM8:
      begin
        if (FVersion = RSLodBitmaps) then
        begin
          NoPal:= pal <= 0;
          if (NoPal or (Bits = -1)) and FFiles.FindFile(nam, i) then
          begin
            if pal <= 0 then
              pal:= GetIntAt(i, 20);
            if Bits = -1 then
              Bits:= GetIntAt(i, 28) or $12;
          end else
            if Bits = -1 then
              Bits:= $12;
              
          if NoPal and (Bits <> 0) and Assigned(OnNeedPalette) then
            OnNeedPalette(self, b, pal);
        end else
          if Bits = -1 then
            Bits:= 0;

        PackBitmap(b, m, pal, Bits, Keep);
      end;
      else
        raise ERSLodException.Create(SRSLodNoBitmaps);
    end;
    m.Seek(0, 0);
    if FVersion <> RSLodHeroes then
      Result:= FFiles.Add(nam, m, m.Size, clNone)
    else
      Result:= FFiles.Add(nam, m);
  finally
    m.Free;
    if not Keep then
      b.Free;
  end;
end;

procedure TRSLod.DoBackupFile(Index: int; Overwrite: Boolean);
var
  a: TFileStream;
  s: string;
begin
  if Version in [RSLodBitmaps, RSLodSprites] then
  begin
    s:= MakeBackupDir + FFiles.Name[Index] + '.mmrawdata';
    if not Overwrite and FileExists(s) then  exit;
    a:= TFileStream.Create(s, fmCreate);
    try
      FFiles.RawExtract(Index, a);
    finally
      a.Free;
    end;
  end else
    inherited;
end;

function TRSLod.CloneForProcessing(const NewFile: string;
  FilesCount: int): TRSMMArchive;
begin
  Result:= inherited CloneForProcessing(NewFile, FilesCount);
  with TRSLod(Result) do
  begin
    FBitmapsLod:= self.FBitmapsLod;
    FOnNeedBitmapsLod:= self.FOnNeedBitmapsLod;
    FOnSpritePalette:= self.FOnSpritePalette;
  end;
end;

function TRSLod.PackPcx(b: TBitmap; m: TMemoryStream; KeepBmp: Boolean): int;
var
  i, j: int;
  HasPal: Boolean;
  b1: TBitmap;
begin
  b1:= nil;
  try
    if b.PixelFormat <> pf8bit then
    begin
      if (b.PixelFormat <> pf24bit) and KeepBmp then
      begin
        b1:= TBitmap.Create;
        b1.Assign(b);
        b:= b1;
      end;
      b.PixelFormat:=pf24bit;
      i:=3;
      Result:= $11;
    end else
    begin
      i:=1;
      Result:= $10;
    end;

    HasPal:= i = 1;
    i:= i * b.Width * b.Height;
    j:= i + SizeOf(TPCXFileHeader);
    if HasPal then
      m.SetSize(j + 256*3)
    else
      m.SetSize(j);

    with PPCXFileHeader(m.Memory)^ do
    begin
      ImageSize:= i;
      Width:= b.Width;
      Height:= b.Height;
    end;
    RSBitmapToBuffer(PChar(m.Memory) + SizeOf(TPCXFileHeader), b);

    if HasPal then
      RSWritePalette(PChar(m.Memory) + j, b.Palette);
  finally
    b1.Free;
  end;
end;

function MixCl(c1, c2, c3, c4: int): int;
begin
  Result:= ((c1 and $FCFCFC + c2 and $FCFCFC + c3 and $FCFCFC + c4 and $FCFCFC) +
    (c1 and $030303 + c2 and $030303 + c3 and $030303 + c4 and $030303 + $020202) and $C0C0C) shr 2;
end;

procedure TRSLod.PackBitmap(b: TBitmap; m: TMemoryStream; pal, ABits: int; Keep: Boolean);

  function GetLn2(v: int): int;
  begin
    Result:= 0;
    while (v <> 0) and (v and 1 = 0) do
    begin
      v:= v shr 1;
      inc(Result);
    end;
    if v <> 1 then
      Result:= 0;
  end;

  procedure FillBitmapZooms(b2: TBitmap; buf: PChar; pal: HPALETTE);
  const
    dx = 4;
  var
    i, x, y, dy, c, w, h: int;
    p: PChar;
  begin
    b2.HandleType:= bmDIB;
    b2.PixelFormat:= pf32bit;
    w:= b2.Width;
    h:= b2.Height;
    inc(buf, w*h);  // skip normal size picture
    p:= b2.ScanLine[0];
    dy:= int(b2.ScanLine[1]) - int(p);
    for i := 1 to 3 do
    begin
      w:= w div 2;
      h:= h div 2;
      for y := 0 to h - 1 do
        for x := 0 to w - 1 do
        begin
          c:= MixCl(pint(p + y*2*dy + x*2*dx)^,
                    pint(p + y*2*dy + (x*2 + 1)*dx)^,
                    pint(p + (y*2 + 1)*dy + x*2*dx)^,
                    pint(p + (y*2 + 1)*dy + (x*2 + 1)*dx)^);
          if i = 1 then
            c:= RSSwapColor(c);
          pint(p + y*dy + x*dx)^:= c;
          buf^:= chr(GetNearestPaletteIndex(pal, c));
          inc(buf);
        end;
    end;
  end;

var
  buf: TMemoryStream;
  zoom: Boolean;
  b1, b2: TBitmap;
  p: PChar;
  i, sz0: int;
begin
  //if b.PixelFormat <> pf8bit then
  //  raise ERSLodException.Create(SRSLodBitmapsMust256);
  sz0:= m.Size;
  m.SetSize(sz0 + SizeOf(TMMLodFile));
  ZeroMemory(PChar(m.Memory) + sz0, SizeOf(TMMLodFile));
  with TMMLodFile(ptr(PChar(m.Memory) + sz0)^) do
  begin
    BmpWidth:= b.Width;
    BmpHeight:= b.Height;
    BmpSize:= BmpWidth*BmpHeight;
    UnpSize:= BmpSize;
    zoom:= false;
    if (FVersion = RSLodBitmaps) and (BmpWidth <> 0) then
    begin
      Palette:= pal;
      Bits:= ABits;

      if ABits and 2 <> 0 then
      begin
        // in fact the game ignores these 4 fields
        BmpWidthLn2:= GetLn2(BmpWidth);
        if BmpWidthLn2 < 2 then
          raise ERSLodBitmapException.CreateFmt(SRSLodMustPowerOf2, ['width']);
        BmpHeightLn2:= GetLn2(BmpHeight);
        if BmpHeightLn2 < 2 then
          raise ERSLodBitmapException.CreateFmt(SRSLodMustPowerOf2, ['height']);
        BmpWidthMinus1:= BmpWidth - 1;
        BmpHeightMinus1:= BmpHeight - 1;
        zoom:= true;
        inc(UnpSize, ((BmpSize div 4 + BmpSize) div 4 + BmpSize) div 4);
      end;
    end;
    if UnpSize <= 256 then
    begin
      buf:= nil;
      DataSize:= UnpSize;
      UnpSize:= 0;
      i:= m.Size;
      m.SetSize(i + DataSize);
      p:= PChar(m.Memory) + i;
    end else
    begin
      buf:= TMemoryStream.Create;
      buf.SetSize(UnpSize);
      p:= buf.Memory;
    end;
  end;
  b1:= nil;
  b2:= nil;
  try
    if b.Width <> 0 then
    begin
      if (Keep or zoom) and (b.PixelFormat <> pf8bit) or
          Keep and (b.HandleType <> bmDIB) then
      begin
        b1:= TBitmap.Create;
        b1.Assign(b);
      end else
        b1:= b;
      b1.PixelFormat:= pf8bit;
      b1.HandleType:= bmDIB;
      RSBitmapToBuffer(p, b1);
      if zoom then
      begin
        b2:= TBitmap.Create;
        b2.Assign(b);
        FillBitmapZooms(b2, p, b1.Palette);
      end;
    end else
      b1:= b;
      
    if buf <> nil then
      with TMMLodFile(ptr(PChar(m.Memory) + sz0)^) do
        Zip(m, buf, UnpSize, @DataSize, @UnpSize);
    i:= m.Seek(0, soEnd);
    m.SetSize(i + 256*3);
    RSWritePalette(PChar(m.Memory) + i, b1.Palette);
  finally
    buf.Free;
    if b1 <> b then
      b1.Free;
    b2.Free;
  end;
end;

procedure TRSLod.PackSprite(b: TBitmap; m: TMemoryStream; pal: int);
var
  buf: TMemoryStream;
  i, j, k, bp: int;
  scan0, p: PChar; dscan, sz0: int;
  oldht: TBitmapHandleType;
begin
  if b.PixelFormat <> pf8bit then
    raise ERSLodBitmapException.Create(SRSLodSpriteMust256);
  if pal = 0 then
    raise ERSLodBitmapException.Create(SRSLodSpriteMustPal);
  oldht:= b.HandleType;
  buf:= TMemoryStream.Create;
  try
    sz0:= m.Size - 4;
    m.SetSize(sz0 + SizeOf(TSprite) + b.Height*SizeOf(TSpriteLine));
    with TSpriteEx(ptr(PChar(m.Memory) + sz0)^), Sprite do
    begin
      w:= b.Width;
      h:= b.Height;
      Palette:= pal;
      unk_1:= 0;
      yskip:= h;
      unk_2:= 0;

      b.HandleType:= bmDIB;
      scan0:= nil;
      dscan:= 0;
      if h > 0 then  scan0:= b.ScanLine[0];
      if h > 1 then  dscan:= IntPtr(b.ScanLine[1]) - IntPtr(scan0);

      bp:= 0;
      for i := 0 to h - 1 do
        with Lines[i] do
        begin
          p:= scan0 + dscan*i;
          k:= w - 1;
          while (k >= 0) and ((p + k)^ = #0) do  dec(k);

          if k >= 0 then
          begin
            yskip:= h - i - 1;
            j:= 0;
            while ((p + j)^ = #0) do  inc(j);
            a1:= j;
            a2:= k;
            pos:= bp;
            buf.WriteBuffer((p + j)^, k - j + 1);
            inc(bp, k - j + 1);
          end else
          begin
            a1:= -1;
            a2:= -1;
            pos:= 0;
          end;
        end;
      buf.Seek(0, 0);
      Zip(m, buf, buf.Size, @Size, @UnpSize);
    end;
  finally
    b.HandleType:= oldht;
    buf.Free;
  end;
end;

procedure TRSLod.PackStr(m: TMemoryStream; Data: TStream; Size: int);
var
  s: string;
  a: TStream;
  i: int;
begin
  SetLength(s, Size);
  Data.ReadBuffer(s[1], Size);
  i:= length(s);
  while (i > 0) and (s[i] <> #0) do
    dec(i);
  if i = 0 then  // no #0 found
    s:= RSStringReplace(s, #13#10, #0);
  a:= TRSStringStream.Create(s);
  try
    with PMMLodFile(FFiles.Options.NameSize)^ do
      Zip(m, a, length(s), int(@DataSize), int(@UnpSize));
  finally
    a.Free;
  end;
end;

procedure TRSLod.UnpackBitmap(data: TStream; b: TBitmap; const FileHeader);
var
  m: TMemoryStream;
  hdr: TMMLodFile absolute FileHeader;
begin
  Assert(hdr.BmpSize = hdr.BmpWidth*hdr.BmpHeight);
  m:= TMemoryStream.Create;
  with b do
    try
      m.Size:= 768;
      data.Seek(hdr.DataSize, soCurrent);
      data.ReadBuffer(m.Memory^, 768);
      PixelFormat:= pf8bit;
      Palette:= RSMakePalette(m.Memory);

      data.Seek(-hdr.DataSize - 768, soCurrent);
      Unzip(data, m, hdr.DataSize, hdr.UnpSize, true);

      Width:= hdr.BmpWidth;
      Height:= hdr.BmpHeight;
      RSBufferToBitmap(m.Memory, b);
      FLastPalette:= hdr.Palette;
    finally
      m.Free;
    end
end;

{
procedure TRSLod.UnpackBitmap(data: TStream; b: TBitmap; const FileHeader);
var
  j: int;
  m, a: TMemoryStream;
  hdr: TMMLodFile absolute FileHeader;
begin
  Assert(hdr.BmpSize = hdr.BmpWidth*hdr.BmpHeight);
  m:= TMemoryStream.Create;
  a:= TMemoryStream.Create;
  with b do
    try
      PixelFormat:= pf8bit;

      Unzip(data, m, hdr.DataSize, hdr.UnpSize, true);

      Width:= hdr.BmpWidth;
      Height:= hdr.BmpHeight;

      Assert(FFiles.FindFile(Format('pal%.3d', [int(hdr.Palette)]), j));
      a:= ptr(Extract(j));
      Palette:= RSMakePalette(a.Memory);

      RSBufferToBitmap(m.Memory, b);
    finally
      m.Free;
      a.Free;
    end
end;
}

procedure TRSLod.UnpackPcx(data: TMemoryStream; b: TBitmap);
var
  w, h, len, ByteCount:int;
  p: PChar;
begin
  p:= data.Memory;
  with PPCXFileHeader(p)^ do
  begin
    len:= ImageSize;
    w:= Width;
    h:= Height;
  end;
  inc(p, SizeOf(TPCXFileHeader));
  if w*h <> 0 then
    ByteCount:= len div (w*h)
  else
    if data.Size >= SizeOf(TPCXFileHeader) + 256*3 then
      ByteCount:= 1
    else
      ByteCount:= 3;
      
  Assert(ByteCount*w*h=len);
  Assert(ByteCount in [1,3] {, 'Unsupported bitmap type. Bits per pixel = '
                             + IntToStr(ByteCount*8)});
  with b do
  begin
    Width:=0;
    Height:=0;

    if ByteCount = 1 then
    begin
      PixelFormat:= pf8bit;
      Palette:= RSMakePalette(p + len)
    end else
      PixelFormat:= pf24bit;

    Width:=w;
    Height:=h;
    RSBufferToBitmap(p, b, Rect(0,0,w,h));
  end;
end;

procedure TRSLod.UnpackSprite(const name: string; data: TStream; b: TBitmap; size: int);
{
  function FindPals(a1, a2: int): int;
  begin
    if not BitmapsLod.RawFiles.FindFile(Format('pal%.3d', [a1]), Result) and
       ((a1 = a2) or not BitmapsLod.RawFiles.FindFile(Format('pal%.3d', [a2]), Result)) then
      raise ERSLodException.CreateFmt(SRSLodPalNotFound, [a1]);
  end;
}
var
  hdr: TSprite;
  Lines: array of TSpriteLine;
  a: TMemoryStream;
  i, j, w, dy: int;
  p, pbuf: PChar;
begin
  if (FBitmapsLod = nil) and Assigned(OnNeedBitmapsLod) then
    OnNeedBitmapsLod(self);
  if FBitmapsLod = nil then
    raise ERSLodException.Create(SRSLodSpriteExtractNeedLods);
  data.ReadBuffer(hdr, SizeOf(hdr));
  {
  if not FindSpritePal(name, pal) then
    pal:= hdr.Palette;
  if pal = hdr.Palette + 1 then
    j:= FindPals(hdr.Palette, pal)
  else
    j:= FindPals(pal, hdr.Palette);
  }
  if Assigned(OnSpritePalette) then
    OnSpritePalette(self, name, hdr.Palette, hdr);
  if not BitmapsLod.RawFiles.FindFile(Format('pal%.3d', [int(hdr.Palette)]),j){ and
     (not FindSpritePal(name, pal) or
      not BitmapsLod.RawFiles.FindFile(Format('pal%.3d', [int(pal)]), j))} then
    raise ERSLodException.CreateFmt(SRSLodPalNotFound, [int(hdr.Palette), name]);

  FLastPalette:= hdr.Palette;
  SetLength(Lines, hdr.h);
  data.ReadBuffer(Lines[0], hdr.h*SizeOf(TSpriteLine));

  a:= TMemoryStream.Create;
  try
    BitmapsLod.Extract(j, a);
    b.HandleType:= bmDIB;
    b.PixelFormat:= pf8bit;
    b.Palette:= RSMakePalette(a.Memory);
    b.Width:= hdr.w;
    b.Height:= hdr.h;

    if hdr.h = 0 then
      exit;
      
    a.Clear;
    Unzip(data, a, size - SizeOf(hdr) - hdr.h*SizeOf(TSpriteLine), hdr.UnpSize, true);
    pbuf:= a.Memory;

    p:= b.ScanLine[0];
    dy:= 0;
    if hdr.h > 1 then
      dy:= int(b.ScanLine[1]) - int(p);
    w:= hdr.w;
    for i := 0 to hdr.h - 1 do
    begin
      with Lines[i] do
        if a1 >= 0 then
        begin
          FillChar(p^, a1, 0);
          CopyMemory(p + a1, pbuf + pos, a2 - a1 + 1);
          FillChar((p + a2 + 1)^, w - a2 - 1, 0);
        end else
          FillChar(p^, w, 0);
      inc(p, dy);
    end;
      
  finally
    a.Free;
  end;
end;

procedure TRSLod.UnpackStr(a, Output: TStream; const FileHeader);
var
  m: TRSStringStream;
  hdr: TMMLodFile absolute FileHeader;
  s: string;
begin
  m:= TRSStringStream.Create(s);
  try
    Unzip(a, m, hdr.DataSize, hdr.UnpSize, true);
    s:= RSStringReplace(s, #0, #13#10);
  finally
    m.Free;
  end;
  Output.WriteBuffer(s[1], length(s));
end;

procedure TRSLod.Unzip(input, output: TStream; size, unp: int; noless: Boolean);
begin
  if unp <> 0 then
    if not FFiles.IgnoreUnzipErrors then
    begin
      input:= TDecompressionStream.Create(input);
      try
        RSCopyStream(output, input, unp);
      finally
        input.Free;
      end;
    end else
      UnzipIgnoreErrors(output, input, unp, noless)
  else
    RSCopyStream(output, input, size);
end;

procedure TRSLod.Zip(output: TMemoryStream; buf: TStream; size, pk, unp: int);
var
  a: TStream;
  i: int;
begin
  i:= output.Seek(int(0), soEnd);
  if (size > 256) and (pk >= 0) then
  begin
    a:= TCompressionStream.Create(clDefault, output);
    try
      RSCopyStream(a, buf, size);
    finally
      a.Free;
    end;
    i:= output.Seek(int(0), soEnd) - i;
    if i < size then
    begin
      pint(PChar(output.Memory) + pk)^:= i;
      pint(PChar(output.Memory) + unp)^:= size;
      exit;
    end else
    begin
      i:= output.Seek(-i, soEnd);
      buf.Seek(-size, soCurrent);
    end;
  end;
  output.SetSize(i + size);
  buf.ReadBuffer((PChar(output.Memory) + i)^, size);
  if pk >= 0 then
    pint(PChar(output.Memory) + pk)^:= size;
  pint(PChar(output.Memory) + unp)^:= 0;
  output.Seek(0, soEnd);
end;

procedure TRSLod.Zip(output:TMemoryStream; buf:TStream; size: int;
   DataSize, UnpackedSize: ptr);
var
  p: PChar;
begin
  p:= PChar(output.Memory);
  Zip(output, buf, size, int(PChar(DataSize) - p), int(PChar(UnpackedSize) - p));
end;

{ TRSSnd }

function TRSSnd.Add(const Name: string; Data: TStream; Size, pal: int): int;
begin
  Result:= FFiles.Add(ChangeFileExt(Name, ''), Data, Size);
end;

function TRSSnd.CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive;
begin
  Result:= inherited CloneForProcessing(NewFile, FilesCount);
  TRSSnd(Result).FMM:= FMM;
end;

function TRSSnd.GetExtractName(Index: int): string;
begin
  Result:= FFiles.Name[Index] + '.wav';
end;

procedure TRSSnd.InitOptions(var Options: TRSMMFilesOptions);
begin
  with Options do
  begin
    NameSize:= $28;
    AddrOffset:= $28;
    SizeOffset:= $2C;
    if FMM then
    begin
      UnpackedSizeOffset:= $30;
      ItemSize:= $34;
    end else
      ItemSize:= $30;

    DataStart:= 4;
    AddrStart:= 0;
    MinFileSize:= 0;
  end;
end;

procedure TRSSnd.New(const FileName: string; MightAndMagic: Boolean);
var
  o: TRSMMFilesOptions;
begin
  FMM:= MightAndMagic;
  RSMMFilesOptionsInitialize(o);
  InitOptions(o);
  FFiles.New(FileName, o);
end;

type
  TSndOneFilePart = record
    Count: DWord;
    Name: array[1..$28] of char;
    Addr: DWord;
    Size: DWord;
    UnpSize: DWord;
  end;

procedure TRSSnd.ReadHeader(Sender: TRSMMFiles; Stream: TStream;
   var Options: TRSMMFilesOptions; var FilesCount: int);
const
  aWav = $4952;
  aZip = $9C78;
var
  OneFilePart: TSndOneFilePart;
  Sig: word;
  readCount: int;
begin
  readCount:= Stream.Read(OneFilePart, SizeOf(OneFilePart));
  if readCount < 4 then
    raise ERSLodException.Create(SRSLodUnknownSnd);

  FilesCount:= OneFilePart.Count;
  // heuristics to find the type of archive
  if (OneFilePart.Count > 0) and (readCount >= SizeOf(TSndOneFilePart)) then
  begin
    Stream.Seek(OneFilePart.Addr, 0);
    sig:= 0;
    Stream.Read(Sig, 2);
    FMM:= (sig = aZip) or (OneFilePart.UnpSize = OneFilePart.Size);
    {MyReadBuffer(Stream, Sig, 2);
    case sig of
      aWav:  FMM:= OneFilePart.UnpSize = OneFilePart.Size; // Not for sure
      aZip:  FMM:= true;
      else
        raise ERSLodException.Create(SRSLodUnknownSnd);
    end;
    }
  end else
    FMM:= (OneFilePart.Count = 0) and
          not FileExists(ExtractFilePath(FFiles.FileName) + 'H3sprite.lod');

  InitOptions(Options);
end;

procedure TRSSnd.WriteHeader(Sender: TRSMMFiles; Stream: TStream);
var i: int;
begin
  i:= Sender.Count;
  Stream.WriteBuffer(i, 4);
end;

{ TRSVid }

function TRSVid.Add(const Name: string; Data: TStream; Size, pal: int): int;
begin
  if FNoExtension and (LowerCase(ExtractFileExt(Name)) = '.smk') then
    Result:= inherited Add(ChangeFileExt(Name, ''), Data, Size, pal)
  else
    Result:= inherited Add(Name, Data, Size, pal)
end;

function TRSVid.CloneForProcessing(const NewFile: string; FilesCount: int): TRSMMArchive;
begin
  Result:= inherited CloneForProcessing(NewFile, FilesCount);
  TRSVid(Result).FNoExtension:= FNoExtension;
end;

constructor TRSVid.CreateInternal(Files: TRSMMFiles);
begin
  inc(FTagSize, 4);
  inherited;
  FFiles.OnGetFileSize:= GetFileSize;
end;

type
  TVideoHeaderPart = record
    Signature: array[0..2] of char;
    Version: byte;
    case Integer of
      0:
      (
        BinkSize:DWord;
      );
      1:
      (
        Width: int;
        Height: int;
        Count: int;
        FrameRate: int;
        Flags: int;
        AudioBiggestSize: array[0..6] of int;
        TreesSize: uint;
      );
  end;

function TRSVid.DoGetFileSize(Stream: TStream; sz: uint): uint;
var
  Header: TVideoHeaderPart;
  Sizes: array of uint;
  i, n: uint;
begin
  Result:= sz;
  if Stream.Read(Header, SizeOf(Header)) <> SizeOf(Header) then  exit;
  with Stream, Header do
    if Signature[0] = 'S' then
    begin
      Seek($68 - SizeOf(Header), 1);
      n:= Count;
      if (Flags and 1) <> 0 then
        inc(n);
      Result:= TreesSize + $68 + n*5;
      if Result < sz then
      begin
        SetLength(Sizes, n);
        Read(Sizes[0], n*4);
        for i:= 0 to n - 1 do
        begin
          inc(Result, Sizes[i] and not 3);
          if Result > sz then  break;
        end;
      end;
    end else
      if Signature[0] = 'B' then
        Result:= Header.BinkSize + 8;

  if Result > sz then
    Result:= sz;
end;

function TRSVid.GetExtractName(Index: int): string;
begin
  Result:= FFiles.Name[Index];
  if ExtractFileExt(Result) = '' then
    Result:= Result + '.smk';
end;

procedure TRSVid.GetFileSize(Sender: TRSMMFiles; Index: int; var Size: int);
var
  sz, start, i, j: int;
  r: TStream;
begin
  Size:= pint(FFiles.UserData[Index])^;
  if Size = 0 then
  begin
    r:= FFiles.GetAsIsFileStream(Index, true);
    try
      start:= r.Seek(int(0), soCurrent);
      sz:= r.Seek(int(0), soEnd);
      for i:= 0 to FFiles.Count - 1 do
        if (zSet(j, FFiles.Address[i]) >= start) and (j < sz) and (i <> Index) then
          sz:= j;
      r.Seek(start, soBeginning);
      Size:= DoGetFileSize(r, sz - start);
    finally
      FFiles.FreeAsIsFileStream(Index, r);
    end;
    pint(FFiles.UserData[Index])^:= Size;
  end;
end;

procedure TRSVid.InitOptions(var Options: TRSMMFilesOptions);
begin
  with Options do
  begin
    NameSize:= $28;
    AddrOffset:= $28;
    ItemSize:= $2C;
    DataStart:= 4;
    AddrStart:= 0;
    MinFileSize:= 0;
  end;
end;

procedure TRSVid.Load(const FileName: string);
var
  s: string;
  i: int;
begin
  inherited;
  FNoExtension:= false;
  for i := 0 to FFiles.Count - 1 do
  begin
    s:= ExtractFileExt(FFiles.Name[i]);
    if s = '' then
    begin
      FNoExtension:= true;
      exit;
    end else
      if SameText(s, '.smk') then
        exit;
  end;
end;

procedure TRSVid.New(const FileName: string; NoExtension: Boolean);
var
  o: TRSMMFilesOptions;
begin
  FNoExtension:= NoExtension;
  RSMMFilesOptionsInitialize(o);
  InitOptions(o);
  FFiles.New(FileName, o);
end;

procedure TRSVid.ReadHeader(Sender: TRSMMFiles; Stream: TStream;
   var Options: TRSMMFilesOptions; var FilesCount: int);
begin
  MyReadBuffer(Stream, FilesCount, 4);
  InitOptions(Options);
end;

procedure TRSVid.WriteHeader(Sender: TRSMMFiles; Stream: TStream);
var i: int;
begin
  i:= Sender.Count;
  Stream.WriteBuffer(i, 4);
end;

{------------------------------------------------------------------------------}

procedure RSMMFilesOptionsInitialize(var Options: TRSMMFilesOptions);
begin
  with Options do
  begin
    NameSize:= 0;
    AddrOffset:= -1;
    SizeOffset:= -1;
    UnpackedSizeOffset:= -1;
    PackedSizeOffset:= -1;
    ItemSize:= 0;
    DataStart:= 0;
    AddrStart:= 0;
    MinFileSize:= 0;
  end;
end;

function RSLoadMMArchive(const FileName: string): TRSMMArchive;
var
  ext: string;
begin
  ext:= LowerCase(ExtractFileExt(FileName));
  if ext = '.snd' then
    Result:= TRSSnd.Create(FileName)
  else if ext = '.vid' then
    Result:= TRSVid.Create(FileName)
  else
    Result:= TRSLod.Create(FileName);
end;

end.
