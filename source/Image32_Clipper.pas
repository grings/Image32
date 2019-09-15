unit Image32_Clipper;

(*******************************************************************************
* Author    :  Angus Johnson                                                   *
* Version   :  1.17                                                            *
* Date      :  11 August 2019                                                  *
* Website   :  http://www.angusj.com                                           *
* Copyright :  Angus Johnson 2010-2019                                         *
* Purpose   :  Wrapper module for the Clipper library                          *
* License   :  http://www.boost.org/LICENSE_1_0.txt                            *
*******************************************************************************)

interface

uses
  ClipperCore, Clipper, ClipperOffset,
  Image32, Image32_Draw, Image32_Vector;

function InflatePolygon(const polygon: TArrayOfPointD;
  delta: Double; joinStyle: TJoinStyle = jsAuto;
  miterLimit: double = 2.0): TArrayOfArrayOfPointD;
function InflatePolygons(const polygons: TArrayOfArrayOfPointD;
  delta: Double; joinStyle: TJoinStyle = jsAuto;
  miterLimit: double = 2.0): TArrayOfArrayOfPointD;

function UnionPolygon(const polygon: TArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
function UnionPolygons(const polygon1, polygon2: TArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD; overload;
function UnionPolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD; overload;

function IntersectPolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;

function DifferencePolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;

implementation

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

function InflatePolygon(const polygon: TArrayOfPointD;
  delta: Double; joinStyle: TJoinStyle;
  miterLimit: double): TArrayOfArrayOfPointD;
var
  polygons: TArrayOfArrayOfPointD;
begin
  setLength(polygons, 1);
  polygons[0] := polygon;
  Result := InflatePolygons(polygons, delta, joinStyle, miterLimit);
end;
//------------------------------------------------------------------------------

function InflatePolygons(const polygons: TArrayOfArrayOfPointD;
  delta: Double; joinStyle: TJoinStyle;
  miterLimit: double): TArrayOfArrayOfPointD;
var
  jt: ClipperOffset.TJoinType;
begin
  case joinStyle of
    jsSquare: jt := jtSquare;
    jsMiter: jt :=  jtMiter;
    else jt := jtRound;
  end;
  Result := TArrayOfArrayOfPointD(ClipperOffset.ClipperOffsetPaths(
    ClipperCore.TPathsD(polygons), delta, jt, etPolygon, miterLimit));
end;
//------------------------------------------------------------------------------

function UnionPolygon(const polygon: TArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
begin
  with TClipperD.Create do
  try
    AddPath(ClipperCore.TPathD(polygon));
    Execute(ctUnion,
      ClipperCore.TFillRule(fillRule), ClipperCore.TPathsD(result));
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------

function UnionPolygons(const polygon1, polygon2: TArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
begin
  with TClipperD.Create do
  try
    AddPath(ClipperCore.TPathD(polygon1), ptSubject);
    AddPath(ClipperCore.TPathD(polygon2), ptClip);
    Execute(ctUnion,
      ClipperCore.TFillRule(fillRule), ClipperCore.TPathsD(result));
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------

function UnionPolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
begin
  with TClipperD.Create do
  try
    AddPaths(ClipperCore.TPathsD(polygons1), ptSubject);
    AddPaths(ClipperCore.TPathsD(polygons2), ptClip);
    Execute(ctUnion,
      ClipperCore.TFillRule(fillRule), ClipperCore.TPathsD(result));
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------

function IntersectPolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
begin
  with TClipperD.Create do
  try
    AddPaths(ClipperCore.TPathsD(polygons1), ptSubject);
    AddPaths(ClipperCore.TPathsD(polygons2), ptClip);
    Execute(ctIntersection,
      ClipperCore.TFillRule(fillRule), ClipperCore.TPathsD(result));
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------

function DifferencePolygons(const polygons1, polygons2: TArrayOfArrayOfPointD;
  fillRule: TFillRule): TArrayOfArrayOfPointD;
begin
  with TClipperD.Create do
  try
    AddPaths(ClipperCore.TPathsD(polygons1), ptSubject);
    AddPaths(ClipperCore.TPathsD(polygons2), ptClip);
    Execute(ctDifference,
      ClipperCore.TFillRule(fillRule), ClipperCore.TPathsD(result));
  finally
    Free;
  end;
end;
//------------------------------------------------------------------------------

end.
