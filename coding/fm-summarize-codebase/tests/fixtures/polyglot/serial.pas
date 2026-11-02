const
  WIDTH = 3;

var
  Count: Integer;

// ---------------------------------------------------------------
// Left-pads Value with zeros to Width digits.
// ---------------------------------------------------------------
function ZeroPad(Value, Width: Integer): String;
begin
  Result := IntToStr(Value);
  while Length(Result) < Width do
    Result := '0' + Result;
end;

procedure Bump;
begin
  Count := Count + 1;
end;

begin
  Bump;
  FileName := ZeroPad(Count, WIDTH) + ' ' + FileName;
end.
