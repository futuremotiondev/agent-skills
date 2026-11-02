// ============================================================================
//  Serialize-Duplicates-Pad2.pas — den4b ReNamer Pascal Script rule (v5)
// ----------------------------------------------------------------------------
//  Serializes files that share the same name AFTER all upstream rules run,
//  numbering the WHOLE group — including the first file — with a space +
//  TWO-DIGIT zero-padded counter:
//
//    Save 01.svg / Save 02.svg / ... / Search 14.svg
//
//  Unique post-rule names are left untouched. Counters outgrow the padding
//  naturally. Works with ANY combination of upstream rules — nothing is
//  replicated.
//
//  v4: DISK-BACKED TALLY. ReNamer re-initializes script state on every
//  preview run (globals only persist across files WITHIN one pass), so the
//  cross-pass tally lives in TALLY_FILE: each pass records every post-rule
//  FileName it receives and writes them out at the end; the next pass
//  loads that file and serializes from it.
//
//  v5: BYTE-SYMMETRIC TALLY I/O. The tally is plain UTF-8, no BOM, one
//  name per line, read back via FileReadContent + UTF8Decode rather than
//  FileReadTextLines — whose BOM handling leaked a phantom first entry
//  into the loaded tally, tripping the stale-tally popup on clean second
//  previews. The loader still tolerates a BOM (v4 tally files had one).
//
//  WORKFLOW — PREVIEW TWICE:
//    1st preview after adding the rule, or after any change to the file
//    table or rule stack: learning pass. Nothing renames; a popup reports
//    the tally stats. 2nd preview: serialization applied. Then Rename.
//  Self-policing: a stale-tally popup now fires ONLY when files/rules
//  genuinely changed since the tally was written — preview once more.
//  Silence after a serializing pass = tally in sync = safe to rename.
//
//  TALLY_FILE notes: shared by all four siblings on purpose — the tally
//  stores pre-serialization names, so it is padding-agnostic and you can
//  switch siblings between previews without relearning. Left over from a
//  previous batch it just triggers one stale-tally pass, which self-heals;
//  delete the file to force a fresh learning pass. Don't run two ReNamer
//  instances with this rule simultaneously (they share the file).
//
//  Sibling scripts — identical except the ZeroPad width on the marked line:
//    Serialize-Duplicates-NoPad.pas  ->  Save 1.svg
//    Serialize-Duplicates-Pad2.pas   ->  Save 01.svg   (this file)
//    Serialize-Duplicates-Pad3.pas   ->  Save 001.svg
//    Serialize-Duplicates-Pad4.pas   ->  Save 0001.svg
// ============================================================================

const
  // Cross-preview tally location. C:\Users\Public exists and is writable
  // on every Windows install; change it here if you prefer another spot.
  TALLY_FILE = 'C:\Users\Public\ReNamer-Serialize-Duplicates-Tally.txt';

var
  PrevNames: TWideStringArray; // tally loaded from TALLY_FILE: names...
  PrevCount: TIntegerArray;    // ...and how many files carried each one
  NextNum:   TIntegerArray;    // per PrevNames entry: next counter this pass
  SeenNames: TWideStringArray; // every post-rule name seen this pass, in order
  CurNames:  TWideStringArray; // distinct names seen this pass...
  CurCount:  TIntegerArray;    // ...with occurrence counts (for stats/sync)
  UsedNames: TWideStringArray; // names already emitted this pass
  LearnPass: Boolean;          // True when no usable tally was loaded

// ----------------------------------------------------------------------------
// Left-pads Value with zeros to at least Width digits.
// ----------------------------------------------------------------------------
function ZeroPad(Value, Width: Integer): WideString;
begin
  Result := IntToStr(Value);
  while Length(Result) < Width do
    Result := '0' + Result;
end;

// ----------------------------------------------------------------------------
// Case-insensitive linear search; returns index or -1 if not found.
// ----------------------------------------------------------------------------
function IndexOfName(const Arr: TWideStringArray; const S: WideString): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to Length(Arr) - 1 do
    if WideSameText(Arr[I], S) then
    begin
      Result := I;
      Break;
    end;
end;

// ----------------------------------------------------------------------------
// Appends S to a dynamic string array.
// ----------------------------------------------------------------------------
procedure AppendName(var Arr: TWideStringArray; const S: WideString);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[Length(Arr) - 1] := S;
end;

// ----------------------------------------------------------------------------
// LoadTally: reads TALLY_FILE (one post-rule name per line, written by the
// previous pass) and tallies it into PrevNames/PrevCount. Byte-symmetric
// with SaveTally: raw read + UTF8Decode, so no reader quirks can inject
// phantom entries. Missing or empty file leaves the tally empty, which
// makes this pass a learning pass.
// ----------------------------------------------------------------------------
procedure LoadTally;
var
  Raw: String;
  Text, L: WideString;
  Lines: TWideStringArray;
  I, K: Integer;
begin
  SetLength(PrevNames, 0);
  SetLength(PrevCount, 0);

  if WideFileExists(TALLY_FILE) then
  begin
    Raw := FileReadContent(TALLY_FILE);

    // Tolerate a UTF-8 BOM (v4 tallies had one; editors may add one).
    // Length guard wraps the indexing because this engine does not
    // short-circuit booleans; inside it, indexes 1..3 are always valid.
    if Length(Raw) >= 3 then
    begin
      if (Raw[1] = #$EF) and (Raw[2] = #$BB) and (Raw[3] = #$BF) then
        Raw := Copy(Raw, 4, Length(Raw) - 3);
    end;

    Text := UTF8Decode(Raw);

    // Split on LF, then strip stray CR / BOM residue from line ends —
    // handles CRLF and LF files identically.
    Lines := WideSplitString(Text, #10);
    for I := 0 to Length(Lines) - 1 do
    begin
      L := WideTrimChars(Lines[I], #13 + #65279);
      if L <> '' then
      begin
        K := IndexOfName(PrevNames, L);
        if K < 0 then
        begin
          AppendName(PrevNames, L);
          SetLength(PrevCount, Length(PrevCount) + 1);
          PrevCount[Length(PrevCount) - 1] := 1;
        end
        else
          PrevCount[K] := PrevCount[K] + 1;
      end;
    end;
  end;
end;

// ----------------------------------------------------------------------------
// SaveTally: writes every post-rule name seen this pass to TALLY_FILE —
// plain UTF-8, no BOM, one name per line. LoadTally mirrors this format
// byte for byte.
// ----------------------------------------------------------------------------
procedure SaveTally;
begin
  FileWriteContent(TALLY_FILE, UTF8Encode(WideJoinStrings(SeenNames, #13#10)));
end;

// ----------------------------------------------------------------------------
// StartPass: load the previous pass's tally from disk, reset all per-pass
// state. Runs on the first file of every pass.
// ----------------------------------------------------------------------------
procedure StartPass;
var
  I: Integer;
begin
  LoadTally;

  // Fresh per-pass counters: every group restarts numbering at 1.
  SetLength(NextNum, Length(PrevNames));
  for I := 0 to Length(NextNum) - 1 do
    NextNum[I] := 1;

  SetLength(SeenNames, 0);
  SetLength(CurNames, 0);
  SetLength(CurCount, 0);
  SetLength(UsedNames, 0);

  LearnPass := (Length(PrevNames) = 0);
end;

// ----------------------------------------------------------------------------
// RecordName: remembers a post-rule name for the tally file and tallies it
// for this pass's stats and sync check.
// ----------------------------------------------------------------------------
procedure RecordName(const Name: WideString);
var
  K: Integer;
begin
  AppendName(SeenNames, Name);

  K := IndexOfName(CurNames, Name);
  if K < 0 then
  begin
    AppendName(CurNames, Name);
    SetLength(CurCount, Length(CurCount) + 1);
    CurCount[Length(CurCount) - 1] := 1;
  end
  else
    CurCount[K] := CurCount[K] + 1;
end;

// ----------------------------------------------------------------------------
// TalliesInSync: True when this pass saw exactly the names and counts the
// loaded tally recorded — i.e. the serialization just applied was based on
// up-to-date information.
// ----------------------------------------------------------------------------
function TalliesInSync: Boolean;
var
  I, K: Integer;
begin
  Result := (Length(CurNames) = Length(PrevNames));
  if Result then
    for I := 0 to Length(CurNames) - 1 do
    begin
      // Nested lookup on purpose: no boolean short-circuiting in this
      // engine, so PrevCount[K] must never be touched while K might be -1.
      K := IndexOfName(PrevNames, CurNames[I]);
      if K < 0 then
        Result := False
      else if CurCount[I] <> PrevCount[K] then
        Result := False;
    end;
end;

// ----------------------------------------------------------------------------
// Main — runs once per file, in table order.
// ----------------------------------------------------------------------------
var
  K, I, DupGroups: Integer;
  Base, Ext, Cand: WideString;
begin
  if GetCurrentFileIndex = 1 then
    StartPass;

  // Record this file's post-rule name (BEFORE serialization) for the next
  // pass. FileName here is already the name after all upstream rules.
  RecordName(FileName);

  // Serialize using the tally written by the previous pass.
  K := IndexOfName(PrevNames, FileName);

  // Nested ifs on purpose: ReNamer's Pascal Script does not short-circuit
  // boolean expressions, so PrevCount[K] must never share a compound
  // condition with the K >= 0 guard.
  if K >= 0 then
  begin
    if PrevCount[K] > 1 then
    begin
      // Duplicate group: suffix the current name with the lowest free
      // counter for this group.
      Base := WideExtractBaseName(FileName);
      Ext  := WideExtractFileExt(FileName);
      repeat
        // >>> The ONLY line that differs between the four sibling scripts.
        Cand := Base + ' ' + ZeroPad(NextNum[K], 2) + Ext;
        NextNum[K] := NextNum[K] + 1;
      until (IndexOfName(UsedNames, Cand) < 0) and  // not already emitted
            (IndexOfName(PrevNames, Cand) < 0);     // not another file's name
      FileName := Cand;
    end;
  end;
  // Names the tally does not recognize fall through untouched (safe).

  // Record the emitted name so later files steer around it.
  AppendName(UsedNames, FileName);

  // End of pass: persist the tally for the next pass, then report verdict.
  if GetCurrentFileIndex = GetTotalNumberOfFiles then
  begin
    SaveTally;
    if not WideFileExists(TALLY_FILE) then
      ShowMessage(
        'Could not write the tally file:' + #13#10 + TALLY_FILE + #13#10 + #13#10 +
        'Serialization cannot work without it. Adjust TALLY_FILE in the' + #13#10 +
        'script to a writable location.')
    else if LearnPass then
    begin
      DupGroups := 0;
      for I := 0 to Length(CurCount) - 1 do
        if CurCount[I] > 1 then
          DupGroups := DupGroups + 1;
      ShowMessage(
        'Learning pass complete (nothing renamed yet).' + #13#10 +
        'Files: ' + IntToStr(GetTotalNumberOfFiles) + #13#10 +
        'Distinct post-rule names: ' + IntToStr(Length(CurNames)) + #13#10 +
        'Duplicate groups: ' + IntToStr(DupGroups) + #13#10 + #13#10 +
        'Tally saved. Preview again to apply serialization.');
    end
    else
    begin
      if not TalliesInSync then
        ShowMessage(
          'The file table or upstream rules changed since the tally was' + #13#10 +
          'written, so this preview used stale data. The tally has been' + #13#10 +
          'refreshed — preview again before renaming.');
    end;
  end;
end.
