unit UnitMainTools;

interface

uses SysUtils, Classes, Windows, Forms, Controls, SpTBXTabs, TBX, SciLexer,
  SciLexerMemo, ExtCtrls, Graphics, sciKeyBindings, ComCtrls, TB2Item,
  sciLexerMod, ScintillaLanguageManager, Menus, SpTBXItem, Registry,
  ShellApi, DDEMan, IdFTP, IdFTPList, IdException, JvInspector, JvComCtrls;

type TDocument = class(TCollectionItem)
  private
    FSelLength: Integer;
    FSelStart: Integer;
    FFileName: String;
    FCode: TStringList;
    FReadOnly: Boolean;
    FTopLine: Integer;
    FHighlighter: String;
    FTitle: String;
    FModified: Boolean;
    FNotesText: String;
    procedure SetFileName(const Value: String);
  published
    property FileName: String read FFileName write SetFileName;
    property Title: String read FTitle write FTitle;
    property Code: TStringList read FCode write FCode;
    property SelStart: Integer read FSelStart write FSelStart;
    property SelLength: Integer read FSelLength write FSelLength;
    property Highlighter: String read FHighlighter write FHighlighter;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property TopLine: Integer read FTopLine write FTopLine;
    property Modified: Boolean read FModified write FModified;
    property NotesText: String read FNotesText write FNotesText;
  public
    constructor Create(ACollection: TCollection; AHighlighter: String); reintroduce;
    destructor Destroy; reintroduce;
    function Untitled: Boolean;
    function Save: Boolean;
end;

type TDocCollection = class(TCollection)
  private
    FHighlighter: String;
    FActiveDocument: TDocument;
  public
    constructor Create(AHighlighter: String); reintroduce;
    function Add(AFilename: String; AHighlighter: String = ''): TDocument; reintroduce;
    function Open(AFilename: String; AHighlighter: String = ''): Integer;
    function Save(AIndex: Integer; AFilename: String = ''): Boolean;
    procedure Close(AIndex: Integer);
    procedure Activate(Document: Integer; RestoreCaret: Boolean; SaveLastDoc: Boolean = True); overload;
    procedure Activate(Document: TDocument; RestoreCaret: Boolean; SaveLastDoc: Boolean = True); overload;
  published
    property Highlighter: String read FHighlighter write FHighlighter;
    property ActiveDocument: TDocument read FActiveDocument write FActiveDocument;
end;

type TStringArray = array of string;

function GetMenuItem(Caption: String; eParent: TTBCustomItem = nil): TTBCustomItem;

function GetCat: String;
function GetCIItem(eName: String; eParent: TJvCustomInspectorItem = nil): TJvCustomInspectorItem;
function GetCIItemByValue(eValue: String; eParent: TJvCustomInspectorItem = nil): TJvCustomInspectorItem;
function FindSettingsNode(eText: String; eParent: TTreeNode = nil): TTreeNode;

procedure LoadPlugins;
function GetAllIncludeFiles: TStringArray;
function GetCurrLang(FileName: String = ''): TSciLangItem;
procedure FillCodeExplorer(Lang: String);
function IEInstalled: Boolean;
function GetAMXXDir(ListenServer: Boolean): String;

function CloseDocument(eDocument: TDocument; SaveActiveDoc: Boolean = False): Boolean;
function AddExtension(eFilename, eHighlighter: String): String;

function ShowColorDialog(var Color: TColor; ePaintImage: TImage): Boolean;

procedure LoadCodeSnippets(Lang: String);
procedure SetProgressStatus(eStatus: String);
function IsNumeric(eText: String): Boolean;
procedure ActivateProjects(Index: Integer; JumpToLastDoc: Boolean);
procedure ReloadIni;
procedure SelectLanguage(Lang: String);

procedure ShowProgress;
procedure HideProgress;

procedure mIRCDDE(Service, Topic, Cmd: string);
function mIRCGet(Service, Topic, Item: string): String;

function GetAllDirs: TStringList;
procedure SetProxySettings;
function TryConnect: Integer;

var PAWNProjects: TDocCollection;
    CPPProjects: TDocCollection;
    OtherProjects: TDocCollection;

    Started: Boolean;
    ActiveDoc: TDocument;
    Cancel: Boolean;

    OldPercent: Integer; // We don't need to update caption when the new percentage equals to the old
    CurrProjects: Integer;


implementation

uses UnitfrmMain, UnitfrmSettings, UnitLanguages, UnitfrmSelectColor,
     UnitCodeSnippets, UnitTextAnalyze, UnitCodeUtils, UnitfrmAutoIndent,
  UnitPlugins;

function GetCat: String;
begin
  if frmMain.mnuPAWN.Checked then
    Result := 'Pawn'
  else if frmMain.mnuCPP.Checked then
    Result := 'C++'
  else if frmMain.mnuHTML.Checked then
    Result := 'HTML'
  else
    Result := 'Other';
end;

function GetCIItem(eName: String; eParent: TJvCustomInspectorItem = nil): TJvCustomInspectorItem;
var i: integer;
begin
  eName := LowerCase(eName);
  Result := nil;

  if eParent = nil then begin
    for i := 0 to frmMain.jviCode.Root.Count -1 do begin
      if LowerCase(frmMain.jviCode.Root.Items[i].DisplayName) = eName then
        Result := frmMain.jviCode.Root.Items[i]
      else if frmMain.jviCode.Root.Items[i].Count <> 0 then
        Result := GETCIItem(eName, frmMain.jviCode.Root.Items[i]);

      if Assigned(Result) then
        exit;
    end;
  end
  else begin
    for i := 0 to eParent.Count -1 do begin
      if LowerCase(eParent.Items[i].DisplayName) = eName then
        Result := eParent.Items[i]
      else if eParent.Items[i].Count <> 0 then
        Result := GETCIItem(eName, eParent.Items[i]);

      if Assigned(Result) then
        exit;
    end;
  end;
end;

function GetCIItemByValue(eValue: String; eParent: TJvCustomInspectorItem = nil): TJvCustomInspectorItem;
var i: integer;
begin
  eValue := LowerCase(eValue);
  Result := nil;

  if eParent = nil then begin
    for i := 0 to frmMain.jviCode.Root.Count -1 do begin
      if LowerCase(frmMain.jviCode.Root.Items[i].DisplayValue) = eValue then
        Result := frmMain.jviCode.Root.Items[i]
      else if frmMain.jviCode.Root.Items[i].Count <> 0 then
        Result := GetCIItemByValue(eValue, frmMain.jviCode.Root.Items[i]);

      if Assigned(Result) then
        exit;
    end;
  end
  else begin
    for i := 0 to eParent.Count -1 do begin
      if LowerCase(eParent.Items[i].DisplayValue) = eValue then
        Result := eParent.Items[i]
      else if eParent.Items[i].Count <> 0 then
        Result := GetCIItemByValue(eValue, eParent.Items[i]);

      if Assigned(Result) then
        exit;
    end;
  end;
end;

function FindSettingsNode(eText: String; eParent: TTreeNode = nil): TTreeNode;
var i: integer;
begin
  Result := nil;    
  if eText = '' then exit;

  eText := LowerCase(eText);
  if eParent = nil then begin
    for i := 0 to frmSettings.trvSettings.Items.Count -1 do begin
      if LowerCase(frmSettings.trvSettings.Items[i].Text) = eText then
        Result := frmSettings.trvSettings.Items[i]
      else if frmSettings.trvSettings.Items[i].Count <> 0 then
        Result := FindSettingsNode(eText, frmSettings.trvSettings.Items[i]);

      if Assigned(Result) then
        exit;
    end;
  end
  else begin
    for i := 0 to eParent.Count -1 do begin
      if LowerCase(eParent[i].Text) = eText then
        Result := eParent[i]
      else if eParent[i].Count <> 0 then
        Result := FindSettingsNode(eText, eParent[i]);

      if Assigned(Result) then
        exit;
    end;
  end;
end;

function GetMenuItem(Caption: String; eParent: TTBCustomItem = nil): TTBCustomItem;
var i: integer;
begin
  Result := nil;
  if eParent = nil then begin
    for i := 0 to frmMain.tbxMenu.Items.Count -1 do begin
      if frmMain.tbxMenu.Items[i].Caption = Caption then begin
        Result := frmMain.tbxMenu.Items[i];
        break;
      end
      else if frmMain.tbxMenu.Items[i].Count <> 0 then begin
        Result := GetMenuItem(Caption, frmMain.tbxMenu.Items[i]);
        if Assigned(Result) then
          break;
      end;
    end;
  end
  else begin
    for i := 0 to eParent.Count -1 do begin
      if eParent.Items[i].Caption = Caption then begin
        Result := eParent.Items[i];
        break;
      end
      else if eParent.Items[i].Count <> 0 then begin
        Result := GetMenuItem(Caption, eParent.Items[i]);
        if Assigned(Result) then
          break;
      end;
    end;
  end;
end;

procedure LoadPlugins;
var i: integer;
    ePConfig: TStringList;
    eRec: TSearchRec;
    eFound: Boolean;
    eItem: TListItem;
begin
  ePConfig := TStringList.Create;
  ePConfig.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'config\plugins.cfg');
  if FindFirst(ExtractFilePath(ParamStr(0)) + 'plugins\*.dll', faAnyFile, eRec) = 0 then begin
    repeat
      if (eRec.Name[1] <> '.') and (eRec.Attr and faDirectory <> faDirectory) then begin
        eFound := False;
        for i := 0 to ePConfig.Count -1 do begin
          if Pos(#32 + eRec.Name, ePConfig[i]) <> 0 then begin
            // We don't need to handle unloaded plugins...
            if Pos('LOADED', ePConfig[i]) = 1 then begin // Loaded
              eItem := frmSettings.lvPlugins.Items.Add;
              eItem.Caption := '-';
              eItem.SubItems.Add(eRec.Name);
              eItem.SubItems.Add('-');
              eItem.SubItems.Add('Unloaded');
              LoadPlugin(eItem);
              eFound := True;
            end;
            break;
          end;
        end;

        if not eFound then begin
          with frmSettings.lvPlugins.Items.Add do begin
            Caption := '-';
            SubItems.Add(eRec.Name);
            SubItems.Add('-');
            SubItems.Add('Unloaded');
          end;
        end;
      end;
    until FindNext(eRec) <> 0;
  end;
  ePConfig.Free;
end;

function GetAllIncludeFiles: TStringArray;
var eSearchRec: TSearchRec;
    eStr: TStringList;
    i: integer;
begin
  eStr := TStringList.Create;
  if GetAMXXDir(False) <> '' then begin
    if FindFirst(GetAMXXDir(False) + 'scripting\include\*.inc', faAnyFile, eSearchRec) = 0 then begin
      repeat
        if (eSearchRec.Name[1] <> '.') and (eSearchRec.Attr and faDirectory <> faDirectory) then
          eStr.Add(eSearchRec.Name); 
      until (FindNext(eSearchRec) <> 0);
    end;
    if FindFirst(GetAMXXDir(False) + 'scripting\*.inc', faAnyFile, eSearchRec) = 0 then begin
      repeat
        if (eSearchRec.Name[1] <> '.') and (eSearchRec.Attr and faDirectory <> faDirectory) then
          eStr.Add(eSearchRec.Name); 
      until (FindNext(eSearchRec) <> 0);
    end;
  end;
  
  if (not ActiveDoc.Untitled) then begin
    if FindFirst(GetAMXXDir(False) + 'scripting\include\*.inc', faAnyFile, eSearchRec) = 0 then begin
      repeat
        if (eSearchRec.Name[1] <> '.') and (eSearchRec.Attr and faDirectory <> faDirectory) then
          eStr.Add(eSearchRec.Name); 
      until (FindNext(eSearchRec) <> 0);
    end;
  end;

  SetLength(Result, eStr.Count);
  for i := 0 to eStr.Count -1 do
    Result[i] := eStr[i];

  eStr.Free;
end;


function GetCurrLang(FileName: String = ''): TSciLangItem;
var eExt, eLang: String;
begin
  if FileName = '' then
    eExt := LowerCase(ExtractFileExt(ActiveDoc.FileName))
  else
    eExt := LowerCase(ExtractFileExt(FileName));
    
  if (eExt = '.sma') or (eExt = '.inc') then
    eLang := 'Pawn'
  else if (eExt = '.cpp') or (eExt = '.h') then
    eLang := 'C++'
  else if (eExt = '.htm') or (eExt = '.html') then
    eLang := 'HTML'
  else if (eExt = '.xml') then
    eLang := 'XML'
  else if (eExt = '.sql') then
    eLang := 'SQL'
  else
    eLang := 'null';
    
  Result := frmMain.sciEditor.LanguageManager.LanguageList.Find(eLang);
end;

procedure FillCodeExplorer(Lang: String);
function AddItem(eParent: TTreeNode; eText: String): TTreeNode;
begin
  if eParent = nil then
    Result := frmMain.trvExplorer.Items.Add(nil, eText)
  else
    Result := frmMain.trvExplorer.Items.AddChild(eParent, eText);
    
  with Result do begin
    ImageIndex := 42;
    SelectedIndex := 42;
  end;
end;

var eTemp: TTreeNode;
begin
  frmMain.trvExplorer.Items.BeginUpdate;
  if (Lang = 'Pawn') then begin // Pawn
    AddItem(nil, 'Constants');
    eTemp := AddItem(nil, 'Defined');
    AddItem(eTemp, 'CVars');
    AddItem(nil, 'Forwards');
    AddItem(nil, 'Included');
    eTemp := AddItem(nil, 'Methods');
    AddItem(eTemp, 'Default');
    AddItem(eTemp, 'Events');
    AddItem(eTemp, 'Stocks');
    AddItem(nil, 'Natives');
    AddItem(nil, 'Variables');
  end;
  frmMain.trvExplorer.Items.EndUpdate;
end;

function IEInstalled: Boolean;
var eReg: TRegistry;
    eVersion: String;
begin
  eReg := TRegistry.Create(KEY_READ);
  with eReg do begin
    RootKey := HKEY_LOCAL_MACHINE;
    OpenKey('Software\Microsoft\Internet Explorer', False);
    if ValueExists('Version') then
      eVersion := ReadString('Version')
    else
      eVersion := '';
    CloseKey;
    Free;
  end;
  Result := Pos('6.0', eVersion) = 1;
end;

function GetAMXXDir(ListenServer: Boolean): String;
begin
  if Started then begin
    if ListenServer then
      Result := frmSettings.txtAMXXDir.Text
    else if Length(frmSettings.txtPAWNCompilerPath.Text) > 8 then
      Result := IncludeTrailingPathDelimiter(Copy(ExtractFilePath(frmSettings.txtPAWNCompilerPath.Text), 1, Length(ExtractFilePath(frmSettings.txtPAWNCompilerPath.Text)) - 10))
    else
      Result := '';
  end
  else
    Result := '';
end;

function CloseDocument(eDocument: TDocument; SaveActiveDoc: Boolean = False): Boolean;
var Collection: TDocCollection;
begin
  case frmMain.tsMain.ActiveTabIndex of
    0: Collection := PAWNProjects;
    1: Collection := CPPProjects;
    else Collection := OtherProjects;
  end;
  Result := True;

  if (eDocument.Modified) then begin
    case MessageBox(frmMain.Handle, PChar(Format(lCloseModify, [ExtractFileName(eDocument.FileName)])), PChar(Application.Title), MB_ICONQUESTION + MB_YESNOCANCEL) of
      mrYes: begin
        frmMain.mnuSave.Click;
        if not eDocument.Untitled then
          Collection.Close(eDocument.Index);
      end;
      mrNo: Collection.Close(eDocument.Index);
      mrCancel: Result := False;
    end;
  end
  else
    Collection.Close(eDocument.Index);
end;

function AddExtension(eFilename, eHighlighter: String): String;
begin
  if ExtractFileExt(eFilename) = '' then begin
    if eHighlighter = 'Pawn' then
      Result := eFilename + '.sma';
    if eHighlighter = 'C++' then
      Result := eFilename + '.cpp';
    if eHighlighter = 'HTML' then
      Result := eFilename + '.html';
    if eHighlighter = 'SQL' then
      Result := eFilename + '.sql';
    if eHighlighter = 'XML' then
      Result := eFilename + '.xml';
  end
  else
    Result := eFilename;
end;

procedure LoadCodeSnippets(Lang: String);
var i: integer;
    CSItem: TSpTBXItem;
begin
  for i := frmMain.tbxCodeSnippets.Items.Count -1 downto 5 do
    frmMain.tbxCodeSnippets.Items.Delete(i);

  with GetSnippetList(Lang) do begin
    for i := 0 to Count -1 do begin
      CSItem := TSpTBXItem.Create(frmMain.tbxCodeSnippets);
      CSItem.Caption := Strings[i];
      CSItem.OnClick := frmMain.OnCodeSnippetClick;
      frmMain.tbxCodeSnippets.Items.Add(CSItem);
    end;
  end;
end;

function ShowColorDialog(var Color: TColor; ePaintImage: TImage): Boolean;
begin
  frmSelectColor.Hexa.SelectedColor := Color;
  frmSelectColor.HSL.SelectedColor := Color;
  frmSelectColor.chkDefault1.Checked := Color = clDefault;
  frmSelectColor.chkDefault2.Checked := Color = clDefault;
  frmSelectColor.OldSwatch.Color := Color;
  Result := frmSelectColor.ShowModal = mrOk;
  if Result then begin
    if frmSelectColor.chkDefault1.Checked then
      Color := clDefault
    else
      Color := frmSelectColor.NewSwatch.Color;
      
    ePaintImage.Canvas.Pen.Color := $008396A0;
    ePaintImage.Canvas.Brush.Color := Color;
    ePaintImage.Canvas.Rectangle(0, 0, ePaintImage.Width, ePaintImage.Height);
  end;
end;

procedure SetProgressStatus(eStatus: String);
var Percent: Integer;
begin
  if not Started then exit;
  
  if (frmMain.pbLoading.Position <> frmMain.pbLoading.Max) and (frmMain.pbLoading.Max <> 0) then
    Percent := Round((frmMain.pbLoading.Position / frmMain.pbLoading.Max) * 100)
  else
    Percent := 0;

  if frmMain.pbLoading.Caption = IntToStr(Percent) + '% - ' + eStatus then exit;
  OldPercent := Percent;
  
  frmMain.pbLoading.Caption := IntToStr(Percent) + '% - ' + eStatus;
end;


function IsNumeric(eText: String): Boolean;
var i: integer;
begin
  Result := Length(eText) > 0;
  if Result then begin
    for i := 1 to Length(eText) do
      Result := (Result) and (Pos(eText[i], '0123456789') <> 0);
  end;
end;

procedure ActivateProjects(Index: Integer; JumpToLastDoc: Boolean);
var Collection: TDocCollection;
    i: integer;
    TabItem: TSpTBXTabItem;
    OldIndex: Integer;
begin
  if not Plugin_ProjectsChange(CurrProjects, Index, True) then begin
    Started := False;
    frmMain.tsMain.ActiveTabIndex := CurrProjects;
    Started := True;
    exit;
  end;

  OldIndex := CurrProjects;

  with frmMain do begin
    // no save here, it saves when another tab is being activated...

    case Index of
        0: Collection := PAWNProjects; // PAWN
        1: Collection := CPPProjects;   // C++
      else Collection := OtherProjects; // Other
    end;


    Started := False; // dont run this command twice
    frmMain.tsMain.Items[Index].Checked := True; // select tab
    CurrProjects := Index;
    Started := True;

    tsDocuments.Items.Clear;
    for i := 0 to Collection.Count -1 do begin
      TabItem := TSpTBXTabItem.Create(tsDocuments);
      TabItem.Caption := TDocument(Collection.Items[i]).Title;
      TabItem.OnSelect := frmMain.OnTabSelect;
      tsDocuments.Items.Add(TabItem);
    end;
    
    if JumpToLastDoc then begin
      Started := False;
      tsDocuments.Items[Collection.ActiveDocument.Index].Checked := True;
      Collection.Activate(Collection.ActiveDocument.Index, True);
      Started := True;
    end;

    Plugin_ProjectsChange(OldIndex, Index, False);
  end;
end;

procedure ReloadIni;
var i: integer;
   	KeyCommand: TSciKeyCommand;
   	Item: TListItem;
   	Ident: string;
begin
  //> INI-Values <//
  { Tools }
  frmSettings.chkRestoreCaret.Checked := eConfig.ReadBool('Editor', 'LimitCaretRestore', True);
  frmSettings.txtLines.Text := eConfig.ReadString('Editor', 'LimitCaretRestoreVal', '600');
  frmSettings.txtDefaultName.Text := eConfig.ReadString('Misc', 'DefaultPluginName', 'New Plugin');
  frmSettings.txtDefaultVersion.Text := eConfig.ReadString('Misc', 'DefaultPluginVersion', '1.0');
  frmSettings.txtDefaultAuthor.Text := eConfig.ReadString('Misc', 'DefaultPluginAuthor', 'Your name');
  frmSettings.chkHighlightBraces.Checked := eConfig.ReadBool('Editor', 'HighlightBraces', True);
  frmSettings.chkClearUndoAfterSave.Checked := eConfig.ReadBool('Editor', 'ClearUndoAfterSave', False);
  { Misc }
  if (TBXCurrentTheme <> eConfig.ReadString('Misc', 'Theme', 'Office11Adaptive')) then
    TBXSetTheme(eConfig.ReadString('Misc', 'Theme', 'Office11Adaptive'));
  //> Update Settings-Dialog <//
  { Highlighter }
  frmSettings.cboLanguage.Clear;
  for i := 0 to frmMain.sciEditor.LanguageManager.LanguageList.Count -1 do
    frmSettings.cboLanguage.Items.Add(TSciLangItem(frmMain.sciEditor.LanguageManager.LanguageList.Items[i]).Name);
  frmSettings.cboLanguage.ItemIndex := 0;
  frmSettings.cboLanguageChange(frmMain);
  frmSettings.lstStyles.Items.Clear;
  { Tools }
  frmSettings.chkIndentGuides.Checked := IndentationGuides in frmMain.sciEditor.Indentation;
  frmSettings.chkHighlightBraces.Checked := frmMain.sciEditor.BraceHilite;
  frmSettings.chkClearUndoAfterSave.Checked := frmMain.sciEditor.ClearUndoAfterSave;
  frmSettings.chkAutoCloseBraces.Checked := frmMain.sciEditor.AutoCloseBraces;
  frmSettings.chkAutoCloseQuotes.Checked := frmMain.sciEditor.AutoCloseQuotes;
  frmSettings.chkWordWrap.Checked := frmMain.sciEditor.WordWrap = sciWrap;
  frmSettings.chkAutoIndent.Checked := eConfig.ReadBool('Editor', 'Auto-Indent', True); 
  frmAutoIndent.chkIndentOpeningBrace.Checked := eConfig.ReadBool('Editor', 'IndentOpeningBrace', True);
  frmAutoIndent.chkUnindentPressingClosingBrace.Checked := eConfig.ReadBool('Editor', 'UnindentClosingBrace', True);
  frmAutoIndent.chkUnindentLine.Checked := eConfig.ReadBool('Editor', 'UnindentEmptyLine', False);

  if foldFold in frmMain.sciEditor.Folding then begin
    case frmMain.sciEditor.FoldMarkerType of
      sciMarkArrows: frmSettings.cboCodeFolding.ItemIndex := 0;
      sciMarkBox: frmSettings.cboCodeFolding.ItemIndex := 1;
      sciMarkCircle: frmSettings.cboCodeFolding.ItemIndex := 2;
      sciMarkPlusMinus: frmSettings.cboCodeFolding.ItemIndex := 3;
    end;
  end
  else
    frmSettings.cboCodeFolding.ItemIndex := 4;
  frmSettings.PaintCaretFore(frmMain.sciEditor.Caret.ForeColor);
  frmSettings.CaretFore := frmMain.sciEditor.Caret.ForeColor;
  frmSettings.PaintCaretBack(frmMain.sciEditor.Caret.LineBackColor);
  frmSettings.CaretBack := frmMain.sciEditor.Caret.LineBackColor;
  frmSettings.txtPeriod.Text := IntToStr(frmMain.sciEditor.Caret.Period);
  frmSettings.chkShowCaret.Checked := frmMain.sciEditor.Caret.LineVisible;
  if frmSettings.chkIndentGuides.Checked then
    frmMain.sciEditor.Indentation := frmMain.sciEditor.Indentation + [IndentationGuides]
  else
    frmMain.sciEditor.Indentation := frmMain.sciEditor.Indentation - [IndentationGuides];
  frmMain.sciEditor.AutoCloseBraces := frmSettings.chkAutoCloseBraces.Checked;
  frmMain.sciEditor.AutoCloseQuotes := frmSettings.chkAutoCloseQuotes.Checked;
  frmMain.sciEditor.BraceHilite := frmSettings.chkHighlightBraces.Checked;
  frmMain.sciEditor.ClearUndoAfterSave := frmSettings.chkClearUndoAfterSave.Checked;
  { Shortcuts }
	frmSettings.lvShortcuts.Items.BeginUpdate;
	try
		frmSettings.lvShortcuts.Clear;
		for i := 0 to frmMain.sciEditor.KeyCommands.Count - 1 do begin
			KeyCommand := frmMain.sciEditor.KeyCommands.Items[i] as TSciKeyCommand;
      Ident:= 'Unknown';
			IntToIdent(KeyCommand.Command, Ident, Sci_KeyboardCommandMap);
      if Ident <> 'No Command' then begin // Important for Control Chars, the user mustn't change the values for it...
      	Item := frmSettings.lvShortcuts.Items.Add;
 	      Item.Caption:= Ident;
        Item.SubItems.Add(ShortCutToText(KeyCommand.ShortCut));
 	    	Item.Data := KeyCommand;
      end;
		end;
	finally
		frmSettings.lvShortcuts.Items.EndUpdate;
	end;
  { FTP Settings }
  frmSettings.txtHost.Text := eConfig.ReadString('FTP', 'Host', '');
  frmSettings.txtPort.Text := eConfig.ReadString('FTP', 'Port', '21');
  frmSettings.txtUsername.Text := eConfig.ReadString('FTP', 'Username', '');
  frmSettings.txtPassword.Text := eConfig.ReadString('FTP', 'Password', '');
  frmSettings.txtDefaultDir.Text := eConfig.ReadString('FTP', 'DefaultDir', '');
  frmSettings.chkPassive.Checked := eConfig.ReadBool('FTP', 'Passive', True);

  with frmMain.IdFTP do begin
    Host := frmSettings.txtHost.Text;
    Port := StrToInt(frmSettings.txtPort.Text);
    Username := frmSettings.txtUsername.Text;
    Password := frmSettings.txtPassword.Text;
    Passive := frmSettings.chkPassive.Checked;
  end;
  { FTP Proxy }
  frmSettings.cboProxy.ItemIndex := eConfig.ReadInteger('Proxy', 'ProxyType', 0);
  frmSettings.txtProxyHost.Text := eConfig.ReadString('Proxy', 'Host', '');
  frmSettings.txtProxyPort.Text := eConfig.ReadString('Proxy', 'Port', '8080');
  frmSettings.txtUsername.Text := eConfig.ReadString('Proxy', 'Username', '');
  frmSettings.txtProxyPassword.Text := eConfig.ReadString('Proxy', 'Password', '');

  SetProxySettings;
  { Compiler }
  frmSettings.txtPAWNCompilerPath.Text := eConfig.ReadString('Pawn-Compiler', 'Path', '');
  frmSettings.txtPAWNArgs.Text := eConfig.ReadString('Pawn-Compiler', 'Args', '');
  frmSettings.txtPAWNOutput.Text := IncludeTrailingPathDelimiter(eConfig.ReadString('Pawn-Compiler', 'DefaultOutput', ''));
  if frmSettings.txtPAWNOutput.Text = '\' then
    frmSettings.txtPAWNOutput.Text := '';
  frmSettings.txtCPPCompilerPath.Text := eConfig.ReadString('CPP-Compiler', 'Path', '');
  frmSettings.txtCPPCompilerArguments.Text := eConfig.ReadString('CPP-Compiler', 'Args', '');
  frmSettings.txtCPPOutput.Text := IncludeTrailingPathDelimiter(eConfig.ReadString('CPP-Compiler', 'DefaultOutput', ''));
  if frmSettings.txtCPPOutput.Text = '\' then
    frmSettings.txtCPPOutput.Text := '';
  { HL }
  frmSettings.txtHLExec.Text := eConfig.ReadString('Half-Life', 'Filename', '');
  frmSettings.txtCustomParameters.Text := eConfig.ReadString('Half-Life', 'Params', '');
  frmSettings.txtAMXXDir.Text := IncludeTrailingPathDelimiter(eConfig.ReadString('Half-Life', 'AMXXListen', ''));
  if frmSettings.txtAMXXDir.Text = '\' then
    frmSettings.txtAMXXDir.Text := '';
  { Code-Snippets }
  frmSettings.ftcCodeSnippets.ActiveTab := 0;
  { Misc }
  frmSettings.txtDefaultName.Text := eConfig.ReadString('Misc', 'DefaultPluginName', 'New Plug-In');
  frmSettings.txtDefaultVersion.Text := eConfig.ReadString('Misc', 'DefaultPluginVersion', '1.0');
  frmSettings.txtDefaultAuthor.Text := eConfig.ReadString('Misc', 'DefaultPluginAuthor', 'Your Name');
  case eConfig.ReadInteger('Misc', 'SaveNotesTo', 0) of
    0: frmSettings.optFileComment.Checked := True;
    1: frmSettings.optConfig.Checked := True;
    else frmSettings.optDontSave.Checked := True;
  end;
  frmSettings.sldSpeed.Value := eConfig.ReadInteger('Misc', 'CPUSpeed', 5);
  if frmSettings.sldSpeed.Value <> 0 then
    eCPUSpeed := frmSettings.sldSpeed.Value
  else
    eCPUSpeed := 1; // otherwise the program would hang up
  frmSettings.chkShowStatusbar.Checked := eConfig.ReadBool('Misc', 'ShowStatusbar', True);
  frmMain.sbStatus.Visible := frmSettings.chkShowStatusbar.Checked;
end;

procedure SelectLanguage(Lang: String);
begin
  frmMain.sciEditor.LanguageManager.SelectedLanguage := Lang;
  frmMain.mnuHPAWN.Checked := Lang = 'Pawn';
  frmMain.mnuHCPP.Checked := Lang = 'C++';
  frmMain.mnuHHTML.Checked := Lang = 'HTML';
  frmMain.mnuHSQL.Checked := Lang = 'SQL';
  frmMain.mnuHXML.Checked := Lang = 'XML';
  frmMain.mnuHNone.Checked := Lang = 'null';
end;

procedure ShowProgress;
var i: integer;
begin
  if not Started then exit;
  
  frmMain.pnlLoading.Show;
  for i := 0 to frmMain.tsDocuments.Items.Count -1 do
    frmMain.tsDocuments.Items[i].Enabled := i = frmMain.tsDocuments.ActiveTabIndex;
  for i := 0 to frmMain.tsMain.Items.Count -1 do
    frmMain.tsMain.Items[i].Enabled := i = frmMain.tsMain.ActiveTabIndex;
  for i := 0 to frmMain.tbxMenu.Items.Count -1 do
    frmMain.tbxMenu.Items[i].Enabled := False;
  for i := 0 to frmMain.tbxToolbar.Items.Count -1 do
    frmMain.tbxToolbar.Items[i].Enabled := False;
  for i := 0 to frmMain.tbxEdit.Items.Count -1 do
    frmMain.tbxEdit.Items[i].Enabled := False;
  for i := 0 to frmMain.tbxCodeSnippets.Items.Count -1 do
    frmMain.tbxCodeSnippets.Items[i].Enabled := False;
  for i := 0 to frmMain.tcTools.Items.Count -1 do
    frmMain.tcTools.Items[i].Enabled := False;
  frmMain.ppmDocuments.Items.Enabled := False;
  frmMain.sciEditor.ReadOnly := True;
end;

procedure HideProgress;
var i: integer;
begin
  if not Started then exit;
  
  frmMain.pnlLoading.Hide;
  for i := 0 to frmMain.tsDocuments.Items.Count -1 do
    frmMain.tsDocuments.Items[i].Enabled := True;
  for i := 0 to frmMain.tsMain.Items.Count -1 do
    frmMain.tsMain.Items[i].Enabled := True;
  for i := 0 to frmMain.tbxMenu.Items.Count -1 do
    frmMain.tbxMenu.Items[i].Enabled := True;
  for i := 0 to frmMain.tbxToolbar.Items.Count -1 do
    frmMain.tbxToolbar.Items[i].Enabled := True;
  for i := 0 to frmMain.tbxEdit.Items.Count -1 do
    frmMain.tbxEdit.Items[i].Enabled := True;
  for i := 0 to frmMain.tbxCodeSnippets.Items.Count -1 do
    frmMain.tbxCodeSnippets.Items[i].Enabled := True;
  for i := 0 to frmMain.tcTools.Items.Count -1 do
    frmMain.tcTools.Items[i].Enabled := True;

  frmMain.tiCPP.Enabled := eCPP;
  frmMain.mnuNewHeaderCPP.Enabled := eCPP;
  frmMain.mnuNewModule.Enabled := eCPP;
  frmMain.mnuNewUnit.Enabled := eCPP;

  frmMain.ppmDocuments.Items.Enabled := True;
  frmMain.sciEditor.ReadOnly := False;
end;

{ TDocument }

constructor TDocument.Create(ACollection: TCollection;
  AHighlighter: String);
begin
  inherited Create(ACollection);
  FHighlighter := TDocCollection(ACollection).Highlighter;
  FCode := TStringList.Create;
  FModified := False;
end;

destructor TDocument.Destroy;
begin
  inherited Destroy;
  FCode.Free;
end;

function TDocument.Save: Boolean;
var i: integer;
    F: Textfile;
    sLines: TStringList;
    sNotes: String;
    eFound: Boolean;
begin
  if not Plugin_FileSave(FFilename, True) then begin
    Result := False;
    exit;
  end;

  Result := True;

  ShowProgress;
  try
    AssignFile(F, FFilename);
    Rewrite(F);
    if ActiveDoc = Self then begin
      sLines := TStringList(frmMain.sciEditor.Lines);
      sNotes := GetRTFText(frmMain.rtfNotes);
    end
    else begin
      sLines := Code;
      sNotes := NotesText;
    end;

    frmMain.pbLoading.Max := sLines.Count -1;
    frmMain.pbLoading.Position := 0;
    // ... save file...
    for i := 0 to sLines.Count -1 do begin
      if Cancel then begin
        CloseFile(F);
        Cancel := False;
        exit;
      end;

      WriteLn(F, sLines[i]);
      frmMain.pbLoading.Position := i;
      SetProgressStatus('Saving File...');
      Application.ProcessMessages;
    end;
    // ... and notes ...
    if frmSettings.optFileComment.Checked then begin
      WriteLn(F, GetCurrLang.CommentBoxStart + ' AMXX-Studio Notes - DO NOT MODIFY BELOW HERE');
      WriteLn(F, GetCurrLang.CommentBoxMiddle + sNotes);
      WriteLn(F, GetCurrLang.CommentBoxEnd);
      CloseFile(F);
    end
    else begin
      CloseFile(F);
      sLines := TStringList.Create;
      
      i := 0; // line 1 should be a comment
      if FileExists(ParamStr(0) + 'config\Notes.dat') then
        sLines.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'config\Notes.dat')
      else begin
        sLines.Clear; // something must be wrong, clear
        sLines.Add('AMXX-Studio Notes - DO NOT MODIFY THIS FILE');
      end;

      eFound := False;
      if sLines.Count > 2 then begin
        while i <> sLines.Count -1 do begin
          Inc(i, 2);
          if LowerCase(FFilename) = LowerCase(sLines[i -1]) then begin
            sLines[i] := sNotes;
            eFound := True;
            break;
          end;
        end;
      end;

      if not eFound then begin // no entry found
        sLines.Add(FFilename);
        sLines.Add(sNotes);
      end;
      sLines.SaveToFile(ExtractFilePath(ParamStr(0)) + 'config\Notes.dat');
      sLines.Free;
    end;
    
    FModified := False;
  except
    Result := False;
  end;

  HideProgress;
  Plugin_FileSave(FFilename, False);
end;

procedure TDocument.SetFileName(const Value: String);
begin
  FFileName := Value;
  FTitle := '< ' + IntToStr(Index +1) + #32 + ExtractFileName(Value) + ' >';
end;

function TDocument.Untitled: Boolean;
begin
  Result := Pos('\', FFilename) = 0;
end;

{ TDocCollection }

procedure TDocCollection.Activate(Document: Integer; RestoreCaret: Boolean; SaveLastDoc: Boolean = True);
begin
  Activate(TDocument(Items[Document]), RestoreCaret, SaveLastDoc);
end;

procedure TDocCollection.Activate(Document: TDocument; RestoreCaret: Boolean; SaveLastDoc: Boolean = True);
begin
  if not Plugin_DocChange(Document.Index, Document.FileName, Document.Highlighter, RestoreCaret, True) then begin
    Started := False;
    TSpTBXTabItem(frmMain.tsDocuments.Items[ActiveDoc.Index]).Checked := True;
    Started := True;
    exit;
  end;

  Screen.Cursor := crHourGlass;
  { Save old }
  if SaveLastDoc then begin
    ActiveDoc.Code.Text := frmMain.sciEditor.Lines.Text; // saving is fast, but loading is usually slow because of code-folding...
    ActiveDoc.Highlighter := frmMain.sciEditor.LanguageManager.SelectedLanguage;
    ActiveDoc.ReadOnly := frmMain.sciEditor.ReadOnly;
    ActiveDoc.SelStart := frmMain.sciEditor.SelStart;
    ActiveDoc.SelLength := frmMain.sciEditor.SelLength;
    ActiveDoc.TopLine := frmMain.sciEditor.GetFirstVisibleLine;
    ActiveDoc.Modified := frmMain.sciEditor.Modified;
    ActiveDoc.NotesText := GetRTFText(frmMain.rtfNotes);
  end;
  { Other }
  ActiveDoc := Document; // one global for save...
  FActiveDocument := Document; // ... and one for switch
  frmMain.sciEditor.EmptyUndoBuffer;
  { Load new }
  SelectLanguage(Document.Highlighter);
  frmMain.sciEditor.Lines.Clear;
  if Started then begin
    Started := False;
    frmMain.tsDocuments.Items[Document.Index].Checked := True;
    if (frmMain.Canvas.TextWidth(Document.FileName) > frmMain.mnuFilename.CustomWidth) and (not Document.Untitled) then
      frmMain.mnuFilename.Caption := ExtractFileName(Document.FileName)
    else
      frmMain.mnuFilename.Caption := Document.FileName;
    Started := True;
  end;
  
  frmMain.sciEditor.SetText(Document.Code.GetText);
  SetRTFText(frmMain.rtfNotes, Document.NotesText);
  frmMain.sciEditor.ReadOnly := Document.ReadOnly;
  
  if Document.Modified then
    frmMain.mnuModified.Caption := lModified
  else
    frmMain.mnuModified.Caption := '';
  frmMain.sciEditor.Modified := Document.Modified;

  if RestoreCaret then begin
    if (eConfig.ReadBool('Editor', 'CheckRestoreCaret', True)) and (eConfig.ReadInteger('Editor', 'CheckRestoreLines', 600) < Document.Code.Count) then begin
      Screen.Cursor := crDefault;
      exit;
    end;
       
    frmMain.sciEditor.LineScroll(0, (0 - frmMain.sciEditor.GetFirstVisibleLine) + Document.TopLine);
    frmMain.sciEditor.SelStart := Document.SelStart;
    frmMain.sciEditor.SelLength := Document.SelLength;
  end;
  Screen.Cursor := crDefault;
  Plugin_DocChange(Document.Index, Document.FileName, Document.Highlighter, RestoreCaret, False);
end;

function TDocCollection.Add(AFilename: String; AHighlighter: String = ''): TDocument;
var TabItem: TSpTBXTabItem;
begin
  if AHighlighter = '' then
    AHighlighter := Highlighter;

  Result := TDocument.Create(Self, AHighlighter);
  with Result do begin
    Highlighter := AHighlighter;
    FileName := AFileName;

    if Filename = '' then begin // Empty document
      if AHighlighter = 'Pawn' then begin
        Title := '< ' + IntToStr(Count) + ' Untitled.sma >';
        FileName := 'Untitled.sma';
      end
      else if AHighlighter = 'C++' then begin
        Title := '< ' + IntToStr(Count) + ' Untitled.cpp >';
        FileName := 'Untitled.cpp';
      end
      else if AHighlighter = 'HTML' then begin
        Title := '< ' + IntToStr(Count) + ' Untitled.html >';
        FileName := 'Untitled.html';
      end
      else if AHighlighter = 'SQL' then begin
        Title := '< ' + IntToStr(Count) + ' Untitled.sql >';
        FileName := 'Untitled.sql';
      end
      else if AHighlighter = 'XML' then begin
        Title := '< ' + IntToStr(Count) + ' Untitled.xml >';
        FileName := 'Untitled.xml';
      end
      else begin
        Title := '< ' + IntToStr(Count) + ' Untitled.txt >';
        FileName := 'Untitled.txt';
      end;
    end
    else
      Title := '< ' + IntToStr(Count) + #32 + ExtractFileName(AFilename) + ' >';

    if not Started then exit;
    if (Self = PawnProjects) and (frmMain.tsMain.ActiveTabIndex <> 0) then exit;
    if (Self = CPPProjects) and (frmMain.tsMain.ActiveTabIndex <> 1) then exit;
    if (Self = OtherProjects) and (frmMain.tsMain.ActiveTabIndex <> 2) then exit;

    TabItem := TSpTBXTabItem.Create(frmMain.tsDocuments);
    TabItem.Caption := Title;
    TabItem.OnSelect := frmMain.OnTabSelect;
    frmMain.tsDocuments.Items.Add(TabItem);
  end;
end;

procedure TDocCollection.Close(AIndex: Integer);
var Collection: TDocCollection;
    i: integer;
begin
  case frmMain.tsMain.ActiveTabIndex of
    0: Collection := PAWNProjects;
    1: Collection := CPPProjects;
    else Collection := OtherProjects;
  end;

  if Collection = Self then begin
    frmMain.tsDocuments.Items.Delete(AIndex);
    frmMain.tsDocuments.Refresh;
  end;
  
  Delete(AIndex);
  for i := 0 to Count -1 do
    TDocument(Items[i]).Title := '< ' + IntToStr(i +1) + #32 + ExtractFileName(TDocument(Items[i]).FileName) + ' >';

  if Collection = Self then begin
    for i := 0 to frmMain.tsDocuments.Items.Count -1 do
      TSpTBXTabItem(frmMain.tsDocuments.Items[i]).Caption := TDocument(Items[i]).Title;
  end;

  if Count = 0 then
    Add('', '');

  if (AIndex < Count) then
    Activate(AIndex, True, False)
  else
    Activate(0, True, False);
end;

constructor TDocCollection.Create(AHighlighter: String);
begin
  inherited Create(TDocument);
  Highlighter := AHighlighter;
  FActiveDocument := Add('');
end;

function TDocCollection.Open(AFilename: String; AHighlighter: String = ''): Integer;
var F: TextFile;
    i: integer;
    eString: String;
    eLines: TStringList;
begin
  Result := -1;

  if not Plugin_FileLoad(AFilename, True) then exit;

  if not FileExists(AFilename) then begin
    MessageBox(frmMain.Handle, PChar(lInvalidFile), 'AMXX-Studio', MB_ICONWARNING);
    exit;
  end;

  if Assigned(ActiveDoc) then begin
    ActiveDoc.Code.Text := frmMain.sciEditor.Lines.Text; // saving is fast, but loading is usually slow because of code-folding...
    ActiveDoc.Highlighter := frmMain.sciEditor.LanguageManager.SelectedLanguage;
    ActiveDoc.ReadOnly := frmMain.sciEditor.ReadOnly;
    ActiveDoc.SelStart := frmMain.sciEditor.SelStart;
    ActiveDoc.SelLength := frmMain.sciEditor.SelLength;
    ActiveDoc.TopLine := frmMain.sciEditor.GetFirstVisibleLine;
    ActiveDoc.Modified := frmMain.sciEditor.Modified;
    ActiveDoc.NotesText := GetRTFText(frmMain.rtfNotes);
  end;

  Screen.Cursor := crHourGlass;
  ShowProgress;

  AssignFile(F, AFilename);
  { ... count lines ... }
  i := 0;
  Reset(F);

  while not EOF(F) do begin
    ReadLn(F, eString);
    Inc(i, 1);
  end;
  { ... read lines ... }
  Reset(F);
  with Add(AFilename, AHighlighter) do begin
    ShowProgress;
    frmMain.pbLoading.Max := i;
    i := 0;
    while not EOF(F) do begin
      if Cancel then begin
        Cancel := False;
        CloseFile(F);
        exit;
      end;
      ReadLn(F, eString);
      if Assigned(GetCurrLang(AFilename)) then begin
         if (eString = GetCurrLang(AFilename).CommentBoxStart + ' AMXX-Studio Notes - DO NOT MODIFY BELOW HERE') and (frmSettings.optFileComment.Checked) then begin
           try
             ReadLn(F, eString);
             eString := Copy(eString, Length(GetCurrLang(AFilename).CommentBoxMiddle) +1, Length(eString));
             NotesText := eString;
             ReadLn(F, eString);
           except
            MessageBox(frmMain.Handle, PChar(lFailedLoadNotes), PChar(Application.Title), MB_ICONERROR);
          end;
        end
        else
          Code.Add(eString);
      end
      else
        Code.Add(eString); 
      frmMain.pbLoading.Position := i;
      SetProgressStatus('Loading file...');
      Inc(i, 1);
      Application.ProcessMessages;
    end;
    HideProgress;
    Result := Index;

    CloseFile(F);

    if frmSettings.optConfig.Checked then begin
      eLines := TStringList.Create;
      if FileExists(ExtractFilePath(ParamStr(0)) + 'config\Notes.dat') then
        eLines.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'config\Notes.dat')
      else begin
        eLines.Clear; // something must be wrong, clear
        eLines.Add('AMXX-Studio Notes - DO NOT MODIFY THIS FILE');
        eLines.SaveToFile(ExtractFilePath(ParamStr(0)) + 'config\Notes.dat');
      end;

      i := 0; // line 1 is a comment
      while i < eLines.Count -1 do begin
        Inc(i, 2);
        if LowerCase(FFilename) = LowerCase(eLines[i -1]) then begin
          NotesText := eLines[i];
          break;
        end;
      end;

      eLines.Free;
    end;
  end;
  Screen.Cursor := crDefault;

  if not Plugin_FileLoad(AFilename, False) then exit;
  
  if Result <> -1 then
    Activate(Result, False);
end;

function TDocCollection.Save(AIndex: Integer; AFilename: String): Boolean;
begin
  if AFilename <> '' then
    TDocument(Items[AIndex]).FileName := AFileName;

  Result := TDocument(Items[AIndex]).Save;
end;

procedure mIRCDDE(Service, Topic, Cmd: string);
var
  DDE: TDDEClientConv;
begin
  DDE := TDDEClientConv.Create(nil);
  try
    DDE.SetLink(Service, Topic);
    DDE.OpenLink;
    DDE.PokeData(Topic, PChar(Cmd));
  finally
    DDE.Free;
  end;
end;

function mIRCGet(Service, Topic, Item: string): String;
var
  DDE: TDDEClientConv;
begin
  DDE := TDDEClientConv.Create(nil);
  try
    DDE.SetLink(Service, Topic);
    Result := DDE.RequestData(Item);
  finally
    DDE.Free;
  end;
end;

function GetAllDirs: TStringList;
var eList: TStringList;
    i: integer;
begin
  eList := TStringList.Create;
  frmMain.IdFTP.List(eList);
  frmMain.IdFTP.DirectoryListing.LoadList(eList);
  eList.Clear;
  for i := 0 to frmMain.IdFTP.DirectoryListing.Count -1 do begin
    if frmMain.IdFTP.DirectoryListing.Items[i].ItemType = ditDirectory then
      eList.Add(frmMain.IdFTP.DirectoryListing.Items[i].FileName);
  end;
  Result := eList;
end;

procedure SetProxySettings;
begin
  with frmMain.IdFTP.ProxySettings do begin
    case frmSettings.cboProxy.ItemIndex of
      0: ProxyType := fpcmNone; // none
      1: ProxyType := fpcmHttpProxyWithFtp; // HTTP Proxy with FTP
      2: ProxyType := fpcmOpen; // Open
      3: ProxyType := fpcmSite; // Site
      4: ProxyType := fpcmTransparent; // Transparent
      5: ProxyType := fpcmUserPass; // User (Password)
      6: ProxyType := fpcmUserSite; // User (Site)
    end;      
    Host := frmSettings.txtProxyHost.Text;
    Port := StrToInt(frmSettings.txtProxyPort.Text);
    Username := frmSettings.txtProxyUsername.Text;
    Password := frmSettings.txtProxyPassword.Text;
  end;
end;

function TryConnect: Integer;
begin
  Result := 0;

  frmMain.IdFTP.Host := frmSettings.txtHost.Text;
  frmMain.IdFTP.Port := StrToInt(frmSettings.txtPort.Text);
  frmMain.IdFTP.Username := frmSettings.txtUsername.Text;
  frmMain.IdFTP.Passive := frmSettings.chkPassive.Checked;
  frmMain.IdFTP.Password := frmSettings.txtPassword.Text;
  SetProxySettings;

  try
    frmMain.IdFTP.Connect(True, 15000);
  except
    on E: Exception do begin
      if Pos('Login incorrect.', E.Message) <> 0 then begin // login failed
        MessageBox(Application.Handle, PChar(lLoginIncorrect), PChar(Application.Title), MB_ICONWARNING);
        Result := 1;
      end
      else if Pos('Host not found.', E.Message) <> 0 then begin // host not found
        MessageBox(Application.Handle, PChar(lHostNotFound), PChar(Application.Title), MB_ICONWARNING);
        Result := 2;
      end
      else if Pos('Connection refused.', E.Message) <> 0 then begin // wrong port (?)
        MessageBox(Application.Handle, PChar(lConnectionRefused), PChar(Application.Title), MB_ICONWARNING);
        Result := 3;
      end
      else if E is EIdProtocolReplyError then begin // wrong port
        MessageBox(Application.Handle, PChar(lWrongPort), PChar(Application.Title), MB_ICONWARNING);
        Result := 4;
      end
      else begin
        MessageBox(Application.Handle, PChar(E.Message), PChar(Application.Title), MB_ICONWARNING); // unknown error
        Result := 5;
      end;
    end;
  end;
end;

{ Initialization & Finalization }

initialization

PAWNProjects := TDocCollection.Create('Pawn');
CPPProjects := TDocCollection.Create('C++');
OtherProjects := TDocCollection.Create('null');
CurrProjects := 0;
ActiveDoc := PAWNProjects.ActiveDocument;

finalization

PAWNProjects.Free;
CPPProjects.Free;
OtherProjects.Free;

end.