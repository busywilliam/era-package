unit Era;
{
DESCRIPTION:  Era SDK
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

(***)  interface  (***)
uses Windows;

const
  (* Hooks *)
  HOOKTYPE_JUMP   = 0;  // jmp, 5 bytes
  HOOKTYPE_CALL   = 1;  // call, 5 bytes
  {
  Opcode: call, 5 bytes.
  Automatically creates safe bridge to high-level function "F".
  FUNCTION  F (Context: PHookHandlerArgs): TExecuteDefaultCodeFlag; STDCALL;
  If default code should be executed, it can contain any commands except jumps.
  }
  HOOKTYPE_BRIDGE = 2;
  
  OPCODE_JUMP     = $E9;
  OPCODE_CALL     = $E8;
  OPCODE_RET      = $C3;
  
  EXEC_DEF_CODE   = true;
  
  (* Erm triggers *)
  TRIGGER_FU1       = 0;
  TRIGGER_FU30000   = 29999;
  TRIGGER_TM1       = 30000;
  TRIGGER_TM100     = 30099;
  TRIGGER_HE0       = 30100;
  TRIGGER_HE198     = 30298;
  TRIGGER_BA0       = 30300;
  TRIGGER_BA1       = 30301;
  TRIGGER_BR        = 30302;
  TRIGGER_BG0       = 30303;
  TRIGGER_BG1       = 30304;
  TRIGGER_MW0       = 30305;
  TRIGGER_MW1       = 30306;
  TRIGGER_MR0       = 30307;
  TRIGGER_MR1       = 30308;
  TRIGGER_MR2       = 30309;
  TRIGGER_CM0       = 30310;
  TRIGGER_CM1       = 30311;
  TRIGGER_CM2       = 30312;
  TRIGGER_CM3       = 30313;
  TRIGGER_CM4       = 30314;
  TRIGGER_AE0       = 30315;
  TRIGGER_AE1       = 30316;
  TRIGGER_MM0       = 30317;
  TRIGGER_MM1       = 30318;
  TRIGGER_CM5       = 30319;
  TRIGGER_MP        = 30320;
  TRIGGER_SN        = 30321;
  TRIGGER_MG0       = 30322;
  TRIGGER_MG1       = 30323;
  TRIGGER_TH0       = 30324;
  TRIGGER_TH1       = 30325;
  TRIGGER_IP0       = 30330;
  TRIGGER_IP1       = 30331;
  TRIGGER_IP2       = 30332;
  TRIGGER_IP3       = 30333;
  TRIGGER_CO0       = 30340;
  TRIGGER_CO1       = 30341;
  TRIGGER_CO2       = 30342;
  TRIGGER_CO3       = 30343;
  TRIGGER_BA50      = 30350;
  TRIGGER_BA51      = 30351;
  TRIGGER_BA52      = 30352;
  TRIGGER_BA53      = 30353;
  TRIGGER_GM0       = 30360;
  TRIGGER_GM1       = 30361;
  TRIGGER_PI        = 30370;
  TRIGGER_DL        = 30371;
  TRIGGER_HM        = 30400;
  TRIGGER_HM0       = 30401;
  TRIGGER_HM198     = 30599;
  TRIGGER_HL        = 30600;
  TRIGGER_HL0       = 30601;
  TRIGGER_HL198     = 30799;
  TRIGGER_BF        = 30800;
  TRIGGER_MF1       = 30801;
  TRIGGER_TL0       = 30900;
  TRIGGER_TL1       = 30901;
  TRIGGER_TL2       = 30902;
  TRIGGER_TL3       = 30903;
  TRIGGER_TL4       = 30904;
  TRIGGER_OB_POS    = integer($10000000);
  TRIGGER_LE_POS    = integer($20000000);
  TRIGGER_OB_LEAVE  = integer($08000000);
  
  (* Era Triggers *)
  TRIGGER_BEFORE_SAVE_GAME          = 77000;  // DEPRECATED;
  TRIGGER_SAVEGAME_WRITE            = 77001;
  TRIGGER_SAVEGAME_READ             = 77002;
  TRIGGER_KEYPRESS                  = 77003;
  TRIGGER_OPEN_HEROSCREEN           = 77004;
  TRIGGER_CLOSE_HEROSCREEN          = 77005;
  TRIGGER_STACK_OBTAINS_TURN        = 77006;
  TRIGGER_REGENERATE_PHASE          = 77007;
  TRIGGER_AFTER_SAVE_GAME           = 77008;
  TRIGGER_SKEY_SAVEDIALOG           = 77009;  // DEPRECATED;
  TRIGGER_HEROESMEET                = 77010;  // DEPRECATED;
  TRIGGER_BEFOREHEROINTERACT        = 77010;
  TRIGGER_AFTERHEROINTERACT         = 77011;
  TRIGGER_ONSTACKTOSTACKDAMAGE      = 77012;
  TRIGGER_ONAICALCSTACKATTACKEFFECT = 77013;
  TRIGGER_ONCHAT                    = 77014;


type
  PTxtFile  = ^TTxtFile;
  TTxtFile  = packed record
    Dummy:    array [0..$17] of byte;
    RefCount: integer;
    (* Dummy *)
  end; // .record TTxtFile

  PHookHandlerArgs  = ^THookHandlerArgs;
  THookHandlerArgs  = packed record
    EDI, ESI, EBP, ESP, EBX, EDX, ECX, EAX: integer;
    RetAddr:                                pointer;
  end; // .record THookHandlerArgs

  PEvent  = ^TEvent;
  TEvent  = packed record
      Name:     pchar;
  {n} Data:     pointer;
      DataSize: integer;
  end; // .record TEvent

  PEventParams  = ^TEventParams;
  TEventParams  = array[0..15] of integer;
  TEventHandler = procedure (Event: PEvent) stdcall;

  PErmVVars = ^TErmVVars;
  TErmVVars = array [1..10000] of integer;
  TErmZVar  = array [0..511] of char;
  PErmZVars = ^TErmZVars;
  TErmZVars = array [1..1000] of TErmZVar;
  PErmYVars = ^TErmYVars;
  TErmYVars = array [1..100] of integer;
  PErmXVars = ^TErmXVars;
  TErmXVars = array [1..16] of integer;
  PErmFlags = ^TErmFlags;
  TErmFlags = array [1..1000] of boolean;
  PErmEVars = ^TErmEVars;
  TErmEVars = array [1..100] of single;
  
  PGameState  = ^TGameState;
  TGameState  = packed record
    RootDlgId:    integer;
    CurrentDlgId: integer;
  end; // .record TGameState


{$IFDEF FPC}
var
(* WoG vars *)
  v:  TErmVVars ABSOLUTE $887668;
  z:  TErmZVars ABSOLUTE $9273E8;
  y:  TErmYVars ABSOLUTE $A48D80;
  x:  TErmXVars ABSOLUTE $91DA38;
  f:  TErmFlags ABSOLUTE $91F2E0;
  e:  TErmEVars ABSOLUTE $A48F18;
{$ELSE}
const
  (* WoG vars *)
  v:  PErmVVars = Ptr($887668);
  z:  PErmZVars = Ptr($9273E8);
  y:  PErmYVars = Ptr($A48D80);
  x:  PErmXVars = Ptr($91DA38);
  f:  PErmFlags = Ptr($91F2E0);
  e:  PErmEVars = Ptr($A48F18);
{$ENDIF}


procedure WriteAtCode (Count: integer; Src, Dst: pointer); stdcall;

procedure Hook
(
  HandlerAddr:  pointer;
  HookType:     integer;
  PatchSize:    integer;
  CodeAddr:     pointer
); stdcall;

procedure ApiHook (HandlerAddr: pointer; HookType: integer; CodeAddr: pointer); stdcall;
procedure KillThisProcess;
procedure FatalError (Err: pchar); stdcall;
function  RecallAPI (Context: PHookHandlerArgs; NumArgs: integer): integer; stdcall;
procedure RegisterHandler (Handler: TEventHandler; EventName: pchar); stdcall;
procedure FireEvent (EventName: pchar; {n} EventData: pointer; DataSize: integer); stdcall;
function  LoadTxt (Name: pchar): {n} PTxtFile; stdcall;
procedure ForceTxtUnload (Name: pchar); stdcall;
procedure ExecErmCmd (CmdStr: pchar); stdcall;
procedure ReloadErm;
procedure ExtractErm;
procedure FireErmEvent (EventID: integer); stdcall;
procedure ClearAllIniCache;
procedure ClearIniCache (FileName: pchar); stdcall;
function  ReadStrFromIni (Key, SectionName, FilePath, Res: pchar): boolean; stdcall;
function  WriteStrToIni (Key, Value, SectionName, FilePath: pchar): boolean; stdcall;
function  SaveIni (FilePath: pchar): boolean; stdcall;
procedure NameColor (Color32: integer; Name: pchar); stdcall;
procedure WriteSavegameSection (DataSize: integer; {n} Data: pointer; SectionName: pchar); stdcall;

function  ReadSavegameSection
(
      DataSize:     integer;
  {n} Dest:         pointer;
      SectionName:  pchar
): integer; stdcall;

procedure GetGameState (var GameState: TGameState); stdcall;
function  GetButtonID (ButtonName: pchar): integer; stdcall;
function  PatchExists (PatchName: pchar): boolean; stdcall;
function  PluginExists (PluginName: pchar): boolean; stdcall;
procedure RedirectFile (OldFileName, NewFileName: pchar); stdcall;
procedure GlobalRedirectFile (OldFileName, NewFileName: pchar); stdcall;
procedure SaveEventParams;
procedure RestoreEventParams;
procedure RedirectMemoryBlock (OldAddr: pointer; BlockSize: integer; NewAddr: pointer); stdcall;
function  GetRealAddr (Addr: pointer): pointer; stdcall;
procedure ReportPluginVersion (VersionLine: pchar); external 'era.dll';
procedure GetEraVersion: pchar; external 'era.dll' name 'GetVersion';


var
  EventParams:  PEventParams;


(***) implementation (***)


procedure WriteAtCode;          external 'era.dll' NAME 'WriteAtCode';
procedure Hook;                 external 'era.dll' NAME 'Hook';
procedure ApiHook;              external 'era.dll' NAME 'ApiHook';
procedure KillThisProcess;      external 'era.dll' NAME 'KillThisProcess';
procedure FatalError;           external 'era.dll' NAME 'FatalError';
function  RecallAPI;            external 'era.dll' NAME 'RecallAPI';
procedure RegisterHandler;      external 'era.dll' NAME 'RegisterHandler';
procedure FireEvent;            external 'era.dll' NAME 'FireEvent';
function  LoadTxt;              external 'era.dll' NAME 'LoadTxt';
procedure ForceTxtUnload;       external 'era.dll' NAME 'ForceTxtUnload';
procedure ExecErmCmd;           external 'era.dll' NAME 'ExecErmCmd';
procedure ReloadErm;            external 'era.dll' NAME 'ReloadErm';
procedure ExtractErm;           external 'era.dll' NAME 'ExtractErm';
procedure FireErmEvent;         external 'era.dll' NAME 'FireErmEvent';
procedure ClearAllIniCache;     external 'era.dll' NAME 'ClearAllIniCache';
procedure ClearIniCache;        external 'era.dll' NAME 'ClearIniCache';
function  ReadStrFromIni;       external 'era.dll' NAME 'ReadStrFromIni';
function  WriteStrToIni;        external 'era.dll' NAME 'WriteStrToIni';
function  SaveIni;              external 'era.dll' NAME 'SaveIni';
procedure NameColor;            external 'era.dll' NAME 'NameColor';
procedure WriteSavegameSection; external 'era.dll' NAME 'WriteSavegameSection';
function  ReadSavegameSection;  external 'era.dll' NAME 'ReadSavegameSection';
procedure GetGameState;         external 'era.dll' NAME 'GetGameState';
function  GetButtonID;          external 'era.dll' NAME 'GetButtonID';
function  PatchExists;          external 'era.dll' NAME 'PatchExists';
function  PluginExists;         external 'era.dll' NAME 'PluginExists';
procedure RedirectFile;         external 'era.dll' NAME 'RedirectFile';
procedure GlobalRedirectFile;   external 'era.dll' NAME 'GlobalRedirectFile';
procedure RedirectMemoryBlock;  external 'era.dll' NAME 'RedirectMemoryBlock';
function  GetRealAddr;          external 'era.dll' NAME 'GetRealAddr';
procedure SaveEventParams;      external 'angel.dll' NAME 'SaveEventParams';
procedure RestoreEventParams;   external 'angel.dll' NAME 'RestoreEventParams';


begin
  EventParams :=  Windows.GetProcAddress(Windows.LoadLibrary('angel.dll'), 'EventParams');
end.
